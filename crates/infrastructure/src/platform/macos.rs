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
    AgentHooks, AppFolders, BackgroundPrograms, FileIdentity, Keychain, PrivateFiles, ProcessTrees,
    Processes, ProgramSearch, RunningProcess, ScriptShell, Signals, unix,
};

pub struct MacOs;

impl BackgroundPrograms for MacOs {
    fn command(program: &OsStr) -> Command {
        unix::command(program)
    }
}

impl ProcessTrees for MacOs {
    fn own_group(command: &mut Command) {
        unix::own_group(command);
    }
    fn kill_tree(pid: u32) {
        unix::kill_tree(pid);
    }
    fn kill_group(pid: u32) {
        unix::kill_group(pid);
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

    fn owner_only_dir(dir: &Path) -> std::io::Result<()> {
        unix::owner_only_dir(dir)
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

impl Processes for MacOs {
    /// `ps` for its executable and arguments, `lsof` for its folder: no
    /// /proc here, and Kumo uses no unsafe code to call libproc.
    fn process(pid: u32) -> Option<RunningProcess> {
        let pid = pid.to_string();
        let mut ps = unix::command(OsStr::new("/bin/ps"));
        ps.args(["-ww", "-o", "comm=", "-p", &pid]);
        let (exe, _) =
            crate::process::run_with_timeout(ps, std::time::Duration::from_secs(2)).ok()?;
        let mut ps = unix::command(OsStr::new("/bin/ps"));
        ps.args(["-ww", "-o", "args=", "-p", &pid]);
        let (args, _) =
            crate::process::run_with_timeout(ps, std::time::Duration::from_secs(2)).ok()?;
        let mut lsof = unix::command(OsStr::new("/usr/sbin/lsof"));
        lsof.args(["-a", "-d", "cwd", "-p", &pid, "-Fn"]);
        let cwd = crate::process::run_with_timeout(lsof, std::time::Duration::from_secs(2))
            .ok()
            .and_then(|(out, _)| {
                out.lines()
                    .find_map(|l| l.strip_prefix('n').map(PathBuf::from))
            })
            .unwrap_or_default();
        let exe = exe.trim();
        (!exe.is_empty()).then(|| RunningProcess {
            exe: PathBuf::from(exe),
            // Split on spaces: enough to tell the program and its script.
            args: args.split_whitespace().map(str::to_owned).collect(),
            cwd,
        })
    }
}
