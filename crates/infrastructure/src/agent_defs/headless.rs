//! Programs run with no terminal (`claude -p`), read line by line.

use std::io::{BufRead, BufReader, Read};
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::Duration;

use kumo_domain::agent_defs::{HeadlessKiller, HeadlessProcess, HeadlessRunner, HeadlessSpec};
use kumo_domain::agents::AgentError;

use crate::platform;
use crate::process::run_with_timeout;

/// The end of stderr kept for the error message.
const STDERR_TAIL: usize = 2_000;

/// [`HeadlessRunner`] with the OS's processes.
#[derive(Debug, Clone, Copy, Default)]
pub struct ProcessHeadlessRunner;

struct Killer {
    child: Arc<Mutex<Child>>,
    pid: u32,
}

impl HeadlessKiller for Killer {
    /// Its tools go with it: one left running would hold the output open and
    /// keep working in a folder that's about to go.
    fn kill(&self) {
        let mut child = self.child.lock().unwrap_or_else(PoisonError::into_inner);
        // Gone already: its pid may be someone else's by now.
        if matches!(child.try_wait(), Ok(None)) {
            platform::kill_process_tree(self.pid);
            let _ = child.kill();
        }
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
        platform::own_process_group(&mut command);
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
        let pid = child.id();
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
            killer: Box::new(Killer { child, pid }),
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

    fn has_flag(&self, program: &Path, flag: &str, env: &[(String, String)]) -> Option<bool> {
        let mut command = Command::new(program);
        command.arg("--help");
        command.envs(env.iter().map(|(k, v)| (k, v)));
        let (out, err) = run_with_timeout(command, Duration::from_secs(10)).ok()?;
        if out.contains(flag) || err.contains(flag) {
            return Some(true);
        }
        // A help that lists options, without this one; else it didn't run.
        out.contains("--").then_some(false)
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
    fn stopping_takes_what_it_started_along() {
        let dir = tempfile::tempdir().unwrap();
        let pid_file = dir.path().join("pid");
        let script = format!(
            // `set -m`: in a group of its own, as Claude Code starts its tools.
            "set -m; /bin/sleep 60 & echo $! > '{}'; echo up; wait",
            pid_file.display()
        );
        let spec = HeadlessSpec {
            program: "/bin/sh".into(),
            args: vec!["-c".into(), script],
            cwd: dir.path().to_owned(),
            env: Vec::new(),
        };
        let HeadlessProcess {
            mut lines,
            killer,
            wait,
        } = ProcessHeadlessRunner.start(&spec).unwrap();
        assert_eq!(lines.next().as_deref(), Some("up"));
        let tool = std::fs::read_to_string(&pid_file)
            .unwrap()
            .trim()
            .to_owned();
        killer.kill();
        // Reads end, though the tool had the output open too.
        assert_eq!(lines.next(), None);
        wait();
        let alive = std::process::Command::new("/bin/kill")
            .args(["-0", &tool])
            .output()
            .unwrap()
            .status
            .success();
        assert!(!alive, "the tool it started is still running");
    }

    #[test]
    fn flags_come_from_help() {
        let dir = tempfile::tempdir().unwrap();
        let program = dir.path().join("fake");
        std::fs::write(&program, "#!/bin/sh\necho '  --max-budget-usd <amount>'\n").unwrap();
        let mut perms = std::fs::metadata(&program).unwrap().permissions();
        std::os::unix::fs::PermissionsExt::set_mode(&mut perms, 0o755);
        std::fs::set_permissions(&program, perms).unwrap();
        assert_eq!(
            ProcessHeadlessRunner.has_flag(&program, "--max-budget-usd", &[]),
            Some(true)
        );
        // It ran and listed options, or didn't list a thing: not the same.
        assert_eq!(
            ProcessHeadlessRunner.has_flag(&program, "--nope", &[]),
            Some(false)
        );
        std::fs::write(&program, "#!/bin/sh\necho $KUMO_MARK\n").unwrap();
        assert_eq!(
            ProcessHeadlessRunner.has_flag(&program, "--nope", &[]),
            None,
            "a hiccup isn't an answer"
        );
        let env = [("KUMO_MARK".to_owned(), "--from-its-env".to_owned())];
        assert_eq!(
            ProcessHeadlessRunner.has_flag(&program, "--from-its-env", &env),
            Some(true)
        );
    }
}
