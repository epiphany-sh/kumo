use std::collections::HashMap;
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
        Ok(Self {
            store,
            opener,
            profiles: Mutex::new(profiles),
            bundles: Mutex::default(),
            stats: Mutex::default(),
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
    /// time.
    pub async fn resolve(&self, id: Option<&str>) -> Result<Arc<B>, ProfileError> {
        let profile = self.find(id)?;
        let slot = Arc::clone(lock(&self.bundles).entry(profile.id.clone()).or_default());
        let bundle = slot
            .get_or_try_init(|| async {
                let bundle = self.opener.open(&profile).await?;
                bundle.configure(&profile);
                Ok::<_, ProfileError>(Arc::new(bundle))
            })
            .await?;
        Ok(Arc::clone(bundle))
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
            let id = ProfileId::from_name(name, |id| profiles.iter().any(|p| &p.id == id));
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
        if let Some(bundle) = self.open_bundle(&profile.id) {
            bundle.close().await;
        }
        lock(&self.bundles).remove(&profile.id);
        lock(&self.stats).remove(&profile.id);
        profiles.retain(|p| p.id != profile.id);
        self.commit(profiles)?;
        // Leftover tokens are harmless under a name no profile uses; the
        // folder goes anyway.
        if let Err(error) = self.opener.forget(&profile) {
            tracing::warn!(profile = %profile.id, %error, "keychain tokens left behind");
        }
        self.store.remove_data(&profile.id)
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
        let (opener, closed) = (Arc::clone(&self.opener), profile.clone());
        let stats = tokio::task::spawn_blocking(move || opener.stats(&closed))
            .await
            .unwrap_or_default();
        lock(&self.stats).insert(profile.id.clone(), stats);
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
