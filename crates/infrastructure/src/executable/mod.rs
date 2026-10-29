//! The daemon's own program file, to tell when an update replaced it.

use std::path::{Path, PathBuf};
use std::time::SystemTime;

use kumo_domain::daemon::Executable;

/// What identifies the file's contents without reading them.
#[derive(Debug, Clone, PartialEq, Eq)]
struct Fingerprint {
    len: u64,
    modified: Option<SystemTime>,
    #[cfg(unix)]
    inode: u64,
}

impl Fingerprint {
    fn of(path: &Path) -> Option<Self> {
        let meta = std::fs::metadata(path).ok()?;
        Some(Self {
            len: meta.len(),
            modified: meta.modified().ok(),
            #[cfg(unix)]
            inode: std::os::unix::fs::MetadataExt::ino(&meta),
        })
    }
}

/// [`Executable`] on the file at a path, compared with how it was at start.
/// A program swapped for another (an update, `cargo build`, `codesign`)
/// changes its size, date or inode.
#[derive(Debug)]
pub struct ProgramFile {
    path: PathBuf,
    at_start: Option<Fingerprint>,
}

impl ProgramFile {
    pub fn new(path: PathBuf) -> Self {
        let at_start = Fingerprint::of(&path);
        Self { path, at_start }
    }

    /// The running program. Unknown (no path): never replaced.
    pub fn current() -> Self {
        Self::new(std::env::current_exe().unwrap_or_default())
    }
}

impl Executable for ProgramFile {
    fn replaced(&self) -> bool {
        // Gone counts as replaced: an update that removed it means a new
        // program is elsewhere, and this one can't be relaunched.
        self.at_start.is_some() && Fingerprint::of(&self.path) != self.at_start
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_file_swapped_for_another_is_replaced() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("kumod");
        std::fs::write(&path, "v1").unwrap();
        let program = ProgramFile::new(path.clone());
        assert!(!program.replaced());

        // How updates land: a new file renamed over the old one.
        let next = dir.path().join("kumod.new");
        std::fs::write(&next, "v2 is longer").unwrap();
        std::fs::rename(&next, &path).unwrap();
        assert!(program.replaced());
    }

    #[test]
    fn a_program_without_a_path_is_never_replaced() {
        assert!(!ProgramFile::new(PathBuf::new()).replaced());
    }
}
