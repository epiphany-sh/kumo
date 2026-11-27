//! File system change notifications (FSEvents on macOS, ReadDirectoryChanges
//! on Windows, inotify on Linux) through `notify`.

mod ignored;

use std::path::{Path, PathBuf};

use kumo_domain::changes::{ChangeWatcher, ChangesError, OnChange, WatchGuard};
use notify::{EventKind, RecursiveMode, Watcher};

use ignored::GitIgnored;

/// [`ChangeWatcher`] on the OS's native notifications.
#[derive(Debug, Default, Clone, Copy)]
pub struct NotifyWatcher {
    skip_git_ignored: bool,
}

impl NotifyWatcher {
    /// For repositories and worktrees: changes inside folders git ignores
    /// (a build's `target/`, `node_modules/`) aren't reported, since they
    /// don't change any status. Everything under `.git/` still is.
    pub fn for_git() -> Self {
        Self {
            skip_git_ignored: true,
        }
    }
}

struct Guard(#[allow(dead_code)] notify::RecommendedWatcher);

impl WatchGuard for Guard {}

impl ChangeWatcher for NotifyWatcher {
    fn watch(
        &self,
        paths: &[PathBuf],
        on_change: OnChange,
    ) -> Result<Box<dyn WatchGuard>, ChangesError> {
        let ignored = self
            .skip_git_ignored
            .then(|| GitIgnored::new(paths.to_vec(), ignore::gitignore::gitconfig_excludes_path()));
        let mut watcher =
            notify::recommended_watcher(move |event: notify::Result<notify::Event>| {
                let Ok(event) = event else { return };
                if matches!(event.kind, EventKind::Access(_)) {
                    return;
                }
                if let Some(ignored) = &ignored {
                    ignored.forget(&event.paths);
                }
                let counts =
                    |p: &PathBuf| relevant(p) && !ignored.as_ref().is_some_and(|i| i.ignored(p));
                let changed: Vec<PathBuf> = event.paths.into_iter().filter(counts).collect();
                if !changed.is_empty() {
                    on_change(&changed);
                }
            })
            .map_err(|e| ChangesError::Io(format!("can't watch files: {e}")))?;
        for path in paths {
            watcher
                .watch(path, RecursiveMode::Recursive)
                .map_err(|e| ChangesError::Io(format!("can't watch {}: {e}", path.display())))?;
        }
        Ok(Box::new(Guard(watcher)))
    }
}

/// Git's object store churns on every operation without changing status.
fn relevant(path: &Path) -> bool {
    let mut components = path.components().map(|c| c.as_os_str()).peekable();
    while let Some(component) = components.next() {
        if component == ".git" && components.peek().is_some_and(|next| *next == "objects") {
            return false;
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::time::{Duration, Instant};

    use super::*;

    #[test]
    fn git_objects_dont_count() {
        assert!(!relevant(Path::new("/r/.git/objects/ab/cdef")));
        assert!(relevant(Path::new("/r/.git/index")));
        assert!(relevant(Path::new("/r/objects/x")));
        assert!(relevant(Path::new("/r/src/main.rs")));
    }

    struct Watching {
        _dir: tempfile::TempDir,
        _guard: Box<dyn WatchGuard>,
        root: PathBuf,
        seen: Arc<AtomicUsize>,
    }

    /// A repository whose `target/` is ignored, watched.
    fn watching(watcher: NotifyWatcher) -> Watching {
        let dir = tempfile::tempdir().unwrap();
        let root = crate::platform::canonical(dir.path());
        std::fs::create_dir_all(root.join(".git")).unwrap();
        std::fs::create_dir_all(root.join("target/debug")).unwrap();
        std::fs::write(root.join(".gitignore"), "target/\n").unwrap();
        let seen = Arc::new(AtomicUsize::new(0));
        let counter = Arc::clone(&seen);
        let guard = watcher
            .watch(
                std::slice::from_ref(&root),
                Box::new(move |_: &[PathBuf]| {
                    counter.fetch_add(1, Ordering::SeqCst);
                }),
            )
            .unwrap();
        // Let the events from setting up the folder go by.
        std::thread::sleep(Duration::from_millis(500));
        seen.store(0, Ordering::SeqCst);
        Watching {
            _dir: dir,
            _guard: guard,
            root,
            seen,
        }
    }

    fn wait_for(seen: &AtomicUsize) -> bool {
        let started = Instant::now();
        while started.elapsed() < Duration::from_secs(5) {
            if seen.load(Ordering::SeqCst) > 0 {
                return true;
            }
            std::thread::sleep(Duration::from_millis(10));
        }
        false
    }

    #[test]
    fn a_build_in_an_ignored_folder_isnt_a_change_for_git() {
        let Watching { root, seen, .. } = &watching(NotifyWatcher::for_git());
        for n in 0..50 {
            std::fs::write(root.join(format!("target/debug/unit-{n}.o")), "o").unwrap();
        }
        std::thread::sleep(Duration::from_secs(1));
        assert_eq!(seen.load(Ordering::SeqCst), 0, "build output was reported");

        std::fs::write(root.join("main.rs"), "fn main() {}").unwrap();
        assert!(wait_for(seen), "a tracked folder's change wasn't reported");
    }

    #[test]
    fn without_git_every_change_counts() {
        let Watching { root, seen, .. } = &watching(NotifyWatcher::default());
        std::fs::write(root.join("target/debug/unit.o"), "o").unwrap();
        assert!(wait_for(seen));
    }
}
