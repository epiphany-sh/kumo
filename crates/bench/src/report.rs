//! Plain-text reporting, easy to paste into `docs/perf/`.

use std::time::Duration;

use hdrhistogram::Histogram;

pub fn print_environment() {
    println!(
        "# kumo-bench {} — {} {} — {} logical CPUs",
        env!("CARGO_PKG_VERSION"),
        std::env::consts::OS,
        std::env::consts::ARCH,
        std::thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(0),
    );
    if cfg!(debug_assertions) {
        println!("WARNING: debug build, numbers are not representative (use --release)");
    }
}

/// Latency histogram in nanoseconds.
pub fn latency_histogram() -> Histogram<u64> {
    Histogram::new_with_bounds(1, 60_000_000_000, 3).expect("valid histogram bounds")
}

pub fn record(histogram: &mut Histogram<u64>, value: Duration) {
    let nanos = u64::try_from(value.as_nanos()).unwrap_or(u64::MAX).max(1);
    histogram.saturating_record(nanos);
}

pub fn print_latency(name: &str, histogram: &Histogram<u64>, budget_p99: Option<Duration>) {
    let ms = |q: f64| histogram.value_at_quantile(q) as f64 / 1e6;
    let verdict = match budget_p99 {
        Some(budget) if Duration::from_nanos(histogram.value_at_quantile(0.99)) <= budget => {
            format!("  ✅ p99 ≤ {} ms", budget.as_secs_f64() * 1e3)
        }
        Some(budget) => format!("  ❌ p99 > {} ms", budget.as_secs_f64() * 1e3),
        None => String::new(),
    };
    println!(
        "{name:<34} n={:<6} p50={:>7.3} ms  p95={:>7.3} ms  p99={:>7.3} ms  max={:>7.3} ms{verdict}",
        histogram.len(),
        ms(0.50),
        ms(0.95),
        ms(0.99),
        histogram.max() as f64 / 1e6,
    );
}
