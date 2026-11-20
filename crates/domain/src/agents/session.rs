use std::fmt;
use std::path::PathBuf;
use std::time::Duration;

use crate::terminal::{ExitStatus, TerminalId};
use crate::time::Timestamp;

use super::AgentPreset;
use super::usage::AgentModel;

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct AgentSessionId(String);

impl AgentSessionId {
    pub fn generate() -> Self {
        Self(uuid::Uuid::new_v4().simple().to_string())
    }

    pub fn parse(raw: &str) -> Option<Self> {
        let raw = raw.trim();
        (!raw.is_empty()).then(|| Self(raw.to_owned()))
    }
}

impl fmt::Display for AgentSessionId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// What an agent is doing, as seen from its terminal.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AgentState {
    Working,
    /// Quiet, or it asked for attention (bell / notification).
    NeedsInput,
    Exited(ExitStatus),
}

/// An agent running (or that ran) in a worktree, in its own terminal.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentSession {
    pub id: AgentSessionId,
    pub provider_id: String,
    pub provider_name: String,
    pub short: String,
    pub worktree: PathBuf,
    pub terminal: TerminalId,
    pub title: String,
    pub prompt: String,
    pub state: AgentState,
    /// Waiting because it asked something (an approval), so what's typed
    /// now answers it; false when it's only quiet.
    pub asked: bool,
    /// Its CLI was told to say when it asks. False: `asked` is never set, and
    /// what's typed could be taken as an answer.
    pub tells_asking: bool,
    pub started_at: Timestamp,
    pub state_since: Timestamp,
    /// How long it spent working before `state_since`.
    pub worked: Duration,
    pub last_line: String,
    /// What it was given to work from, in the order it got it.
    pub context: Vec<AgentContext>,
    /// What it did, oldest first; the last [`AgentSession::MAX_EVENTS`].
    pub events: Vec<AgentEvent>,
    /// The agent of yours it runs (`claude --agent <name>`).
    pub agent_name: Option<String>,
    /// What it was given for the run, as files (`--add-dir`).
    pub context_dir: Option<PathBuf>,
    /// The model and effort it runs on, as its CLI last reported them.
    pub model: AgentModel,
}

/// Where a piece of context came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ContextKind {
    Task,
    Doc,
    /// Code selected in a file.
    Code,
    /// A pull request: its diff and description.
    PullRequest,
    /// Files or a folder of a worktree.
    Files,
    /// A web page, read once.
    Link,
}

/// A ticket or page an agent was given.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentContext {
    pub kind: ContextKind,
    /// e.g. "TSK-412 · Bulk discounts by category".
    pub title: String,
    /// Where it lives, e.g. "Jira" or "Confluence · Platform".
    pub detail: String,
    pub url: String,
    /// Its id where it comes from (a task's or a page's), if known.
    pub id: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AgentEventKind {
    Started,
    Edited,
    Ran,
    Read,
    Searched,
    /// Another tool, named in the text.
    Tool,
    /// Its turn ended; the text is what it said last.
    Waiting,
    /// It was sent a ticket or page.
    Context,
    /// The process ended; the text says how.
    Exited,
}

/// One step of an agent's timeline.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentEvent {
    pub at: Timestamp,
    pub kind: AgentEventKind,
    pub text: String,
}

impl AgentSession {
    pub const MAX_EVENTS: usize = 80;

    /// Adds a step to the timeline. Waiting twice in a row (nothing done
    /// in between) is one step, updated.
    pub fn record(&mut self, kind: AgentEventKind, text: String, at: Timestamp) {
        if kind == AgentEventKind::Waiting
            && let Some(last) = self.events.last_mut()
            && last.kind == AgentEventKind::Waiting
        {
            last.at = at;
            last.text = text;
            return;
        }
        self.events.push(AgentEvent { at, kind, text });
        if self.events.len() > Self::MAX_EVENTS {
            let extra = self.events.len() - Self::MAX_EVENTS;
            self.events.drain(..extra);
        }
    }

    /// Moves to `state`, adding up the time it worked.
    pub fn enter(&mut self, state: AgentState, now: Timestamp) {
        self.worked = self.worked_at(now);
        self.state = state;
        self.state_since = now;
    }

    /// How long it has been working by `now`; waiting for you doesn't count.
    pub fn worked_at(&self, now: Timestamp) -> Duration {
        if self.state != AgentState::Working {
            return self.worked;
        }
        self.worked + now.since(self.state_since)
    }

    /// The card title: the given one, else the prompt's first line, else
    /// the agent's name.
    pub fn title_for(title: &str, prompt: &str, provider_name: &str) -> String {
        let title = title.trim();
        if !title.is_empty() {
            return title.to_owned();
        }
        match prompt.lines().map(str::trim).find(|l| !l.is_empty()) {
            Some(line) if line.chars().count() > 80 => {
                format!("{}…", line.chars().take(79).collect::<String>())
            }
            Some(line) => line.to_owned(),
            None => provider_name.to_owned(),
        }
    }
}

/// A known agent CLI in the foreground of one of Kumo's terminals, started
/// there by hand (typed `claude` in a shell).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TerminalAgent {
    pub terminal: TerminalId,
    pub provider_id: String,
    /// The program as it runs, e.g. `claude`.
    pub program: String,
    pub cwd: PathBuf,
    /// Read from its screen, like a session's.
    pub state: AgentState,
    /// Producing output.
    pub busy: bool,
    /// The model and effort it runs on, as its CLI last reported them.
    pub model: AgentModel,
}

/// Runtimes a CLI can be a script of (`node …/claude`, a shell wrapper).
const RUNTIMES: &[&str] = &[
    "node", "bun", "deno", "python", "python3", "sh", "bash", "zsh",
];

/// Extensions a program has on Windows (`claude.exe`, `codex.cmd`,
/// `node.exe`). Only stripped from Windows names: on macOS and Linux a
/// name matches as it is.
const WINDOWS_EXTENSIONS: &[&str] = &[".exe", ".cmd", ".bat", ".ps1"];

fn base_name(path: &str) -> &str {
    path.rsplit(['/', '\\']).next().unwrap_or(path)
}

/// `path`'s file name; a Windows one lowercase (Windows names ignore
/// case) and without its [extension](WINDOWS_EXTENSIONS).
fn program_name(path: &str, windows: bool) -> String {
    let name = base_name(path);
    if !windows {
        return name.to_owned();
    }
    let name = name.to_ascii_lowercase();
    WINDOWS_EXTENSIONS
        .iter()
        .find_map(|ext| name.strip_suffix(ext))
        .map_or_else(|| name.clone(), str::to_owned)
}

/// The npm package a script is in, by full name
/// (`…/node_modules/@scope/name/…` → `@scope/name`): npm's shims on
/// Windows run `node` on the package's script itself
/// (`…/@anthropic-ai/claude-code/cli.js`), not on a `claude` link.
fn npm_package(script: &str) -> Option<String> {
    let parts: Vec<&str> = script.split(['/', '\\']).collect();
    let at = parts.iter().rposition(|p| *p == "node_modules")?;
    let mut rest = parts[at + 1..].iter();
    let first = rest.next()?;
    let name = if first.starts_with('@') {
        format!("{first}/{}", rest.next()?)
    } else {
        (*first).to_owned()
    };
    // A file right in node_modules isn't a package.
    rest.next()?;
    Some(name)
}

/// Which of `programs` (provider id, program) a process is: its
/// executable or its first argument, or, for a runtime, its script (by
/// name, or by the npm package it's in: only a known CLI's own
/// [packages](AgentPreset::packages), by full name). A Windows process
/// (its executable's path has `\`) is matched ignoring case and
/// `.exe`/`.cmd`/`.bat`/`.ps1`.
pub fn agent_program<'a>(
    exe: &str,
    args: &[String],
    programs: &'a [(String, String)],
) -> Option<&'a (String, String)> {
    let windows = exe.contains('\\');
    let mut names = vec![program_name(exe, windows)];
    if let Some(first) = args.first() {
        names.push(program_name(first, windows));
    }
    let mut package = None;
    if names.iter().any(|n| RUNTIMES.contains(&n.as_str()))
        && let Some(script) = args.get(1)
    {
        names.push(program_name(script, windows));
        package = npm_package(script);
    }
    programs.iter().find(|(id, program)| {
        let program = program_name(program, windows);
        let in_package = package.as_deref().is_some_and(|package| {
            AgentPreset::find(id).is_some_and(|preset| {
                preset.packages.iter().any(|known| {
                    if windows {
                        known.eq_ignore_ascii_case(package)
                    } else {
                        *known == package
                    }
                })
            })
        });
        (!program.is_empty() && names.contains(&program)) || in_package
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_time_working_adds_up() {
        let at = |secs: u64| Timestamp::from_unix_nanos(secs * 1_000_000_000);
        let mut session = AgentSession {
            id: AgentSessionId::generate(),
            provider_id: String::new(),
            provider_name: String::new(),
            short: String::new(),
            worktree: PathBuf::new(),
            terminal: TerminalId::generate(),
            title: String::new(),
            prompt: String::new(),
            state: AgentState::Working,
            asked: false,
            tells_asking: true,
            started_at: at(0),
            state_since: at(0),
            worked: Duration::ZERO,
            last_line: String::new(),
            context: Vec::new(),
            events: Vec::new(),
            agent_name: None,
            context_dir: None,
            model: AgentModel::default(),
        };
        let secs = Duration::from_secs;
        assert_eq!(session.worked_at(at(10)), secs(10));
        session.enter(AgentState::NeedsInput, at(10));
        assert_eq!(session.worked_at(at(500)), secs(10));
        session.enter(AgentState::Working, at(500));
        assert_eq!(session.worked_at(at(503)), secs(13));
    }

    #[test]
    fn a_cli_is_found_by_its_program_or_its_script() {
        let programs = vec![
            ("claude".to_owned(), "claude".to_owned()),
            ("codex".to_owned(), "codex".to_owned()),
        ];
        let args = |a: &[&str]| a.iter().map(|s| (*s).to_owned()).collect::<Vec<_>>();
        assert_eq!(
            agent_program("/opt/homebrew/bin/codex", &args(&["codex"]), &programs)
                .unwrap()
                .0,
            "codex"
        );
        assert_eq!(
            agent_program(
                "/usr/local/bin/node",
                &args(&["node", "/usr/local/bin/claude", "-c"]),
                &programs
            )
            .unwrap()
            .0,
            "claude"
        );
        assert_eq!(
            agent_program("claude", &args(&["claude", "--resume"]), &programs)
                .unwrap()
                .0,
            "claude"
        );
        assert!(agent_program("/usr/bin/vim", &args(&["vim", "claude"]), &programs).is_none());
        assert!(agent_program("/bin/zsh", &args(&["-zsh"]), &programs).is_none());
        assert!(agent_program("/bin/sh", &args(&["/bin/sh", "-c", "claude"]), &programs).is_none());
        assert_eq!(
            agent_program("/bin/sh", &args(&["/bin/sh", "/opt/bin/claude"]), &programs)
                .unwrap()
                .0,
            "claude"
        );
    }

    #[test]
    fn a_cli_is_found_on_windows_as_npm_and_installers_run_it() {
        let programs = vec![
            ("claude".to_owned(), "claude".to_owned()),
            ("codex".to_owned(), "codex".to_owned()),
            ("gemini".to_owned(), "gemini".to_owned()),
            ("opencode".to_owned(), "opencode".to_owned()),
        ];
        let args = |a: &[&str]| a.iter().map(|s| (*s).to_owned()).collect::<Vec<_>>();
        let id = |exe: &str, a: &[&str]| agent_program(exe, &args(a), &programs).map(|p| &p.0);
        let node = r"C:\Program Files\nodejs\node.exe";
        let npm = r"C:\Users\Jane Doe\AppData\Roaming\npm\node_modules";

        // The native installer's executable, any case.
        let native = r"C:\Users\me\.local\bin\claude.exe";
        assert_eq!(id(native, &[native, "--resume"]).unwrap(), "claude");
        assert_eq!(id(r"C:\x\Claude.EXE", &["Claude.EXE"]).unwrap(), "claude");
        // npm's shims run node on the package's script, wherever it is.
        let cli = format!(r"{npm}\@anthropic-ai\claude-code\cli.js");
        assert_eq!(id(node, &[node, &cli, "-c"]).unwrap(), "claude");
        let codex = format!(r"{npm}\@openai\codex\bin\codex.js");
        assert_eq!(id(node, &["node", &codex]).unwrap(), "codex");
        let gemini = format!(r"{npm}\@google\gemini-cli\dist\index.js");
        assert_eq!(id(node, &["node.exe", &gemini]).unwrap(), "gemini");
        let opencode = format!(r"{npm}\opencode-ai\bin\opencode");
        assert_eq!(id(node, &[node, &opencode]).unwrap(), "opencode");
        // The `.cmd` shim, run by a shell of its own.
        let shim = r"C:\Users\me\AppData\Roaming\npm\codex.cmd";
        assert_eq!(id(shim, &[shim]).unwrap(), "codex");

        // Another package, or an editor opening the CLI's files: no.
        let other = format!(r"{npm}\claudette\cli.js");
        assert!(id(node, &[node, &other]).is_none());
        let server = format!(r"{npm}\typescript\lib\tsserver.js");
        assert!(id(node, &[node, &server]).is_none());
        assert!(id(r"C:\x\notepad.exe", &["notepad.exe", &cli]).is_none());
        assert!(id(r"C:\x\pwsh.exe", &["pwsh.exe", "-NoLogo"]).is_none());
    }

    fn preset_programs() -> Vec<(String, String)> {
        super::super::PRESETS
            .iter()
            .map(|p| (p.id.to_owned(), p.program.to_owned()))
            .collect()
    }

    #[test]
    fn only_a_cli_s_own_npm_package_is_it() {
        let programs = preset_programs();
        let args = |a: &[&str]| a.iter().map(|s| (*s).to_owned()).collect::<Vec<_>>();
        let id = |exe: &str, a: &[&str]| agent_program(exe, &args(a), &programs).map(|p| &p.0);
        for (node, modules, sep) in [
            (
                r"C:\Program Files\nodejs\node.exe",
                r"C:\npm\node_modules",
                "\\",
            ),
            ("/usr/local/bin/node", "/usr/local/lib/node_modules", "/"),
        ] {
            let script = |package: &str| {
                let package = package.replace('/', sep);
                format!("{modules}{sep}{package}{sep}dist{sep}cli.js")
            };
            for other in [
                "claude-code-router",
                "@musistudio/claude-code-router",
                "claude-flow",
                "claude-task-master",
                "codex-cli",
                "gemini-mcp-tool",
                "opencode-mcp",
                // Same names, someone else's packages.
                "claude-code",
                "codex",
                "gemini-cli",
            ] {
                assert!(id(node, &[node, &script(other)]).is_none(), "{other}");
            }
            for (package, provider) in [
                ("@anthropic-ai/claude-code", "claude"),
                ("@openai/codex", "codex"),
                ("@google/gemini-cli", "gemini"),
                ("@github/copilot", "copilot"),
                ("opencode-ai", "opencode"),
                ("@qwen-code/qwen-code", "qwen"),
                ("@sourcegraph/amp", "amp"),
            ] {
                let found = id(node, &[node, &script(package)]);
                assert_eq!(found.map(String::as_str), Some(provider), "{package}");
            }
        }
    }

    #[test]
    fn unix_names_match_as_they_always_did() {
        /// `agent_program` before Windows support.
        fn before<'a>(
            exe: &str,
            args: &[String],
            programs: &'a [(String, String)],
        ) -> Option<&'a (String, String)> {
            let mut names = vec![base_name(exe)];
            if let Some(first) = args.first() {
                names.push(base_name(first));
            }
            if names.iter().any(|n| RUNTIMES.contains(n))
                && let Some(script) = args.get(1)
            {
                names.push(base_name(script));
            }
            programs.iter().find(|(_, program)| {
                let program = base_name(program);
                !program.is_empty() && names.contains(&program)
            })
        }
        let programs = preset_programs();
        let cases: &[(&str, &[&str])] = &[
            ("/opt/homebrew/bin/codex", &["codex"]),
            (
                "/usr/local/bin/node",
                &["node", "/usr/local/bin/claude", "-c"],
            ),
            ("/usr/local/bin/node", &["node", "/x/claude.js"]),
            ("/usr/local/bin/node", &["node", "/x/codex.mjs"]),
            ("/usr/local/bin/node", &["node", "/x/Claude"]),
            ("/x/claude.exe", &["claude.exe"]),
            ("/x/codex.cmd", &["codex.cmd"]),
            ("/x/Claude", &["Claude"]),
            ("/x/CODEX", &["CODEX"]),
            ("/x/gemini.ps1", &["gemini.ps1"]),
            ("/usr/bin/vim", &["vim", "claude"]),
            ("/bin/zsh", &["-zsh"]),
            ("/bin/sh", &["/bin/sh", "-c", "claude"]),
            ("/bin/sh", &["/bin/sh", "/opt/bin/claude"]),
            ("/usr/bin/python3", &["python3", "/x/aider"]),
            ("/usr/bin/python3", &["python3", "/x/aider.py"]),
            ("/x/cursor-agent", &["cursor-agent"]),
            ("/x/claude-code-router", &["ccr"]),
            (
                "/usr/local/bin/node",
                &["node", "/n/node_modules/claude-flow/cli.js"],
            ),
            (
                "/usr/local/bin/node",
                &["node", "/n/node_modules/codex-cli/codex"],
            ),
        ];
        for (exe, a) in cases {
            let a: Vec<String> = a.iter().map(|s| (*s).to_owned()).collect();
            assert_eq!(
                agent_program(exe, &a, &programs),
                before(exe, &a, &programs),
                "{exe} {a:?}"
            );
        }
    }
}
