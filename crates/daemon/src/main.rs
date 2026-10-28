//! `kumod` binary entry point.

use std::io::IsTerminal;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::process::ExitCode;

use clap::Parser;
use kumo_domain::daemon::{DaemonError, ListenAddress};
use kumod::{Daemon, DaemonConfig};
use tracing_subscriber::EnvFilter;

/// Kumo daemon: runs agents and terminals, serves the UI over gRPC.
#[derive(Debug, Parser)]
#[command(version)]
struct Args {
    /// Loopback address to listen on. Port 0 picks an ephemeral port.
    #[arg(long, default_value = "127.0.0.1:0")]
    listen: SocketAddr,

    /// Directory for `daemon.json` (default: per-user local data dir).
    #[arg(long)]
    data_dir: Option<PathBuf>,

    /// Async worker threads. The daemon is I/O bound: a few workers beat
    /// one per core (less wake-up contention), see docs/perf/.
    #[arg(long, default_value_t = 2)]
    worker_threads: usize,
}

fn main() -> ExitCode {
    let args = Args::parse();
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(args.worker_threads.max(1))
        .thread_name("kumod-worker")
        .enable_all()
        .build();
    match runtime {
        Ok(runtime) => runtime.block_on(async_main(args)),
        Err(error) => {
            eprintln!("kumod: failed to start async runtime: {error}");
            ExitCode::FAILURE
        }
    }
}

async fn async_main(args: Args) -> ExitCode {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
        .with_ansi(std::io::stderr().is_terminal())
        .with_writer(std::io::stderr)
        .init();

    match run(args).await {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            if let Some(DaemonError::AlreadyRunning { addr, pid }) = error.downcast_ref() {
                eprintln!("kumod is already running at {addr} (pid {pid})");
                return ExitCode::SUCCESS;
            }
            eprintln!("kumod: {error:#}");
            ExitCode::FAILURE
        }
    }
}

async fn run(args: Args) -> anyhow::Result<()> {
    let config = DaemonConfig {
        listen: ListenAddress::new(args.listen)?,
        data_dir: args.data_dir,
        ..DaemonConfig::default()
    };
    Daemon::start(config).await?.run(shutdown_signal()).await
}

/// Ctrl-C everywhere, plus SIGTERM on Unix.
async fn shutdown_signal() {
    let ctrl_c = async {
        let _ = tokio::signal::ctrl_c().await;
    };
    #[cfg(unix)]
    {
        use tokio::signal::unix::{SignalKind, signal};
        match signal(SignalKind::terminate()) {
            Ok(mut term) => tokio::select! {
                _ = ctrl_c => {}
                _ = term.recv() => {}
            },
            Err(_) => ctrl_c.await,
        }
    }
    #[cfg(not(unix))]
    ctrl_c.await;
}
