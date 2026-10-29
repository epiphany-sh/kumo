//! Reads what an agent did from the lines its CLI prints for each tool
//! call: `⏺ Bash(cargo test)` (Claude Code), `• Ran cargo test` (Codex),
//! `✔ Shell cargo test` (Gemini).

use std::collections::VecDeque;

use super::AgentEventKind;
use crate::terminal::LineSplitter;

/// Longest text kept for one action.
const MAX_TEXT: usize = 120;
/// Actions remembered to skip TUI redraws of the same lines.
const REMEMBER: usize = 64;

/// Turns an agent's output into the actions it took, once each.
#[derive(Debug, Default)]
pub struct ActionReader {
    lines: LineSplitter,
    seen: VecDeque<(AgentEventKind, String)>,
}

impl ActionReader {
    /// The new actions in `bytes`.
    pub fn push(&mut self, bytes: &[u8]) -> Vec<(AgentEventKind, String)> {
        let mut found = Vec::new();
        for line in self.lines.push(bytes) {
            let Some(action) = action_of(&line) else {
                continue;
            };
            if self.seen.contains(&action) {
                continue;
            }
            if self.seen.len() == REMEMBER {
                self.seen.pop_front();
            }
            self.seen.push_back(action.clone());
            found.push(action);
        }
        found
    }
}

/// The action a line reports, if it reports one.
pub fn action_of(line: &str) -> Option<(AgentEventKind, String)> {
    let line = line.trim();
    let mut chars = line.chars();
    let marker = chars.next()?;
    let rest = chars.as_str().trim_start();
    match marker {
        // Claude Code: `Name(args)`; folded reads: `Read 3 files (ctrl+o…)`.
        '⏺' | '●' => called(rest).or_else(|| folded(rest)),
        // Codex: a verb and what it acted on.
        '•' => {
            let (verb, what) = rest.split_once(' ').unwrap_or((rest, ""));
            let kind = match verb {
                "Ran" => AgentEventKind::Ran,
                "Edited" | "Added" | "Deleted" | "Wrote" => AgentEventKind::Edited,
                "Read" | "Explored" => AgentEventKind::Read,
                "Searched" | "Listed" => AgentEventKind::Searched,
                _ => return None,
            };
            Some((kind, clip(if what.is_empty() { verb } else { what })))
        }
        // Gemini: a tool name and its arguments.
        '✔' | '✓' => {
            let (name, what) = rest.split_once(char::is_whitespace).unwrap_or((rest, ""));
            if !is_name(name) {
                return None;
            }
            Some(named(name, what.trim()))
        }
        _ => None,
    }
}

/// `Bash(cargo test)`.
fn called(rest: &str) -> Option<(AgentEventKind, String)> {
    let open = rest.find('(')?;
    let name = &rest[..open];
    let args = rest[open + 1..].strip_suffix(')')?;
    is_name(name).then(|| named(name, args.trim()))
}

/// `Read 3 files (ctrl+o to expand)`, `Searched for 2 patterns, read 1 file`.
fn folded(rest: &str) -> Option<(AgentEventKind, String)> {
    let (text, _) = rest.split_once(" (ctrl+")?;
    let kind = if text.starts_with("Read ") {
        AgentEventKind::Read
    } else if text.starts_with("Searched ") || text.starts_with("Listed ") {
        AgentEventKind::Searched
    } else {
        return None;
    };
    Some((kind, clip(text)))
}

fn named(name: &str, args: &str) -> (AgentEventKind, String) {
    let kind = match name {
        "Bash" | "Shell" | "Run" => AgentEventKind::Ran,
        "Edit" | "MultiEdit" | "Update" | "Write" | "Create" | "WriteFile" | "Replace"
        | "NotebookEdit" => AgentEventKind::Edited,
        "Read" | "ReadFile" | "ReadManyFiles" | "ReadFolder" | "WebFetch" | "Fetch" => {
            AgentEventKind::Read
        }
        "Grep" | "Glob" | "LS" | "Search" | "SearchText" | "FindFiles" | "WebSearch"
        | "GoogleSearch" => AgentEventKind::Searched,
        _ => {
            let text = if args.is_empty() {
                name.to_owned()
            } else {
                format!("{name} {args}")
            };
            return (AgentEventKind::Tool, clip(&text));
        }
    };
    (kind, clip(if args.is_empty() { name } else { args }))
}

/// A tool name: a capitalized word (`Bash`, `ReadFile`, `mcp__x__y` isn't).
fn is_name(name: &str) -> bool {
    name.len() >= 2
        && name.starts_with(|c: char| c.is_ascii_uppercase())
        && name.chars().all(|c| c.is_ascii_alphanumeric())
}

fn clip(text: &str) -> String {
    let text = text.trim();
    if text.chars().count() <= MAX_TEXT {
        return text.to_owned();
    }
    format!("{}…", text.chars().take(MAX_TEXT - 1).collect::<String>())
}

#[cfg(test)]
mod tests {
    use super::*;
    use AgentEventKind::*;

    #[test]
    fn reads_each_cli_s_tool_lines() {
        let cases = [
            (
                "⏺ Bash(cargo test --workspace)",
                Some((Ran, "cargo test --workspace")),
            ),
            ("● Update(src/lib.rs)", Some((Edited, "src/lib.rs"))),
            (
                "⏺ Read 3 files (ctrl+o to expand)",
                Some((Read, "Read 3 files")),
            ),
            (
                "⏺ Task(Find the parser)",
                Some((Tool, "Task Find the parser")),
            ),
            ("⏺ I'll look at the parser first.", None),
            ("• Ran cargo fmt", Some((Ran, "cargo fmt"))),
            (
                "• Edited src/main.rs (+3 -1)",
                Some((Edited, "src/main.rs (+3 -1)")),
            ),
            ("• I think the bug is here", None),
            ("✔ ReadFile src/a.rs", Some((Read, "src/a.rs"))),
            ("✓ Shell npm test", Some((Ran, "npm test"))),
            ("  plain output", None),
        ];
        for (line, want) in cases {
            assert_eq!(
                action_of(line),
                want.map(|(k, t)| (k, t.to_owned())),
                "{line}"
            );
        }
    }

    #[test]
    fn redraws_dont_repeat_actions() {
        let mut reader = ActionReader::default();
        let first = reader.push("\x1b[2K\x1b[1m⏺\x1b[0m Bash(make test)\r\n  ⎿  ok\r\n".as_bytes());
        assert_eq!(first, [(Ran, "make test".to_owned())]);
        assert!(reader.push("⏺ Bash(make test)\r\n".as_bytes()).is_empty());
        assert_eq!(
            reader.push("⏺ Edit(a.rs)\n".as_bytes()),
            [(Edited, "a.rs".to_owned())]
        );
    }
}
