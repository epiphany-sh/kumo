//! macOS.

use std::collections::HashMap;
use std::ffi::OsStr;
use std::fs::{Metadata, OpenOptions};
use std::future::Future;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Arc;

use keyring_core::{CredentialStore, Error as KeyringError};

use super::{
    AgentHooks, AppFolders, BackgroundPrograms, FileIdentity, Keychain, PrivateFiles,
    ProgramSearch, ScriptShell, Signals, unix,
};

pub struct MacOs;

impl BackgroundPrograms for MacOs {
    fn command(program: &OsStr) -> Command {
        unix::command(program)
    }
}

impl ProgramSearch for MacOs {
    fn login_shell_path() -> Option<String> {
        unix::login_shell_path()
    }
    fn install_dirs() -> Vec<PathBuf> {
        unix::install_dirs()
    }
    fn executable_names(program: &str) -> Vec<String> {
        unix::executable_names(program)
    }
    fn is_executable(meta: &Metadata) -> bool {
        unix::is_executable(meta)
    }
}

impl ScriptShell for MacOs {
    fn script(command: &str) -> (String, Vec<String>) {
        unix::script(command)
    }
}

impl FileIdentity for MacOs {
    fn file_id(meta: &Metadata) -> Option<u64> {
        unix::file_id(meta)
    }
    fn same_file(source: &Path, target: &Path, existing: &Metadata) -> bool {
        unix::same_file(source, target, existing)
    }
}

impl PrivateFiles for MacOs {
    fn owner_only(options: &mut OpenOptions) {
        unix::owner_only(options);
    }
}

/// The login keychain.
impl Keychain for MacOs {
    fn native_store() -> Result<Arc<CredentialStore>, KeyringError> {
        Ok(apple_native_keyring_store::keychain::Store::new()?)
    }
    fn search_spec(service: &'static str) -> HashMap<&'static str, &'static str> {
        HashMap::from([("service", service)])
    }
}

impl AppFolders for MacOs {
    fn obsidian_settings(home: &Path) -> PathBuf {
        home.join("Library/Application Support/obsidian/obsidian.json")
    }
}

impl AgentHooks for MacOs {
    fn sh_status_line() -> bool {
        unix::sh_status_line()
    }
}

impl Signals for MacOs {
    fn shutdown() -> impl Future<Output = ()> + Send {
        unix::shutdown()
    }
}
