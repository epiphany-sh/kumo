//! Which changes git doesn't see: files inside a folder that `.gitignore`
//! (or `.git/info/exclude`, or the user's `core.excludesFile`) leaves out,
//! such as a build's `target/` or `node_modules/`. A build writes there for
//! minutes; none of it changes `git status`.
//!
//! Only files *inside* an ignored folder are skipped. A file that matches a
//! pattern itself may still be tracked (added before the pattern, or with
//! `git add -f`), and git shows its changes. Anything under `.git/` always
//! counts: commits, checkouts and stages show there.
//!
//! Rules are read from the files only, never by running git. They are
//! loaded per folder on first use and dropped when a rules file changes.
//! When a rules file can't be read, nothing under it is skipped.

use std::collections::HashMap;
use std::ffi::OsStr;
use std::path::{Component, Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError};

use ignore::Match;
use ignore::gitignore::{Gitignore, GitignoreBuilder};

/// Past this many folders the cache starts over (a tree with many folders
/// that aren't ignored, read while files change in all of them).
const MAX_DIRS: usize = 10_000;

/// Skips the changes git ignores under some watched roots.
#[derive(Debug)]
pub(super) struct GitIgnored {
    roots: Vec<PathBuf>,
    /// The user's `core.excludesFile` (or git's default for it).
    global: Option<PathBuf>,
    dirs: Mutex<HashMap<PathBuf, Arc<Dir>>>,
}

/// One folder's rules.
#[derive(Debug)]
struct Dir {
    gitignore: Rules,
    /// Set when a repository or worktree starts here (it has `.git`): its
    /// `info/exclude` and the user's excludes, below its own `.gitignore`s.
    /// Rules from folders above don't apply inside it.
    repo: Option<Rules>,
}

#[derive(Debug, Clone)]
enum Rules {
    None,
    Some(Arc<Gitignore>),
    /// There are rules, but they couldn't be read: nothing is skipped.
    Unreadable,
}

impl GitIgnored {
    pub(super) fn new(roots: Vec<PathBuf>, global: Option<PathBuf>) -> Self {
        Self {
            roots,
            global,
            dirs: Mutex::default(),
        }
    }

    /// Drops the rules that `changed` may have edited, so they're read
    /// again. Call it with every changed path, skipped or not.
    pub(super) fn forget(&self, changed: &[PathBuf]) {
        let mut dirs = self.lock();
        for path in changed {
            let name = path.file_name();
            if name == Some(OsStr::new(".gitignore")) || name == Some(OsStr::new(".git")) {
                if let Some(parent) = path.parent() {
                    dirs.remove(parent);
                }
            } else if path.ends_with("info/exclude") {
                dirs.clear();
            }
        }
    }

    /// Whether git ignores the folder `path` is in, so a change to `path`
    /// doesn't change any status.
    pub(super) fn ignored(&self, path: &Path) -> bool {
        if path.components().any(|c| c.as_os_str() == ".git") {
            return false;
        }
        let Some(root) = self
            .roots
            .iter()
            .filter(|root| path.starts_with(root))
            .max_by_key(|root| root.as_os_str().len())
        else {
            return false;
        };
        let Ok(relative) = path.strip_prefix(root) else {
            return false;
        };
        let mut folders: Vec<&OsStr> = Vec::new();
        for component in relative.components() {
            match component {
                Component::Normal(name) => folders.push(name),
                _ => return false,
            }
        }
        folders.pop(); // the path itself: only the folders it's in count

        let mut chain = vec![root.clone()];
        for name in folders {
            let next = chain[chain.len() - 1].join(name);
            chain.push(next);
        }
        let dirs: Vec<Arc<Dir>> = chain.iter().map(|path| self.dir(path)).collect();
        // The repository the path is in: a worktree inside a folder the
        // main checkout ignores is still a worktree.
        let start = dirs.iter().rposition(|d| d.repo.is_some()).unwrap_or(0);
        let mut stack: Vec<Rules> = Vec::new();
        let mut repo = Rules::None;
        push(&dirs[start], &mut stack, &mut repo);
        for (folder, dir) in chain.iter().zip(&dirs).skip(start + 1) {
            match decide(folder, &stack, &repo) {
                Decision::Ignored => return true,
                Decision::Unknown => return false,
                Decision::Kept => push(dir, &mut stack, &mut repo),
            }
        }
        false
    }

    fn dir(&self, path: &Path) -> Arc<Dir> {
        if let Some(dir) = self.lock().get(path) {
            return Arc::clone(dir);
        }
        // Read without the lock: another event's lookup needn't wait.
        let dir = Arc::new(Dir {
            gitignore: read_rules(path, &[path.join(".gitignore")]),
            repo: git_dir(path).map(|git_dir| {
                let exclude = common_dir(&git_dir).join("info/exclude");
                // Later files win: info/exclude over the user's excludes.
                let files: Vec<PathBuf> = self.global.iter().cloned().chain([exclude]).collect();
                read_rules(path, &files)
            }),
        });
        let mut dirs = self.lock();
        if dirs.len() >= MAX_DIRS {
            dirs.clear();
        }
        dirs.insert(path.to_path_buf(), Arc::clone(&dir));
        dir
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, HashMap<PathBuf, Arc<Dir>>> {
        self.dirs.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

/// Adds a folder's rules to the ones in effect below it; a repository
/// starts over.
fn push(dir: &Dir, stack: &mut Vec<Rules>, repo: &mut Rules) {
    if let Some(rules) = &dir.repo {
        stack.clear();
        *repo = rules.clone();
    }
    stack.push(dir.gitignore.clone());
}

enum Decision {
    Ignored,
    Kept,
    Unknown,
}

/// Git's order: the closest `.gitignore` first, then the repository's
/// `info/exclude`, then the user's excludes. The first match wins.
fn decide(folder: &Path, stack: &[Rules], repo: &Rules) -> Decision {
    for rules in stack.iter().rev().chain(std::iter::once(repo)) {
        match rules {
            Rules::None => {}
            Rules::Unreadable => return Decision::Unknown,
            Rules::Some(gitignore) => match gitignore.matched(folder, true) {
                Match::None => {}
                Match::Ignore(_) => return Decision::Ignored,
                Match::Whitelist(_) => return Decision::Kept,
            },
        }
    }
    Decision::Kept
}

/// The rules in `files` (those that exist), relative to `dir`.
fn read_rules(dir: &Path, files: &[PathBuf]) -> Rules {
    let present: Vec<&PathBuf> = files.iter().filter(|f| f.is_file()).collect();
    if present.is_empty() {
        // A rules file that exists but isn't a file (or can't be looked at)
        // is treated as unreadable.
        return if files.iter().any(|f| f.exists() && !f.is_file()) {
            Rules::Unreadable
        } else {
            Rules::None
        };
    }
    let mut builder = GitignoreBuilder::new(dir);
    for file in present {
        if builder.add(file).is_some() {
            return Rules::Unreadable;
        }
    }
    match builder.build() {
        Ok(gitignore) => Rules::Some(Arc::new(gitignore)),
        Err(_) => Rules::Unreadable,
    }
}

/// The git folder of a repository or worktree starting at `dir`: `.git`
/// itself, or where a worktree's `.git` file points.
fn git_dir(dir: &Path) -> Option<PathBuf> {
    let dot_git = dir.join(".git");
    if dot_git.is_dir() {
        return Some(dot_git);
    }
    if !dot_git.is_file() {
        return None;
    }
    let text = std::fs::read_to_string(&dot_git).ok();
    let pointed = text
        .as_deref()
        .and_then(|t| t.lines().next())
        .and_then(|line| line.strip_prefix("gitdir:"))
        .map(|p| dir.join(p.trim()));
    // A `.git` file that can't be followed still marks a repository: the
    // folders above it say nothing about what's inside.
    Some(pointed.unwrap_or(dot_git))
}

/// A linked worktree's git folder names the repository's shared one in
/// `commondir`; that's where `info/exclude` is.
fn common_dir(git_dir: &Path) -> PathBuf {
    match std::fs::read_to_string(git_dir.join("commondir")) {
        Ok(common) => git_dir.join(common.trim()),
        Err(_) => git_dir.to_path_buf(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Repo {
        _dir: tempfile::TempDir,
        root: PathBuf,
    }

    impl Repo {
        fn new(gitignore: &str) -> Self {
            let dir = tempfile::tempdir().unwrap();
            let root = dir.path().to_path_buf();
            std::fs::create_dir_all(root.join(".git/info")).unwrap();
            std::fs::write(root.join(".gitignore"), gitignore).unwrap();
            Self { _dir: dir, root }
        }

        fn write(&self, path: &str, text: &str) {
            let path = self.root.join(path);
            std::fs::create_dir_all(path.parent().unwrap()).unwrap();
            std::fs::write(path, text).unwrap();
        }

        fn ignored(&self) -> GitIgnored {
            GitIgnored::new(vec![self.root.clone()], None)
        }

        fn skips(&self, ignored: &GitIgnored, path: &str) -> bool {
            ignored.ignored(&self.root.join(path))
        }
    }

    #[test]
    fn skips_what_is_inside_an_ignored_folder() {
        let repo = Repo::new("target/\nnode_modules\n");
        let ignored = repo.ignored();

        assert!(repo.skips(&ignored, "target/debug/deps/unit.o"));
        assert!(repo.skips(&ignored, "web/node_modules/left-pad/index.js"));
        assert!(!repo.skips(&ignored, "src/main.rs"));
        assert!(!repo.skips(&ignored, "README.md"));
    }

    #[test]
    fn keeps_the_ignored_folder_itself_and_matching_files() {
        // `rm -rf target` changes nothing, but one read is cheap; a file
        // that matches a pattern may be tracked.
        let repo = Repo::new("target/\n*.log\n");
        let ignored = repo.ignored();

        assert!(!repo.skips(&ignored, "target"));
        assert!(!repo.skips(&ignored, "build.log"));
        assert!(!repo.skips(&ignored, "logs/build.log"));
    }

    #[test]
    fn keeps_everything_under_git() {
        let repo = Repo::new(".git\n*\n");
        let ignored = repo.ignored();

        assert!(!repo.skips(&ignored, ".git/index"));
        assert!(!repo.skips(&ignored, ".git/refs/heads/main"));
    }

    #[test]
    fn closer_rules_win_and_a_whitelist_keeps_a_folder() {
        let repo = Repo::new("*.out/\n!keep.out/\n");
        repo.write("app/.gitignore", "gen/\n");
        repo.write("app/sub/.gitignore", "!gen/\n");
        let ignored = repo.ignored();

        assert!(repo.skips(&ignored, "x.out/file"));
        assert!(!repo.skips(&ignored, "keep.out/file"));
        assert!(repo.skips(&ignored, "app/gen/file.rs"));
        assert!(!repo.skips(&ignored, "gen/file.rs"));
        assert!(!repo.skips(&ignored, "app/sub/gen/file.rs"));
    }

    #[test]
    fn a_folder_inside_an_ignored_one_stays_ignored() {
        // Git doesn't look inside an ignored folder, whatever it says.
        let repo = Repo::new("build/\n!build/keep/\n");
        let ignored = repo.ignored();

        assert!(repo.skips(&ignored, "build/keep/file"));
    }

    #[test]
    fn reads_info_exclude_and_the_users_excludes() {
        let repo = Repo::new("");
        std::fs::write(repo.root.join(".git/info/exclude"), "out/\n").unwrap();
        let global = repo.root.join("global-ignore");
        std::fs::write(&global, "dist/\nout/\n!out/\n").unwrap();
        let ignored = GitIgnored::new(vec![repo.root.clone()], Some(global));

        assert!(repo.skips(&ignored, "dist/app.js"));
        // info/exclude wins over the user's excludes.
        assert!(repo.skips(&ignored, "out/app.js"));
    }

    #[test]
    fn a_worktree_inside_an_ignored_folder_has_its_own_rules() {
        // Worktrees made under `.claude/worktrees/` (ignored by the main
        // checkout) are watched through it.
        let repo = Repo::new(".claude/\n");
        let worktree = repo.root.join(".git/worktrees/fix");
        std::fs::create_dir_all(&worktree).unwrap();
        std::fs::write(worktree.join("commondir"), "../..\n").unwrap();
        std::fs::write(repo.root.join(".git/info/exclude"), "tmp/\n").unwrap();
        repo.write(
            ".claude/worktrees/fix/.git",
            &format!("gitdir: {}\n", worktree.display()),
        );
        repo.write(".claude/worktrees/fix/.gitignore", "target/\n");
        let ignored = repo.ignored();

        assert!(repo.skips(&ignored, ".claude/settings/file"));
        assert!(!repo.skips(&ignored, ".claude/worktrees/fix/src/main.rs"));
        assert!(repo.skips(&ignored, ".claude/worktrees/fix/target/debug/x"));
        // The shared info/exclude applies in the worktree too.
        assert!(repo.skips(&ignored, ".claude/worktrees/fix/tmp/x"));
    }

    #[test]
    fn rules_are_read_again_after_they_change() {
        let repo = Repo::new("");
        let ignored = repo.ignored();
        assert!(!repo.skips(&ignored, "dist/app.js"));

        std::fs::write(repo.root.join(".gitignore"), "dist/\n").unwrap();
        assert!(!repo.skips(&ignored, "dist/app.js"), "cached until told");
        ignored.forget(&[repo.root.join(".gitignore")]);
        assert!(repo.skips(&ignored, "dist/app.js"));

        std::fs::write(repo.root.join(".git/info/exclude"), "cache/\n").unwrap();
        ignored.forget(&[repo.root.join(".git/info/exclude")]);
        assert!(repo.skips(&ignored, "cache/x"));
    }

    #[test]
    fn rules_that_cant_be_read_skip_nothing() {
        let repo = Repo::new("target/\n");
        std::fs::create_dir_all(repo.root.join("app/.gitignore")).unwrap();
        let ignored = repo.ignored();

        assert!(!repo.skips(&ignored, "app/target/x"));
        assert!(repo.skips(&ignored, "target/x"));
    }

    #[test]
    fn paths_outside_the_roots_are_kept() {
        let repo = Repo::new("*/\n");
        let ignored = repo.ignored();

        assert!(!ignored.ignored(Path::new("/somewhere/else/target/x")));
        assert!(!ignored.ignored(&repo.root.join("../x/y")));
    }
}
