//! Linux (and any other Unix but macOS).

use std::collections::HashMap;
use std::ffi::OsStr;
use std::fs::{Metadata, OpenOptions};
use std::future::Future;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Arc;

use keyring_core::{CredentialStore, Error as KeyringError};

use super::{
    AgentHooks, AppFolders, BackgroundPrograms, FileIdentity, Keychain, PrivateFiles, Processes,
    ProgramSearch, RunningProcess, ScriptShell, Signals, unix,
};

pub struct Linux;

impl BackgroundPrograms for Linux {
    fn command(program: &OsStr) -> Command {
        unix::command(program)
    }
}

impl ProgramSearch for Linux {
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

impl ScriptShell for Linux {
    fn script(command: &str) -> (String, Vec<String>) {
        unix::script(command)
    }
}

impl FileIdentity for Linux {
    fn file_id(meta: &Metadata) -> Option<u64> {
        unix::file_id(meta)
    }
    fn same_file(source: &Path, target: &Path, existing: &Metadata) -> bool {
        unix::same_file(source, target, existing)
    }
}

impl PrivateFiles for Linux {
    fn owner_only(options: &mut OpenOptions) {
        unix::owner_only(options);
    }
}

/// None yet: tokens are kept in memory only.
impl Keychain for Linux {
    fn native_store() -> Result<Arc<CredentialStore>, KeyringError> {
        Err(KeyringError::NotSupportedByStore(
            "Linux keychains aren't supported yet".into(),
        ))
    }
    fn search_spec(service: &'static str) -> HashMap<&'static str, &'static str> {
        HashMap::from([("pattern", service)])
    }
}

impl AppFolders for Linux {
    fn obsidian_settings(home: &Path) -> PathBuf {
        home.join(".config/obsidian/obsidian.json")
    }
}

impl AgentHooks for Linux {
    fn sh_status_line() -> bool {
        unix::sh_status_line()
    }
}

impl Signals for Linux {
    fn shutdown() -> impl Future<Output = ()> + Send {
        unix::shutdown()
    }
}

impl Processes for Linux {
    fn process(pid: u32) -> Option<RunningProcess> {
        let dir = PathBuf::from(format!("/proc/{pid}"));
        let exe = std::fs::read_link(dir.join("exe")).ok()?;
        let args = std::fs::read(dir.join("cmdline"))
            .map(|raw| {
                raw.split(|b| *b == 0)
                    .filter(|a| !a.is_empty())
                    .map(|a| String::from_utf8_lossy(a).into_owned())
                    .collect()
            })
            .unwrap_or_default();
        let cwd = std::fs::read_link(dir.join("cwd")).unwrap_or_default();
        Some(RunningProcess { exe, args, cwd })
    }
}
