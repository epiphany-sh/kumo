//! Running a background program to its end, for its output.

use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

/// Runs `command` with no stdin, killing it after `timeout`.
/// Returns (stdout, stderr).
pub(crate) fn run_with_timeout(
    mut command: Command,
    timeout: Duration,
) -> Result<(String, String), String> {
    let mut child = command
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("can't run {:?}: {e}", command.get_program()))?;
    let deadline = Instant::now() + timeout;
    loop {
        match child.try_wait() {
            Ok(Some(_)) => break,
            Ok(None) if Instant::now() < deadline => std::thread::sleep(Duration::from_millis(20)),
            Ok(None) => {
                let _ = child.kill();
                let _ = child.wait();
                return Err(format!(
                    "{:?} did not answer within {} s",
                    command.get_program(),
                    timeout.as_secs()
                ));
            }
            Err(e) => return Err(e.to_string()),
        }
    }
    let output = child.wait_with_output().map_err(|e| e.to_string())?;
    let stdout = String::from_utf8_lossy(&output.stdout).into_owned();
    let stderr = String::from_utf8_lossy(&output.stderr).into_owned();
    if !output.status.success() {
        let message = if stderr.trim().is_empty() {
            &stdout
        } else {
            &stderr
        };
        return Err(message.trim().lines().next().unwrap_or("failed").to_owned());
    }
    Ok((stdout, stderr))
}
