//! Benchmark scenarios (kumo.md §10, M0).

pub mod echo;
pub mod hello;
pub mod throughput;

use crate::daemon_process::sibling_binary;

/// Program that echoes raw keystrokes after printing `READY`.
/// Unix uses the shell (as specified in kumo.md); Windows uses `kumo-echo`.
pub(crate) fn echo_program() -> anyhow::Result<(String, Vec<String>)> {
    if cfg!(unix) {
        let script = "stty raw -echo; printf READY; exec cat";
        Ok(("sh".into(), vec!["-c".into(), script.into()]))
    } else {
        Ok((
            sibling_binary("kumo-echo")?.display().to_string(),
            Vec::new(),
        ))
    }
}
