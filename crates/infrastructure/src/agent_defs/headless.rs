//! Programs run with no terminal (`claude -p`), read line by line.

use std::io::{BufRead, BufReader, Read};
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::Duration;

use kumo_domain::agent_defs::{HeadlessKiller, HeadlessProcess, HeadlessRunner, HeadlessSpec};
use kumo_domain::agents::AgentError;

use crate::process::run_with_timeout;

/// The end of stderr kept for the error message.
const STDERR_TAIL: usize = 2_000;

/// [`HeadlessRunner`] with the OS's processes.
#[derive(Debug, Clone, Copy, Default)]
pub struct ProcessHeadlessRunner;

struct Killer(Arc<Mutex<Child>>);

impl HeadlessKiller for Killer {
    fn kill(&self) {
        let _ = self.0.lock().unwrap_or_else(PoisonError::into_inner).kill();
    }
}

impl HeadlessRunner for ProcessHeadlessRunner {
    fn start(&self, spec: &HeadlessSpec) -> Result<HeadlessProcess, AgentError> {
        let mut command = Command::new(&spec.program);
        command
            .args(&spec.args)
            .current_dir(&spec.cwd)
            .envs(spec.env.iter().map(|(k, v)| (k, v)))
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        let mut child = command.spawn().map_err(|e| {
            AgentError::Launch(format!("can't run {}: {e}", spec.program.display()))
        })?;
        let stdout = child.stdout.take().expect("piped stdout");
        let mut stderr = child.stderr.take().expect("piped stderr");
        let err_tail = std::thread::spawn(move || {
            let mut all = Vec::new();
            let _ = stderr.read_to_end(&mut all);
            let text = String::from_utf8_lossy(&all).into_owned();
            let start = text.len().saturating_sub(STDERR_TAIL);
            let start = (start..text.len())
                .find(|i| text.is_char_boundary(*i))
                .unwrap_or(0);
            text[start..].trim().to_owned()
        });
        let child = Arc::new(Mutex::new(child));
        let waited = Arc::clone(&child);
        let lines = BufReader::new(stdout)
            .split(b'\n')
            .map_while(Result::ok)
            .map(|bytes| {
                String::from_utf8_lossy(&bytes)
                    .trim_end_matches('\r')
                    .to_owned()
            });
        Ok(HeadlessProcess {
            lines: Box::new(lines),
            killer: Box::new(Killer(child)),
            wait: Box::new(move || {
                let code = loop {
                    let status = waited
                        .lock()
                        .unwrap_or_else(PoisonError::into_inner)
                        .try_wait();
                    match status {
                        Ok(Some(status)) => break status.code().unwrap_or(-1),
                        Ok(None) => std::thread::sleep(Duration::from_millis(20)),
                        Err(_) => break -1,
                    }
                };
                (code, err_tail.join().unwrap_or_default())
            }),
        })
    }

    fn has_flag(&self, program: &Path, flag: &str) -> bool {
        let mut command = Command::new(program);
        command.arg("--help");
        run_with_timeout(command, Duration::from_secs(10))
            .is_ok_and(|(out, err)| out.contains(flag) || err.contains(flag))
    }
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;

    fn sh(script: &str) -> HeadlessSpec {
        HeadlessSpec {
            program: "/bin/sh".into(),
            args: vec!["-c".into(), script.into()],
            cwd: std::env::temp_dir(),
            env: vec![("KUMO_X".into(), "v".into())],
        }
    }

    #[test]
    fn lines_then_the_exit_code_and_stderr() {
        let process = ProcessHeadlessRunner
            .start(&sh("echo one; echo \"$KUMO_X\"; echo oops >&2; exit 3"))
            .unwrap();
        let lines: Vec<String> = process.lines.collect();
        assert_eq!(lines, ["one", "v"]);
        assert_eq!((process.wait)(), (3, "oops".to_owned()));
    }

    #[test]
    fn killing_ends_it() {
        let process = ProcessHeadlessRunner
            .start(&sh("echo go; sleep 30"))
            .unwrap();
        let mut lines = process.lines;
        assert_eq!(lines.next().unwrap(), "go");
        process.killer.kill();
        assert!(lines.next().is_none());
        assert_ne!((process.wait)().0, 0);
    }

    #[test]
    fn flags_come_from_help() {
        let dir = tempfile::tempdir().unwrap();
        let program = dir.path().join("fake");
        std::fs::write(&program, "#!/bin/sh\necho '  --max-budget-usd <amount>'\n").unwrap();
        let mut perms = std::fs::metadata(&program).unwrap().permissions();
        std::os::unix::fs::PermissionsExt::set_mode(&mut perms, 0o755);
        std::fs::set_permissions(&program, perms).unwrap();
        assert!(ProcessHeadlessRunner.has_flag(&program, "--max-budget-usd"));
        assert!(!ProcessHeadlessRunner.has_flag(&program, "--nope"));
    }
}
