//! Windows.

use std::collections::HashMap;
use std::ffi::OsStr;
use std::fs::{Metadata, OpenOptions};
use std::os::windows::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Arc;

use keyring_core::{CredentialStore, Error as KeyringError};

use super::{
    AgentHooks, AppFolders, BackgroundPrograms, FileIdentity, Keychain, PlainPaths, PrivateFiles,
    ProcessTrees, Processes, ProgramSearch, RunningProcess, SavedSignIns, ScriptShell, Signals,
};

/// The child gets a console nobody sees.
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

pub struct Windows;

impl BackgroundPrograms for Windows {
    /// `kumod` runs without a console (the UI starts it detached), so a
    /// console program it starts would open a window of its own: one per
    /// `git status`, and a refresh runs many. With `CREATE_NO_WINDOW` it
    /// gets a hidden console instead, which what it starts (ssh, git's
    /// credential helper) shares.
    fn command(program: &OsStr) -> Command {
        let mut command = Command::new(program);
        command.creation_flags(CREATE_NO_WINDOW);
        command
    }
}

impl ProcessTrees for Windows {
    /// `taskkill /T` follows parents, not groups.
    fn own_group(_command: &mut Command) {}

    fn kill_tree(pid: u32) {
        let _ = Self::command(OsStr::new("taskkill"))
            .args(["/T", "/F", "/PID", &pid.to_string()])
            .output();
    }

    /// No groups to look for; `taskkill /T` needs the parent alive.
    fn kill_group(_pid: u32) {}
}

impl ProgramSearch for Windows {
    /// Programs started from Explorer already get the user's PATH.
    fn login_shell_path() -> Option<String> {
        None
    }

    fn install_dirs() -> Vec<PathBuf> {
        Vec::new()
    }

    /// The runnable extensions first: npm puts a `claude` shell script
    /// (for Git Bash) next to `claude.cmd`, and Windows can't start the
    /// script. The bare name last, for a name that has its extension.
    fn executable_names(program: &str) -> Vec<String> {
        [".exe", ".cmd", ".bat", ""]
            .iter()
            .map(|ext| format!("{program}{ext}"))
            .collect()
    }

    /// No execute bit: any file.
    fn is_executable(meta: &Metadata) -> bool {
        meta.is_file()
    }
}

impl ScriptShell for Windows {
    /// `cmd.exe /C <command>`.
    fn script(command: &str) -> (String, Vec<String>) {
        let shell = std::env::var("ComSpec").unwrap_or_else(|_| "cmd.exe".to_owned());
        (shell, vec!["/C".to_owned(), command.to_owned()])
    }
}

impl FileIdentity for Windows {
    /// No inode: size and date tell the files apart.
    fn file_id(_meta: &Metadata) -> Option<u64> {
        None
    }

    /// The same path but for its case (Windows disks ignore case).
    fn same_file(source: &Path, target: &Path, _existing: &Metadata) -> bool {
        source
            .to_string_lossy()
            .eq_ignore_ascii_case(&target.to_string_lossy())
    }
}

/// The longest path programs take without `\\?\` (`MAX_PATH`).
const MAX_PATH: usize = 260;

impl PlainPaths for Windows {
    /// `\\?\C:\x` → `C:\x`, `\\?\UNC\server\share` → `\\server\share`.
    /// Kept as it is when the plain form wouldn't name the same file: too
    /// long, or a name ending in a dot or a space (Windows drops those).
    fn plain(path: PathBuf) -> PathBuf {
        let Some(text) = path.to_str() else {
            return path;
        };
        let plain = if let Some(share) = text.strip_prefix(r"\\?\UNC\") {
            format!(r"\\{share}")
        } else if let Some(local) = text.strip_prefix(r"\\?\")
            && is_drive_path(local)
        {
            local.to_owned()
        } else {
            return path;
        };
        let names_change = plain
            .split('\\')
            .any(|name| name.ends_with('.') && name != "." && name != ".." || name.ends_with(' '));
        if plain.len() >= MAX_PATH || names_change {
            return path;
        }
        PathBuf::from(plain)
    }
}

/// `C:` or `C:\…`.
fn is_drive_path(path: &str) -> bool {
    let bytes = path.as_bytes();
    bytes.len() >= 2
        && bytes[0].is_ascii_alphabetic()
        && bytes[1] == b':'
        && (bytes.len() == 2 || bytes[2] == b'\\')
}

impl PrivateFiles for Windows {
    /// Files under the user's profile are already theirs alone.
    fn owner_only(_options: &mut OpenOptions) {}

    fn owner_only_dir(_dir: &Path) -> std::io::Result<()> {
        Ok(())
    }
}

/// The Credential Manager.
impl Keychain for Windows {
    fn native_store() -> Result<Arc<CredentialStore>, KeyringError> {
        Ok(windows_native_keyring_store::Store::new()?)
    }
    fn search_spec(service: &'static str) -> HashMap<&'static str, &'static str> {
        HashMap::from([("pattern", service)])
    }
}

impl AppFolders for Windows {
    fn obsidian_settings(home: &Path) -> PathBuf {
        home.join("AppData/Roaming/obsidian/obsidian.json")
    }
}

impl AgentHooks for Windows {
    /// Claude Code runs status lines through Git Bash or PowerShell,
    /// whichever it finds: no way to know which, so Kumo's isn't used.
    fn sh_status_line() -> bool {
        false
    }
}

impl SavedSignIns for Windows {
    /// Claude Code keeps its sign-in in a file here, and Copilot CLI's
    /// is found through `gh` instead.
    fn saved_secret(_service: &str, _account: Option<&str>) -> Result<Option<String>, String> {
        Ok(None)
    }
}

impl Signals for Windows {
    /// Ctrl-C (Windows has no SIGTERM).
    async fn shutdown() {
        let _ = tokio::signal::ctrl_c().await;
    }
}

impl Processes for Windows {
    /// Not read yet: terminals on Windows don't report agent CLIs.
    fn process(_pid: u32) -> Option<RunningProcess> {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn runs_background_programs_and_scripts() {
        let (program, args) = Windows::script("exit 3");
        let status = Windows::command(OsStr::new(&program))
            .args(args)
            .status()
            .unwrap();
        assert_eq!(status.code(), Some(3));
    }

    #[test]
    fn tries_runnable_extensions_before_the_bare_name() {
        assert_eq!(
            Windows::executable_names("claude"),
            ["claude.exe", "claude.cmd", "claude.bat", "claude"]
        );
    }

    #[test]
    fn plain_paths_drop_the_verbatim_prefix() {
        let plain = |path: &str| Windows::plain(PathBuf::from(path));
        assert_eq!(
            plain(r"\\?\C:\Users\me\wt\x"),
            PathBuf::from(r"C:\Users\me\wt\x")
        );
        assert_eq!(
            plain(r"\\?\UNC\server\share\x"),
            PathBuf::from(r"\\server\share\x")
        );
        assert_eq!(plain(r"C:\Users\me"), PathBuf::from(r"C:\Users\me"));
        // The plain form would name another file, or be too long.
        assert_eq!(plain(r"\\?\C:\x\name."), PathBuf::from(r"\\?\C:\x\name."));
        let long = format!(r"\\?\C:\{}", "a".repeat(MAX_PATH));
        assert_eq!(plain(&long), PathBuf::from(&long));
        assert_eq!(plain(r"\\?\Volume{0}\x"), PathBuf::from(r"\\?\Volume{0}\x"));
    }

    /// `canonicalize` gives `\\?\C:\…`, which `cmd.exe` won't start in.
    #[test]
    fn canonical_paths_are_plain() {
        let dir = tempfile::tempdir().unwrap();
        let path = super::super::canonical(dir.path().to_path_buf());
        assert!(
            !path.to_string_lossy().starts_with(r"\\?\"),
            "{}",
            path.display()
        );
        assert!(path.is_dir());
    }

    #[test]
    fn same_file_ignores_case() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("Notes.md");
        std::fs::write(&path, "x").unwrap();
        let meta = std::fs::metadata(&path).unwrap();
        assert!(Windows::same_file(
            &dir.path().join("notes.MD"),
            &path,
            &meta
        ));
        assert!(!Windows::same_file(
            &dir.path().join("other.md"),
            &path,
            &meta
        ));
    }
}
