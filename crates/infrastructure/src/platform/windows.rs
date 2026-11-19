//! Windows.

use std::collections::HashMap;
use std::ffi::OsStr;
use std::fs::{Metadata, OpenOptions};
use std::os::windows::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Arc;

use keyring_core::{CredentialStore, Error as KeyringError};
use winreg::RegKey;
use winreg::enums::{HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE};

use super::{
    AgentHooks, AppFolders, BackgroundPrograms, FileIdentity, Keychain, PlainPaths, PrivateFiles,
    ProcessTrees, Processes, ProgramSearch, RunningProcess, SavedSignIns, ScriptShell, Signals,
    StatusLineHook, TerminalShells, process_tree, windows_processes,
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
    /// The PATH saved in the registry: Kumo's own is the one it started
    /// with, so a CLI installed since (npm, WinGet) would be missing.
    fn login_shell_path() -> Option<String> {
        registry_path(
            saved_path(&RegKey::predef(HKEY_LOCAL_MACHINE), MACHINE_ENVIRONMENT),
            saved_path(&RegKey::predef(HKEY_CURRENT_USER), USER_ENVIRONMENT),
            &env_var,
        )
    }

    /// The usual install folders that exist, in case the PATH lacks them.
    fn install_dirs() -> Vec<PathBuf> {
        existing_install_dirs(&env_var)
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

/// Where the system's and the user's PATH are saved.
const MACHINE_ENVIRONMENT: &str = r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment";
const USER_ENVIRONMENT: &str = "Environment";

/// The `Path` value under `subkey` of `root`, as saved (`%VARS%` unexpanded).
fn saved_path(root: &RegKey, subkey: &str) -> Option<String> {
    root.open_subkey(subkey).ok()?.get_value("Path").ok()
}

/// A process environment variable, None when unset or empty.
fn env_var(name: &str) -> Option<String> {
    std::env::var(name).ok().filter(|value| !value.is_empty())
}

/// `%NAME%` replaced by `lookup(NAME)`; like `ExpandEnvironmentStrings`,
/// what isn't set stays as written.
fn expand_vars(text: &str, lookup: &impl Fn(&str) -> Option<String>) -> String {
    let mut out = String::with_capacity(text.len());
    let mut rest = text;
    while let Some(start) = rest.find('%') {
        out.push_str(&rest[..start]);
        let after = &rest[start + 1..];
        let Some(end) = after.find('%') else {
            out.push_str(&rest[start..]);
            return out;
        };
        let name = &after[..end];
        let value = if name.is_empty() { None } else { lookup(name) };
        match value {
            Some(value) => {
                out.push_str(&value);
                rest = &after[end + 1..];
            }
            // The closing `%` may open the next variable.
            None => {
                out.push('%');
                out.push_str(name);
                rest = &after[end..];
            }
        }
    }
    out.push_str(rest);
    out
}

/// The system's PATH, then the user's, expanded: how Windows builds the
/// PATH of a new process. None when neither has anything.
fn registry_path(
    machine: Option<String>,
    user: Option<String>,
    lookup: &impl Fn(&str) -> Option<String>,
) -> Option<String> {
    let parts: Vec<String> = [machine, user]
        .into_iter()
        .flatten()
        .map(|part| expand_vars(part.trim_matches(';'), lookup))
        .filter(|part| !part.is_empty())
        .collect();
    (!parts.is_empty()).then(|| parts.join(";"))
}

/// Where npm, Scoop, WinGet, the Store and the curl-style installers put
/// their programs; those under an unset variable left out.
fn install_dir_candidates(lookup: &impl Fn(&str) -> Option<String>) -> Vec<PathBuf> {
    [
        ("APPDATA", "npm"),
        ("USERPROFILE", r"scoop\shims"),
        ("LOCALAPPDATA", r"Microsoft\WinGet\Links"),
        ("LOCALAPPDATA", r"Microsoft\WindowsApps"),
        ("USERPROFILE", r".local\bin"),
        ("USERPROFILE", r".cargo\bin"),
        ("USERPROFILE", r".bun\bin"),
    ]
    .into_iter()
    .filter_map(|(var, dir)| {
        let base = lookup(var).filter(|base| !base.is_empty())?;
        Some(Path::new(&base).join(dir))
    })
    .collect()
}

/// The [candidates](install_dir_candidates) that exist.
fn existing_install_dirs(lookup: &impl Fn(&str) -> Option<String>) -> Vec<PathBuf> {
    install_dir_candidates(lookup)
        .into_iter()
        .filter(|dir| dir.is_dir())
        .collect()
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

impl TerminalShells for Windows {
    /// cmd.exe and PowerShell aren't covered, and a Git Bash would be
    /// handed Windows paths to its scripts.
    fn shell_integration() -> bool {
        false
    }
}

impl AgentHooks for Windows {
    /// Claude Code runs status lines through Git Bash or PowerShell,
    /// whichever it finds: no way to know which, so Kumo's is a
    /// `powershell.exe` command that runs the same in both.
    fn status_line_hook() -> StatusLineHook {
        StatusLineHook::PowerShell
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
    /// Its executable's path, its command line split as the C runtime
    /// splits it, and its current directory (empty when it can't be read).
    fn process(pid: u32) -> Option<RunningProcess> {
        let exe = windows_processes::exe(pid)?;
        let args = windows_processes::command_line(pid)
            .map(|line| process_tree::split_command_line(&line))
            .unwrap_or_default();
        let cwd = windows_processes::cwd(pid).unwrap_or_default();
        Some(RunningProcess { exe, args, cwd })
    }

    /// ConPTY has no process groups: one snapshot of every process, read
    /// as [`process_tree::foreground`] says. Start times are read only
    /// for what the walk compares, in the root's tree alone (see
    /// [`process_tree::start_times_needed`]). Blocks: run it off the async
    /// runtime.
    fn foreground(root: u32) -> Option<u32> {
        let mut rows = windows_processes::snapshot();
        let needed = process_tree::start_times_needed(&rows, root);
        for row in &mut rows {
            if needed.contains(&row.pid) {
                row.created = windows_processes::created(row.pid);
            }
        }
        process_tree::foreground(&rows, root)
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

    fn env<'a>(vars: &'a [(&'a str, &'a str)]) -> impl Fn(&str) -> Option<String> + 'a {
        move |name| {
            vars.iter()
                .find(|(key, _)| key.eq_ignore_ascii_case(name))
                .map(|(_, value)| (*value).to_owned())
        }
    }

    #[test]
    fn expands_variables_and_keeps_unknown_ones() {
        let lookup = env(&[
            ("USERPROFILE", r"C:\Users\me"),
            ("SystemRoot", r"C:\WINDOWS"),
        ]);
        assert_eq!(
            expand_vars(r"%USERPROFILE%\bin;%systemroot%\system32", &lookup),
            r"C:\Users\me\bin;C:\WINDOWS\system32"
        );
        // Like ExpandEnvironmentStrings: what isn't set stays as written.
        assert_eq!(expand_vars(r"%NOPE%\bin", &lookup), r"%NOPE%\bin");
        assert_eq!(expand_vars("100% sure", &lookup), "100% sure");
        assert_eq!(expand_vars("%%", &lookup), "%%");
    }

    #[test]
    fn the_registry_path_is_the_machine_one_then_the_users() {
        let lookup = env(&[("USERPROFILE", r"C:\Users\me")]);
        assert_eq!(
            registry_path(
                Some(r"C:\WINDOWS;C:\Tools;".to_owned()),
                Some(r"%USERPROFILE%\AppData\Roaming\npm".to_owned()),
                &lookup
            ),
            Some(r"C:\WINDOWS;C:\Tools;C:\Users\me\AppData\Roaming\npm".to_owned())
        );
        assert_eq!(
            registry_path(None, Some(r"C:\x".to_owned()), &lookup),
            Some(r"C:\x".to_owned())
        );
        assert_eq!(registry_path(Some(String::new()), None, &lookup), None);
    }

    #[test]
    fn install_dirs_are_the_usual_ones_that_exist() {
        let root = tempfile::tempdir().unwrap();
        let profile = root.path().join("me");
        let appdata = profile.join(r"AppData\Roaming");
        let local = profile.join(r"AppData\Local");
        let profile_text = profile.display().to_string();
        let appdata_text = appdata.display().to_string();
        let local_text = local.display().to_string();
        let vars = [
            ("USERPROFILE", profile_text.as_str()),
            ("APPDATA", appdata_text.as_str()),
            ("LOCALAPPDATA", local_text.as_str()),
        ];
        let lookup = env(&vars);
        assert_eq!(
            install_dir_candidates(&lookup),
            [
                appdata.join("npm"),
                profile.join(r"scoop\shims"),
                local.join(r"Microsoft\WinGet\Links"),
                local.join(r"Microsoft\WindowsApps"),
                profile.join(r".local\bin"),
                profile.join(r".cargo\bin"),
                profile.join(r".bun\bin"),
            ]
        );
        assert_eq!(existing_install_dirs(&lookup), Vec::<PathBuf>::new());

        std::fs::create_dir_all(appdata.join("npm")).unwrap();
        std::fs::create_dir_all(profile.join(r"scoop\shims")).unwrap();
        assert_eq!(
            existing_install_dirs(&lookup),
            [appdata.join("npm"), profile.join(r"scoop\shims")]
        );
    }

    #[test]
    fn install_dirs_skip_unset_variables() {
        let lookup = env(&[
            ("APPDATA", r"C:\Users\me\AppData\Roaming"),
            ("USERPROFILE", ""),
        ]);
        assert_eq!(
            install_dir_candidates(&lookup),
            [PathBuf::from(r"C:\Users\me\AppData\Roaming\npm")]
        );
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
        let path = super::super::canonical(dir.path());
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
