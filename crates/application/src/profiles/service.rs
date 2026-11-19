use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::time::Duration;

use futures::Stream;
use futures::future::BoxFuture;
use kumo_domain::profiles::{
    Profile, ProfileActivity, ProfileChanges, ProfileError, ProfileId, ProfileStore,
};
use kumo_domain::time::Timestamp;
use tokio::sync::{OnceCell, watch};

/// How often activity (agents, terminals) is re-read for watchers.
const ACTIVITY_EVERY: Duration = Duration::from_secs(1);
/// How long a deleted profile's folder is waited for: 2 s in all.
const REMOVE_TRIES: u32 = 40;
const REMOVE_RETRY: Duration = Duration::from_millis(50);

/// What one profile runs: its stores and services. Isolation comes from
/// here: a bundle only reaches its own profile's data.
pub trait ProfileBundle: Send + Sync + 'static {
    fn activity(&self) -> ProfileActivity;
    /// Applies settings that can change while it's open.
    fn configure(&self, profile: &Profile);
    /// Stops what runs in it (agents, terminals) before it's deleted.
    fn close(&self) -> BoxFuture<'_, ()>;
    /// Copies `source`'s agent commands (never sign-ins or sessions).
    fn copy_agents_from<'a>(&'a self, source: &'a Self) -> BoxFuture<'a, Result<(), ProfileError>>;
}

/// Builds a profile's bundle (the composition root knows how).
pub trait OpenProfile<B>: Send + Sync + 'static {
    fn open<'a>(&'a self, profile: &'a Profile) -> BoxFuture<'a, Result<B, ProfileError>>;
    /// Namespaces and repositories of a profile that isn't open, read
    /// without starting anything. Blocks.
    fn stats(&self, profile: &Profile) -> ProfileActivity;
    /// Removes what a deleted profile kept outside its data folder (its
    /// keychain tokens). Blocks.
    fn forget(&self, profile: &Profile) -> Result<(), ProfileError>;
}

/// A profile and what it has and runs right now.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProfileView {
    pub profile: Profile,
    pub activity: ProfileActivity,
}

type Slot<B> = Arc<OnceCell<Arc<B>>>;

/// The registry of profiles and their open bundles.
///
/// Bundles stay open once opened, so the agents and terminals of a profile
/// the user switched away from keep running. Only deleting a profile
/// closes its bundle.
pub struct ProfileService<B> {
    store: Arc<dyn ProfileStore>,
    opener: Arc<dyn OpenProfile<B>>,
    /// Sorted by position.
    profiles: Mutex<Vec<Profile>>,
    bundles: Mutex<HashMap<ProfileId, Slot<B>>>,
    /// Counts of closed profiles, read once (nothing changes them).
    stats: Mutex<HashMap<ProfileId, ProfileActivity>>,
    /// Profiles being deleted: nothing opens them or reads their data.
    deleting: Mutex<HashSet<ProfileId>>,
    windows: Arc<Windows>,
    /// Serializes registry changes.
    writes: tokio::sync::Mutex<()>,
    activity_every: Duration,
}

impl<B> std::fmt::Debug for ProfileService<B> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ProfileService")
            .field("profiles", &*lock(&self.profiles))
            .finish_non_exhaustive()
    }
}

impl<B: ProfileBundle> ProfileService<B> {
    /// Loads the registry. The first time (a data folder from before
    /// profiles), it creates the default profile around the existing data.
    pub fn load(
        store: Arc<dyn ProfileStore>,
        opener: Arc<dyn OpenProfile<B>>,
    ) -> Result<Self, ProfileError> {
        let profiles = match store.load()? {
            Some(profiles) if !profiles.is_empty() => profiles,
            _ => {
                let first = vec![Profile::first(Timestamp::now())];
                store.save(&first)?;
                first
            }
        };
        let mut profiles = profiles;
        profiles.sort_by_key(|p| p.position);
        // Folders of profiles deleted while still in use.
        sweep(store.as_ref(), &profiles);
        Ok(Self {
            store,
            opener,
            profiles: Mutex::new(profiles),
            bundles: Mutex::default(),
            stats: Mutex::default(),
            deleting: Mutex::default(),
            windows: Arc::new(Windows::default()),
            writes: tokio::sync::Mutex::new(()),
            activity_every: ACTIVITY_EVERY,
        })
    }

    #[cfg(test)]
    pub(super) fn with_activity_every(mut self, every: Duration) -> Self {
        self.activity_every = every;
        self
    }

    /// In switcher order.
    pub fn profiles(&self) -> Vec<Profile> {
        lock(&self.profiles).clone()
    }

    /// The bundle of the profile a request names (`None` or empty: the
    /// default one, for clients from before profiles). Opens it the first
    /// time. A profile being deleted is gone already.
    pub async fn resolve(&self, id: Option<&str>) -> Result<Arc<B>, ProfileError> {
        let profile = self.find(id)?;
        let gone = || ProfileError::NotFound(profile.id.to_string());
        let slot = {
            let mut bundles = lock(&self.bundles);
            if self.is_deleting(&profile.id) {
                return Err(gone());
            }
            Arc::clone(bundles.entry(profile.id.clone()).or_default())
        };
        let bundle = slot
            .get_or_try_init(|| async {
                let bundle = self.opener.open(&profile).await?;
                bundle.configure(&profile);
                Ok::<_, ProfileError>(Arc::new(bundle))
            })
            .await?;
        // Its deletion started while it opened: what it started goes too.
        if self.is_deleting(&profile.id) || self.find(Some(profile.id.as_str())).is_err() {
            bundle.close().await;
            return Err(gone());
        }
        Ok(Arc::clone(bundle))
    }

    fn is_deleting(&self, id: &ProfileId) -> bool {
        lock(&self.deleting).contains(id)
    }

    /// Every profile with its activity, in switcher order.
    pub async fn list(&self) -> Vec<ProfileView> {
        let profiles = self.profiles();
        let mut views = Vec::with_capacity(profiles.len());
        for profile in profiles {
            let activity = self.activity(&profile).await;
            views.push(ProfileView { profile, activity });
        }
        views
    }

    /// Every profile now, then again whenever one changes or what runs in
    /// them does.
    pub fn watch(self: &Arc<Self>) -> impl Stream<Item = Vec<ProfileView>> + Send + 'static {
        let changes = self.windows.changed.subscribe();
        let state = (Arc::clone(self), changes, None::<Vec<ProfileView>>);
        futures::stream::unfold(state, |(this, mut changes, last)| async move {
            loop {
                if last.is_some() {
                    tokio::select! {
                        _ = changes.changed() => {}
                        () = tokio::time::sleep(this.activity_every) => {}
                    }
                }
                let views = this.list().await;
                if last.as_ref() != Some(&views) {
                    return Some((views.clone(), (this, changes, Some(views))));
                }
            }
        })
    }

    /// A window showing `id` (`None`: the default profile): the profile
    /// can't be deleted while the returned guard lives.
    pub fn connect(&self, id: Option<&str>) -> Result<Window, ProfileError> {
        let id = self.find(id)?.id;
        *lock(&self.windows.open).entry(id.clone()).or_default() += 1;
        Ok(Window {
            id,
            windows: Arc::clone(&self.windows),
        })
    }

    /// A new profile, last in the switcher. `copy_agents_from` copies that
    /// profile's agent commands.
    pub async fn create(
        &self,
        name: &str,
        color: &str,
        copy_agents_from: Option<&str>,
    ) -> Result<Profile, ProfileError> {
        let source = match copy_agents_from.filter(|id| !id.is_empty()) {
            Some(id) => Some(self.resolve(Some(id)).await?),
            None => None,
        };
        let profile = {
            let _write = self.writes.lock().await;
            let mut profiles = self.profiles();
            // A deleted profile's folder still there isn't a new one's.
            let leftovers = sweep(self.store.as_ref(), &profiles);
            let id = ProfileId::from_name(name, |id| {
                profiles.iter().any(|p| &p.id == id) || leftovers.contains(id)
            });
            let position = u32::try_from(profiles.len()).unwrap_or(u32::MAX);
            let profile = Profile::new(id, name, color, position, Timestamp::now())?;
            profiles.push(profile.clone());
            self.commit(profiles)?;
            profile
        };
        if let Some(source) = source {
            let created = self.resolve(Some(profile.id.as_str())).await?;
            created.copy_agents_from(&source).await?;
        }
        Ok(profile)
    }

    pub async fn update(&self, id: &str, changes: ProfileChanges) -> Result<Profile, ProfileError> {
        let _write = self.writes.lock().await;
        let mut profiles = self.profiles();
        let index = profiles
            .iter()
            .position(|p| p.id.as_str() == id)
            .ok_or_else(|| ProfileError::NotFound(id.to_owned()))?;
        let position = changes.position;
        profiles[index].apply(changes)?;
        if let Some(position) = position {
            let moved = profiles.remove(index);
            let to = usize::try_from(position)
                .unwrap_or(usize::MAX)
                .min(profiles.len());
            profiles.insert(to, moved);
        }
        let updated = profiles
            .iter()
            .find(|p| p.id.as_str() == id)
            .cloned()
            .ok_or_else(|| ProfileError::NotFound(id.to_owned()))?;
        self.commit(profiles)?;
        if let Some(bundle) = self.open_bundle(&updated.id) {
            bundle.configure(&updated);
        }
        self.find(Some(id))
    }

    /// Stops what runs in the profile and deletes its data. Repositories
    /// and worktrees on disk are never touched.
    pub async fn delete(&self, id: &str) -> Result<(), ProfileError> {
        let _write = self.writes.lock().await;
        let profile = self.find(Some(id))?;
        if profile.is_default() {
            return Err(ProfileError::DefaultProfile);
        }
        let mut profiles = self.profiles();
        if profiles.len() <= 1 {
            return Err(ProfileError::LastProfile);
        }
        if self.windows.count(&profile.id) > 0 {
            return Err(ProfileError::InUse(profile.id.to_string()));
        }
        // From here nothing opens it again (see `resolve`, `activity`).
        let _deleting = Deleting::start(&self.deleting, &profile.id);
        if let Some(bundle) = self.open_bundle(&profile.id) {
            bundle.close().await;
        }
        lock(&self.bundles).remove(&profile.id);
        lock(&self.stats).remove(&profile.id);
        // Marked before it's unlisted: a folder that outlives the profile
        // is known to be garbage, and swept later.
        self.store.mark_deleted(&profile.id)?;
        // Unlisted next: a list that can't be saved keeps the profile, and
        // its data, unmarked (a later sweep would take it otherwise).
        profiles.retain(|p| p.id != profile.id);
        if let Err(error) = self.commit(profiles) {
            if let Err(unmark) = self.store.unmark_deleted(&profile.id) {
                tracing::warn!(profile = %profile.id, error = %unmark, "deletion mark left behind");
            }
            return Err(error);
        }
        // Leftover tokens are harmless under a name no profile uses.
        if let Err(error) = self.opener.forget(&profile) {
            tracing::warn!(profile = %profile.id, %error, "keychain tokens left behind");
        }
        if let Err(error) = self.remove_data_once_released(&profile.id).await {
            tracing::warn!(
                profile = %profile.id,
                %error,
                "deleted profile's folder left behind, removed on a later start"
            );
        }
        Ok(())
    }

    /// Removes the profile's folder. What the closed bundle ran lets go
    /// of its database a moment later (its tasks end on their own), and
    /// Windows can't delete a file still open: tries again for a while.
    async fn remove_data_once_released(&self, id: &ProfileId) -> Result<(), ProfileError> {
        let mut tries = 0;
        loop {
            match self.store.remove_data(id) {
                Err(ProfileError::Storage(error)) if tries < REMOVE_TRIES => {
                    tracing::debug!(profile = %id, %error, "profile folder busy, trying again");
                    tries += 1;
                    tokio::time::sleep(REMOVE_RETRY).await;
                }
                result => return result,
            }
        }
    }

    /// The profile `id` names (None or empty: the default one).
    pub fn find_profile(&self, id: Option<&str>) -> Result<Profile, ProfileError> {
        self.find(id)
    }

    fn find(&self, id: Option<&str>) -> Result<Profile, ProfileError> {
        let id = id.filter(|id| !id.is_empty()).unwrap_or(ProfileId::DEFAULT);
        lock(&self.profiles)
            .iter()
            .find(|p| p.id.as_str() == id)
            .cloned()
            .ok_or_else(|| ProfileError::NotFound(id.to_owned()))
    }

    /// The bundle if it's already open; never opens one.
    fn open_bundle(&self, id: &ProfileId) -> Option<Arc<B>> {
        lock(&self.bundles)
            .get(id)
            .and_then(|slot| slot.get().cloned())
    }

    async fn activity(&self, profile: &Profile) -> ProfileActivity {
        if let Some(bundle) = self.open_bundle(&profile.id) {
            return bundle.activity();
        }
        if let Some(stats) = lock(&self.stats).get(&profile.id) {
            return *stats;
        }
        // Its data is going: never opened to count it.
        if self.is_deleting(&profile.id) {
            return ProfileActivity::default();
        }
        let (opener, closed) = (Arc::clone(&self.opener), profile.clone());
        let stats = tokio::task::spawn_blocking(move || opener.stats(&closed))
            .await
            .unwrap_or_default();
        if !self.is_deleting(&profile.id) {
            lock(&self.stats).insert(profile.id.clone(), stats);
        }
        stats
    }

    /// Renumbers positions, saves, and tells watchers.
    fn commit(&self, mut profiles: Vec<Profile>) -> Result<(), ProfileError> {
        for (position, profile) in profiles.iter_mut().enumerate() {
            profile.position = u32::try_from(position).unwrap_or(u32::MAX);
        }
        self.store.save(&profiles)?;
        *lock(&self.profiles) = profiles;
        self.windows.changed.send_modify(|n| *n += 1);
        Ok(())
    }
}

/// Windows connected per profile, and a tick on every registry change.
#[derive(Debug)]
struct Windows {
    open: Mutex<HashMap<ProfileId, usize>>,
    changed: watch::Sender<u64>,
}

impl Default for Windows {
    fn default() -> Self {
        Self {
            open: Mutex::default(),
            changed: watch::channel(0).0,
        }
    }
}

impl Windows {
    fn count(&self, id: &ProfileId) -> usize {
        lock(&self.open).get(id).copied().unwrap_or(0)
    }
}

/// A window showing a profile (see [`ProfileService::connect`]).
#[derive(Debug)]
pub struct Window {
    id: ProfileId,
    windows: Arc<Windows>,
}

impl Window {
    pub fn profile(&self) -> &ProfileId {
        &self.id
    }
}

impl Drop for Window {
    fn drop(&mut self) {
        let mut open = lock(&self.windows.open);
        if let Some(count) = open.get_mut(&self.id) {
            *count = count.saturating_sub(1);
            if *count == 0 {
                open.remove(&self.id);
            }
        }
    }
}

fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}

/// Removes the folders of deleted profiles that outlived them (see
/// [`ProfileStore::mark_deleted`]); the ids of those still in use.
fn sweep(store: &dyn ProfileStore, listed: &[Profile]) -> HashSet<ProfileId> {
    let listed: Vec<ProfileId> = listed.iter().map(|p| p.id.clone()).collect();
    store.sweep_deleted(&listed).into_iter().collect()
}

/// A profile being deleted, until dropped.
struct Deleting<'a> {
    deleting: &'a Mutex<HashSet<ProfileId>>,
    id: ProfileId,
}

impl<'a> Deleting<'a> {
    fn start(deleting: &'a Mutex<HashSet<ProfileId>>, id: &ProfileId) -> Self {
        lock(deleting).insert(id.clone());
        Self {
            deleting,
            id: id.clone(),
        }
    }
}

impl Drop for Deleting<'_> {
    fn drop(&mut self) {
        lock(self.deleting).remove(&self.id);
    }
}
