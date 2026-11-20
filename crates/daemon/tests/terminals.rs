//! `Terminals` service end to end, over real gRPC and real PTYs.

mod common;

use common::{Attached, TestDaemon, line, open, open_script, sleeper, wait_exited};
use kumo_proto::v1 as pb;

/// Reads until the terminal's program printed its size as `rows` and
/// `cols` (`stty size`, or `mode con` on Windows).
async fn read_until_size(attached: &mut Attached, rows: u32, cols: u32) {
    let size = if cfg!(windows) {
        format!("Lines: {rows} Columns: {cols}")
    } else {
        format!("{rows} {cols}")
    };
    attached
        .read_until_with(&size, |text| {
            let words: Vec<&str> = text.split_whitespace().collect();
            words.join(" ").contains(&size)
        })
        .await;
}

/// What prints the terminal's size: see [`read_until_size`].
const SIZE: (&str, &str) = ("stty size", "mode con");

#[tokio::test(flavor = "multi_thread")]
async fn streams_output_and_exit_code() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open_script(&mut client, "printf hello; exit 3", "echo hello& exit 3").await;

    let mut attached = Attached::new(&mut client, &id, true).await;
    assert_eq!(attached.read_to_exit().await, 3);
    assert!(attached.received.text().contains("hello"));
}

#[tokio::test(flavor = "multi_thread")]
async fn echoes_input() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open_script(
        &mut client,
        "stty -echo; printf READY; read line; echo got:$line",
        "echo READY& set /p line=& echo got:!line!",
    )
    .await;

    let mut attached = Attached::new(&mut client, &id, true).await;
    attached.read_until("READY").await;
    attached.send(line("ping")).await;
    attached.read_until("got:ping").await;
    assert_eq!(attached.read_to_exit().await, 0);
}

#[tokio::test(flavor = "multi_thread")]
async fn resize_reaches_the_process() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open_script(
        &mut client,
        &format!("stty -echo; printf READY; read _; {}", SIZE.0),
        &format!("echo READY& set /p _=& {}", SIZE.1),
    )
    .await;

    let mut attached = Attached::new(&mut client, &id, true).await;
    attached.read_until("READY").await;
    attached.resize(100, 30).await;
    attached.send(line("")).await;
    read_until_size(&mut attached, 30, 100).await;
}

#[tokio::test(flavor = "multi_thread")]
async fn detach_and_reattach_replays_without_gaps_or_duplicates() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open_script(
        &mut client,
        "for i in 1 2 3 4 5 6; do echo n$i; sleep 0.05; done",
        "for /l %i in (1,1,6) do @(echo n%i& ping -n 1 127.0.0.1 >nul)",
    )
    .await;

    // First client sees the beginning and goes away mid-run.
    let mut first = Attached::new(&mut client, &id, true).await;
    first.read_until("n2").await;
    let seen = first.received.batches.clone();
    drop(first);

    // The session keeps running without anyone attached.
    wait_exited(&mut client, &id).await;

    // A new client gets everything, in order, exactly once.
    let mut second = Attached::new(&mut client, &id, true).await;
    assert_eq!(second.read_to_exit().await, 0);
    let seqs = second.received.seqs();
    let expected: Vec<u64> = (1..=seqs.len() as u64).collect();
    assert_eq!(seqs, expected, "replay must be contiguous from 1");
    for n in 1..=6 {
        assert!(
            second.received.text().contains(&format!("n{n}")),
            "missing n{n}"
        );
    }
    // What the first client saw is a prefix of the replay.
    assert_eq!(&second.received.batches[..seen.len()], &seen[..]);
}

#[tokio::test(flavor = "multi_thread")]
async fn reattach_without_replay_only_gets_new_output() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open_script(
        &mut client,
        "stty -echo; printf READY; read l; echo after:$l",
        "echo READY& set /p l=& echo after:!l!",
    )
    .await;

    let mut first = Attached::new(&mut client, &id, true).await;
    first.read_until("READY").await;
    let last_seen = *first.received.seqs().last().unwrap();
    drop(first);

    let mut second = Attached::new(&mut client, &id, false).await;
    second.send(line("x")).await;
    second.read_until("after:x").await;
    assert!(!second.received.text().contains("READY"));
    assert!(second.received.seqs().iter().all(|seq| *seq > last_seen));
}

#[tokio::test(flavor = "multi_thread")]
async fn close_kills_and_forgets_the_terminal() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let (program, args) = sleeper();
    let id = open(&mut client, program, args).await;

    let mut attached = Attached::new(&mut client, &id, true).await;
    client
        .terminals
        .close(pb::CloseRequest {
            terminal_id: id.clone(),
        })
        .await
        .unwrap();
    attached.read_to_exit().await;

    let list = client
        .terminals
        .list(pb::ListRequest {})
        .await
        .unwrap()
        .into_inner();
    assert!(list.terminals.iter().all(|t| t.terminal_id != id));

    let missing = client
        .terminals
        .close(pb::CloseRequest { terminal_id: id })
        .await
        .unwrap_err();
    assert_eq!(missing.code(), tonic::Code::NotFound);
}

/// A test run or an agent nobody watches: no client attached, and the
/// program still runs to its end (ConPTY waits to be told where the cursor
/// is; the daemon tells it).
#[tokio::test(flavor = "multi_thread")]
async fn a_program_nobody_attached_to_runs_to_its_end() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open_script(&mut client, "exit 0", "exit 0").await;
    wait_exited(&mut client, &id).await;
}

/// A client attaching after the daemon answered the terminal for it isn't
/// asked again: its answer would reach the program as typed text.
#[tokio::test(flavor = "multi_thread")]
async fn a_client_attaching_late_is_not_asked_what_was_answered() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open_script(
        &mut client,
        "printf READY; read l; echo got:$l",
        "echo READY& set /p l=& echo got:[!l!]",
    )
    .await;
    // Nobody attached yet: the daemon answers ConPTY.
    tokio::time::sleep(std::time::Duration::from_millis(500)).await;

    let mut late = Attached::new(&mut client, &id, true).await;
    late.read_until("READY").await;
    assert!(!late.received.text().contains("\x1b[6n"));
    late.send(line("x")).await;
    if cfg!(windows) {
        late.read_until("got:[x]").await;
    } else {
        late.read_until("got:x").await;
    }
}
#[tokio::test(flavor = "multi_thread")]
async fn unknown_program_fails_to_open() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let request = pb::OpenRequest {
        program: "kumo-definitely-not-a-program".into(),
        ..Default::default()
    };
    let error = client.terminals.open(request).await.unwrap_err();
    assert_eq!(error.code(), tonic::Code::FailedPrecondition);
}

#[tokio::test(flavor = "multi_thread")]
async fn list_reports_where_each_terminal_started() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let dir = tempfile::tempdir().unwrap();
    let cwd = dir.path().display().to_string();
    let (program, args) = sleeper();
    let response = client
        .terminals
        .open(pb::OpenRequest {
            program: program.into(),
            args: args.iter().map(|a| (*a).to_owned()).collect(),
            cwd: cwd.clone(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    let elsewhere = open(&mut client, program, args).await;

    let list = client
        .terminals
        .list(pb::ListRequest {})
        .await
        .unwrap()
        .into_inner();
    let cwd_of = |id: &str| {
        list.terminals
            .iter()
            .find(|t| t.terminal_id == id)
            .map(|t| t.cwd.clone())
    };
    assert_eq!(cwd_of(&response.terminal_id), Some(cwd));
    assert_eq!(cwd_of(&elsewhere), Some(String::new()));
}

/// The Terminal view and the Agents view on one terminal: both see all of
/// it, input from either goes in, and the last resize wins.
#[tokio::test(flavor = "multi_thread")]
async fn two_attachments_share_a_terminal() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let id = open_script(
        &mut client,
        &format!(
            "stty -echo; printf READY; read a; echo first:$a; read b; echo second:$b; read _; {}",
            SIZE.0
        ),
        &format!(
            "echo READY& set /p a=& echo first:!a!& set /p b=& echo second:!b!& set /p _=& {}",
            SIZE.1
        ),
    )
    .await;

    let mut terminal_view = Attached::new(&mut client, &id, true).await;
    terminal_view.read_until("READY").await;
    let mut agents_view = Attached::new(&mut client, &id, true).await;
    // The terminal view answered already.
    agents_view.answers_cursor = false;
    agents_view.read_until("READY").await;

    terminal_view.send(line("one")).await;
    agents_view.read_until("first:one").await;
    agents_view.send(line("two")).await;
    terminal_view.read_until("second:two").await;
    agents_view.read_until("second:two").await;

    // Last to arrive wins (two streams sent at once may arrive either way).
    terminal_view.resize(90, 20).await;
    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    agents_view.resize(120, 40).await;
    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    terminal_view.send(line("")).await;
    read_until_size(&mut terminal_view, 40, 120).await;
    read_until_size(&mut agents_view, 40, 120).await;
    assert_eq!(terminal_view.read_to_exit().await, 0);
}

/// zsh and bash get Kumo's integration on macOS and Linux only (a Git
/// Bash on Windows would be handed Windows paths to its scripts).
#[cfg(unix)]
mod posix_shells {
    use super::*;

    /// The next snapshot of the shells that `want` accepts.
    async fn activity_until(
        stream: &mut tonic::Streaming<pb::TerminalsActivity>,
        want: impl Fn(&pb::TerminalsActivity) -> bool,
    ) -> pb::TerminalsActivity {
        tokio::time::timeout(std::time::Duration::from_secs(20), async {
            loop {
                let snapshot = stream.message().await.unwrap().expect("the watch ended");
                if want(&snapshot) {
                    return snapshot;
                }
            }
        })
        .await
        .expect("no such snapshot")
    }

    /// Opens `shell` as the UI opens yours (`-l`, with Kumo's integration),
    /// with `home` as its home folder.
    async fn open_shell(
        client: &mut kumo_grpc::client::KumoClient,
        shell: &str,
        home: &std::path::Path,
        integration: bool,
    ) -> String {
        open_shell_remembering(client, shell, home, integration, false).await
    }

    /// [`open_shell`], remembering what it runs when `remember`.
    async fn open_shell_remembering(
        client: &mut kumo_grpc::client::KumoClient,
        shell: &str,
        home: &std::path::Path,
        integration: bool,
        remember: bool,
    ) -> String {
        let home = home.display().to_string();
        client
            .terminals
            .open(pb::OpenRequest {
                program: shell.into(),
                args: vec!["-l".into()],
                cwd: home.clone(),
                env: [
                    ("HOME".to_owned(), home.clone()),
                    ("ZDOTDIR".to_owned(), home),
                ]
                .into(),
                shell_integration: integration,
                remember_commands: remember,
                ..Default::default()
            })
            .await
            .unwrap()
            .into_inner()
            .terminal_id
    }

    /// The shell, where this machine has it.
    fn installed(shell: &str) -> Option<String> {
        ["/bin", "/usr/bin"]
            .into_iter()
            .map(|dir| format!("{dir}/{shell}"))
            .find(|path| std::path::Path::new(path).exists())
    }

    /// Runs `true` and `false` in a shell with Kumo's integration: its own
    /// startup file still loads, and each command is marked with its status.
    async fn marks_what_you_ran(shell: &str, rc_file: &str) {
        let Some(path) = installed(shell) else {
            eprintln!("{shell} isn't installed: skipped");
            return;
        };
        let daemon = TestDaemon::start().await;
        let home = daemon.home();
        std::fs::create_dir_all(&home).unwrap();
        std::fs::write(home.join(rc_file), "echo YOUR_RC_RAN\n").unwrap();
        let mut client = daemon.client().await;
        let id = open_shell(&mut client, &path, &home, true).await;

        let mut attached = Attached::new(&mut client, &id, true).await;
        attached.read_until("YOUR_RC_RAN").await;
        attached.read_until("\x1b]133;A").await;
        attached.send(b"true\n").await;
        attached.read_until("\x1b]133;D;0").await;
        attached.send(b"false\n").await;
        attached.read_until("\x1b]133;D;1").await;
        attached.send(b"exit\n").await;
        attached.read_to_exit().await;
        let text = attached.received.text();
        assert_eq!(text.matches("\x1b]133;C").count(), 3, "{text:?}");
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn zsh_marks_what_you_ran() {
        marks_what_you_ran("zsh", ".zshrc").await;
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn bash_marks_what_you_ran() {
        // A login bash reads .bash_profile, not .bashrc.
        marks_what_you_ran("bash", ".bash_profile").await;
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn a_shell_opened_without_integration_marks_nothing() {
        let Some(zsh) = installed("zsh") else {
            eprintln!("zsh isn't installed: skipped");
            return;
        };
        let daemon = TestDaemon::start().await;
        let home = daemon.home();
        std::fs::create_dir_all(&home).unwrap();
        std::fs::write(home.join(".zshrc"), "echo YOUR_RC_RAN\n").unwrap();
        let mut client = daemon.client().await;
        let id = open_shell(&mut client, &zsh, &home, false).await;

        let mut attached = Attached::new(&mut client, &id, true).await;
        attached.read_until("YOUR_RC_RAN").await;
        attached.send(b"exit\n").await;
        attached.read_to_exit().await;
        assert!(!attached.received.text().contains("\x1b]133;"));
    }

    /// Runs commands in a shell with Kumo's integration, in and out of a
    /// repository: each is remembered in the repository it ran in, once per
    /// line, with its last status; a line started with a space and a command
    /// line that only output names are not.
    async fn remembers_what_you_ran(shell: &str, rc_file: &str) {
        let Some(path) = installed(shell) else {
            eprintln!("{shell} isn't installed: skipped");
            return;
        };
        let daemon = TestDaemon::start().await;
        let home = daemon.home();
        std::fs::create_dir_all(&home).unwrap();
        std::fs::write(home.join(rc_file), "PS1='$ '\n").unwrap();
        let repo = common::git_repo(&home.join("app"), None);
        let mut client = daemon.client().await;
        let id = open_shell_remembering(&mut client, &path, &home, true, true).await;

        let mut attached = Attached::new(&mut client, &id, true).await;
        let done = "\x1b]133;D;";
        attached.read_until_count(done, 1).await;
        let steps: [&'static [u8]; 6] = [
            b"cd app\n",
            b"true\n",
            b"false\n",
            b"true\n",
            b" echo private\n",
            b"printf '\\033]633;E;forged;guess\\007'\n",
        ];
        for (i, step) in steps.into_iter().enumerate() {
            attached.send(step).await;
            attached.read_until_count(done, i + 2).await;
        }
        // Where you type is marked at the end of your prompt.
        assert!(attached.received.text().contains("$ \x1b]133;B\x07"));

        let history = client
            .terminals
            .history(pb::HistoryRequest {
                terminal_id: id.clone(),
                limit: 0,
            })
            .await
            .unwrap()
            .into_inner();
        let repo = repo.canonicalize().unwrap();
        assert_eq!(history.repo, repo.display().to_string());
        assert_eq!(
            std::path::Path::new(&history.cwd).canonicalize().unwrap(),
            repo
        );
        let commands: Vec<(&str, u32, Option<i32>)> = history
            .entries
            .iter()
            .map(|e| (e.command.as_str(), e.runs, e.last_exit))
            .collect();
        assert_eq!(
            commands,
            [
                ("printf '\\033]633;E;forged;guess\\007'", 1, Some(0)),
                ("true", 2, Some(0)),
                ("false", 1, Some(1)),
            ],
            "{:?}",
            attached.received.text()
        );

        let forgotten = client
            .terminals
            .forget_history(pb::ForgetHistoryRequest {
                terminal_id: id.clone(),
                everything: false,
            })
            .await
            .unwrap()
            .into_inner()
            .forgotten;
        assert_eq!(forgotten, 3);
        // `cd app` ran outside the repository: kept with the rest.
        let everything = client
            .terminals
            .forget_history(pb::ForgetHistoryRequest {
                terminal_id: String::new(),
                everything: true,
            })
            .await
            .unwrap()
            .into_inner()
            .forgotten;
        assert_eq!(everything, 1);
        attached.send(b"exit\n").await;
        attached.read_to_exit().await;
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn zsh_remembers_what_you_ran() {
        remembers_what_you_ran("zsh", ".zshrc").await;
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn bash_remembers_what_you_ran() {
        remembers_what_you_ran("bash", ".bash_profile").await;
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn a_shell_not_asked_to_remember_keeps_nothing() {
        let Some(zsh) = installed("zsh") else {
            eprintln!("zsh isn't installed: skipped");
            return;
        };
        let daemon = TestDaemon::start().await;
        let home = daemon.home();
        std::fs::create_dir_all(&home).unwrap();
        let mut client = daemon.client().await;
        let id = open_shell(&mut client, &zsh, &home, true).await;

        let mut attached = Attached::new(&mut client, &id, true).await;
        attached.read_until_count("\x1b]133;D;", 1).await;
        attached.send(b"true\n").await;
        attached.read_until_count("\x1b]133;D;", 2).await;
        let history = client
            .terminals
            .history(pb::HistoryRequest {
                terminal_id: id.clone(),
                limit: 0,
            })
            .await
            .unwrap()
            .into_inner();
        assert!(history.entries.is_empty());
        attached.send(b"exit\n").await;
        attached.read_to_exit().await;
    }
    #[tokio::test(flavor = "multi_thread")]
    async fn watch_says_what_each_shell_runs_and_how_its_last_command_ended() {
        let Some(zsh) = installed("zsh") else {
            eprintln!("zsh isn't installed: skipped");
            return;
        };
        let daemon = TestDaemon::start().await;
        let home = daemon.home();
        std::fs::create_dir_all(&home).unwrap();
        std::fs::write(home.join(".zshrc"), "PS1='$ '\n").unwrap();
        let mut client = daemon.client().await;
        let mut watch = client
            .terminals
            .watch(pb::WatchTerminalsRequest {})
            .await
            .unwrap()
            .into_inner();
        let id = open_shell(&mut client, &zsh, &home, true).await;
        let mut attached = Attached::new(&mut client, &id, true).await;
        attached.read_until_count("\x1b]133;D;", 1).await;

        let shell =
            |s: &pb::TerminalsActivity| s.shells.iter().find(|x| x.terminal_id == id).cloned();
        let first = activity_until(&mut watch, |s| shell(s).is_some()).await;
        let first = shell(&first).unwrap();
        assert!(
            first.running.is_none() && first.last.is_none(),
            "a prompt alone ran nothing"
        );

        attached.send(b"false\n").await;
        let failed = activity_until(&mut watch, |s| shell(s).and_then(|x| x.last).is_some()).await;
        let last = shell(&failed).unwrap().last.unwrap();
        assert_eq!((last.command.as_str(), last.exit_code), ("false", Some(1)));

        attached.send(b"sleep 2\n").await;
        let running =
            activity_until(&mut watch, |s| shell(s).and_then(|x| x.running).is_some()).await;
        assert_eq!(shell(&running).unwrap().running.unwrap().command, "sleep 2");
        let done = activity_until(&mut watch, |s| {
            shell(s)
                .and_then(|x| x.last)
                .is_some_and(|l| l.command == "sleep 2")
        })
        .await;
        let done = shell(&done).unwrap();
        assert!(done.running.is_none());
        assert_eq!(done.last.unwrap().exit_code, Some(0));
        assert_eq!(
            std::path::Path::new(&done.cwd).canonicalize().unwrap(),
            home.canonicalize().unwrap()
        );

        attached.send(b"exit\n").await;
        attached.read_to_exit().await;
    }
}

/// Windows PowerShell, the shell Kumo integrates there.
#[cfg(windows)]
mod powershell {
    use super::*;

    /// Runs commands in Windows PowerShell with Kumo's integration (as the
    /// UI opens it, without your profile), in and out of a repository: each
    /// is marked with its status and remembered in the repository it ran
    /// in, once per line; a line started with a space and a command line
    /// that only output names are not.
    #[tokio::test(flavor = "multi_thread")]
    async fn powershell_marks_and_remembers_what_you_ran() {
        let daemon = TestDaemon::start().await;
        let home = daemon.home();
        std::fs::create_dir_all(&home).unwrap();
        let repo = common::git_repo(&home.join("app"), None);
        let mut client = daemon.client().await;
        let id = client
            .terminals
            .open(pb::OpenRequest {
                program: "powershell.exe".into(),
                args: vec!["-NoLogo".into(), "-NoProfile".into()],
                cwd: home.display().to_string(),
                // PSReadLine keeps its history under the profile folder: a
                // temporary one, so nothing lands in yours.
                env: [("USERPROFILE".to_owned(), home.display().to_string())].into(),
                shell_integration: true,
                remember_commands: true,
                ..Default::default()
            })
            .await
            .unwrap()
            .into_inner()
            .terminal_id;

        let mut attached = Attached::new(&mut client, &id, true).await;
        let done = "\x1b]133;D;";
        attached.read_until_count(done, 1).await;
        let steps = [
            "cd app",
            "cmd /c exit 0",
            "cmd /c exit 1",
            "cmd /c exit 0",
            " echo private",
            "Write-Host ([char]27 + ']633;E;forged;guess' + [char]7)",
        ];
        for (i, step) in steps.into_iter().enumerate() {
            attached.send(line(step)).await;
            attached.read_until_count(done, i + 2).await;
        }
        let text = attached.received.text();
        // PSReadLine's history went to the temporary profile.
        let saved = home.join(r"AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine");
        assert!(saved.join("ConsoleHost_history.txt").is_file());
        // Where you type is marked at the end of your prompt.
        assert!(text.contains("> \x1b]133;B\x07"), "{text:?}");
        assert!(text.contains("\x1b]133;D;1\x07"), "{text:?}");

        let history = client
            .terminals
            .history(pb::HistoryRequest {
                terminal_id: id.clone(),
                limit: 0,
            })
            .await
            .unwrap()
            .into_inner();
        assert_eq!(history.repo, repo.display().to_string());
        assert_eq!(kumo_infrastructure::platform::canonical(&history.cwd), repo);
        let commands: Vec<(&str, u32, Option<i32>)> = history
            .entries
            .iter()
            .map(|e| (e.command.as_str(), e.runs, e.last_exit))
            .collect();
        assert_eq!(
            commands,
            [
                (
                    "Write-Host ([char]27 + ']633;E;forged;guess' + [char]7)",
                    1,
                    Some(0)
                ),
                ("cmd /c exit 0", 2, Some(0)),
                ("cmd /c exit 1", 1, Some(1)),
            ],
            "{text:?}"
        );

        // `cd app` ran outside the repository: kept with the rest.
        let everything = client
            .terminals
            .forget_history(pb::ForgetHistoryRequest {
                terminal_id: String::new(),
                everything: true,
            })
            .await
            .unwrap()
            .into_inner()
            .forgotten;
        assert_eq!(everything, 4);
        attached.send(line("exit")).await;
        attached.read_to_exit().await;
    }
}
