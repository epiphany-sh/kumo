//! Unary RTT: budget p99 ≤ 1 ms.

use std::time::{Duration, Instant};

use kumo_grpc::client::KumoClient;
use kumo_grpc::proto as pb;

use crate::report;

pub async fn run(client: &mut KumoClient, iterations: u32, warmup: u32) -> anyhow::Result<()> {
    let request = pb::HelloRequest {
        client_api_version: 1,
        client_name: "kumo-bench".into(),
    };
    let mut rtt = report::latency_histogram();
    for i in 0..warmup + iterations {
        let started = Instant::now();
        client.core.hello(request.clone()).await?;
        if i >= warmup {
            report::record(&mut rtt, started.elapsed());
        }
    }
    println!("\n## hello");
    report::print_latency("unary Hello RTT", &rtt, Some(Duration::from_millis(1)));
    Ok(())
}
