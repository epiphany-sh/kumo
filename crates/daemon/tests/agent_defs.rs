//! `AgentDefs` end to end: your agents' files in a profile's Claude Code
//! folder and in a repository, runs and test runs of a fake `claude` (a
//! shell script that writes down how it was called).
#![cfg(unix)]

mod common;

use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use common::{Attached, TIMEOUT, TestDaemon, git, git_repo, open, save_namespace};
use kumo_grpc::client::KumoClient;
use kumo_proto::v1 as pb;
use tonic::Code;

/// A fake Claude Code. Interactive, it says "ready" and waits; with `-p`
/// it prints stream-json (or plain text for a question), and fails when
/// `<log>/fail` exists. Each call writes its arguments (one per line) and
/// folder to `<log>/<run|play|ask>.{args,cwd}`.
fn fake_claude(bin: &Path, log: &Path) {
    std::fs::create_dir_all(log).unwrap();
    let log = log.display();
    let script = format!(
        r#"#!/bin/sh
if [ "$1" = "--version" ]; then echo "2.1.0 (Claude Code)"; exit 0; fi
if [ "$1" = "--help" ]; then echo "  --max-budget-usd <amount>"; exit 0; fi
kind=run
if [ "$1" = "-p" ]; then kind=play; fi
case "$*" in *"--output-format text"*) kind=ask;; esac
: > "{log}/$kind.args"
for a in "$@"; do printf '%s\n' "$a" >> "{log}/$kind.args"; done
pwd > "{log}/$kind.cwd"
if [ "$kind" = ask ]; then echo "---"; echo "name: drafted"; exit 0; fi
if [ "$kind" = play ]; then
  if [ -f "{log}/fail" ]; then echo "Not signed in" >&2; exit 2; fi
  echo '{{"type":"system","subtype":"init"}}'
  echo changed > touched.txt
  echo '{{"type":"result","subtype":"success","result":"done"}}'
  exit 0
fi
echo ready
while read line; do :; done
"#
    );
    let path = bin.join("claude");
    std::fs::write(&path, script).unwrap();
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
}

struct Setup {
    daemon: TestDaemon,
    client: KumoClient,
    repo: PathBuf,
    log: PathBuf,
}

impl Setup {
    /// A second profile (its Claude Code folder is its own, inside the
    /// data folder), one repository, a fake claude connected.
    async fn new() -> Self {
        let daemon = TestDaemon::start().await;
        let mut first = daemon.client().await;
        first
            .profiles
            .create(pb::CreateProfileRequest {
                name: "Workspace 1".into(),
                ..Default::default()
            })
            .await
            .unwrap();
        let mut client = first.with_profile(Some("workspace-1"));
        let log = daemon.home().join("log");
        fake_claude(&daemon.bin(), &log);
        let repo = git_repo(
            &daemon.home().join("dev/app"),
            Some("https://github.com/acme/app.git"),
        );
        save_namespace(&mut client, "app", &[&repo]).await;
        connect_claude(&mut client).await;
        Self {
            daemon,
            client,
            repo,
            log,
        }
    }

    fn profile_dir(&self) -> PathBuf {
        self.daemon
            .home()
            .parent()
            .unwrap()
            .join("data/profiles/workspace-1")
    }

    fn claude_dir(&self) -> PathBuf {
        self.profile_dir().join("cli/claude")
    }

    /// The arguments of the last `what` call, without the `--settings`
    /// Kumo passes to read Claude Code's usage.
    fn logged(&self, what: &str) -> Vec<String> {
        let mut args: Vec<String> = std::fs::read_to_string(self.log.join(format!("{what}.args")))
            .unwrap()
            .lines()
            .map(str::to_owned)
            .collect();
        if args.first().is_some_and(|a| a == "--settings") {
            args.drain(..2);
        }
        args
    }

    fn cwd(&self, what: &str) -> PathBuf {
        let raw = std::fs::read_to_string(self.log.join(format!("{what}.cwd"))).unwrap();
        std::fs::canonicalize(raw.trim()).unwrap()
    }
}

async fn connect_claude(client: &mut KumoClient) {
    client
        .agents
        .save_provider(pb::SaveProviderRequest {
            id: "claude".into(),
            name: "Claude Code".into(),
            program: "claude".into(),
            enabled: true,
            is_default: true,
            ..Default::default()
        })
        .await
        .unwrap();
}

fn markdown(name: &str) -> String {
    format!(
        "---\nname: {name}\ndescription: Reviews things. Use it when asked.\ntools: Read\n---\n\nYou review.\n"
    )
}

fn personal(name: &str) -> pb::AgentDefFile {
    pb::AgentDefFile {
        scope: pb::AgentDefScope::Personal.into(),
        name: name.into(),
        markdown: markdown(name),
        ..Default::default()
    }
}

fn project(repo: &Path, name: &str) -> pb::AgentDefFile {
    pb::AgentDefFile {
        scope: pb::AgentDefScope::Project.into(),
        repo_path: repo.display().to_string(),
        repo_name: "app".into(),
        name: name.into(),
        markdown: markdown(name),
        ..Default::default()
    }
}

async fn save(
    client: &mut KumoClient,
    agent: pb::AgentDefFile,
    previous: Option<pb::AgentDefFile>,
) -> pb::AgentDefFile {
    client
        .agent_defs
        .save(pb::SaveAgentDefRequest {
            agent: Some(agent),
            previous,
        })
        .await
        .unwrap()
        .into_inner()
}

async fn list(client: &mut KumoClient) -> Vec<pb::AgentDefFile> {
    client
        .agent_defs
        .list(pb::ListAgentDefsRequest {})
        .await
        .unwrap()
        .into_inner()
        .agents
}

#[tokio::test(flavor = "multi_thread")]
async fn files_are_saved_moved_and_deleted_in_both_scopes() {
    let mut s = Setup::new().await;
    let limits = pb::AgentDefSettings {
        max_minutes: Some(15),
        max_cost_usd: Some(2.0),
        triggers: vec![pb::AgentDefTrigger::PullRequest.into()],
    };
    let saved = save(
        &mut s.client,
        pb::AgentDefFile {
            settings: Some(limits.clone()),
            ..personal("researcher")
        },
        None,
    )
    .await;
    let file = s.claude_dir().join("agents/researcher.md");
    assert_eq!(saved.file_path, file.display().to_string());
    assert_eq!(
        std::fs::read_to_string(&file).unwrap(),
        markdown("researcher")
    );
    save(&mut s.client, project(&s.repo, "rev"), None).await;
    assert!(s.repo.join(".claude/agents/rev.md").exists());
    // Written by hand: listed as is, whatever it says.
    std::fs::write(s.repo.join(".claude/agents/broken.md"), "no frontmatter").unwrap();
    std::fs::write(s.repo.join(".claude/agents/notes.txt"), "not an agent").unwrap();

    let all = list(&mut s.client).await;
    let names: Vec<(&str, i32)> = all.iter().map(|a| (a.name.as_str(), a.scope)).collect();
    assert_eq!(names, [("researcher", 0), ("broken", 1), ("rev", 1)]);
    assert_eq!(all[0].settings.as_ref().unwrap(), &limits);
    assert_eq!(all[1].markdown, "no frontmatter");
    assert_eq!(all[2].repo_name, "app");

    // A rename and a move to Personal: the old file goes, settings follow.
    let old = project(&s.repo, "rev");
    let moved = pb::AgentDefFile {
        settings: Some(pb::AgentDefSettings {
            max_minutes: Some(3),
            ..Default::default()
        }),
        ..personal("reviewer")
    };
    save(&mut s.client, moved, Some(old)).await;
    assert!(!s.repo.join(".claude/agents/rev.md").exists());
    let all = list(&mut s.client).await;
    let reviewer = all.iter().find(|a| a.name == "reviewer").unwrap();
    assert_eq!(reviewer.settings.as_ref().unwrap().max_minutes, Some(3));

    s.client
        .agent_defs
        .delete(pb::DeleteAgentDefRequest {
            agent: Some(personal("reviewer")),
        })
        .await
        .unwrap();
    assert!(!s.claude_dir().join("agents/reviewer.md").exists());

    for bad in [
        personal("../x"),
        personal("Upper"),
        project(Path::new("/elsewhere"), "x"),
    ] {
        let error = s
            .client
            .agent_defs
            .save(pb::SaveAgentDefRequest {
                agent: Some(bad),
                previous: None,
            })
            .await
            .unwrap_err();
        assert_eq!(error.code(), Code::InvalidArgument, "{error:?}");
    }
    assert!(!s.claude_dir().join("x.md").exists());
}

#[tokio::test(flavor = "multi_thread")]
async fn capabilities_list_skills_and_mcp_servers() {
    let mut s = Setup::new().await;
    std::fs::create_dir_all(s.claude_dir().join("skills/go-tests")).unwrap();
    std::fs::create_dir_all(s.repo.join(".claude/skills/sql-review")).unwrap();
    std::fs::write(
        s.repo.join(".mcp.json"),
        r#"{"mcpServers":{"postgres":{}}}"#,
    )
    .unwrap();
    std::fs::write(
        s.claude_dir().join(".claude.json"),
        r#"{"mcpServers":{"jira":{}}}"#,
    )
    .unwrap();
    let got = s
        .client
        .agent_defs
        .capabilities(pb::AgentDefCapabilitiesRequest {})
        .await
        .unwrap()
        .into_inner();
    assert_eq!(got.skills, ["go-tests", "sql-review"]);
    assert_eq!(got.mcp_servers, ["jira", "postgres"]);
    assert!(!got.triggers_supported);
}

fn run(
    agent: pb::AgentDefFile,
    place: pb::run_agent_def_request::Where,
    prompt: &str,
) -> pb::RunAgentDefRequest {
    pb::RunAgentDefRequest {
        agent: Some(agent),
        r#where: Some(place),
        prompt: prompt.into(),
        ..Default::default()
    }
}

/// Waits for `path` to exist (the fake writes it once it starts).
async fn appears(path: &Path) {
    tokio::time::timeout(TIMEOUT, async {
        while !path.exists() {
            tokio::time::sleep(std::time::Duration::from_millis(20)).await;
        }
    })
    .await
    .unwrap_or_else(|_| panic!("{} never appeared", path.display()));
}

async fn session_where(
    client: &mut KumoClient,
    id: &str,
    ready: impl Fn(&pb::AgentSession) -> bool,
) -> pb::AgentSession {
    let mut stream = client
        .agents
        .watch(pb::WatchAgentsRequest {})
        .await
        .unwrap()
        .into_inner();
    tokio::time::timeout(TIMEOUT, async {
        loop {
            let snapshot = stream.message().await.unwrap().expect("watch ended");
            if let Some(found) = snapshot.sessions.iter().find(|x| x.id == id && ready(x)) {
                return found.clone();
            }
        }
    })
    .await
    .unwrap_or_else(|_| panic!("session {id} never got there"))
}

#[tokio::test(flavor = "multi_thread")]
async fn a_run_starts_claude_with_its_agent_and_its_context() {
    use pb::run_agent_def_request::Where;
    let mut s = Setup::new().await;
    let agent = save(&mut s.client, personal("rev"), None).await;
    let mut request = run(
        agent.clone(),
        Where::WorktreePath(s.repo.display().to_string()),
        "Review the branch",
    );
    request.context = vec![
        pb::AgentContext {
            kind: pb::AgentContextKind::Files.into(),
            title: "src/lib.rs".into(),
            ..Default::default()
        },
        pb::AgentContext {
            kind: pb::AgentContextKind::Task.into(),
            title: "PRC-1 · Nowhere".into(),
            ..Default::default()
        },
    ];
    let session = s.client.agent_defs.run(request).await.unwrap().into_inner();
    assert_eq!(
        (session.agent_name.as_str(), session.title.as_str()),
        ("rev", "Review the branch")
    );
    let context = PathBuf::from(&session.context_dir);
    assert_eq!(context, s.profile_dir().join("runs/rev-1"));
    appears(&s.log.join("run.cwd")).await;
    let sentence = format!(
        "What you were given for this run is in {}: start with context.md.",
        context.display()
    );
    let args = s.logged("run");
    assert_eq!(
        args[..4],
        [
            "--agent",
            "rev",
            "--add-dir",
            &context.display().to_string()
        ]
    );
    assert_eq!(
        args[4..],
        [
            "--append-system-prompt",
            &kumo_domain::agent_defs::role_sentence("rev"),
            "Review the branch",
            "",
            &sentence
        ]
    );
    assert_eq!(s.cwd("run"), s.repo);
    let index = std::fs::read_to_string(context.join("context.md")).unwrap();
    assert!(
        index.contains(&format!(
            "- Files: src/lib.rs ({})",
            s.repo.join("src/lib.rs").display()
        )),
        "{index}"
    );
    assert!(
        index.contains("- Ticket: PRC-1 · Nowhere · couldn’t be read:"),
        "{index}"
    );

    // Stop is a stop; a second run counts.
    s.client
        .agents
        .stop(pb::StopAgentRequest {
            id: session.id.clone(),
        })
        .await
        .unwrap();
    session_where(&mut s.client, &session.id, |x| {
        x.state == pb::AgentState::Exited as i32
    })
    .await;

    // A project agent outside its repo goes inline, in a scratch folder,
    // and with no prompt the user types.
    std::fs::remove_file(s.log.join("run.cwd")).unwrap();
    let mut inline = run(project(&s.repo, "rev"), Where::Scratch(true), "");
    inline.inline_json = r#"{"rev":{"description":"d","prompt":"p"}}"#.into();
    let second = s.client.agent_defs.run(inline).await.unwrap().into_inner();
    assert_eq!(second.title, "Run 2");
    assert!(second.context_dir.is_empty());
    appears(&s.log.join("run.cwd")).await;
    assert_eq!(
        s.logged("run"),
        [
            "--agents",
            r#"{"rev":{"description":"d","prompt":"p"}}"#,
            "--agent",
            "rev",
            "--append-system-prompt",
            &kumo_domain::agent_defs::role_sentence("rev"),
        ]
    );
    let scratch = std::fs::canonicalize(s.profile_dir().join("scratch/rev-1")).unwrap();
    assert_eq!(s.cwd("run"), scratch);

    // A new worktree on a branch of its own.
    std::fs::remove_file(s.log.join("run.cwd")).unwrap();
    s.client
        .agent_defs
        .run(run(
            agent.clone(),
            Where::NewWorktreeRepo(s.repo.display().to_string()),
            "",
        ))
        .await
        .unwrap();
    appears(&s.log.join("run.cwd")).await;
    let branch = git(&s.cwd("run"), &["rev-parse", "--abbrev-ref", "HEAD"]);
    assert_eq!(branch.trim(), "rev-1");

    // A link to a repository of the workspace runs in it.
    std::fs::remove_file(s.log.join("run.cwd")).unwrap();
    s.client
        .agent_defs
        .run(run(
            agent.clone(),
            Where::LinkUrl("https://github.com/acme/app".into()),
            "",
        ))
        .await
        .unwrap();
    appears(&s.log.join("run.cwd")).await;
    assert_eq!(s.cwd("run"), s.repo);

    let missing = s
        .client
        .agent_defs
        .run(run(agent, Where::Folder("/no/such/folder".into()), ""))
        .await
        .unwrap_err();
    assert_eq!(missing.code(), Code::InvalidArgument);
}

#[tokio::test(flavor = "multi_thread")]
async fn a_run_is_stopped_when_its_time_is_up() {
    use pb::run_agent_def_request::Where;
    let mut s = Setup::new().await;
    // A minute lasts 300 ms in tests.
    let agent = pb::AgentDefFile {
        settings: Some(pb::AgentDefSettings {
            max_minutes: Some(1),
            ..Default::default()
        }),
        ..personal("slow")
    };
    let session = s
        .client
        .agent_defs
        .run(run(
            agent,
            Where::WorktreePath(s.repo.display().to_string()),
            "go",
        ))
        .await
        .unwrap()
        .into_inner();
    let ended = session_where(&mut s.client, &session.id, |x| {
        x.state == pb::AgentState::Exited as i32
    })
    .await;
    assert_eq!(ended.exit_code, 124);
    assert_eq!(ended.events.last().unwrap().text, "Stopped: its time limit");
}

/// A conversation isn't cut short while it waits for you: only working
/// counts towards the limit.
#[tokio::test(flavor = "multi_thread")]
async fn waiting_for_you_does_not_use_up_a_runs_time() {
    use pb::run_agent_def_request::Where;
    let mut s = Setup::new().await;
    let path = s.daemon.bin().join("claude");
    std::fs::write(
        &path,
        r#"#!/bin/sh
if [ "$1" = "--version" ]; then echo "2.1.0 (Claude Code)"; exit 0; fi
if [ "$1" = "--help" ]; then echo "  --max-budget-usd <amount>"; exit 0; fi
printf 'Allow?\a'
read answer
while :; do /bin/sleep 0.05; printf .; done
"#,
    )
    .unwrap();
    // A minute lasts 300 ms in tests.
    let agent = pb::AgentDefFile {
        settings: Some(pb::AgentDefSettings {
            max_minutes: Some(1),
            ..Default::default()
        }),
        ..personal("patient")
    };
    let session = s
        .client
        .agent_defs
        .run(run(
            agent,
            Where::WorktreePath(s.repo.display().to_string()),
            "go",
        ))
        .await
        .unwrap()
        .into_inner();
    session_where(&mut s.client, &session.id, |x| x.asked).await;

    // Three times its limit, waiting.
    tokio::time::sleep(std::time::Duration::from_millis(900)).await;
    let waiting = session_where(&mut s.client, &session.id, |_| true).await;
    assert_eq!(waiting.state(), pb::AgentState::NeedsInput, "{waiting:?}");

    let terminal = Attached::new(&mut s.client, &session.terminal_id, false).await;
    terminal.send(b"yes\r").await;
    let ended = session_where(&mut s.client, &session.id, |x| {
        x.state == pb::AgentState::Exited as i32
    })
    .await;
    assert_eq!(ended.exit_code, 124);
    assert!(ended.worked_ms >= 250, "{ended:?}");
}

async fn play(client: &mut KumoClient, request: pb::PlayRequest) -> Vec<pb::PlayEvent> {
    let mut stream = client.agent_defs.play(request).await.unwrap().into_inner();
    tokio::time::timeout(TIMEOUT, async {
        let mut events = Vec::new();
        while let Some(event) = stream.message().await.unwrap() {
            events.push(event);
        }
        events
    })
    .await
    .expect("the test run never ended")
}

#[tokio::test(flavor = "multi_thread")]
async fn a_test_run_streams_its_lines_and_keeps_them() {
    let mut s = Setup::new().await;
    let owner = save(&mut s.client, personal("rev"), None).await;
    let request = pb::PlayRequest {
        name: "rev-draft".into(),
        inline_json: r#"{"rev-draft":{}}"#.into(),
        task: "Review #521".into(),
        worktree_path: s.repo.display().to_string(),
        throwaway: true,
        max_turns: Some(8),
        max_cost_usd: Some(0.5),
        agent: Some(owner.clone()),
        draft: true,
        ..Default::default()
    };
    let events = play(&mut s.client, request.clone()).await;
    use pb::play_event::Kind;
    let kinds: Vec<&Kind> = events.iter().map(|e| e.kind.as_ref().unwrap()).collect();
    assert_eq!(
        kinds,
        [
            &Kind::Line(r#"{"type":"system","subtype":"init"}"#.into()),
            &Kind::Line(r#"{"type":"result","subtype":"success","result":"done"}"#.into()),
            &Kind::Exited(0),
        ]
    );
    assert_eq!(
        s.logged("play"),
        [
            "-p",
            "--agents",
            r#"{"rev-draft":{}}"#,
            "--agent",
            "rev-draft",
            "--output-format",
            "stream-json",
            "--verbose",
            "--append-system-prompt",
            &kumo_domain::agent_defs::role_sentence("rev-draft"),
            "--max-turns",
            "8",
            "--max-budget-usd",
            "0.5",
            "--",
            "Review #521"
        ]
    );
    // It ran in a throwaway worktree, gone now with what it changed.
    let ran_in = std::fs::read_to_string(s.log.join("play.cwd")).unwrap();
    assert!(
        ran_in.contains("/profiles/workspace-1/plays/play-"),
        "{ran_in}"
    );
    assert!(!Path::new(ran_in.trim()).exists());
    assert!(!s.repo.join("touched.txt").exists());
    assert!(git(&s.repo, &["worktree", "list"]).lines().count() == 1);

    // Claude Code failing before any result: its error, as a failed result.
    std::fs::write(s.log.join("fail"), "").unwrap();
    let failed = play(
        &mut s.client,
        pb::PlayRequest {
            throwaway: false,
            ..request
        },
    )
    .await;
    let line = match failed[0].kind.as_ref().unwrap() {
        Kind::Line(line) => line.clone(),
        other => panic!("{other:?}"),
    };
    assert!(
        line.contains(r#""is_error":true"#) && line.contains("Not signed in"),
        "{line}"
    );
    assert_eq!(failed.last().unwrap().kind, Some(Kind::Exited(2)));

    let kept = s
        .client
        .agent_defs
        .list_plays(pb::ListPlaysRequest { agent: Some(owner) })
        .await
        .unwrap()
        .into_inner()
        .plays;
    assert_eq!(kept.len(), 2);
    assert_eq!(kept[1].task, "Review #521");
    assert!(kept[1].draft && !kept[1].running);
    assert_eq!(kept[1].events.len(), 3);
}

#[tokio::test(flavor = "multi_thread")]
async fn ask_answers_in_plan_mode() {
    let mut s = Setup::new().await;
    let answer = s
        .client
        .agent_defs
        .ask(pb::AskClaudeRequest {
            prompt: "Write a subagent".into(),
            cwd: String::new(),
        })
        .await
        .unwrap()
        .into_inner()
        .text;
    assert_eq!(answer, "---\nname: drafted");
    assert_eq!(
        s.logged("ask"),
        [
            "-p",
            "--output-format",
            "text",
            "--permission-mode",
            "plan",
            "--",
            "Write a subagent"
        ]
    );
    // In an empty folder of its own, removed after.
    let cwd = std::fs::read_to_string(s.log.join("ask.cwd")).unwrap();
    assert!(cwd.contains("/profiles/workspace-1/ask/"), "{cwd}");
    assert!(!Path::new(cwd.trim()).exists());
}

#[tokio::test(flavor = "multi_thread")]
async fn text_is_typed_into_a_terminal_as_a_paste_when_it_asked_for_one() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    // A program that turns bracketed paste on, then echoes a line.
    let id = open(
        &mut client,
        "/bin/sh",
        &[
            "-c",
            "stty -echo; printf '\\033[?2004h'; read line; printf 'got[%s]\\n' \"$line\"; sleep 5",
        ],
    )
    .await;
    let mut attached = Attached::new(&mut client, &id, true).await;
    attached.read_until("\u{1b}[?2004h").await;
    client
        .agents
        .send_to_terminal(pb::SendToTerminalRequest {
            terminal_id: id.clone(),
            text: "hello".into(),
            submit: true,
        })
        .await
        .unwrap();
    attached
        .read_until("got[\u{1b}[200~hello\u{1b}[201~]")
        .await;

    let plain = open(
        &mut client,
        "/bin/sh",
        &[
            "-c",
            "stty -echo; read line; printf 'got[%s]\\n' \"$line\"; sleep 5",
        ],
    )
    .await;
    let mut attached = Attached::new(&mut client, &plain, true).await;
    client
        .agents
        .send_to_terminal(pb::SendToTerminalRequest {
            terminal_id: plain.clone(),
            text: "hi there".into(),
            submit: true,
        })
        .await
        .unwrap();
    attached.read_until("got[hi there]").await;

    let gone = client
        .agents
        .send_to_terminal(pb::SendToTerminalRequest {
            terminal_id: "nope".into(),
            text: "x".into(),
            submit: false,
        })
        .await
        .unwrap_err();
    assert_ne!(gone.code(), Code::Ok);
}
