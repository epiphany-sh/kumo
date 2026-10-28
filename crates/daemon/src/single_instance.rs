//! "Only one daemon per user": a live discovery record wins.

use std::time::Duration;

use kumo_domain::daemon::{DaemonEndpoint, DaemonError, DiscoveryStore};
use kumo_grpc::client::KumoClient;

const PROBE_TIMEOUT: Duration = Duration::from_millis(500);

/// Fails if the advertised daemon answers `Hello`. A stale record (the
/// process died without cleaning up) is ignored and later overwritten.
pub(crate) async fn ensure_not_running(discovery: &dyn DiscoveryStore) -> Result<(), DaemonError> {
    let Ok(Some(existing)) = discovery.load() else {
        return Ok(());
    };
    if responds(&existing).await {
        return Err(DaemonError::AlreadyRunning {
            addr: existing.addr,
            pid: existing.pid,
        });
    }
    tracing::info!(addr = %existing.addr, pid = existing.pid, "ignoring stale discovery file");
    Ok(())
}

async fn responds(endpoint: &DaemonEndpoint) -> bool {
    let probe = async {
        let mut client = KumoClient::connect(endpoint.addr, &endpoint.token)
            .await
            .ok()?;
        client.hello("kumod-probe").await.ok()
    };
    matches!(
        tokio::time::timeout(PROBE_TIMEOUT, probe).await,
        Ok(Some(_))
    )
}
