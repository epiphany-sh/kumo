use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use futures::StreamExt;
use futures::future::BoxFuture;
use kumo_domain::profiles::{
    Profile, ProfileActivity, ProfileChanges, ProfileError, ProfileId, ProfileStore,
};

use super::{OpenProfile, ProfileBundle, ProfileService};

#[derive(Default)]
struct MemoryStore {
    saved: Mutex<Option<Vec<Profile>>>,
    removed: Mutex<Vec<ProfileId>>,
    /// How many removals fail before one works, as a file still open
    /// fails them on Windows.
    busy_removals: AtomicU32,
    failing_saves: AtomicBool,
    /// Folders marked as being deleted (and not removed yet).
    marked: Mutex<Vec<ProfileId>>,
}

impl ProfileStore for MemoryStore {
    fn load(&self) -> Result<Option<Vec<Profile>>, ProfileError> {
        Ok(self.saved.lock().unwrap().clone())
    }
    fn save(&self, profiles: &[Profile]) -> Result<(), ProfileError> {
        if self.failing_saves.load(Ordering::SeqCst) {
            return Err(ProfileError::Storage("profiles.json: disk full".into()));
        }
        *self.saved.lock().unwrap() = Some(profiles.to_vec());
        Ok(())
    }
    fn mark_deleted(&self, id: &ProfileId) -> Result<(), ProfileError> {
        self.marked.lock().unwrap().push(id.clone());
        Ok(())
    }
    fn unmark_deleted(&self, id: &ProfileId) -> Result<(), ProfileError> {
        self.marked.lock().unwrap().retain(|m| m != id);
        Ok(())
    }
    fn sweep_deleted(&self, listed: &[ProfileId]) -> Vec<ProfileId> {
        let marked = std::mem::take(&mut *self.marked.lock().unwrap());
        let mut left = Vec::new();
        for id in marked {
            if listed.contains(&id) {
                self.marked.lock().unwrap().push(id);
            } else if self.remove_data(&id).is_err() {
                self.marked.lock().unwrap().push(id.clone());
                left.push(id);
            }
        }
        left
    }
    fn remove_data(&self, id: &ProfileId) -> Result<(), ProfileError> {
        let busy = self.busy_removals.load(Ordering::SeqCst);
        if busy > 0 {
            self.busy_removals.store(busy - 1, Ordering::SeqCst);
            return Err(ProfileError::Storage("kumo.db: in use".into()));
        }
        self.marked.lock().unwrap().retain(|m| m != id);
        self.removed.lock().unwrap().push(id.clone());
        Ok(())
    }
}

/// A bundle that records what happens to it.
#[derive(Default)]
struct FakeBundle {
    id: String,
    running: AtomicU32,
    closed: AtomicU32,
    /// How long closing it takes.
    close_takes: Duration,
    worktrees_dir: Mutex<String>,
    agents: Mutex<Vec<String>>,
}

impl ProfileBundle for FakeBundle {
    fn activity(&self) -> ProfileActivity {
        ProfileActivity {
            agents_running: self.running.load(Ordering::SeqCst),
            ..ProfileActivity::default()
        }
    }
    fn configure(&self, profile: &Profile) {
        *self.worktrees_dir.lock().unwrap() = profile.worktrees_dir.clone();
    }
    fn close(&self) -> BoxFuture<'_, ()> {
        self.closed.fetch_add(1, Ordering::SeqCst);
        let takes = self.close_takes;
        Box::pin(async move { tokio::time::sleep(takes).await })
    }
    fn copy_agents_from<'a>(&'a self, source: &'a Self) -> BoxFuture<'a, Result<(), ProfileError>> {
        let copied = source.agents.lock().unwrap().clone();
        self.agents.lock().unwrap().extend(copied);
        Box::pin(async { Ok(()) })
    }
}

#[derive(Default)]
struct FakeOpener {
    opened: AtomicU32,
    forgotten: Mutex<Vec<String>>,
    /// How long closing the bundles it opens takes.
    close_takes: Mutex<Duration>,
    /// How many times a profile other than the default was read closed.
    stats_read: AtomicU32,
}

impl OpenProfile<FakeBundle> for FakeOpener {
    fn open<'a>(&'a self, profile: &'a Profile) -> BoxFuture<'a, Result<FakeBundle, ProfileError>> {
        self.opened.fetch_add(1, Ordering::SeqCst);
        let bundle = FakeBundle {
            id: profile.id.to_string(),
            agents: Mutex::new(vec![format!("agent of {}", profile.id)]),
            close_takes: *self.close_takes.lock().unwrap(),
            ..FakeBundle::default()
        };
        Box::pin(async move {
            tokio::task::yield_now().await;
            Ok(bundle)
        })
    }
    fn stats(&self, profile: &Profile) -> ProfileActivity {
        if !profile.is_default() {
            self.stats_read.fetch_add(1, Ordering::SeqCst);
        }
        ProfileActivity {
            namespaces: 7,
            ..ProfileActivity::default()
        }
    }
    fn forget(&self, profile: &Profile) -> Result<(), ProfileError> {
        self.forgotten.lock().unwrap().push(profile.id.to_string());
        Ok(())
    }
}

struct Setup {
    service: Arc<ProfileService<FakeBundle>>,
    store: Arc<MemoryStore>,
    opener: Arc<FakeOpener>,
}

fn setup() -> Setup {
    let store = Arc::new(MemoryStore::default());
    let opener = Arc::new(FakeOpener::default());
    let service = ProfileService::load(store.clone(), opener.clone())
        .unwrap()
        .with_activity_every(Duration::from_millis(10));
    Setup {
        service: Arc::new(service),
        store,
        opener,
    }
}

#[tokio::test]
async fn first_start_creates_the_default_profile_and_saves_it() {
    let s = setup();
    let profiles = s.service.profiles();
    assert_eq!(profiles.len(), 1);
    assert!(profiles[0].is_default());
    assert!(profiles[0].name.is_empty());
    assert_eq!(s.store.load().unwrap().unwrap(), profiles);

    // Loading again keeps it (no second default).
    let again = ProfileService::load(s.store.clone(), Arc::new(FakeOpener::default())).unwrap();
    assert_eq!(again.profiles(), profiles);
}

#[tokio::test]
async fn requests_without_a_profile_go_to_the_default_one_and_unknown_ids_fail() {
    let s = setup();
    assert_eq!(s.service.resolve(None).await.unwrap().id, "default");
    assert_eq!(s.service.resolve(Some("")).await.unwrap().id, "default");
    assert_eq!(
        s.service.resolve(Some("nope")).await.err(),
        Some(ProfileError::NotFound("nope".into()))
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn a_bundle_is_opened_once_even_under_concurrent_requests() {
    let s = setup();
    let created = s.service.create("Workspace 1", "", None).await.unwrap();
    let id = created.id.to_string();
    let requests = (0..16).map(|_| {
        let (service, id) = (Arc::clone(&s.service), id.clone());
        tokio::spawn(async move { service.resolve(Some(&id)).await.unwrap() })
    });
    let bundles = futures::future::join_all(requests).await;
    let first = bundles[0].as_ref().unwrap();
    assert!(
        bundles
            .iter()
            .all(|b| Arc::ptr_eq(b.as_ref().unwrap(), first))
    );
    assert_eq!(s.opener.opened.load(Ordering::SeqCst), 1);
    assert_eq!(*first.worktrees_dir.lock().unwrap(), "~/wt/workspace-1");
}

#[tokio::test]
async fn create_gives_unique_slugs_and_positions() {
    let s = setup();
    let a = s
        .service
        .create("Workspace 1", "#112233", None)
        .await
        .unwrap();
    let b = s.service.create("Workspace 1", "", None).await.unwrap();
    assert_eq!((a.id.as_str(), a.position), ("workspace-1", 1));
    assert_eq!((b.id.as_str(), b.position), ("workspace-1-2", 2));
    assert_eq!(s.store.load().unwrap().unwrap().len(), 3);
    assert_eq!(
        s.service.create(" ", "", None).await.err(),
        Some(ProfileError::EmptyName)
    );
}

#[tokio::test]
async fn create_can_copy_agent_commands_from_another_profile() {
    let s = setup();
    let created = s
        .service
        .create("Workspace 2", "", Some("default"))
        .await
        .unwrap();
    let bundle = s.service.resolve(Some(created.id.as_str())).await.unwrap();
    assert_eq!(
        *bundle.agents.lock().unwrap(),
        ["agent of workspace-2", "agent of default"]
    );
}

#[tokio::test]
async fn update_changes_fields_reorders_and_reconfigures_open_bundles() {
    let s = setup();
    s.service.create("Workspace 1", "", None).await.unwrap();
    s.service.create("Workspace 2", "", None).await.unwrap();
    let open = s.service.resolve(Some("workspace-2")).await.unwrap();

    let updated = s
        .service
        .update(
            "workspace-2",
            ProfileChanges {
                name: Some("Workspace Two".into()),
                position: Some(0),
                worktrees_dir: Some("~/code/two".into()),
                ..ProfileChanges::default()
            },
        )
        .await
        .unwrap();
    assert_eq!(updated.name, "Workspace Two");
    assert_eq!(updated.id.as_str(), "workspace-2", "renaming keeps the id");
    let order: Vec<_> = s
        .service
        .profiles()
        .into_iter()
        .map(|p| (p.id.to_string(), p.position))
        .collect();
    assert_eq!(
        order,
        [
            ("workspace-2".into(), 0),
            ("default".into(), 1),
            ("workspace-1".into(), 2)
        ]
    );
    assert_eq!(*open.worktrees_dir.lock().unwrap(), "~/code/two");

    let bad = s
        .service
        .update(
            "workspace-1",
            ProfileChanges {
                color: Some("red".into()),
                ..ProfileChanges::default()
            },
        )
        .await;
    assert_eq!(bad.err(), Some(ProfileError::InvalidColor("red".into())));
    assert_eq!(
        s.service
            .update("nope", ProfileChanges::default())
            .await
            .err(),
        Some(ProfileError::NotFound("nope".into()))
    );
}

#[tokio::test]
async fn delete_refuses_the_default_the_last_and_one_in_use() {
    let s = setup();
    assert_eq!(
        s.service.delete("default").await.err(),
        Some(ProfileError::DefaultProfile)
    );

    s.service.create("Workspace 1", "", None).await.unwrap();
    let window = s.service.connect(Some("workspace-1")).unwrap();
    assert_eq!(
        s.service.delete("workspace-1").await.err(),
        Some(ProfileError::InUse("workspace-1".into()))
    );
    drop(window);
    s.service.delete("workspace-1").await.unwrap();
    assert_eq!(s.service.profiles().len(), 1);
    assert_eq!(
        s.store.removed.lock().unwrap().as_slice(),
        [ProfileId::parse("workspace-1").unwrap()]
    );
}

#[tokio::test]
async fn delete_closes_the_open_bundle_and_forgets_it() {
    let s = setup();
    s.service.create("Workspace 1", "", None).await.unwrap();
    let bundle = s.service.resolve(Some("workspace-1")).await.unwrap();
    s.service.delete("workspace-1").await.unwrap();
    assert_eq!(bundle.closed.load(Ordering::SeqCst), 1);
    assert_eq!(*s.opener.forgotten.lock().unwrap(), ["workspace-1"]);
    assert_eq!(
        s.service.resolve(Some("workspace-1")).await.err(),
        Some(ProfileError::NotFound("workspace-1".into()))
    );
}

/// What the closed profile ran lets go of its files a moment later.
#[tokio::test]
async fn delete_waits_for_the_profile_s_files_to_be_let_go() {
    let s = setup();
    s.service.create("Workspace 1", "", None).await.unwrap();
    s.store.busy_removals.store(3, Ordering::SeqCst);
    s.service.delete("workspace-1").await.unwrap();
    assert_eq!(s.service.profiles().len(), 1);
    assert_eq!(s.store.removed.lock().unwrap().len(), 1);
}

/// A list that can't be saved keeps the profile, and its data.
#[tokio::test]
async fn delete_keeps_the_data_when_the_list_cannot_be_saved() {
    let s = setup();
    s.service.create("Workspace 1", "", None).await.unwrap();
    s.store.failing_saves.store(true, Ordering::SeqCst);
    assert!(matches!(
        s.service.delete("workspace-1").await,
        Err(ProfileError::Storage(_))
    ));
    assert_eq!(s.service.profiles().len(), 2);
    assert!(s.store.removed.lock().unwrap().is_empty());
    assert!(s.opener.forgotten.lock().unwrap().is_empty());
    // Not marked either: a later sweep would take a profile still kept.
    assert!(s.store.marked.lock().unwrap().is_empty());

    s.store.failing_saves.store(false, Ordering::SeqCst);
    s.service.delete("workspace-1").await.unwrap();
    assert_eq!(s.service.profiles().len(), 1);
}

/// A folder that can't go is left marked, and swept on the next load; a
/// new profile of that name doesn't get it meanwhile.
#[tokio::test]
async fn a_folder_that_cannot_go_is_swept_later() {
    let s = setup();
    s.service.create("Workspace 1", "", None).await.unwrap();
    s.store.busy_removals.store(u32::MAX, Ordering::SeqCst);
    s.service.delete("workspace-1").await.unwrap();
    assert_eq!(s.service.profiles().len(), 1);
    let workspace_1 = ProfileId::parse("workspace-1").unwrap();
    assert_eq!(
        *s.store.marked.lock().unwrap(),
        std::slice::from_ref(&workspace_1)
    );
    assert!(s.store.removed.lock().unwrap().is_empty());

    let again = s.service.create("Workspace 1", "", None).await.unwrap();
    assert_ne!(again.id, workspace_1);

    s.store.busy_removals.store(0, Ordering::SeqCst);
    ProfileService::load(s.store.clone(), Arc::new(FakeOpener::default())).unwrap();
    assert_eq!(*s.store.removed.lock().unwrap(), [workspace_1]);
}

/// Nothing opens the profile while it's being deleted: not a request for
/// it, not the activity of the list.
#[tokio::test]
async fn nothing_reopens_a_profile_being_deleted() {
    let s = setup();
    s.service.create("Workspace 1", "", None).await.unwrap();
    s.service.resolve(Some("workspace-1")).await.unwrap();
    *s.opener.close_takes.lock().unwrap() = Duration::from_millis(300);
    let deleting = {
        let service = Arc::clone(&s.service);
        tokio::spawn(async move { service.delete("workspace-1").await })
    };
    tokio::time::sleep(Duration::from_millis(50)).await;
    assert!(s.service.resolve(Some("workspace-1")).await.is_err());
    let views = s.service.list().await;
    let deleted = views
        .iter()
        .find(|v| v.profile.id.as_str() == "workspace-1");
    assert!(deleted.is_none_or(|v| v.activity.namespaces == 0));
    deleting.await.unwrap().unwrap();
    assert_eq!(s.opener.opened.load(Ordering::SeqCst), 1);
    assert_eq!(s.opener.stats_read.load(Ordering::SeqCst), 0);
}

#[tokio::test]
async fn list_reads_closed_profiles_without_opening_them() {
    let s = setup();
    s.service.create("Workspace 1", "", None).await.unwrap();
    let views = s.service.list().await;
    assert_eq!(views[1].activity.namespaces, 7);
    assert_eq!(s.opener.opened.load(Ordering::SeqCst), 0);
}

#[tokio::test]
async fn watch_reports_activity_of_profiles_the_user_is_not_in() {
    let s = setup();
    s.service.create("Workspace 1", "", None).await.unwrap();
    let other = s.service.resolve(Some("workspace-1")).await.unwrap();
    let mut watch = Box::pin(s.service.watch());

    let first = watch.next().await.unwrap();
    assert_eq!(first.len(), 2);
    assert_eq!(first[1].activity.agents_running, 0);

    other.running.store(3, Ordering::SeqCst);
    let next = tokio::time::timeout(Duration::from_secs(5), watch.next())
        .await
        .unwrap()
        .unwrap();
    assert_eq!(next[1].activity.agents_running, 3);

    s.service.create("Workspace 2", "", None).await.unwrap();
    let next = tokio::time::timeout(Duration::from_secs(5), watch.next())
        .await
        .unwrap()
        .unwrap();
    assert_eq!(next.len(), 3);
}
