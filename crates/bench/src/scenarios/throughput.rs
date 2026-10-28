//! Sustained output: budget ≥ 50 MB/s through the daemon.
//!
//! Each workload waits behind a gate (one line of input) so the clock starts
//! exactly when output starts, and nothing is produced before we attach.

use std::time::Instant;

use bytes::Bytes;
use kumo_grpc::client::KumoClient;

use crate::daemon_process::sibling_binary;
use crate::terminal::{BenchTerminal, Output};

const BUDGET_MB_S: f64 = 50.0;
const FLOOD_BYTES: u64 = 100 * 1024 * 1024;

pub async fn run(client: &mut KumoClient) -> anyhow::Result<()> {
    println!("\n## throughput");
    for (name, program, args) in workloads()? {
        let args: Vec<&str> = args.iter().map(String::as_str).collect();
        measure(client, &name, &program, &args).await?;
    }
    Ok(())
}

/// `(name, program, args)`. The shell workloads are the ones in kumo.md;
/// they are bound by the producer (`seq` writes line by line to the tty, BSD
/// `tr` alone does ~22 MB/s). `kumo-echo flood` writes 64 KiB blocks and is
/// the one that actually stresses the daemon.
fn workloads() -> anyhow::Result<Vec<(String, String, Vec<String>)>> {
    let echo = sibling_binary("kumo-echo")?.display().to_string();
    let flood = (
        "100 MiB of 'x' (kumo-echo flood)".to_owned(),
        echo,
        vec!["flood".to_owned(), FLOOD_BYTES.to_string()],
    );
    if cfg!(unix) {
        let gated = |cmd: &str| {
            vec![
                "-c".to_owned(),
                format!("stty -echo; printf READY; read _; {cmd}"),
            ]
        };
        Ok(vec![
            ("seq 1 5000000".into(), "sh".into(), gated("seq 1 5000000")),
            (
                "100 MiB of 'x' (head | tr)".into(),
                "sh".into(),
                gated(&format!("head -c {FLOOD_BYTES} /dev/zero | tr '\\0' x")),
            ),
            flood,
        ])
    } else {
        Ok(vec![flood])
    }
}

async fn measure(
    client: &mut KumoClient,
    name: &str,
    program: &str,
    args: &[&str],
) -> anyhow::Result<()> {
    let mut terminal = BenchTerminal::open(client, program, args).await?;
    terminal.wait_for(b"READY").await?;

    let started = Instant::now();
    terminal.send(Bytes::from_static(b"\n")).await?;
    let (mut bytes, mut batches, mut chunks) = (0_u64, 0_u64, 0_u64);
    let exit_code = loop {
        match terminal.next().await? {
            Some(Output::Batch(batch)) => {
                bytes += batch.data.len() as u64;
                batches += 1;
                chunks += u64::from(batch.chunks);
            }
            Some(Output::Exited(code)) => break code,
            None => anyhow::bail!("stream ended before exit"),
        }
    };
    let elapsed = started.elapsed();
    terminal.close(client).await?;

    let mb_s = bytes as f64 / 1e6 / elapsed.as_secs_f64();
    let verdict = if mb_s >= BUDGET_MB_S { "✅" } else { "❌" };
    println!(
        "{name:<34} {:>8.1} MB in {:>6.2} s = {mb_s:>7.1} MB/s {verdict} (≥ {BUDGET_MB_S})  \
         batches={batches} avg={:.1} KiB chunks/batch={:.1} exit={exit_code}",
        bytes as f64 / 1e6,
        elapsed.as_secs_f64(),
        bytes as f64 / batches.max(1) as f64 / 1024.0,
        chunks as f64 / batches.max(1) as f64,
    );
    Ok(())
}
