//! What each OS does its own way, behind one interface per need.
//!
//! Every OS has its own file (`macos.rs`, `linux.rs`, `windows.rs`) that
//! implements all the traits below; what macOS and Linux share lives in
//! `unix.rs`. The build picks one as [`Current`], so the code of one OS
//! never runs, nor needs to compile, on another, and a fix for one can't
//! change another. The rest of the crate calls the functions at the end of
//! this file and never asks which OS it is on.

use std::collections::HashMap;
use std::ffi::OsStr;
use std::fs::{Metadata, OpenOptions};
use std::future::Future;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Arc;

use keyring_core::{CredentialStore, Error as KeyringError};

#[cfg(unix)]
mod unix;

#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "macos")]
use macos::MacOs as Current;

#[cfg(all(unix, not(target_os = "macos")))]
mod linux;
#[cfg(all(unix, not(target_os = "macos")))]
use linux::Linux as Current;

#[cfg(windows)]
mod windows;
#[cfg(windows)]
use windows::Windows as Current;

/// How the daemon starts programs the user never sees (git, gh,
/// ssh-keygen, an agent's `--version`). Terminals don't come through
/// here: the PTY gives them their own.
pub trait BackgroundPrograms {
    /// A [`Command`] for `program` that runs out of sight.
    fn command(program: &OsStr) -> Command;
}

/// Where programs are found: the user's PATH and what counts as a program.
pub trait ProgramSearch {
    /// The PATH the user's own shell sets up, when it isn't the one Kumo
    /// was started with (apps opened from the Finder get a minimal one).
    fn login_shell_path() -> Option<String>;
    /// Install folders searched after the PATH, outside the home folder.
    fn install_dirs() -> Vec<PathBuf>;
    /// The file names `program` can have, in the order they're tried.
    fn executable_names(program: &str) -> Vec<String>;
    /// Whether a file with this metadata can be run.
    fn is_executable(meta: &Metadata) -> bool;
}

/// Running a command line the user wrote (a project's test command).
pub trait ScriptShell {
    /// The program and arguments that run `command`.
    fn script(command: &str) -> (String, Vec<String>);
}

/// Telling files apart.
pub trait FileIdentity {
    /// A number that changes when the file at a path is swapped for
    /// another; None when the OS has none to give.
    fn file_id(meta: &Metadata) -> Option<u64>;
    /// Whether `existing` (the metadata of `target`) is `source` itself.
    fn same_file(source: &Path, target: &Path, existing: &Metadata) -> bool;
}

/// Files only their owner may read.
pub trait PrivateFiles {
    /// Makes `options` create the file readable by its owner only.
    fn owner_only(options: &mut OpenOptions);
}

/// The OS keychain behind [`crate::secrets::KeychainSecretStore`].
pub trait Keychain {
    fn native_store() -> Result<Arc<CredentialStore>, KeyringError>;
    /// What finds every item of `service`, as this store searches.
    fn search_spec(service: &'static str) -> HashMap<&'static str, &'static str>;
}

/// Where other apps keep their settings.
pub trait AppFolders {
    /// Obsidian's list of vaults.
    fn obsidian_settings(home: &Path) -> PathBuf;
}

/// What the agents' CLIs can run for Kumo.
pub trait AgentHooks {
    /// Whether Claude Code runs a POSIX `sh` status line command (Kumo's
    /// usage hook is one).
    fn sh_status_line() -> bool;
}

/// A running process, as seen from outside.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RunningProcess {
    pub exe: PathBuf,
    /// Its arguments, the program first.
    pub args: Vec<String>,
    pub cwd: PathBuf,
}

/// Reading other processes (an agent CLI started by hand in a terminal).
pub trait Processes {
    /// What `pid` runs and where; None when the OS can't tell.
    fn process(pid: u32) -> Option<RunningProcess>;
}

/// How the OS asks the daemon to stop.
pub trait Signals {
    /// Resolves when the daemon is asked to stop.
    fn shutdown() -> impl Future<Output = ()> + Send;
}

/// `Command::new(program)` as this OS runs a background program.
pub fn background(program: impl AsRef<OsStr>) -> Command {
    Current::command(program.as_ref())
}

/// See [`ProgramSearch::login_shell_path`].
pub fn login_shell_path() -> Option<String> {
    Current::login_shell_path()
}

/// See [`ProgramSearch::install_dirs`].
pub fn install_dirs() -> Vec<PathBuf> {
    Current::install_dirs()
}

/// See [`ProgramSearch::executable_names`].
pub fn executable_names(program: &str) -> Vec<String> {
    Current::executable_names(program)
}

/// Whether `path` is a file this OS can run.
pub fn is_executable(path: &Path) -> bool {
    std::fs::metadata(path).is_ok_and(|meta| Current::is_executable(&meta))
}

/// See [`ScriptShell::script`].
pub fn script(command: &str) -> (String, Vec<String>) {
    Current::script(command)
}

/// See [`FileIdentity::file_id`].
pub fn file_id(meta: &Metadata) -> Option<u64> {
    Current::file_id(meta)
}

/// See [`FileIdentity::same_file`].
pub fn same_file(source: &Path, target: &Path, existing: &Metadata) -> bool {
    Current::same_file(source, target, existing)
}

/// See [`PrivateFiles::owner_only`].
pub fn owner_only(options: &mut OpenOptions) {
    Current::owner_only(options);
}

/// See [`Keychain::native_store`].
pub fn native_keychain() -> Result<Arc<CredentialStore>, KeyringError> {
    Current::native_store()
}

/// See [`Keychain::search_spec`].
pub fn keychain_search(service: &'static str) -> HashMap<&'static str, &'static str> {
    Current::search_spec(service)
}

/// See [`AppFolders::obsidian_settings`].
pub fn obsidian_settings(home: &Path) -> PathBuf {
    Current::obsidian_settings(home)
}

/// See [`AgentHooks::sh_status_line`].
pub fn sh_status_line() -> bool {
    Current::sh_status_line()
}

/// See [`Processes::process`].
pub fn process(pid: u32) -> Option<RunningProcess> {
    Current::process(pid)
}

/// See [`Signals::shutdown`].
pub fn shutdown_signal() -> impl Future<Output = ()> + Send {
    Current::shutdown()
}
