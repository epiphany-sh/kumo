//! Ports implemented by the infrastructure layer.

use std::fmt;
use std::io::{Read, Write};

use super::{ExitStatus, LaunchSpec, TerminalError, TerminalSize};

/// Spawns processes attached to a new pseudo-terminal.
pub trait PtySystem: Send + Sync + 'static {
    fn spawn(&self, spec: &LaunchSpec) -> Result<PtyProcess, TerminalError>;
}

/// A running process on a PTY, split into independently owned handles so
/// each one can live on its own thread.
///
/// The slave side must already be released by the implementation, otherwise
/// the reader never sees end-of-file.
pub struct PtyProcess {
    /// Blocking reader of the PTY output.
    pub reader: Box<dyn Read + Send>,
    /// Blocking writer to the PTY input.
    pub writer: Box<dyn Write + Send>,
    pub master: Box<dyn PtyMaster>,
    pub child: Box<dyn PtyChild>,
    pub killer: Box<dyn PtyKiller>,
}

impl fmt::Debug for PtyProcess {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PtyProcess").finish_non_exhaustive()
    }
}

/// Master side of the PTY. Dropping it releases the pseudo-terminal.
pub trait PtyMaster: Send {
    fn resize(&self, size: TerminalSize) -> Result<(), TerminalError>;
}

/// The spawned process, for waiting on its exit.
pub trait PtyChild: Send {
    /// Blocks until the process exits.
    fn wait(&mut self) -> Result<ExitStatus, TerminalError>;
}

/// Kills the spawned process from any thread.
pub trait PtyKiller: Send + Sync {
    fn kill(&mut self) -> Result<(), TerminalError>;
}
