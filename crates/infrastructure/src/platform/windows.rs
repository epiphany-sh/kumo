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
    AgentHooks, AppFolders, BackgroundPrograms, FileIdentity, Keychain, PrivateFiles, ProcessTrees,
    Processes, ProgramSearch, RunningProcess, ScriptShell, Signals,
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

impl PrivateFiles for Windows {
    /// Files under the user's profile are already theirs alone.
    fn owner_only(_options: &mut OpenOptions) {}
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
