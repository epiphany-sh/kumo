//! Other processes, read the way this OS allows.

use kumo_domain::agents::{ProcessDetails, ProcessInspector};

use crate::platform;

/// [`ProcessInspector`] over the OS (see [`platform::process`]).
#[derive(Debug, Clone, Copy, Default)]
pub struct OsProcesses;

impl ProcessInspector for OsProcesses {
    fn inspect(&self, pid: u32) -> Option<ProcessDetails> {
        platform::process(pid).map(|p| ProcessDetails {
            exe: p.exe,
            args: p.args,
            cwd: p.cwd,
        })
    }
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;

    #[test]
    fn reads_a_running_process() {
        let mut child = std::process::Command::new("/bin/sh")
            .args(["-c", "read x"])
            .current_dir(std::env::temp_dir())
            .stdin(std::process::Stdio::piped())
            .spawn()
            .unwrap();
        let details = OsProcesses.inspect(child.id()).unwrap();
        let _ = child.kill();
        let _ = child.wait();
        assert!(details.exe.ends_with("sh"), "{details:?}");
        assert!(
            details.args.iter().any(|a| a == "read" || a == "-c"),
            "{details:?}"
        );
        let expected = std::fs::canonicalize(std::env::temp_dir()).unwrap();
        assert_eq!(std::fs::canonicalize(&details.cwd).unwrap(), expected);
    }
}
