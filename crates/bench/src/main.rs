//! `kumo-bench`: measures the daemon against the budget in kumo.md §4.
//!
//! By default it spawns its own `kumod` (next to this binary) with a
//! throwaway data dir, so runs are isolated and reproducible.
//! Build with `--release` before measuring.

mod daemon_process;
mod report;
mod scenarios;
mod terminal;

use std::path::PathBuf;

use clap::{Parser, Subcommand};
use kumo_grpc::client::KumoClient;

use daemon_process::DaemonProcess;

#[derive(Debug, Parser)]
#[command(about = "Kumo daemon benchmarks")]
struct Args {
    /// Path to `kumod` (default: next to this binary).
    #[arg(long, global = true)]
    daemon: Option<PathBuf>,

    /// Extra arguments for `kumod` (e.g. `--daemon-arg=--worker-threads=4`).
    #[arg(long = "daemon-arg", global = true, allow_hyphen_values = true)]
    daemon_args: Vec<String>,

    #[command(subcommand)]
    scenario: Scenario,
}

#[derive(Debug, Subcommand)]
enum Scenario {
    /// Unary `Hello` round-trip time.
    Hello {
        #[arg(long, default_value_t = 10_000)]
        iterations: u32,
        #[arg(long, default_value_t = 1_000)]
        warmup: u32,
    },
    /// Keystroke echo through gRPC and a raw-mode PTY.
    Echo {
        #[arg(long, default_value_t = 1_000)]
        iterations: u32,
        #[arg(long, default_value_t = 100)]
        warmup: u32,
        /// Pause between keystrokes, in milliseconds.
        #[arg(long, default_value_t = 2)]
        pause_ms: u64,
    },
    /// Sustained terminal output.
    Throughput,
    /// All of the above with default parameters.
    All,
}

// One connection, one client: a single-threaded runtime keeps the client
// side from competing with the daemon for cores.
#[tokio::main(flavor = "current_thread")]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let daemon = DaemonProcess::spawn(args.daemon, &args.daemon_args).await?;
    let mut client = KumoClient::connect(daemon.endpoint().addr, &daemon.endpoint().token).await?;
    client.hello("kumo-bench").await?;

    report::print_environment();
    match args.scenario {
        Scenario::Hello { iterations, warmup } => {
            scenarios::hello::run(&mut client, iterations, warmup).await?
        }
        Scenario::Echo {
            iterations,
            warmup,
            pause_ms,
        } => scenarios::echo::run(&mut client, iterations, warmup, pause_ms).await?,
        Scenario::Throughput => scenarios::throughput::run(&mut client).await?,
        Scenario::All => {
            scenarios::hello::run(&mut client, 10_000, 1_000).await?;
            scenarios::echo::run(&mut client, 1_000, 100, 2).await?;
            scenarios::throughput::run(&mut client).await?;
        }
    }
    Ok(())
}
