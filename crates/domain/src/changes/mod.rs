//! Changes, files and history of one worktree: what the Files, Source
//! control and Git views show, and the git actions on it.

mod commit;
mod diff;
mod error;
mod file;
mod ports;
mod relative_path;
mod status;

pub use commit::{CommitInfo, CommitOptions};
pub use diff::{DiffLine, DiffLineKind, DiffScope, FileDiff};
pub use error::ChangesError;
pub use file::{FileContent, FileList};
pub use ports::{ChangeWatcher, FileStore, GitChanges, WatchGuard};
pub use relative_path::RelativePath;
pub use status::{ChangeKind, FileChange, WorktreeChanges};
