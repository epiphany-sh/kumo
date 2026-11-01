use std::sync::atomic::{AtomicU32, Ordering};
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
}

impl ProfileStore for MemoryStore {
    fn load(&self) -> Result<Option<Vec<Profile>>, ProfileError> {
        Ok(self.saved.lock().unwrap().clone())
    }
    fn save(&self, profiles: &[Profile]) -> Result<(), ProfileError> {
        *self.saved.lock().unwrap() = Some(profiles.to_vec());
        Ok(())
    }
    fn remove_data(&self, id: &ProfileId) -> Result<(), ProfileError> {
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
        Box::pin(async {})
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
}

impl OpenProfile<FakeBundle> for FakeOpener {
    fn open<'a>(&'a self, profile: &'a Profile) -> BoxFuture<'a, Result<FakeBundle, ProfileError>> {
        self.opened.fetch_add(1, Ordering::SeqCst);
        let bundle = FakeBundle {
            id: profile.id.to_string(),
            agents: Mutex::new(vec![format!("agent of {}", profile.id)]),
            ..FakeBundle::default()
        };
        Box::pin(async move {
            tokio::task::yield_now().await;
            Ok(bundle)
        })
    }
    fn stats(&self, _profile: &Profile) -> ProfileActivity {
        ProfileActivity {
            namespaces: 7,
            ..ProfileActivity::default()
        }
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
    assert_eq!(
        s.service.resolve(Some("workspace-1")).await.err(),
        Some(ProfileError::NotFound("workspace-1".into()))
    );
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
