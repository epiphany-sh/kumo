//! What macOS and Linux do the same way: `macos.rs` and `linux.rs` call
//! these.

use std::ffi::OsStr;
use std::fs::{Metadata, OpenOptions};
use std::os::unix::fs::{MetadataExt, OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Duration;

use crate::process::run_with_timeout;

const MARK: &str = "__KUMO_PATH__";
const SHELL_TIMEOUT: Duration = Duration::from_secs(5);

/// A plain `Command`: a program without a terminal shows nothing.
pub(super) fn command(program: &OsStr) -> Command {
    Command::new(program)
}

/// `$PATH` as the user's login shell sets it up.
pub(super) fn own_group(command: &mut Command) {
    use std::os::unix::process::CommandExt;
    command.process_group(0);
}

pub(super) fn kill_tree(pid: u32) {
    // Read first: once it's dead its children move to another parent.
    let table = Command::new("ps")
        .args(["-axo", "pid=,ppid="])
        .output()
        .map(|out| String::from_utf8_lossy(&out.stdout).into_owned())
        .unwrap_or_default();
    // Its group, for what it left behind; each descendant by pid, because a
    // CLI can start its tools in groups of their own (Claude Code does).
    let mut targets = vec![format!("-{pid}")];
    targets.extend(descendants(&table, pid).iter().map(u32::to_string));
    let _ = Command::new("/bin/kill")
        .args(["-KILL", "--"])
        .args(&targets)
        .output();
}

pub(super) fn kill_group(pid: u32) {
    let _ = Command::new("/bin/kill")
        .args(["-KILL", "--", &format!("-{pid}")])
        .output();
}

/// Everything below `pid` in a `pid ppid` table.
fn descendants(table: &str, pid: u32) -> Vec<u32> {
    let rows: Vec<(u32, u32)> = table
        .lines()
        .filter_map(|line| {
            let mut fields = line.split_whitespace();
            Some((fields.next()?.parse().ok()?, fields.next()?.parse().ok()?))
        })
        .collect();
    let mut found = vec![pid];
    let mut next = 0;
    while let Some(&parent) = found.get(next) {
        found.extend(rows.iter().filter(|r| r.1 == parent).map(|r| r.0));
        next += 1;
    }
    found.remove(0);
    found
}

pub(super) fn login_shell_path() -> Option<String> {
    let shell = std::env::var("SHELL").unwrap_or_else(|_| "/bin/zsh".into());
    let mut command = command(OsStr::new(&shell));
    // Interactive too: many people set PATH in .zshrc / .bashrc.
    command.args(["-ilc", &format!("printf '{MARK}%s{MARK}' \"$PATH\"")]);
    let (stdout, _) = run_with_timeout(command, SHELL_TIMEOUT).ok()?;
    let start = stdout.find(MARK)? + MARK.len();
    let end = stdout[start..].find(MARK)? + start;
    Some(stdout[start..end].to_owned())
}

/// Homebrew's folders.
pub(super) fn install_dirs() -> Vec<PathBuf> {
    ["/opt/homebrew/bin", "/usr/local/bin"]
        .into_iter()
        .map(PathBuf::from)
        .collect()
}

/// A program has no extension.
pub(super) fn executable_names(program: &str) -> Vec<String> {
    vec![program.to_owned()]
}

/// A file with an execute bit.
pub(super) fn is_executable(meta: &Metadata) -> bool {
    meta.is_file() && meta.permissions().mode() & 0o111 != 0
}

/// `/bin/sh -c <command>`.
pub(super) fn script(command: &str) -> (String, Vec<String>) {
    (
        "/bin/sh".to_owned(),
        vec!["-c".to_owned(), command.to_owned()],
    )
}

/// The inode.
pub(super) fn file_id(meta: &Metadata) -> Option<u64> {
    Some(meta.ino())
}

/// Same device and inode.
pub(super) fn same_file(source: &Path, _target: &Path, existing: &Metadata) -> bool {
    std::fs::symlink_metadata(source)
        .is_ok_and(|s| s.dev() == existing.dev() && s.ino() == existing.ino())
}

/// Mode `0600`.
pub(super) fn owner_only(options: &mut OpenOptions) {
    options.mode(0o600);
}

/// Claude Code runs status lines with `sh`.
pub(super) fn sh_status_line() -> bool {
    true
}

/// Ctrl-C or SIGTERM.
pub(super) async fn shutdown() {
    use tokio::signal::unix::{SignalKind, signal};
    let ctrl_c = async {
        let _ = tokio::signal::ctrl_c().await;
    };
    match signal(SignalKind::terminate()) {
        Ok(mut term) => tokio::select! {
            _ = ctrl_c => {}
            _ = term.recv() => {}
        },
        Err(_) => ctrl_c.await,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn descendants_go_all_the_way_down() {
        let table = " 10 1\n 11 10\n 12 11\n 13 12\n 20 1\n bad row\n";
        assert_eq!(descendants(table, 10), [11, 12, 13]);
        assert!(descendants(table, 13).is_empty());
    }

    #[test]
    fn runs_background_programs_as_given() {
        let command = command(OsStr::new("sh"));
        assert_eq!(command.get_program(), "sh");
        assert_eq!(command.get_args().count(), 0);
        assert_eq!(command.get_envs().count(), 0);

        let (program, args) = script("exit 3");
        let status = Command::new(program).args(args).status().unwrap();
        assert_eq!(status.code(), Some(3));
    }

    #[test]
    fn needs_the_execute_bit() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("tool");
        std::fs::write(&path, "#!/bin/sh\n").unwrap();
        assert!(!is_executable(&std::fs::metadata(&path).unwrap()));
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
        assert!(is_executable(&std::fs::metadata(&path).unwrap()));
        assert_eq!(executable_names("claude"), vec!["claude".to_owned()]);
    }

    #[test]
    fn private_files_are_owner_only_and_known_by_inode() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("secret");
        let mut options = OpenOptions::new();
        options.write(true).create(true);
        owner_only(&mut options);
        options.open(&path).unwrap();
        let meta = std::fs::metadata(&path).unwrap();
        assert_eq!(meta.permissions().mode() & 0o777, 0o600);
        assert_eq!(file_id(&meta), Some(meta.ino()));
        assert!(same_file(&path, &path, &meta));
        assert!(!same_file(&dir.path().join("other"), &path, &meta));
    }
}
