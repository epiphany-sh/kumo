use std::sync::Arc;

use tokio::sync::watch;

use crate::terminal::TerminalService;

/// Why the daemon didn't stop.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ShutdownRefused {
    #[error("{0} terminal(s) still running")]
    Busy(usize),
}

/// Stopping the daemon from a client (after an update, to run the new
/// program). Its terminals end with it.
#[derive(Debug, Clone)]
pub struct DaemonControl {
    terminals: Arc<TerminalService>,
    stop: watch::Sender<bool>,
}

impl DaemonControl {
    pub fn new(terminals: Arc<TerminalService>) -> Self {
        Self {
            terminals,
            stop: watch::channel(false).0,
        }
    }

    /// Asks the daemon to stop. With `if_idle`, only when no terminal is
    /// running: a terminal opened since the client looked is never killed.
    pub fn shutdown(&self, if_idle: bool) -> Result<(), ShutdownRefused> {
        let running = self.terminals.running();
        if if_idle && running > 0 {
            return Err(ShutdownRefused::Busy(running));
        }
        tracing::info!(running, "shutdown requested by a client");
        self.stop.send_replace(true);
        Ok(())
    }

    /// Resolves once [`shutdown`](Self::shutdown) was accepted.
    pub async fn stopped(&self) {
        let mut stop = self.stop.subscribe();
        let _ = stop.wait_for(|stop| *stop).await;
    }
}
