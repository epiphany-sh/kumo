//! What a worktree's status costs to read again, kept between reads: the
//! changes committed since the base (they change only with HEAD or the
//! base) and untracked files' line counts (only with the file).

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard, PoisonError};
use std::time::SystemTime;

use kumo_domain::changes::{ChangeKind, ChangesError, FileChange};

/// Untracked files bigger than this are not opened to count their lines.
pub(super) const MAX_COUNTED_BYTES: u64 = 1024 * 1024;
/// Untracked files read at once.
const READERS: usize = 4;

/// Both caches, shared by every clone of a [`GitCli`](super::GitCli).
#[derive(Default)]
pub(super) struct StatusCaches {
    pub committed: CommittedCache,
    pub untracked: UntrackedCounts,
}

impl std::fmt::Debug for StatusCaches {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("StatusCaches").finish_non_exhaustive()
    }
}

/// What the committed changes were read for.
#[derive(Debug, Clone, PartialEq, Eq)]
struct CommittedKey {
    head: String,
    base: String,
    base_oid: String,
}

/// The changes committed since the base; None: no merge base.
type Committed = Option<Vec<FileChange>>;

/// Per worktree, the committed changes, for the HEAD and base commits they
/// were read at.
#[derive(Default)]
pub(super) struct CommittedCache(Mutex<HashMap<PathBuf, (CommittedKey, Committed)>>);

impl CommittedCache {
    /// The changes for these commits: the kept ones, or `read`'s (kept
    /// unless it fails).
    pub fn get_or_read(
        &self,
        worktree: &Path,
        head: &str,
        (base, base_oid): (&str, &str),
        read: impl FnOnce() -> Result<Committed, ChangesError>,
    ) -> Result<Committed, ChangesError> {
        let key = CommittedKey {
            head: head.to_owned(),
            base: base.to_owned(),
            base_oid: base_oid.to_owned(),
        };
        if let Some((kept, changes)) = lock(&self.0).get(worktree)
            && *kept == key
        {
            return Ok(changes.clone());
        }
        let changes = read()?;
        lock(&self.0).insert(worktree.to_path_buf(), (key, changes.clone()));
        Ok(changes)
    }
}

/// An untracked file's count, for the size and time it was read at.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Counted {
    len: u64,
    modified: Option<SystemTime>,
    binary: bool,
    lines: u32,
}

/// Per worktree, the line counts of its untracked files.
#[derive(Default)]
pub(super) struct UntrackedCounts(Mutex<HashMap<PathBuf, HashMap<String, Counted>>>);

impl UntrackedCounts {
    /// Sets the line count of the untracked files in `changes`, reading
    /// (with `read`) only those new or changed since the last time. Files
    /// over [`MAX_COUNTED_BYTES`] aren't read: no lines, like before.
    pub fn count(
        &self,
        worktree: &Path,
        changes: &mut [FileChange],
        read: impl Fn(&Path) -> Option<Vec<u8>> + Sync,
    ) {
        let kept = lock(&self.0).remove(worktree).unwrap_or_default();
        let mut counted: HashMap<String, Counted> = HashMap::new();
        let mut unread: Vec<(String, u64, Option<SystemTime>)> = Vec::new();
        for change in changes
            .iter()
            .filter(|c| c.unstaged == ChangeKind::Untracked)
        {
            let Ok(meta) = std::fs::metadata(worktree.join(&change.path)) else {
                continue;
            };
            let (len, modified) = (meta.len(), meta.modified().ok());
            match kept.get(&change.path) {
                Some(c) if c.len == len && c.modified == modified => {
                    counted.insert(change.path.clone(), *c);
                }
                _ if len > MAX_COUNTED_BYTES => {
                    let skipped = Counted {
                        len,
                        modified,
                        binary: false,
                        lines: 0,
                    };
                    counted.insert(change.path.clone(), skipped);
                }
                _ => unread.push((change.path.clone(), len, modified)),
            }
        }
        counted.extend(read_all(worktree, &unread, &read));
        for change in changes.iter_mut() {
            if let Some(c) = counted.get(&change.path) {
                change.binary = c.binary;
                change.additions = c.lines;
            }
        }
        lock(&self.0).insert(worktree.to_path_buf(), counted);
    }
}

/// Reads and counts files, a few at once.
fn read_all(
    worktree: &Path,
    files: &[(String, u64, Option<SystemTime>)],
    read: &(impl Fn(&Path) -> Option<Vec<u8>> + Sync),
) -> Vec<(String, Counted)> {
    let count = |chunk: &[(String, u64, Option<SystemTime>)]| -> Vec<(String, Counted)> {
        chunk
            .iter()
            .filter_map(|(path, len, modified)| {
                let bytes = read(&worktree.join(path))?;
                let (binary, lines) = count_lines(&bytes);
                let counted = Counted {
                    len: *len,
                    modified: *modified,
                    binary,
                    lines,
                };
                Some((path.clone(), counted))
            })
            .collect()
    };
    if files.len() < 2 {
        return count(files);
    }
    let size = files.len().div_ceil(READERS);
    std::thread::scope(|scope| {
        let readers: Vec<_> = files
            .chunks(size)
            .map(|chunk| scope.spawn(move || count(chunk)))
            .collect();
        readers
            .into_iter()
            .flat_map(|r| r.join().unwrap_or_default())
            .collect()
    })
}

/// Whether a file is binary, and its lines as `str::lines` counts them.
pub(super) fn count_lines(bytes: &[u8]) -> (bool, u32) {
    if bytes.iter().take(8000).any(|b| *b == 0) {
        return (true, 0);
    }
    let breaks = bytes.iter().filter(|b| **b == b'\n').count();
    let unterminated = usize::from(bytes.last().is_some_and(|b| *b != b'\n'));
    (
        false,
        u32::try_from(breaks + unterminated).unwrap_or(u32::MAX),
    )
}

fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}

#[cfg(test)]
mod tests {
    use std::sync::atomic::{AtomicUsize, Ordering};

    use super::*;

    fn untracked(path: &str) -> FileChange {
        FileChange {
            path: path.into(),
            unstaged: ChangeKind::Untracked,
            ..Default::default()
        }
    }

    /// Counts with a reader that counts its reads.
    fn count(cache: &UntrackedCounts, root: &Path, changes: &mut [FileChange]) -> usize {
        let reads = AtomicUsize::new(0);
        cache.count(root, changes, |path| {
            reads.fetch_add(1, Ordering::SeqCst);
            std::fs::read(path).ok()
        });
        reads.into_inner()
    }

    #[test]
    fn lines_are_counted_like_str_lines() {
        for text in ["", "a", "a\n", "a\nb", "a\r\nb\r\n", "\n\n", "x\ny\nz\n"] {
            assert_eq!(
                count_lines(text.as_bytes()),
                (false, u32::try_from(text.lines().count()).unwrap()),
                "{text:?}"
            );
        }
        assert_eq!(count_lines(b"a\0b\n"), (true, 0));
    }

    #[test]
    fn an_unchanged_file_isnt_read_again() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("a.txt"), "1\n2\n3\n").unwrap();
        std::fs::write(dir.path().join("b.bin"), b"\0\0").unwrap();
        let cache = UntrackedCounts::default();

        let mut changes = vec![untracked("a.txt"), untracked("b.bin")];
        assert_eq!(count(&cache, dir.path(), &mut changes), 2);
        assert_eq!((changes[0].additions, changes[0].binary), (3, false));
        assert!(changes[1].binary);

        let mut again = vec![untracked("a.txt"), untracked("b.bin")];
        assert_eq!(count(&cache, dir.path(), &mut again), 0, "read again");
        assert_eq!(again, changes);
    }

    #[test]
    fn a_changed_file_is_read_again() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("a.txt");
        std::fs::write(&file, "1\n").unwrap();
        let cache = UntrackedCounts::default();
        count(&cache, dir.path(), &mut [untracked("a.txt")]);

        std::fs::write(&file, "1\n2\n3\n4\n").unwrap();
        let mut changes = [untracked("a.txt")];
        assert_eq!(count(&cache, dir.path(), &mut changes), 1);
        assert_eq!(changes[0].additions, 4);
    }

    #[test]
    fn big_files_arent_read() {
        let dir = tempfile::tempdir().unwrap();
        let big = vec![b'x'; usize::try_from(MAX_COUNTED_BYTES).unwrap() + 1];
        std::fs::write(dir.path().join("big.log"), big).unwrap();
        let cache = UntrackedCounts::default();
        let mut changes = [untracked("big.log")];
        assert_eq!(count(&cache, dir.path(), &mut changes), 0);
        assert_eq!((changes[0].additions, changes[0].binary), (0, false));
    }

    #[test]
    fn many_files_are_all_counted() {
        let dir = tempfile::tempdir().unwrap();
        let mut changes: Vec<FileChange> = (0..25)
            .map(|n| {
                let name = format!("f{n}.txt");
                std::fs::write(dir.path().join(&name), "x\n".repeat(n)).unwrap();
                untracked(&name)
            })
            .collect();
        let cache = UntrackedCounts::default();
        assert_eq!(count(&cache, dir.path(), &mut changes), 25);
        for (n, change) in changes.iter().enumerate() {
            assert_eq!(change.additions, u32::try_from(n).unwrap());
        }
    }

    #[test]
    fn committed_changes_are_read_again_only_for_new_commits() {
        let cache = CommittedCache::default();
        let reads = AtomicUsize::new(0);
        let read = |files: usize| {
            reads.fetch_add(1, Ordering::SeqCst);
            Ok(Some(vec![FileChange::default(); files]))
        };
        let wt = Path::new("/wt");
        let get = |head: &str, base_oid: &str, files: usize| {
            cache
                .get_or_read(wt, head, ("origin/main", base_oid), || read(files))
                .unwrap()
                .unwrap()
                .len()
        };

        assert_eq!(get("h1", "b1", 1), 1);
        assert_eq!(get("h1", "b1", 9), 1, "same commits: kept");
        assert_eq!(reads.load(Ordering::SeqCst), 1);
        assert_eq!(get("h2", "b1", 2), 2, "new HEAD");
        assert_eq!(get("h2", "b2", 3), 3, "base moved");
        assert_eq!(reads.load(Ordering::SeqCst), 3);
        assert_eq!(
            cache
                .get_or_read(wt, "h2", ("origin/master", "b2"), || read(4))
                .unwrap()
                .map(|c| c.len()),
            Some(4),
            "another base"
        );
    }

    #[test]
    fn a_failed_read_isnt_kept() {
        let cache = CommittedCache::default();
        let wt = Path::new("/wt");
        let failed = cache.get_or_read(wt, "h", ("main", "b"), || {
            Err(ChangesError::Git("busy".into()))
        });
        assert!(failed.is_err());
        let read = cache.get_or_read(wt, "h", ("main", "b"), || Ok(None));
        assert_eq!(read.unwrap(), None);
    }
}
