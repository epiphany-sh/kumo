use portable_pty::{ChildKiller, CommandBuilder, MasterPty, PtySize, native_pty_system};

use kumo_domain::terminal::{
    ExitStatus, LaunchSpec, PtyChild, PtyKiller, PtyMaster, PtyProcess, PtySystem, TerminalError,
    TerminalSize,
};

/// [`PtySystem`] backed by the platform's native PTY (`openpty` on Unix,
/// ConPTY on Windows).
#[derive(Debug, Default, Clone, Copy)]
pub struct PortablePtySystem;

impl PtySystem for PortablePtySystem {
    fn spawn(&self, spec: &LaunchSpec) -> Result<PtyProcess, TerminalError> {
        let pair = native_pty_system()
            .openpty(pty_size(spec.size()))
            .map_err(spawn_error)?;
        let child = pair
            .slave
            .spawn_command(command(spec)?)
            .map_err(spawn_error)?;
        // Release the slave now: otherwise the reader never sees EOF.
        drop(pair.slave);

        let reader = pair.master.try_clone_reader().map_err(spawn_error)?;
        let writer = pair.master.take_writer().map_err(spawn_error)?;
        let killer = child.clone_killer();
        Ok(PtyProcess {
            reader,
            writer,
            master: Box::new(PortableMaster(pair.master)),
            child: Box::new(PortableChild(child)),
            killer: Box::new(PortableKiller(killer)),
        })
    }
}

fn command(spec: &LaunchSpec) -> Result<CommandBuilder, TerminalError> {
    let mut cmd = CommandBuilder::new(spec.program());
    cmd.args(spec.args());
    let cwd = match spec.cwd() {
        Some(cwd) => cwd.to_path_buf(),
        None => std::env::current_dir().map_err(|e| TerminalError::Spawn(e.to_string()))?,
    };
    cmd.cwd(cwd);
    for (key, value) in spec.effective_env() {
        cmd.env(key, value);
    }
    Ok(cmd)
}

fn pty_size(size: TerminalSize) -> PtySize {
    PtySize {
        rows: size.rows(),
        cols: size.cols(),
        pixel_width: 0,
        pixel_height: 0,
    }
}

fn spawn_error(error: impl std::fmt::Display) -> TerminalError {
    TerminalError::Spawn(error.to_string())
}

struct PortableMaster(Box<dyn MasterPty + Send>);

impl PtyMaster for PortableMaster {
    fn resize(&self, size: TerminalSize) -> Result<(), TerminalError> {
        self.0
            .resize(pty_size(size))
            .map_err(|e| TerminalError::Io(e.to_string()))
    }
}

struct PortableChild(Box<dyn portable_pty::Child + Send + Sync>);

impl PtyChild for PortableChild {
    fn wait(&mut self) -> Result<ExitStatus, TerminalError> {
        let status = self
            .0
            .wait()
            .map_err(|e| TerminalError::Io(e.to_string()))?;
        Ok(ExitStatus::new(
            i32::try_from(status.exit_code()).unwrap_or(i32::MAX),
        ))
    }
}

struct PortableKiller(Box<dyn ChildKiller + Send + Sync>);

impl PtyKiller for PortableKiller {
    fn kill(&mut self) -> Result<(), TerminalError> {
        self.0.kill().map_err(|e| TerminalError::Io(e.to_string()))
    }
}
