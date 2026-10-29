//! "Only one daemon per user": a live discovery record wins, and a lock
//! file covers the moments before there is one.

use std::fs::{File, TryLockError};
use std::path::Path;
use std::time::Duration;

use kumo_domain::daemon::{DaemonEndpoint, DaemonError, DiscoveryStore};
use kumo_grpc::client::KumoClient;

const PROBE_TIMEOUT: Duration = Duration::from_millis(500);
/// A daemon that just stopped can keep the lock a moment longer: a process
/// it started inherits the file until it runs its program.
const LOCK_PATIENCE: Duration = Duration::from_secs(1);
const LOCK_RETRY: Duration = Duration::from_millis(50);

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

/// Held for the daemon's lifetime; the OS releases it when the process
/// ends, however it ends.
#[derive(Debug)]
pub(crate) struct InstanceLock(#[allow(dead_code)] File);

/// Fails if another daemon holds the lock: it is still starting (e.g. the
/// keychain is asking the user something), so a second one must not.
pub(crate) async fn lock(data_dir: &Path) -> Result<InstanceLock, DaemonError> {
    let path = data_dir.join("kumod.lock");
    let failed = |reason: String| DaemonError::Lock {
        path: path.clone(),
        reason,
    };
    std::fs::create_dir_all(data_dir).map_err(|e| failed(e.to_string()))?;
    let file = File::create(&path).map_err(|e| failed(e.to_string()))?;
    let deadline = tokio::time::Instant::now() + LOCK_PATIENCE;
    loop {
        match file.try_lock() {
            Ok(()) => return Ok(InstanceLock(file)),
            Err(TryLockError::WouldBlock) if tokio::time::Instant::now() < deadline => {
                tokio::time::sleep(LOCK_RETRY).await;
            }
            Err(TryLockError::WouldBlock) => return Err(DaemonError::AlreadyStarting(path)),
            Err(TryLockError::Error(e)) => return Err(failed(e.to_string())),
        }
    }
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

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn a_second_daemon_cant_start_while_the_first_holds_the_lock() {
        let dir = tempfile::tempdir().unwrap();
        let first = lock(dir.path()).await.unwrap();
        assert!(matches!(
            lock(dir.path()).await,
            Err(DaemonError::AlreadyStarting(_))
        ));
        drop(first);
        lock(dir.path())
            .await
            .expect("free once the first one is gone");
    }

    #[tokio::test]
    async fn a_lock_released_meanwhile_is_taken() {
        let dir = tempfile::tempdir().unwrap();
        let first = lock(dir.path()).await.unwrap();
        let second = tokio::spawn({
            let dir = dir.path().to_path_buf();
            async move { lock(&dir).await.map(drop) }
        });
        tokio::time::sleep(LOCK_RETRY * 3).await;
        drop(first);
        second.await.unwrap().expect("taken within the patience");
    }
}
