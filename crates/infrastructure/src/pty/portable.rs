use portable_pty::{ChildKiller, CommandBuilder, MasterPty, PtySize, native_pty_system};

use kumo_domain::terminal::{
    ExitStatus, ForegroundProbe, LaunchSpec, PtyChild, PtyKiller, PtyMaster, PtyProcess, PtySystem,
    TerminalError, TerminalSize,
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
        let pid = child.process_id();
        Ok(PtyProcess {
            reader,
            writer,
            master: Box::new(PortableMaster {
                master: pair.master,
                pid,
            }),
            child: Box::new(PortableChild(child)),
            killer: Box::new(PortableKiller { killer, pid }),
            // portable-pty starts ConPTY inheriting the cursor, so it asks
            // where the cursor is first and holds the program until told.
            holds_for_cursor: cfg!(windows),
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
    // `cmd.exe` takes `\\?\C:\x` for a network folder it can't start in.
    cmd.cwd(crate::platform::plain_path(cwd));
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

struct PortableMaster {
    master: Box<dyn MasterPty + Send>,
    /// The program the PTY started, for [`PtyMaster::foreground`] where
    /// the PTY has no process groups.
    #[cfg_attr(unix, allow(dead_code))]
    pid: Option<u32>,
}

impl PtyMaster for PortableMaster {
    fn resize(&self, size: TerminalSize) -> Result<(), TerminalError> {
        self.master
            .resize(pty_size(size))
            .map_err(|e| TerminalError::Io(e.to_string()))
    }

    /// The foreground process group's leader, read right away (cheap).
    #[cfg(unix)]
    fn foreground(&self) -> ForegroundProbe {
        let pid = self
            .master
            .process_group_leader()
            .and_then(|pid| u32::try_from(pid).ok());
        Box::new(move || pid)
    }

    /// ConPTY has no process groups: worked out from the processes, by
    /// the probe.
    #[cfg(not(unix))]
    fn foreground(&self) -> ForegroundProbe {
        let root = self.pid;
        Box::new(move || crate::platform::terminal_foreground(root?))
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

struct PortableKiller {
    killer: Box<dyn ChildKiller + Send + Sync>,
    pid: Option<u32>,
}

impl PtyKiller for PortableKiller {
    #[cfg(unix)]
    fn kill(&mut self) -> Result<(), TerminalError> {
        self.killer
            .kill()
            .map_err(|e| TerminalError::Io(e.to_string()))
    }

    /// portable-pty 0.9 turns `TerminateProcess`'s answer around on
    /// Windows: its error (a stale last error) is the kill having worked,
    /// and its Ok a kill that failed, mostly as the program had exited.
    /// Neither is worth failing the close over.
    #[cfg(not(unix))]
    fn kill(&mut self) -> Result<(), TerminalError> {
        let _ = self.killer.kill();
        Ok(())
    }

    fn kill_tree(&mut self) -> Result<(), TerminalError> {
        let Some(pid) = self.pid else {
            return self.kill();
        };
        crate::platform::kill_process_tree(pid);
        // Already dead, most likely, and that's no failure: it can be gone
        // by now ("no such process").
        let _ = self.kill();
        Ok(())
    }
}

#[cfg(all(test, windows))]
mod tests {
    use std::io::{Read, Write};
    use std::sync::mpsc;
    use std::time::Duration;

    use super::*;

    /// Why an agent's prompt never reaches a batch file as an argument:
    /// quoting it for the program doesn't quote it for `cmd.exe`.
    #[test]
    fn a_batch_file_s_arguments_are_read_by_cmd() {
        let dir = tempfile::tempdir().unwrap();
        let program = dir.path().join("agent.cmd");
        std::fs::write(&program, "@echo off\r\nexit /b 0\r\n").unwrap();
        let spec = LaunchSpec::new(program.display().to_string())
            .unwrap()
            .with_args([r#"x"&echo y>marker&"#])
            .with_cwd(Some(dir.path().to_path_buf()));
        let PtyProcess {
            mut reader,
            mut writer,
            master,
            mut child,
            mut killer,
            ..
        } = PortablePtySystem.spawn(&spec).unwrap();
        // ConPTY asks where the cursor is, and holds the program until the
        // terminal answers.
        std::thread::spawn(move || {
            let (mut seen, mut buffer, mut answered) = (Vec::new(), [0; 1024], false);
            while let Ok(read @ 1..) = reader.read(&mut buffer) {
                seen.extend_from_slice(&buffer[..read]);
                if !answered && seen.windows(4).any(|w| w == b"\x1b[6n") {
                    answered = true;
                    let _ = writer.write_all(b"\x1b[1;1R");
                    let _ = writer.flush();
                }
            }
        });
        let (done, finished) = mpsc::channel();
        std::thread::spawn(move || {
            let _ = child.wait();
            let _ = done.send(());
        });
        if finished.recv_timeout(Duration::from_secs(30)).is_err() {
            let _ = killer.kill_tree();
            panic!("the batch file never finished");
        }
        drop(master);
        assert!(dir.path().join("marker").exists());
    }

    /// Closing a terminal kills its program and says it went fine.
    #[test]
    fn killing_a_running_program_succeeds() {
        let spec = LaunchSpec::new("ping")
            .unwrap()
            .with_args(["-n", "30", "127.0.0.1"]);
        let PtyProcess {
            mut reader,
            writer: _writer,
            master: _master,
            mut child,
            mut killer,
            ..
        } = PortablePtySystem.spawn(&spec).unwrap();
        std::thread::spawn(move || {
            let mut buffer = [0; 1024];
            while let Ok(1..) = reader.read(&mut buffer) {}
        });
        assert_eq!(killer.kill(), Ok(()));
        let (done, finished) = mpsc::channel();
        std::thread::spawn(move || {
            let _ = done.send(child.wait());
        });
        let status = finished.recv_timeout(Duration::from_secs(10)).unwrap();
        assert!(status.is_ok());
    }

    /// What a shell in the terminal runs is its foreground, as a process
    /// group would tell on Unix; the shell itself while it waits.
    #[test]
    fn the_foreground_is_what_the_shell_runs() {
        let dir = tempfile::tempdir().unwrap();
        let spec = LaunchSpec::new("cmd.exe")
            .unwrap()
            .with_args(["/d", "/q"])
            .with_cwd(Some(dir.path().to_path_buf()));
        let PtyProcess {
            mut reader,
            mut writer,
            master,
            child: _child,
            mut killer,
            ..
        } = PortablePtySystem.spawn(&spec).unwrap();
        let (typed, type_it) = mpsc::channel::<Vec<u8>>();
        std::thread::spawn(move || {
            let mut buffer = [0; 1024];
            let mut seen = Vec::new();
            while let Ok(read @ 1..) = reader.read(&mut buffer) {
                seen.extend_from_slice(&buffer[..read]);
                if seen.windows(4).any(|w| w == b"\x1b[6n") {
                    seen.clear();
                    let _ = writer.write_all(b"\x1b[1;1R");
                }
                while let Ok(text) = type_it.try_recv() {
                    let _ = writer.write_all(&text);
                }
                let _ = writer.flush();
            }
        });
        let wait_for = |what: &dyn Fn(Option<u32>) -> bool| {
            let deadline = std::time::Instant::now() + Duration::from_secs(20);
            loop {
                let foreground = master.foreground()();
                if what(foreground) || std::time::Instant::now() > deadline {
                    return foreground;
                }
                // Typed text goes in when the reader wakes up: prod it.
                let _ = typed.send(Vec::new());
                std::thread::sleep(Duration::from_millis(100));
            }
        };
        let name = |pid: Option<u32>| {
            pid.and_then(crate::platform::process).and_then(|p| {
                p.exe
                    .file_name()
                    .map(|n| n.to_string_lossy().to_lowercase())
            })
        };

        let shell = wait_for(&|pid| name(pid).as_deref() == Some("cmd.exe"));
        assert_eq!(name(shell).as_deref(), Some("cmd.exe"));
        typed.send(b"ping -n 60 127.0.0.1 >nul\r".to_vec()).unwrap();
        let ping = wait_for(&|pid| name(pid).as_deref() == Some("ping.exe"));
        let details = crate::platform::process(ping.unwrap()).unwrap();
        assert_eq!(details.args[1..], ["-n", "60", "127.0.0.1"]);
        assert_eq!(
            crate::platform::canonical(&details.cwd),
            crate::platform::canonical(dir.path())
        );
        let _ = killer.kill_tree();
    }
}
