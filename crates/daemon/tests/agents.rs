//! `Agents` service end to end with fake agent CLIs (shell scripts on a
//! PATH of their own), real PTYs and real worktrees.
#![cfg(unix)]

mod common;

use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use common::{Attached, TIMEOUT, TestDaemon, git_repo, save_namespace};
use kumo_grpc::client::KumoClient;
use kumo_proto::v1 as pb;

/// A fake CLI: answers `--version`, otherwise runs `body`.
fn fake_cli(bin: &Path, name: &str, body: &str) {
    let path = bin.join(name);
    let script = format!(
        "#!/bin/sh\nif [ \"$1\" = \"--version\" ]; then echo \"{name} 1.0 (fake)\"; exit 0; fi\n{body}\n"
    );
    std::fs::write(&path, script).unwrap();
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
}

async fn worktree(daemon: &TestDaemon, client: &mut KumoClient) -> PathBuf {
    let repo = git_repo(&daemon.home().join("dev/app"), None);
    save_namespace(client, "app", &[&repo]).await;
    // The workspace reads git right after registering, so the main
    // checkout is a known worktree now.
    repo
}

async fn connect(client: &mut KumoClient, id: &str, default: bool) -> pb::AgentProvider {
    let current = providers(client)
        .await
        .into_iter()
        .find(|p| p.id == id)
        .unwrap();
    client
        .agents
        .save_provider(pb::SaveProviderRequest {
            id: id.into(),
            name: current.name,
            program: current.program,
            args: current.args,
            enabled: true,
            is_default: default,
        })
        .await
        .unwrap()
        .into_inner()
}

async fn providers(client: &mut KumoClient) -> Vec<pb::AgentProvider> {
    client
        .agents
        .list_providers(pb::ListProvidersRequest {})
        .await
        .unwrap()
        .into_inner()
        .providers
}

/// Waits for the session to satisfy `ready` in the agents stream.
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
            if let Some(s) = snapshot.sessions.iter().find(|s| s.id == id && ready(s)) {
                return s.clone();
            }
        }
    })
    .await
    .unwrap_or_else(|_| panic!("session {id} never got there"))
}

fn start(worktree: &Path, provider: &str, prompt: &str) -> pb::StartAgentRequest {
    pb::StartAgentRequest {
        provider_id: provider.into(),
        worktree_path: worktree.display().to_string(),
        prompt: prompt.into(),
        ..Default::default()
    }
}

#[tokio::test(flavor = "multi_thread")]
async fn providers_show_what_is_installed_and_keep_settings() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    fake_cli(&daemon.bin(), "claude", "exit 0");

    let list = providers(&mut client).await;
    let claude = list.iter().find(|p| p.id == "claude").unwrap();
    assert!(claude.installed && !claude.enabled && claude.takes_prompt_argument);
    assert_eq!(
        claude.resolved_path,
        daemon.bin().join("claude").display().to_string()
    );
    let codex = list.iter().find(|p| p.id == "codex").unwrap();
    assert!(!codex.installed);
    assert_eq!(codex.install_hint, "npm install -g @openai/codex");
    assert!(list.iter().any(|p| p.id == "copilot") && list.iter().any(|p| p.id == "grok"));

    let saved = connect(&mut client, "claude", false).await;
    assert!(
        saved.enabled && saved.is_default,
        "the first connected agent is the default"
    );
    let version = client
        .agents
        .test_provider(pb::TestProviderRequest {
            id: "claude".into(),
        })
        .await
        .unwrap()
        .into_inner()
        .version;
    assert_eq!(version, "claude 1.0 (fake)");
    let missing = client
        .agents
        .test_provider(pb::TestProviderRequest { id: "codex".into() })
        .await
        .unwrap_err();
    assert_eq!(missing.code(), tonic::Code::FailedPrecondition);

    // A custom agent: any command.
    fake_cli(&daemon.bin(), "my-agent", "exit 0");
    let custom = client
        .agents
        .save_provider(pb::SaveProviderRequest {
            name: "My agent".into(),
            program: "my-agent".into(),
            args: "--task {prompt}".into(),
            enabled: true,
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    assert!(custom.custom && custom.installed && custom.takes_prompt_argument);
    assert_eq!(custom.short, "MA");
    client
        .agents
        .delete_provider(pb::DeleteProviderRequest {
            id: custom.id.clone(),
        })
        .await
        .unwrap();
    assert!(
        !providers(&mut client)
            .await
            .iter()
            .any(|p| p.id == custom.id)
    );

    let builtin = client
        .agents
        .delete_provider(pb::DeleteProviderRequest {
            id: "claude".into(),
        })
        .await
        .unwrap_err();
    assert_eq!(builtin.code(), tonic::Code::InvalidArgument);
    let bad_args = client
        .agents
        .save_provider(pb::SaveProviderRequest {
            id: "claude".into(),
            program: "claude".into(),
            args: "'unclosed".into(),
            enabled: true,
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(bad_args.code(), tonic::Code::InvalidArgument);
}

#[tokio::test(flavor = "multi_thread")]
async fn agent_gets_its_prompt_works_then_waits_and_exits() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = worktree(&daemon, &mut client).await;
    // Prints its arguments and cwd, rings the bell (needs input), echoes a reply.
    fake_cli(
        &daemon.bin(),
        "claude",
        "echo \"claude got: $* in $(pwd)\"; printf 'ready\\a'; read line; echo \"you said: $line\"",
    );
    connect(&mut client, "claude", true).await;

    let session = client
        .agents
        .start(start(&wt, "", "fix the bug"))
        .await
        .unwrap()
        .into_inner();
    assert_eq!(
        (session.provider_id.as_str(), session.title.as_str()),
        ("claude", "fix the bug")
    );

    let waiting = session_where(&mut client, &session.id, |s| {
        s.state() == pb::AgentState::NeedsInput
    })
    .await;
    assert_eq!(waiting.last_line, "ready", "{waiting:?}");

    let mut terminal = Attached::new(&mut client, &session.terminal_id, true).await;
    terminal
        .read_until(&format!("claude got: fix the bug in {}", wt.display()))
        .await;
    terminal.send(b"hi\r").await;
    terminal.read_until("you said: hi").await;

    let done = session_where(&mut client, &session.id, |s| {
        s.state() == pb::AgentState::Exited
    })
    .await;
    assert_eq!(done.exit_code, 0);
    client
        .agents
        .dismiss(pb::DismissAgentRequest {
            id: session.id.clone(),
        })
        .await
        .unwrap();
    let mut stream = client
        .agents
        .watch(pb::WatchAgentsRequest {})
        .await
        .unwrap()
        .into_inner();
    assert!(stream.message().await.unwrap().unwrap().sessions.is_empty());
}

#[tokio::test(flavor = "multi_thread")]
async fn timeline_and_context_follow_what_the_agent_does() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = worktree(&daemon, &mut client).await;
    // Claude Code's tool lines, then its turn ends; what it's sent comes back.
    fake_cli(
        &daemon.bin(),
        "claude",
        "printf '\\342\\217\\272 Bash(make test)\\r\\n\\342\\217\\272 Edit(src/a.rs)\\r\\n\\342\\217\\272 Bash(make test)\\r\\nDone\\a'; read line; echo \"got: $line\"; read again",
    );
    connect(&mut client, "claude", true).await;
    let ticket = pb::AgentContext {
        kind: pb::AgentContextKind::Task.into(),
        title: "PRC-412 · Bulk discounts".into(),
        detail: "Jira".into(),
        url: "https://acme.atlassian.net/browse/PRC-412".into(),
    };
    let session = client
        .agents
        .start(pb::StartAgentRequest {
            context: vec![ticket.clone()],
            ..start(&wt, "", "do PRC-412")
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(session.context, std::slice::from_ref(&ticket));

    let waiting = session_where(&mut client, &session.id, |s| {
        s.state() == pb::AgentState::NeedsInput
    })
    .await;
    let steps: Vec<_> = waiting
        .events
        .iter()
        .map(|e| (e.kind(), e.text.as_str()))
        .collect();
    assert_eq!(
        steps,
        [
            (pb::AgentEventKind::Started, "Claude Code"),
            (pb::AgentEventKind::Context, "PRC-412 · Bulk discounts"),
            (pb::AgentEventKind::Ran, "make test"),
            (pb::AgentEventKind::Edited, "src/a.rs"),
            (pb::AgentEventKind::Waiting, "Done"),
        ],
        "a redrawn line is one step"
    );

    let page = pb::AgentContext {
        kind: pb::AgentContextKind::Doc.into(),
        title: "Discount rules v3".into(),
        detail: "Confluence · Pricing".into(),
        url: String::new(),
    };
    let updated = client
        .agents
        .add_context(pb::AddAgentContextRequest {
            id: session.id.clone(),
            context: Some(page.clone()),
            text: "read /tmp/rules.md".into(),
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(updated.context, [ticket, page]);
    let mut terminal = Attached::new(&mut client, &session.terminal_id, true).await;
    terminal.read_until("got: read /tmp/rules.md").await;
    client
        .agents
        .stop(pb::StopAgentRequest {
            id: session.id.clone(),
        })
        .await
        .unwrap();
    let done = session_where(&mut client, &session.id, |s| {
        s.state() == pb::AgentState::Exited
    })
    .await;
    let last = done.events.last().unwrap();
    assert_eq!(last.kind(), pb::AgentEventKind::Exited);
}

#[tokio::test(flavor = "multi_thread")]
async fn cli_without_a_prompt_flag_gets_it_typed_in() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = worktree(&daemon, &mut client).await;
    fake_cli(
        &daemon.bin(),
        "copilot",
        "printf 'copilot> \\a'; read line; echo \"typed: $line\"",
    );
    connect(&mut client, "copilot", true).await;

    let session = client
        .agents
        .start(start(&wt, "copilot", "add tests"))
        .await
        .unwrap()
        .into_inner();
    let mut terminal = Attached::new(&mut client, &session.terminal_id, true).await;
    terminal.read_until("typed: add tests").await;
    assert_eq!(
        session_where(&mut client, &session.id, |s| s.state()
            == pb::AgentState::Exited)
        .await
        .exit_code,
        0
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn stop_kills_a_running_agent() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = worktree(&daemon, &mut client).await;
    fake_cli(
        &daemon.bin(),
        "gemini",
        "while true; do echo working; sleep 0.2; done",
    );
    connect(&mut client, "gemini", true).await;

    let session = client
        .agents
        .start(start(&wt, "", ""))
        .await
        .unwrap()
        .into_inner();
    assert_eq!(
        session.title, "Gemini CLI",
        "no prompt: titled after the agent"
    );
    session_where(&mut client, &session.id, |s| s.last_line == "working").await;
    client
        .agents
        .stop(pb::StopAgentRequest {
            id: session.id.clone(),
        })
        .await
        .unwrap();
    session_where(&mut client, &session.id, |s| {
        s.state() == pb::AgentState::Exited
    })
    .await;
}

#[tokio::test(flavor = "multi_thread")]
async fn login_runs_the_cli_sign_in_in_a_terminal() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    fake_cli(&daemon.bin(), "codex", "echo \"signing in with: $*\"");

    let terminal = client
        .agents
        .login_provider(pb::LoginProviderRequest { id: "codex".into() })
        .await
        .unwrap()
        .into_inner()
        .terminal_id;
    let mut attached = Attached::new(&mut client, &terminal, true).await;
    attached.read_until("signing in with: login").await;
}

#[tokio::test(flavor = "multi_thread")]
async fn refuses_to_start_without_an_agent_or_outside_the_workspace() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = worktree(&daemon, &mut client).await;

    let none = client.agents.start(start(&wt, "", "x")).await.unwrap_err();
    assert_eq!(
        none.code(),
        tonic::Code::FailedPrecondition,
        "{}",
        none.message()
    );
    assert!(none.message().contains("Settings"), "{}", none.message());

    connect(&mut client, "codex", true).await; // connected but not installed
    let missing = client.agents.start(start(&wt, "", "x")).await.unwrap_err();
    assert_eq!(missing.code(), tonic::Code::FailedPrecondition);
    assert!(
        missing.message().contains("not installed"),
        "{}",
        missing.message()
    );

    fake_cli(&daemon.bin(), "codex", "exit 0");
    let outside = client
        .agents
        .start(start(Path::new("/tmp"), "", "x"))
        .await
        .unwrap_err();
    assert_eq!(outside.code(), tonic::Code::NotFound);
}
