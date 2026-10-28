//! A `kumod` child process with its own throwaway data directory.

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
    _data_dir: tempfile::TempDir,
}

impl DaemonProcess {
    pub async fn spawn(binary: Option<PathBuf>, extra_args: &[String]) -> anyhow::Result<Self> {
        let binary = match binary {
            Some(path) => path,
            None => sibling_binary("kumod")?,
        };
        let data_dir = tempfile::tempdir()?;
        let child = Command::new(&binary)
            .arg("--data-dir")
            .arg(data_dir.path())
            .args(extra_args)
            .env("RUST_LOG", "warn")
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
            _data_dir: data_dir,
        })
    }

    pub fn endpoint(&self) -> &DaemonEndpoint {
        &self.endpoint
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
