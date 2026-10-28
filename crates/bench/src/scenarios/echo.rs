//! Keystroke echo without UI: budget p50 ≤ 1 ms, p99 ≤ 3 ms.
//!
//! Sends one byte at a time to a raw-mode `cat` and waits for it to come
//! back. Also reports the PTY-read → client leg using the batch timestamp
//! (same machine, same wall clock), an upper bound for the daemon leg
//! (budget p99 ≤ 2 ms).

use std::time::{Duration, Instant};

use bytes::Bytes;
use kumo_domain::time::Timestamp;
use kumo_grpc::client::KumoClient;

use crate::report;
use crate::scenarios::echo_program;
use crate::terminal::{BenchTerminal, Output};

pub async fn run(
    client: &mut KumoClient,
    iterations: u32,
    warmup: u32,
    pause_ms: u64,
) -> anyhow::Result<()> {
    let (program, args) = echo_program()?;
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    let mut terminal = BenchTerminal::open(client, &program, &args).await?;
    terminal.wait_for(b"READY").await?;

    let mut round_trip = report::latency_histogram();
    let mut pty_to_client = report::latency_histogram();
    let mut coalesced = 0_u64;
    let pause = Duration::from_millis(pause_ms);

    for i in 0..warmup + iterations {
        let key = b'a' + (i % 26) as u8;
        let sent = Instant::now();
        terminal.send(Bytes::copy_from_slice(&[key])).await?;
        let batch = loop {
            match terminal.next().await? {
                Some(Output::Batch(batch)) if batch.data.contains(&key) => break batch,
                Some(Output::Batch(_)) => continue,
                Some(Output::Exited(code)) => anyhow::bail!("echo program exited ({code})"),
                None => anyhow::bail!("stream ended"),
            }
        };
        let received_at = Timestamp::now();
        if i >= warmup {
            report::record(&mut round_trip, sent.elapsed());
            let first_read = Timestamp::from_unix_nanos(batch.first_read_unix_nanos);
            report::record(&mut pty_to_client, received_at.since(first_read));
            coalesced += u64::from(batch.chunks > 1);
        }
        tokio::time::sleep(pause).await;
    }
    terminal.close(client).await?;

    println!("\n## echo ({program}, {pause_ms} ms between keys)");
    report::print_latency(
        "keystroke echo (client↔PTY)",
        &round_trip,
        Some(Duration::from_millis(3)),
    );
    report::print_latency(
        "PTY read → client (daemon leg)",
        &pty_to_client,
        Some(Duration::from_millis(2)),
    );
    println!("batches with >1 chunk: {coalesced}");
    Ok(())
}
