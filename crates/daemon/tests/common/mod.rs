//! Shared harness: an in-process daemon and terminal helpers.

#![allow(dead_code)]

use std::time::Duration;

use bytes::Bytes;
use kumo_domain::daemon::DaemonEndpoint;
use kumo_grpc::client::KumoClient;
use kumo_proto::v1 as pb;
use kumod::{Daemon, DaemonConfig, SecretsBackend};
use tokio::sync::{mpsc, oneshot};
use tokio_stream::wrappers::ReceiverStream;

pub const TIMEOUT: Duration = Duration::from_secs(10);

/// A daemon serving on loopback for the duration of a test.
pub struct TestDaemon {
    pub endpoint: DaemonEndpoint,
    stop: Option<oneshot::Sender<()>>,
    _data_dir: tempfile::TempDir,
}

impl TestDaemon {
    pub async fn start() -> Self {
        let data_dir = tempfile::tempdir().unwrap();
        let config = test_config(data_dir.path());
        let daemon = Daemon::start(config).await.unwrap();
        let endpoint = daemon.endpoint().clone();
        let (stop, stopped) = oneshot::channel::<()>();
        tokio::spawn(daemon.run(async {
            let _ = stopped.await;
        }));
        Self {
            endpoint,
            stop: Some(stop),
            _data_dir: data_dir,
        }
    }

    pub async fn client(&self) -> KumoClient {
        KumoClient::connect(self.endpoint.addr, &self.endpoint.token)
            .await
            .unwrap()
    }
}

impl Drop for TestDaemon {
    fn drop(&mut self) {
        if let Some(stop) = self.stop.take() {
            let _ = stop.send(());
        }
    }
}

/// Data and home folders inside `dir`, so tests never touch the real ones.
pub fn test_config(dir: &std::path::Path) -> DaemonConfig {
    // Agent CLIs are only looked up in `bin/`: tests never run real ones.
    let bin = dir.join("bin");
    std::fs::create_dir_all(&bin).unwrap();
    DaemonConfig {
        data_dir: Some(dir.join("data")),
        home: Some(dir.join("home")),
        agent_path: Some(bin.display().to_string()),
        // Never the real keychain.
        secrets: SecretsBackend::Memory,
        ..Default::default()
    }
}

impl TestDaemon {
    pub fn home(&self) -> std::path::PathBuf {
        self._data_dir.path().join("home")
    }

    /// The only folder agent CLIs are looked up in.
    pub fn bin(&self) -> std::path::PathBuf {
        self._data_dir.path().join("bin")
    }
}

pub async fn open(client: &mut KumoClient, program: &str, args: &[&str]) -> String {
    let request = pb::OpenRequest {
        program: program.into(),
        args: args.iter().map(|a| (*a).to_owned()).collect(),
        ..Default::default()
    };
    client
        .terminals
        .open(request)
        .await
        .unwrap()
        .into_inner()
        .terminal_id
}

/// What one attachment has received so far.
#[derive(Debug, Default)]
pub struct Received {
    pub batches: Vec<pb::OutputBatch>,
    pub exit_code: Option<i32>,
}

impl Received {
    pub fn text(&self) -> String {
        let bytes: Vec<u8> = self
            .batches
            .iter()
            .flat_map(|b| b.data.iter().copied())
            .collect();
        String::from_utf8_lossy(&bytes).into_owned()
    }

    pub fn seqs(&self) -> Vec<u64> {
        self.batches.iter().map(|b| b.seq).collect()
    }
}

/// A client attached to a terminal.
pub struct Attached {
    input: mpsc::Sender<pb::TerminalInput>,
    output: tonic::Streaming<pb::TerminalOutput>,
    pub received: Received,
}

impl Attached {
    pub async fn new(client: &mut KumoClient, terminal_id: &str, replay: bool) -> Self {
        let (input, rx) = mpsc::channel(16);
        input
            .send(input_msg(pb::terminal_input::Kind::Attach(pb::AttachTo {
                terminal_id: terminal_id.into(),
                replay_scrollback: replay,
            })))
            .await
            .unwrap();
        let output = client
            .terminals
            .attach(ReceiverStream::new(rx))
            .await
            .unwrap()
            .into_inner();
        Self {
            input,
            output,
            received: Received::default(),
        }
    }

    pub async fn send(&self, data: &'static [u8]) {
        self.input
            .send(input_msg(pb::terminal_input::Kind::Data(
                Bytes::from_static(data),
            )))
            .await
            .unwrap();
    }

    pub async fn resize(&self, cols: u32, rows: u32) {
        self.input
            .send(input_msg(pb::terminal_input::Kind::Resize(pb::Resize {
                cols,
                rows,
            })))
            .await
            .unwrap();
    }

    /// Reads until the accumulated text contains `needle`.
    pub async fn read_until(&mut self, needle: &str) {
        tokio::time::timeout(TIMEOUT, async {
            while !self.received.text().contains(needle) {
                assert!(self.next().await, "stream ended before {needle:?}");
            }
        })
        .await
        .unwrap_or_else(|_| {
            panic!(
                "timed out waiting for {needle:?}, got {:?}",
                self.received.text()
            )
        });
    }

    /// Reads until the terminal reports its exit.
    pub async fn read_to_exit(&mut self) -> i32 {
        tokio::time::timeout(TIMEOUT, async {
            while self.received.exit_code.is_none() {
                assert!(self.next().await, "stream ended without exit");
            }
        })
        .await
        .expect("timed out waiting for exit");
        self.received.exit_code.unwrap()
    }

    /// Receives one message. `false` when the stream ended.
    async fn next(&mut self) -> bool {
        use pb::terminal_output::Kind;
        match self.output.message().await.unwrap() {
            Some(pb::TerminalOutput {
                kind: Some(Kind::Output(batch)),
            }) => self.received.batches.push(batch),
            Some(pb::TerminalOutput {
                kind: Some(Kind::Exited(exited)),
            }) => self.received.exit_code = Some(exited.exit_code),
            Some(_) => {}
            None => return false,
        }
        true
    }
}

fn input_msg(kind: pb::terminal_input::Kind) -> pb::TerminalInput {
    pb::TerminalInput { kind: Some(kind) }
}

/// Polls `List` until the terminal shows as exited.
pub async fn wait_exited(client: &mut KumoClient, terminal_id: &str) {
    tokio::time::timeout(TIMEOUT, async {
        loop {
            let list = client
                .terminals
                .list(pb::ListRequest {})
                .await
                .unwrap()
                .into_inner();
            if list
                .terminals
                .iter()
                .any(|t| t.terminal_id == terminal_id && t.exited)
            {
                return;
            }
            tokio::time::sleep(Duration::from_millis(20)).await;
        }
    })
    .await
    .expect("terminal never exited");
}

/// `git init` with one commit, optionally with an `origin` remote.
pub fn git_repo(dir: &std::path::Path, remote: Option<&str>) -> std::path::PathBuf {
    std::fs::create_dir_all(dir).unwrap();
    for args in [
        &["init", "-q", "-b", "main"][..],
        &["config", "user.email", "test@kumo.dev"],
        &["config", "user.name", "Kumo Test"],
    ] {
        git(dir, args);
    }
    std::fs::write(dir.join("README.md"), "hello\n").unwrap();
    git(dir, &["add", "."]);
    git(dir, &["commit", "-q", "-m", "init"]);
    if let Some(url) = remote {
        git(dir, &["remote", "add", "origin", url]);
    }
    std::fs::canonicalize(dir).unwrap()
}

/// Runs git in `dir`, panicking on failure; returns stdout.
pub fn git(dir: &std::path::Path, args: &[&str]) -> String {
    let out = std::process::Command::new("git")
        .arg("-C")
        .arg(dir)
        .args(args)
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "git {args:?}: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    String::from_utf8_lossy(&out.stdout).into_owned()
}

pub async fn save_namespace(
    client: &mut KumoClient,
    name: &str,
    repos: &[&std::path::Path],
) -> String {
    client
        .workspace
        .save_namespace(pb::SaveNamespaceRequest {
            name: name.into(),
            repo_paths: repos.iter().map(|p| p.display().to_string()).collect(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner()
        .id
}
