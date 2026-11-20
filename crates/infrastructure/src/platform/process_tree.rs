//! What a terminal runs, worked out from a table of processes: Windows
//! has no foreground process group, so it's read from who started whom.
//! Pure, so it's tested on every OS; `windows.rs` fills the table.

use std::collections::{HashMap, HashSet};

/// A process as the OS lists it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct ProcessRow {
    pub pid: u32,
    /// Who started it. Windows reuses pids: the parent may be gone, and
    /// its pid another process's now.
    pub ppid: u32,
    /// The executable's file name, e.g. `node.exe`.
    pub name: String,
    /// When it started, in any unit that grows with time; None when the
    /// OS won't tell.
    pub created: Option<u64>,
}

/// Programs a terminal runs commands in: what they started is the
/// command, not them.
const SHELLS: &[&str] = &[
    "cmd",
    "powershell",
    "pwsh",
    "bash",
    "sh",
    "zsh",
    "fish",
    "nu",
];

/// The console host ConPTY starts: never what the user runs.
const CONSOLE_HOSTS: &[&str] = &["conhost", "openconsole"];

/// `node.exe` → `node`, lowercase.
fn stem(name: &str) -> String {
    let name = name.to_ascii_lowercase();
    name.strip_suffix(".exe")
        .map_or_else(|| name.clone(), str::to_owned)
}

fn is_shell(row: &ProcessRow) -> bool {
    SHELLS.contains(&stem(&row.name).as_str())
}

/// The process in the foreground of a terminal that started `root`, as
/// Unix's foreground process group would tell: while a shell waits on a
/// command, the newest program it started (going through shells it
/// started: `cmd /c claude.cmd`, a shell in the shell); the program
/// itself, not its own children (an agent's tools). None when `root` is
/// gone.
pub(crate) fn foreground(rows: &[ProcessRow], root: u32) -> Option<u32> {
    let mut current = rows.iter().find(|r| r.pid == root)?;
    while is_shell(current) {
        let newest = rows
            .iter()
            .filter(|r| r.ppid == current.pid && r.pid != current.pid)
            .filter(|r| !CONSOLE_HOSTS.contains(&stem(&r.name).as_str()))
            // A pid reused after its parent died: older than the parent.
            .filter(|r| match (r.created, current.created) {
                (Some(child), Some(parent)) => child >= parent,
                _ => true,
            })
            .max_by_key(|r| r.created);
        match newest {
            Some(child) => current = child,
            None => break,
        }
    }
    Some(current.pid)
}

/// The processes whose start time [`foreground`] may compare, walking
/// from `root`: it, and what it and the shells under it started. Only
/// `root`'s tree, whatever else runs: reading a start time opens the
/// process. Empty when `root` is gone.
pub(crate) fn start_times_needed(rows: &[ProcessRow], root: u32) -> HashSet<u32> {
    let mut children: HashMap<u32, Vec<&ProcessRow>> = HashMap::new();
    for row in rows.iter().filter(|r| r.pid != r.ppid) {
        children.entry(row.ppid).or_default().push(row);
    }
    let Some(root) = rows.iter().find(|r| r.pid == root) else {
        return HashSet::new();
    };
    let mut needed = HashSet::from([root.pid]);
    let mut shells = vec![root];
    while let Some(shell) = shells.pop() {
        if !is_shell(shell) {
            continue;
        }
        for &child in children.get(&shell.pid).into_iter().flatten() {
            // A pid seen already: a loop of reused pids.
            if needed.insert(child.pid) {
                shells.push(child);
            }
        }
    }
    needed
}

/// A Windows command line split into arguments, as programs built with
/// the Microsoft C runtime do (`CommandLineToArgvW`): the program up to
/// the first space outside quotes, as written; then `"` groups,
/// `\"` is a quote, and backslashes double only before a quote.
pub(crate) fn split_command_line(line: &str) -> Vec<String> {
    let mut args = Vec::new();
    let mut chars = line.chars().peekable();

    // The program: quotes only group, backslashes are a path's.
    let mut program = String::new();
    let mut quoted = false;
    while let Some(&c) = chars.peek() {
        if c == '"' {
            quoted = !quoted;
        } else if !quoted && (c == ' ' || c == '\t') {
            break;
        } else {
            program.push(c);
        }
        chars.next();
    }
    if program.is_empty() && line.trim().is_empty() {
        return args;
    }
    args.push(program);

    loop {
        while chars.peek().is_some_and(|c| *c == ' ' || *c == '\t') {
            chars.next();
        }
        if chars.peek().is_none() {
            return args;
        }
        let mut arg = String::new();
        let mut quoted = false;
        while let Some(&c) = chars.peek() {
            match c {
                '\\' => {
                    let mut slashes = 0;
                    while chars.peek() == Some(&'\\') {
                        slashes += 1;
                        chars.next();
                    }
                    if chars.peek() == Some(&'"') {
                        arg.extend(std::iter::repeat_n('\\', slashes / 2));
                        if slashes % 2 == 1 {
                            arg.push('"');
                            chars.next();
                        }
                    } else {
                        arg.extend(std::iter::repeat_n('\\', slashes));
                    }
                    continue;
                }
                '"' => {
                    chars.next();
                    // `""` inside quotes is a quote.
                    if quoted && chars.peek() == Some(&'"') {
                        arg.push('"');
                        chars.next();
                    } else {
                        quoted = !quoted;
                    }
                    continue;
                }
                ' ' | '\t' if !quoted => break,
                _ => arg.push(c),
            }
            chars.next();
        }
        args.push(arg);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn row(pid: u32, ppid: u32, name: &str, created: u64) -> ProcessRow {
        ProcessRow {
            pid,
            ppid,
            name: name.to_owned(),
            created: Some(created),
        }
    }

    #[test]
    fn an_idle_shell_is_its_own_foreground() {
        let rows = [
            row(1, 0, "kumod.exe", 1),
            row(10, 1, "pwsh.exe", 10),
            row(11, 1, "OpenConsole.exe", 10),
            row(12, 10, "conhost.exe", 11),
        ];
        assert_eq!(foreground(&rows, 10), Some(10));
        assert_eq!(foreground(&rows, 99), None, "the terminal is gone");
    }

    #[test]
    fn the_newest_command_of_the_shell_and_not_its_tools() {
        let rows = [
            row(10, 1, "pwsh.exe", 10),
            row(20, 10, "node.exe", 20),
            // Started by the agent: its tools, not the foreground.
            row(21, 20, "bash.exe", 21),
            row(22, 21, "rg.exe", 22),
            // An older background job of the shell.
            row(15, 10, "ssh-agent.exe", 15),
        ];
        assert_eq!(foreground(&rows, 10), Some(20));
        // A program the terminal runs directly is the foreground itself.
        assert_eq!(foreground(&rows, 20), Some(20));
    }

    #[test]
    fn goes_through_shells_the_shell_started() {
        // pwsh runs `claude.cmd` through cmd, which starts node.
        let rows = [
            row(10, 1, "pwsh.exe", 10),
            row(30, 10, "CMD.EXE", 30),
            row(31, 30, "node.exe", 31),
            row(32, 31, "git.exe", 32),
        ];
        assert_eq!(foreground(&rows, 10), Some(31));
        // A shell typed in the shell, waiting.
        let rows = [row(10, 1, "cmd.exe", 10), row(40, 10, "pwsh.exe", 40)];
        assert_eq!(foreground(&rows, 10), Some(40));
    }

    #[test]
    fn start_times_are_read_only_where_the_walk_compares_them() {
        let rows = [
            // Its parent's pid reused by a shell it started: a loop, which
            // ends.
            row(10, 70, "pwsh.exe", 10),
            row(70, 10, "bash.exe", 70),
            row(30, 10, "cmd.exe", 30),
            row(31, 30, "node.exe", 31),
            // An agent's tools: never compared.
            row(32, 31, "bash.exe", 32),
            row(33, 32, "rg.exe", 33),
            // Other terminals' and the system's shells and their children.
            row(1, 0, "explorer.exe", 1),
            row(50, 1, "pwsh.exe", 50),
            row(51, 50, "node.exe", 51),
            row(60, 1, "cmd.exe", 60),
            row(61, 60, "git.exe", 61),
        ];
        let mut read: Vec<u32> = start_times_needed(&rows, 10).into_iter().collect();
        read.sort_unstable();
        assert_eq!(read, [10, 30, 31, 70]);
        assert_eq!(
            start_times_needed(&rows, 31)
                .into_iter()
                .collect::<Vec<_>>(),
            [31],
            "a program run directly: just itself"
        );
        assert!(start_times_needed(&rows, 99).is_empty(), "gone");
    }

    #[test]
    fn a_reused_pid_is_no_child() {
        // 10's pid was reused by a process older than it.
        let rows = [
            row(10, 1, "pwsh.exe", 50),
            row(20, 10, "node.exe", 20),
            ProcessRow {
                created: None,
                ..row(21, 10, "claude.exe", 0)
            },
        ];
        assert_eq!(foreground(&rows, 10), Some(21), "unknown age: kept");
        assert_eq!(foreground(&rows[..2], 10), Some(10));
    }

    #[test]
    fn command_lines_split_as_the_c_runtime_does() {
        let split = |line: &str| split_command_line(line);
        assert_eq!(
            split(
                r#""C:\Program Files\nodejs\node.exe"  "C:\Users\Jane Doe\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\cli.js" --resume"#
            ),
            [
                r"C:\Program Files\nodejs\node.exe",
                r"C:\Users\Jane Doe\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\cli.js",
                "--resume",
            ]
        );
        assert_eq!(
            split(r"C:\Users\me\.local\bin\claude.exe -p hi"),
            [r"C:\Users\me\.local\bin\claude.exe", "-p", "hi"]
        );
        // The program keeps its backslashes; quotes and backslashes after.
        assert_eq!(
            split(r#"C:\a\b.exe "a \"b\"" c\\d "e\\" f\\\"g "" "x""y""#),
            [
                r"C:\a\b.exe",
                r#"a "b""#,
                r"c\\d",
                r"e\",
                r#"f\"g"#,
                "",
                r#"x"y"#
            ]
        );
        assert_eq!(
            split(r#"cmd.exe /d /s /c "C:\npm\claude.cmd --resume""#),
            ["cmd.exe", "/d", "/s", "/c", r"C:\npm\claude.cmd --resume"]
        );
        assert!(split("").is_empty());
        assert!(split("   ").is_empty());
    }
}
