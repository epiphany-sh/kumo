//! Kumo's shell integration: zsh, bash, fish and PowerShell report their
//! prompts and the commands run at them (OSC 133, and 633 for the line run
//! and its folder), through scripts loaded on top of the user's own startup
//! files, which load as they always do.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use kumo_domain::terminal::{LaunchSpec, NoShellIntegration, ShellIntegration};

use crate::platform::TerminalShell as Shell;

const ZSHENV: &str = include_str!("shell_integration/zshenv.zsh");
const ZSH: &str = include_str!("shell_integration/kumo.zsh");
const BASH: &str = include_str!("shell_integration/kumo.bash");
const FISH: &str = include_str!("shell_integration/kumo.fish");
const POWERSHELL: &str = include_str!("shell_integration/kumo.ps1");

/// The integration for this OS's shells, its scripts written under `dir`.
/// None where the OS has no shell it covers, or when they can't be written
/// (shells then start as they are).
pub fn shell_integration(dir: &Path) -> Arc<dyn ShellIntegration> {
    if crate::platform::integrated_shells().is_empty() {
        return Arc::new(NoShellIntegration);
    }
    match ShellScripts::install(dir) {
        Ok(scripts) => Arc::new(scripts),
        Err(error) => {
            tracing::warn!(
                dir = %dir.display(),
                %error,
                "shell integration not written: terminals won't mark commands"
            );
            Arc::new(NoShellIntegration)
        }
    }
}

/// [`ShellIntegration`] through Kumo's scripts in a folder of its own.
#[derive(Debug, Clone)]
pub struct ShellScripts {
    dir: PathBuf,
    /// The shells it applies to; any other starts as it is.
    shells: &'static [Shell],
}

impl ShellScripts {
    /// Writes the scripts under `dir`, over the ones an older Kumo left.
    /// It covers this OS's shells (see [`crate::platform::integrated_shells`]).
    pub fn install(dir: &Path) -> std::io::Result<Self> {
        let zsh = dir.join("zsh");
        std::fs::create_dir_all(&zsh)?;
        std::fs::write(zsh.join(".zshenv"), ZSHENV)?;
        std::fs::write(zsh.join("kumo.zsh"), ZSH)?;
        std::fs::write(dir.join("kumo.bash"), BASH)?;
        std::fs::write(dir.join("kumo.fish"), FISH)?;
        Ok(Self {
            dir: dir.to_path_buf(),
            shells: crate::platform::integrated_shells(),
        })
    }

    /// The same scripts, applied to `shells` only.
    #[cfg(test)]
    fn covering(self, shells: &'static [Shell]) -> Self {
        Self { shells, ..self }
    }

    fn file(&self, name: &str) -> String {
        self.dir.join(name).display().to_string()
    }
}

impl ShellIntegration for ShellScripts {
    fn apply(&self, spec: LaunchSpec, nonce: &str) -> LaunchSpec {
        let Some(shell) = shell_of(spec.program()) else {
            return spec;
        };
        if !self.shells.contains(&shell) {
            return spec;
        }
        // A script, `-c` or `-f` runs as asked.
        if !spec.args().iter().all(|arg| interactive(shell, arg)) {
            return spec;
        }
        // The scripts keep it in a shell variable and drop it from the
        // environment, so what the shell runs doesn't get it.
        let spec = spec.with_var("KUMO_NONCE", nonce);
        match shell {
            // zsh reads `.zshenv` from ZDOTDIR first: Kumo's puts the
            // user's ZDOTDIR back and reads theirs.
            Shell::Zsh => {
                let user = spec
                    .var("ZDOTDIR")
                    .map(str::to_owned)
                    .or_else(|| std::env::var("ZDOTDIR").ok());
                let spec = spec.with_var("ZDOTDIR", self.file("zsh"));
                match user {
                    Some(dir) => spec.with_var("KUMO_USER_ZDOTDIR", dir),
                    None => spec,
                }
            }
            // A login bash skips `--init-file`: Kumo's script reads the
            // login files itself when asked to.
            Shell::Bash => {
                let login = spec.args().iter().any(|arg| login(arg));
                let spec = spec.with_args([
                    "--init-file".to_owned(),
                    self.file("kumo.bash"),
                    "-i".to_owned(),
                ]);
                if login {
                    spec.with_var("KUMO_BASH_LOGIN", "1")
                } else {
                    spec
                }
            }
            // Through a variable, so a folder with spaces or quotes in its
            // name needs no quoting.
            Shell::Fish => {
                let mut args = spec.args().to_vec();
                args.extend([
                    "--init-command".to_owned(),
                    "source $KUMO_FISH_INTEGRATION; set -e KUMO_FISH_INTEGRATION".to_owned(),
                ]);
                spec.with_args(args)
                    .with_var("KUMO_FISH_INTEGRATION", self.file("kumo.fish"))
            }
            // Inline, after the profile: the execution policy stops script
            // files (Windows PowerShell's default allows none), not a
            // command. Base64 of UTF-16, so no quoting reaches it.
            Shell::PowerShell => {
                let mut args = spec.args().to_vec();
                if !args.iter().any(|arg| arg.eq_ignore_ascii_case("-NoExit")) {
                    args.push("-NoExit".to_owned());
                }
                args.extend(["-EncodedCommand".to_owned(), encoded(POWERSHELL)]);
                spec.with_args(args)
            }
        }
    }
}

/// `script` as `-EncodedCommand` takes it: base64 of its UTF-16LE.
fn encoded(script: &str) -> String {
    use base64::Engine;
    let utf16: Vec<u8> = script.encode_utf16().flat_map(u16::to_le_bytes).collect();
    base64::engine::general_purpose::STANDARD.encode(utf16)
}

/// The shell `program` is, by its name; None for any other program.
fn shell_of(program: &str) -> Option<Shell> {
    let name = Path::new(program)
        .file_stem()?
        .to_str()?
        .to_ascii_lowercase();
    match name.as_str() {
        "zsh" => Some(Shell::Zsh),
        "bash" => Some(Shell::Bash),
        "fish" => Some(Shell::Fish),
        "pwsh" | "powershell" => Some(Shell::PowerShell),
        _ => None,
    }
}

/// An argument that only asks for an interactive or a login shell (or,
/// for PowerShell, one without a banner or a profile).
fn interactive(shell: Shell, arg: &str) -> bool {
    match shell {
        Shell::PowerShell => matches!(
            arg.to_ascii_lowercase().as_str(),
            "-nologo" | "-noprofile" | "-noexit" | "-interactive"
        ),
        _ => arg == "-i" || login(arg),
    }
}

fn login(arg: &str) -> bool {
    matches!(arg, "-l" | "--login" | "-il" | "-li")
}

#[cfg(test)]
mod tests {
    use super::*;

    const UNIX_SHELLS: &[Shell] = &[Shell::Zsh, Shell::Bash, Shell::Fish];

    fn scripts() -> ShellScripts {
        ShellScripts {
            dir: PathBuf::from("/data/kumo/shell"),
            shells: UNIX_SHELLS,
        }
    }

    fn powershell() -> ShellScripts {
        scripts().covering(&[Shell::PowerShell])
    }

    /// [name] in the scripts' folder, with the OS's separator.
    fn script(name: &str) -> String {
        scripts().dir.join(name).display().to_string()
    }

    fn spec(program: &str, args: &[&str]) -> LaunchSpec {
        LaunchSpec::new(program)
            .unwrap()
            .with_args(args.iter().copied())
    }

    /// The script an `-EncodedCommand` argument runs.
    fn decoded(encoded: &str) -> String {
        use base64::Engine;
        let bytes = base64::engine::general_purpose::STANDARD
            .decode(encoded)
            .unwrap();
        let units: Vec<u16> = bytes
            .as_chunks::<2>()
            .0
            .iter()
            .map(|pair| u16::from_le_bytes(*pair))
            .collect();
        String::from_utf16(&units).unwrap()
    }

    #[test]
    fn zsh_starts_from_kumo_s_zdotdir_and_keeps_the_user_s() {
        let applied = scripts().apply(
            spec("/bin/zsh", &["-l"]).with_var("ZDOTDIR", "/home/u/.config/zsh"),
            "n0nce",
        );
        assert_eq!(applied.args(), ["-l"]);
        assert_eq!(applied.var("ZDOTDIR"), Some(script("zsh").as_str()));
        assert_eq!(
            applied.var("KUMO_USER_ZDOTDIR"),
            Some("/home/u/.config/zsh")
        );
        assert_eq!(applied.var("KUMO_NONCE"), Some("n0nce"));
    }

    #[test]
    fn bash_reads_kumo_s_script_and_is_told_it_was_a_login_shell() {
        let applied = scripts().apply(spec("/bin/bash", &["-l"]), "n0nce");
        assert_eq!(
            applied.args(),
            ["--init-file", script("kumo.bash").as_str(), "-i"]
        );
        assert_eq!(applied.var("KUMO_BASH_LOGIN"), Some("1"));

        let applied = scripts().apply(spec("bash", &[]), "n0nce");
        assert_eq!(applied.var("KUMO_BASH_LOGIN"), None);
    }

    #[test]
    fn fish_sources_kumo_s_script_after_its_own() {
        let applied = scripts().apply(spec("/opt/homebrew/bin/fish", &["-l"]), "n0nce");
        assert_eq!(applied.args()[..2], ["-l", "--init-command"]);
        assert_eq!(
            applied.var("KUMO_FISH_INTEGRATION"),
            Some(script("kumo.fish").as_str())
        );
    }

    #[test]
    fn other_programs_and_commands_run_as_asked() {
        for (program, args) in [
            ("sh", &["-l"][..]),
            ("/bin/zsh", &["-c", "echo hi"][..]),
            ("bash", &["script.sh"][..]),
            ("zsh", &["-f"][..]),
            ("pwsh.exe", &[][..]),
        ] {
            let before = spec(program, args);
            assert_eq!(
                scripts().apply(before.clone(), "n0nce"),
                before,
                "{program} {args:?}"
            );
        }
    }

    /// Inline, not a `.ps1` file: the execution policy (Restricted by
    /// default for Windows PowerShell) only stops script files.
    #[test]
    fn powershell_runs_kumo_s_script_inline_after_its_profile() {
        let applied = powershell().apply(spec("pwsh.exe", &["-NoLogo"]), "n0nce");
        let [nologo, noexit, flag, encoded] = applied.args() else {
            panic!("{:?}", applied.args());
        };
        assert_eq!(
            [nologo, noexit, flag],
            ["-NoLogo", "-NoExit", "-EncodedCommand"]
        );
        assert_eq!(decoded(encoded), POWERSHELL);
        // Well within a Windows command line (32767 characters).
        assert!(encoded.len() < 20_000, "{}", encoded.len());
        assert_eq!(applied.var("KUMO_NONCE"), Some("n0nce"));

        let applied = powershell().apply(spec("POWERSHELL.EXE", &[]), "n0nce");
        assert_eq!(applied.args()[..2], ["-NoExit", "-EncodedCommand"]);
    }

    #[test]
    fn powershell_keeps_its_own_no_exit() {
        let applied = powershell().apply(spec("pwsh", &["-NoExit", "-NoProfile"]), "n0nce");
        assert_eq!(
            applied.args()[..3],
            ["-NoExit", "-NoProfile", "-EncodedCommand"]
        );
    }

    #[test]
    fn powershell_commands_and_scripts_run_as_asked() {
        for (program, args) in [
            ("pwsh.exe", &["-Command", "Get-Date"][..]),
            ("pwsh.exe", &["-File", "build.ps1"][..]),
            ("powershell.exe", &["build.ps1"][..]),
            ("cmd.exe", &[][..]),
            ("bash.exe", &[][..]),
        ] {
            let before = spec(program, args);
            assert_eq!(
                powershell().apply(before.clone(), "n0nce"),
                before,
                "{program} {args:?}"
            );
        }
    }

    #[test]
    fn the_powershell_script_marks_what_the_others_do() {
        for mark in ["133;A", "133;B", "133;C", "133;D;", "633;E;", "633;P;Cwd="] {
            assert!(POWERSHELL.contains(mark), "{mark}");
        }
    }

    /// A program on a real ConPTY, answered as a terminal would.
    #[cfg(windows)]
    struct Terminal {
        seen: std::sync::Arc<std::sync::Mutex<Vec<u8>>>,
        /// Everything it printed.
        log: std::sync::Arc<std::sync::Mutex<Vec<u8>>>,
        typed: std::sync::mpsc::Sender<Vec<u8>>,
        killer: Box<dyn kumo_domain::terminal::PtyKiller>,
        _rest: (
            Box<dyn kumo_domain::terminal::PtyMaster>,
            Box<dyn kumo_domain::terminal::PtyChild>,
        ),
    }

    #[cfg(windows)]
    impl Terminal {
        fn start(launch: &LaunchSpec) -> Self {
            use std::io::{Read, Write};
            use std::sync::{Arc, Mutex, mpsc};

            use kumo_domain::terminal::{CursorRequests, PtyProcess, PtySystem};

            let PtyProcess {
                mut reader,
                mut writer,
                master,
                child,
                killer,
                ..
            } = super::super::PortablePtySystem.spawn(launch).unwrap();
            let seen = Arc::new(Mutex::new(Vec::new()));
            let (typed, type_it) = mpsc::channel::<Vec<u8>>();
            std::thread::spawn(move || {
                for text in type_it {
                    let _ = writer.write_all(&text);
                    let _ = writer.flush();
                }
            });
            let log = Arc::new(Mutex::new(Vec::new()));
            let (output, all) = (Arc::clone(&seen), Arc::clone(&log));
            let answer = typed.clone();
            std::thread::spawn(move || {
                let mut buffer = [0; 4096];
                let mut requests = CursorRequests::new();
                while let Ok(read @ 1..) = reader.read(&mut buffer) {
                    let chunk = &buffer[..read];
                    // ConPTY holds the program until the terminal says where
                    // its cursor is (a request split between reads too).
                    for _ in 0..requests.strip(chunk).requests {
                        let _ = answer.send(b"\x1b[1;1R".to_vec());
                    }
                    output.lock().unwrap().extend_from_slice(chunk);
                    all.lock().unwrap().extend_from_slice(chunk);
                }
            });
            Self {
                seen,
                log,
                typed,
                killer,
                _rest: (master, child),
            }
        }

        /// Types `line` and Enter.
        fn type_line(&self, line: &str) {
            self.typed.send(format!("{line}\r").into_bytes()).unwrap();
        }

        /// Waits for `what` and drops the output up to its end.
        fn wait_for(&mut self, what: &str) {
            use std::time::{Duration, Instant};

            let deadline = Instant::now() + Duration::from_secs(30);
            loop {
                {
                    let mut output = self.seen.lock().unwrap();
                    if let Some(at) = output
                        .windows(what.len())
                        .position(|w| w == what.as_bytes())
                    {
                        output.drain(..at + what.len());
                        return;
                    }
                    if Instant::now() > deadline {
                        let _ = self.killer.kill_tree();
                        panic!(
                            "never saw {what:?} in {:?}",
                            String::from_utf8_lossy(&output)
                        );
                    }
                }
                std::thread::sleep(Duration::from_millis(50));
            }
        }

        /// Everything it printed.
        fn printed(&self) -> String {
            String::from_utf8_lossy(&self.log.lock().unwrap()).into_owned()
        }
    }

    #[cfg(windows)]
    impl Drop for Terminal {
        fn drop(&mut self) {
            let _ = self.killer.kill_tree();
        }
    }

    /// Windows PowerShell in `dir` as a terminal opens it, with no script
    /// allowed and a temporary profile folder (PSReadLine keeps its
    /// history there, so nothing lands in yours).
    #[cfg(windows)]
    fn windows_powershell(dir: &Path) -> LaunchSpec {
        spec("powershell.exe", &["-NoLogo", "-NoProfile"])
            .with_var("PSExecutionPolicyPreference", "Restricted")
            .with_var("USERPROFILE", dir.display().to_string())
            .with_cwd(Some(dir.to_path_buf()))
    }

    /// Windows PowerShell on a terminal, with no script allowed, marks
    /// what it runs and its status.
    #[cfg(windows)]
    #[test]
    fn windows_powershell_marks_its_commands() {
        let dir = tempfile::tempdir().unwrap();
        let dir_path = crate::platform::canonical(dir.path());
        let launch = powershell().apply(windows_powershell(&dir_path), "n0nce");
        let mut terminal = Terminal::start(&launch);
        let cwd = dir_path.display().to_string().replace('\\', "\\\\");

        terminal.wait_for(&format!("\x1b]633;P;Cwd={cwd}\x07"));
        terminal.wait_for("\x1b]133;B\x07");
        for (line, status) in [
            ("cmd /c exit 3", 3),
            ("Get-Item nope-not-here", 1),
            ("cmd /c exit 3", 3),
            ("Write-Output 'a;b'", 0),
        ] {
            terminal.type_line(line);
            let escaped = line.replace(';', "\\x3b");
            // ConPTY may put sequences of its own between two marks.
            terminal.wait_for(&format!("\x1b]633;E;{escaped};n0nce\x07"));
            terminal.wait_for("\x1b]133;C\x07");
            terminal.wait_for(&format!("\x1b]133;D;{status}\x07"));
            terminal.wait_for("\x1b]133;A\x07");
            terminal.wait_for("\x1b]133;B\x07");
        }
    }

    /// Where only constrained language runs (AppLocker, WDAC), the script
    /// steps aside: your prompt stays as it was, without errors.
    #[cfg(windows)]
    #[test]
    fn constrained_powershell_keeps_its_prompt() {
        let dir = tempfile::tempdir().unwrap();
        let dir_path = crate::platform::canonical(dir.path());
        let constrained = format!(
            "$ExecutionContext.SessionState.LanguageMode = 'ConstrainedLanguage'\n{POWERSHELL}"
        );
        let launch = windows_powershell(&dir_path).with_args(
            [
                "-NoLogo",
                "-NoProfile",
                "-NoExit",
                "-EncodedCommand",
                &encoded(&constrained),
            ]
            .map(str::to_owned),
        );
        let mut terminal = Terminal::start(&launch);
        terminal.wait_for(&format!("PS {}> ", dir_path.display()));
        terminal.type_line("Write-Output ('k' + 'umo')");
        terminal.wait_for("kumo");
        terminal.wait_for("> ");
        let rest = terminal.printed();
        assert!(!rest.contains("\x1b]133;"), "{rest:?}");
        assert!(!rest.contains("\x1b]633;"), "{rest:?}");
        assert!(!rest.to_lowercase().contains("error"), "{rest:?}");
    }

    #[test]
    fn install_writes_every_script() {
        let dir = tempfile::tempdir().unwrap();
        ShellScripts::install(dir.path()).unwrap();
        for file in ["zsh/.zshenv", "zsh/kumo.zsh", "kumo.bash", "kumo.fish"] {
            assert!(dir.path().join(file).is_file(), "{file}");
        }
    }
}
