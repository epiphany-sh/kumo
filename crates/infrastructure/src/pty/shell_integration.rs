//! Kumo's shell integration: zsh, bash and fish report their prompts and
//! the commands run at them (OSC 133), through scripts loaded on top of the
//! user's own startup files, which load as they always do.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use kumo_domain::terminal::{LaunchSpec, NoShellIntegration, ShellIntegration};

const ZSHENV: &str = include_str!("shell_integration/zshenv.zsh");
const ZSH: &str = include_str!("shell_integration/kumo.zsh");
const BASH: &str = include_str!("shell_integration/kumo.bash");
const FISH: &str = include_str!("shell_integration/kumo.fish");

/// The integration for this OS's shells, its scripts written under `dir`.
/// None where the OS has no shell it covers, or when they can't be written
/// (shells then start as they are).
pub fn shell_integration(dir: &Path) -> Arc<dyn ShellIntegration> {
    if !crate::platform::shell_integration() {
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
}

impl ShellScripts {
    /// Writes the scripts under `dir`, over the ones an older Kumo left.
    pub fn install(dir: &Path) -> std::io::Result<Self> {
        let zsh = dir.join("zsh");
        std::fs::create_dir_all(&zsh)?;
        std::fs::write(zsh.join(".zshenv"), ZSHENV)?;
        std::fs::write(zsh.join("kumo.zsh"), ZSH)?;
        std::fs::write(dir.join("kumo.bash"), BASH)?;
        std::fs::write(dir.join("kumo.fish"), FISH)?;
        Ok(Self {
            dir: dir.to_path_buf(),
        })
    }

    fn file(&self, name: &str) -> String {
        self.dir.join(name).display().to_string()
    }
}

impl ShellIntegration for ShellScripts {
    fn apply(&self, spec: LaunchSpec) -> LaunchSpec {
        let Some(shell) = Shell::of(spec.program()) else {
            return spec;
        };
        // A script, `-c` or `-f` runs as asked.
        if !spec.args().iter().all(|arg| interactive(arg)) {
            return spec;
        }
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
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Shell {
    Zsh,
    Bash,
    Fish,
}

impl Shell {
    fn of(program: &str) -> Option<Self> {
        match Path::new(program).file_stem()?.to_str()? {
            "zsh" => Some(Self::Zsh),
            "bash" => Some(Self::Bash),
            "fish" => Some(Self::Fish),
            _ => None,
        }
    }
}

/// An argument that only asks for an interactive or a login shell.
fn interactive(arg: &str) -> bool {
    arg == "-i" || login(arg)
}

fn login(arg: &str) -> bool {
    matches!(arg, "-l" | "--login" | "-il" | "-li")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scripts() -> ShellScripts {
        ShellScripts {
            dir: PathBuf::from("/data/kumo/shell"),
        }
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

    #[test]
    fn zsh_starts_from_kumo_s_zdotdir_and_keeps_the_user_s() {
        let applied =
            scripts().apply(spec("/bin/zsh", &["-l"]).with_var("ZDOTDIR", "/home/u/.config/zsh"));
        assert_eq!(applied.args(), ["-l"]);
        assert_eq!(applied.var("ZDOTDIR"), Some(script("zsh").as_str()));
        assert_eq!(
            applied.var("KUMO_USER_ZDOTDIR"),
            Some("/home/u/.config/zsh")
        );
    }

    #[test]
    fn bash_reads_kumo_s_script_and_is_told_it_was_a_login_shell() {
        let applied = scripts().apply(spec("/bin/bash", &["-l"]));
        assert_eq!(
            applied.args(),
            ["--init-file", script("kumo.bash").as_str(), "-i"]
        );
        assert_eq!(applied.var("KUMO_BASH_LOGIN"), Some("1"));

        let applied = scripts().apply(spec("bash", &[]));
        assert_eq!(applied.var("KUMO_BASH_LOGIN"), None);
    }

    #[test]
    fn fish_sources_kumo_s_script_after_its_own() {
        let applied = scripts().apply(spec("/opt/homebrew/bin/fish", &["-l"]));
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
                scripts().apply(before.clone()),
                before,
                "{program} {args:?}"
            );
        }
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
