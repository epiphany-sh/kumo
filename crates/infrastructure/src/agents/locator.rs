use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::OnceLock;
use std::time::{Duration, Instant};

use kumo_domain::agents::{AgentError, ProgramLocator};

const MARK: &str = "__KUMO_PATH__";
const SHELL_TIMEOUT: Duration = Duration::from_secs(5);
const VERSION_TIMEOUT: Duration = Duration::from_secs(15);

/// [`ProgramLocator`] that searches the PATH of the user's login shell.
///
/// Apps opened from the Finder get a minimal PATH, so `claude` or `codex`
/// installed with npm, Homebrew or a curl script would not be found. The
/// shell's PATH is read once, on first use, and merged with the usual
/// install folders.
#[derive(Debug)]
pub struct ShellPathLocator {
    home: PathBuf,
    path: OnceLock<String>,
}

impl ShellPathLocator {
    pub fn new(home: impl Into<PathBuf>) -> Self {
        Self {
            home: home.into(),
            path: OnceLock::new(),
        }
    }

    /// A locator with a fixed PATH (tests).
    pub fn with_path(home: impl Into<PathBuf>, path: impl Into<String>) -> Self {
        let locator = Self::new(home);
        let _ = locator.path.set(path.into());
        locator
    }

    fn path(&self) -> &str {
        self.path.get_or_init(|| {
            let started = Instant::now();
            let path = merged_path(&self.home);
            tracing::debug!(
                elapsed_ms = started.elapsed().as_millis() as u64,
                "resolved the login shell PATH"
            );
            path
        })
    }
}

impl ProgramLocator for ShellPathLocator {
    fn locate(&self, program: &str) -> Option<PathBuf> {
        let program = program.trim();
        if program.is_empty() {
            return None;
        }
        if program.contains('/') || program.contains(std::path::MAIN_SEPARATOR) {
            let path = expand_home(program, &self.home);
            return is_executable(&path).then_some(path);
        }
        std::env::split_paths(self.path()).find_map(|dir| {
            executable_names(program)
                .into_iter()
                .map(|name| dir.join(name))
                .find(|p| is_executable(p))
        })
    }

    fn search_path(&self) -> String {
        self.path().to_owned()
    }

    fn version(&self, program: &Path) -> Result<String, AgentError> {
        let mut command = Command::new(program);
        command.arg("--version").env("PATH", self.path());
        let output = run_with_timeout(command, VERSION_TIMEOUT).map_err(AgentError::Test)?;
        let text = if output.0.trim().is_empty() {
            output.1
        } else {
            output.0
        };
        text.lines()
            .map(str::trim)
            .find(|l| !l.is_empty())
            .map(str::to_owned)
            .ok_or_else(|| {
                AgentError::Test(format!("{} --version printed nothing", program.display()))
            })
    }

    fn home(&self) -> PathBuf {
        self.home.clone()
    }
}

/// The login shell's PATH, then the current one, then usual install dirs.
fn merged_path(home: &Path) -> String {
    let mut dirs: Vec<PathBuf> = Vec::new();
    let mut add = |dir: PathBuf| {
        if !dir.as_os_str().is_empty() && !dirs.contains(&dir) {
            dirs.push(dir);
        }
    };
    if let Some(shell_path) = login_shell_path() {
        std::env::split_paths(&shell_path).for_each(&mut add);
    }
    if let Some(current) = std::env::var_os("PATH") {
        std::env::split_paths(&current).for_each(&mut add);
    }
    for dir in [
        ".local/bin",
        ".npm-global/bin",
        ".bun/bin",
        ".cargo/bin",
        ".claude/local",
        ".opencode/bin",
    ] {
        add(home.join(dir));
    }
    for dir in ["/opt/homebrew/bin", "/usr/local/bin"] {
        add(PathBuf::from(dir));
    }
    std::env::join_paths(dirs)
        .map(|p| p.to_string_lossy().into_owned())
        .unwrap_or_default()
}

#[cfg(unix)]
fn login_shell_path() -> Option<String> {
    let shell = std::env::var("SHELL").unwrap_or_else(|_| "/bin/zsh".into());
    let mut command = Command::new(shell);
    // Interactive too: many people set PATH in .zshrc / .bashrc.
    command.args(["-ilc", &format!("printf '{MARK}%s{MARK}' \"$PATH\"")]);
    let (stdout, _) = run_with_timeout(command, SHELL_TIMEOUT).ok()?;
    let start = stdout.find(MARK)? + MARK.len();
    let end = stdout[start..].find(MARK)? + start;
    Some(stdout[start..end].to_owned())
}

#[cfg(not(unix))]
fn login_shell_path() -> Option<String> {
    None
}

fn executable_names(program: &str) -> Vec<String> {
    if cfg!(windows) {
        ["", ".exe", ".cmd", ".bat"]
            .iter()
            .map(|ext| format!("{program}{ext}"))
            .collect()
    } else {
        vec![program.to_owned()]
    }
}

fn expand_home(raw: &str, home: &Path) -> PathBuf {
    match raw.strip_prefix("~/") {
        Some(rest) => home.join(rest),
        None => PathBuf::from(raw),
    }
}

fn is_executable(path: &Path) -> bool {
    let Ok(meta) = std::fs::metadata(path) else {
        return false;
    };
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        meta.is_file() && meta.permissions().mode() & 0o111 != 0
    }
    #[cfg(not(unix))]
    {
        meta.is_file()
    }
}

/// Runs `command` with no stdin, killing it after `timeout`.
/// Returns (stdout, stderr).
fn run_with_timeout(mut command: Command, timeout: Duration) -> Result<(String, String), String> {
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

#[cfg(all(test, unix))]
mod tests {
    use std::os::unix::fs::PermissionsExt;

    use super::*;

    fn fake_cli(dir: &Path, name: &str, script: &str) -> PathBuf {
        let path = dir.join(name);
        std::fs::write(&path, format!("#!/bin/sh\n{script}\n")).unwrap();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
        path
    }

    #[test]
    fn finds_programs_on_the_given_path_and_reads_versions() {
        let bin = tempfile::tempdir().unwrap();
        fake_cli(bin.path(), "fake-agent", "echo 'fake-agent 1.2.3'");
        std::fs::write(bin.path().join("not-executable"), "x").unwrap();
        let locator = ShellPathLocator::with_path("/home/me", bin.path().display().to_string());

        let found = locator.locate("fake-agent").unwrap();
        assert_eq!(locator.version(&found).unwrap(), "fake-agent 1.2.3");
        assert_eq!(locator.locate("not-executable"), None);
        assert_eq!(locator.locate("missing-agent"), None);
        assert_eq!(locator.locate(&found.display().to_string()), Some(found));
    }

    #[test]
    fn a_failing_version_reports_its_error() {
        let bin = tempfile::tempdir().unwrap();
        let broken = fake_cli(bin.path(), "broken", "echo 'not logged in' >&2; exit 3");
        let locator = ShellPathLocator::with_path("/home/me", "");
        assert_eq!(
            locator.version(&broken),
            Err(AgentError::Test("not logged in".into()))
        );
    }
}
