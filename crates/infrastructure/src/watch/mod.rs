//! File system change notifications (FSEvents on macOS, ReadDirectoryChanges
//! on Windows) through `notify`.

use std::path::{Path, PathBuf};

use kumo_domain::changes::{ChangeWatcher, ChangesError, WatchGuard};
use notify::{EventKind, RecursiveMode, Watcher};

/// [`ChangeWatcher`] on the OS's native notifications.
#[derive(Debug, Default, Clone, Copy)]
pub struct NotifyWatcher;

struct Guard(#[allow(dead_code)] notify::RecommendedWatcher);

impl WatchGuard for Guard {}

impl ChangeWatcher for NotifyWatcher {
    fn watch(
        &self,
        paths: &[PathBuf],
        on_change: Box<dyn Fn() + Send + Sync>,
    ) -> Result<Box<dyn WatchGuard>, ChangesError> {
        let mut watcher =
            notify::recommended_watcher(move |event: notify::Result<notify::Event>| {
                if let Ok(event) = event
                    && !matches!(event.kind, EventKind::Access(_))
                    && event.paths.iter().any(|p| relevant(p))
                {
                    on_change();
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
    !path
        .components()
        .collect::<Vec<_>>()
        .windows(2)
        .any(|w| w[0].as_os_str() == ".git" && w[1].as_os_str() == "objects")
}
