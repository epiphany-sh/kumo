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
        // Right after fork it may not have exec'd yet: its arguments come then.
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(5);
        let details = loop {
            let details = OsProcesses.inspect(child.id()).unwrap();
            if details.args.iter().any(|a| a == "-c") || std::time::Instant::now() > deadline {
                break details;
            }
            std::thread::sleep(std::time::Duration::from_millis(20));
        };
        let _ = child.kill();
        let _ = child.wait();
        // By name: on Ubuntu sh is dash, and Path::ends_with compares whole
        // components.
        let exe = details.exe.file_name().unwrap().to_string_lossy();
        assert!(exe.ends_with("sh"), "{details:?}");
        assert!(
            details.args.iter().any(|a| a == "read" || a == "-c"),
            "{details:?}"
        );
        let expected = std::fs::canonicalize(std::env::temp_dir()).unwrap();
        assert_eq!(std::fs::canonicalize(&details.cwd).unwrap(), expected);
    }
}
