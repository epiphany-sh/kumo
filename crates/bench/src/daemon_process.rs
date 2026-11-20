//! A `kumod` child process with its own throwaway data directory.

use std::collections::HashSet;
use std::ffi::OsString;
use std::path::PathBuf;
use std::process::Stdio;
use std::time::{Duration, Instant};

use anyhow::{Context, bail};
use kumo_domain::daemon::{DaemonEndpoint, DiscoveryStore};
use kumo_infrastructure::discovery::FileDiscoveryStore;
use tokio::process::{Child, Command};

const STARTUP_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug)]
pub struct DaemonProcess {
    endpoint: DaemonEndpoint,
    _child: Child,
    data_dir: tempfile::TempDir,
}

impl DaemonProcess {
    pub async fn spawn(binary: Option<PathBuf>, extra_args: &[String]) -> anyhow::Result<Self> {
        let binary = match binary {
            Some(path) => path,
            None => sibling_binary("kumod")?,
        };
        let data_dir = tempfile::tempdir()?;
        // Every git the daemon runs leaves one file here (git's trace2), so
        // scenarios can count them. Nothing is written while git isn't run.
        let git_trace = data_dir.path().join("git-trace");
        std::fs::create_dir(&git_trace)?;
        let child = Command::new(&binary)
            .arg("--data-dir")
            .arg(data_dir.path())
            .args(extra_args)
            .env("RUST_LOG", "warn")
            .env("GIT_TRACE2_EVENT", &git_trace)
            .stdout(Stdio::null())
            .kill_on_drop(true)
            .spawn()
            .with_context(|| format!("spawning {}", binary.display()))?;

        let store = FileDiscoveryStore::in_dir(data_dir.path());
        let started = Instant::now();
        let endpoint = loop {
            if let Ok(Some(endpoint)) = store.load() {
                break endpoint;
            }
            if started.elapsed() > STARTUP_TIMEOUT {
                bail!("kumod did not write its discovery file in time");
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        };
        Ok(Self {
            endpoint,
            _child: child,
            data_dir,
        })
    }

    pub fn endpoint(&self) -> &DaemonEndpoint {
        &self.endpoint
    }

    /// Where each git process the daemon starts writes its trace.
    pub fn git_trace(&self) -> PathBuf {
        self.data_dir.path().join("git-trace")
    }
}

/// Counts the git processes traced in a folder between two points.
#[derive(Debug)]
pub struct GitCounter {
    dir: PathBuf,
    seen: HashSet<OsString>,
}

impl GitCounter {
    pub fn new(dir: PathBuf) -> Self {
        Self {
            dir,
            seen: HashSet::new(),
        }
    }

    /// The git commands (`status`, `diff`…) run since the last call.
    pub fn take(&mut self) -> anyhow::Result<Vec<String>> {
        let mut names = Vec::new();
        for entry in std::fs::read_dir(&self.dir)? {
            let entry = entry?;
            if !self.seen.insert(entry.file_name()) {
                continue;
            }
            let text = std::fs::read_to_string(entry.path()).unwrap_or_default();
            let name = text
                .lines()
                .find(|l| l.contains(r#""event":"cmd_name""#))
                .and_then(|l| l.split(r#""name":""#).nth(1))
                .and_then(|rest| rest.split('"').next())
                .unwrap_or("?");
            names.push(name.to_owned());
        }
        names.sort();
        Ok(names)
    }
}

/// A binary built alongside this one (same target directory).
pub fn sibling_binary(name: &str) -> anyhow::Result<PathBuf> {
    let exe = std::env::current_exe()?;
    let dir = exe
        .parent()
        .context("bench binary has no parent directory")?;
    let path = dir.join(format!("{name}{}", std::env::consts::EXE_SUFFIX));
    if !path.exists() {
        bail!(
            "{} not found; build the workspace first (cargo build --release)",
            path.display()
        );
    }
    Ok(path)
}
