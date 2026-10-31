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
            read_usage: None,
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
    // Prints its last argument and cwd, rings the bell (needs input), echoes a reply.
    fake_cli(
        &daemon.bin(),
        "claude",
        "for last; do :; done; echo \"claude got: $last in $(pwd)\"; printf 'ready\\a'; read line; echo \"you said: $line\"",
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

/// What the fake CLI was started with, one argument per line.
fn args_of(bin: &Path, name: &str) -> Vec<String> {
    let path = bin.join(format!("{name}.args"));
    let deadline = std::time::Instant::now() + TIMEOUT;
    loop {
        if let Ok(args) = std::fs::read_to_string(&path)
            && args.ends_with('\n')
        {
            return args.lines().map(str::to_owned).collect();
        }
        assert!(std::time::Instant::now() < deadline, "{name} never started");
        std::thread::sleep(std::time::Duration::from_millis(20));
    }
}

/// A fake CLI that saves its arguments, then echoes what's typed into it.
fn recording_cli(bin: &Path, name: &str, before: &str) {
    let args = bin.join(format!("{name}.args"));
    fake_cli(
        bin,
        name,
        &format!(
            "printf '%s\\n' \"$@\" > '{}'; {before} printf 'ready\\a'; while read line; do echo \"typed: $line\"; done",
            args.display()
        ),
    );
}

async fn usage(client: &mut KumoClient) -> pb::UsageReport {
    client
        .agents
        .usage(pb::UsageRequest {})
        .await
        .unwrap()
        .into_inner()
}

/// Polls `Usage` until `ready`.
async fn usage_where(
    client: &mut KumoClient,
    ready: impl Fn(&pb::UsageReport) -> bool,
) -> pb::UsageReport {
    let deadline = tokio::time::Instant::now() + TIMEOUT;
    loop {
        let report = usage(client).await;
        if ready(&report) {
            return report;
        }
        assert!(
            tokio::time::Instant::now() < deadline,
            "usage never got there: {report:?}"
        );
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    }
}

#[tokio::test(flavor = "multi_thread")]
async fn nothing_read_is_an_empty_usage_report() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    assert_eq!(usage(&mut client).await, pb::UsageReport::default());

    // An agent that reports nothing (Gemini) adds nothing either.
    let wt = worktree(&daemon, &mut client).await;
    recording_cli(&daemon.bin(), "gemini", "");
    connect(&mut client, "gemini", true).await;
    client.agents.start(start(&wt, "", "")).await.unwrap();
    assert!(
        !args_of(&daemon.bin(), "gemini")
            .iter()
            .any(|a| a == "--settings"),
        "only Claude Code gets a status line"
    );
    tokio::time::sleep(std::time::Duration::from_millis(300)).await;
    assert_eq!(usage(&mut client).await, pb::UsageReport::default());
}

#[tokio::test(flavor = "multi_thread")]
async fn claude_code_usage_is_read_through_its_status_line() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = worktree(&daemon, &mut client).await;
    // The user's own status line is kept.
    std::fs::create_dir_all(daemon.home().join(".claude")).unwrap();
    std::fs::write(
        daemon.home().join(".claude/settings.json"),
        r#"{"statusLine":{"type":"command","command":"grep -o Opus"}}"#,
    )
    .unwrap();
    recording_cli(&daemon.bin(), "claude", "");
    let provider = connect(&mut client, "claude", true).await;
    assert!(provider.usage_readable && provider.read_usage);

    let session = client
        .agents
        .start(start(&wt, "", "fix it"))
        .await
        .unwrap()
        .into_inner();
    let args = args_of(&daemon.bin(), "claude");
    assert_eq!(
        (args[0].as_str(), args[2].as_str()),
        ("--settings", "fix it")
    );
    let settings: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(&args[1]).unwrap()).unwrap();
    let hook = settings["statusLine"]["command"].as_str().unwrap();

    // Claude Code runs the status line with the session's JSON.
    let resets = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs()
        + 3600;
    let status = format!(
        r#"{{"model":{{"display_name":"Opus"}},"context_window":{{"total_input_tokens":15500,"context_window_size":200000,"used_percentage":8,"remaining_percentage":92,"current_usage":{{"input_tokens":8500}}}},"rate_limits":{{"five_hour":{{"used_percentage":23.5,"resets_at":{resets}}},"seven_day":{{"used_percentage":41.2,"resets_at":{resets}}}}}}}"#
    );
    let mut line = std::process::Command::new("sh")
        .arg("-c")
        .arg(hook)
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .spawn()
        .unwrap();
    use std::io::Write;
    line.stdin
        .take()
        .unwrap()
        .write_all(status.as_bytes())
        .unwrap();
    let shown = line.wait_with_output().unwrap();
    assert_eq!(String::from_utf8_lossy(&shown.stdout), "Opus\n");

    let report = usage_where(&mut client, |r| !r.sessions.is_empty()).await;
    let plan = &report.plans[0];
    assert_eq!(
        (plan.provider_id.as_str(), plan.plan.as_str()),
        ("claude", "")
    );
    let windows: Vec<_> = plan
        .windows
        .iter()
        .map(|w| (w.short.as_str(), w.left, w.resets_at))
        .collect();
    let resets_ms = i64::try_from(resets).unwrap() * 1000;
    assert_eq!(
        windows,
        [("5h", 76.5, resets_ms), ("wk", 100.0 - 41.2, resets_ms)]
    );
    let used = &report.sessions[0];
    assert_eq!(used.session_id, session.id);
    assert_eq!(
        (
            used.model.as_str(),
            used.context_max,
            used.compact_command.as_str()
        ),
        ("Opus", 200_000, "/compact")
    );
    assert_eq!(used.slices.len(), 1);
    assert_eq!(
        (used.slices[0].kind(), used.slices[0].tokens),
        (pb::ContextSliceKind::ContextSliceTotal, 15_500)
    );

    // Compact types Claude Code's own command.
    let mut terminal = Attached::new(&mut client, &session.terminal_id, true).await;
    client
        .agents
        .compact(pb::CompactAgentRequest {
            id: session.id.clone(),
        })
        .await
        .unwrap();
    terminal.read_until("typed: /compact").await;

    // Dismissed: its folder goes; the plan reading stays (account-wide).
    let dir = std::path::PathBuf::from(&args[1])
        .parent()
        .unwrap()
        .to_owned();
    client
        .agents
        .dismiss(pb::DismissAgentRequest { id: session.id })
        .await
        .unwrap();
    let report = usage_where(&mut client, |r| r.sessions.is_empty()).await;
    assert_eq!(report.plans.len(), 1);
    let deadline = std::time::Instant::now() + TIMEOUT;
    while dir.exists() {
        assert!(std::time::Instant::now() < deadline, "folder kept");
        tokio::time::sleep(std::time::Duration::from_millis(20)).await;
    }
}

#[tokio::test(flavor = "multi_thread")]
async fn turned_off_claude_code_gets_no_status_line() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = worktree(&daemon, &mut client).await;
    recording_cli(&daemon.bin(), "claude", "");
    let current = connect(&mut client, "claude", true).await;
    let off = client
        .agents
        .save_provider(pb::SaveProviderRequest {
            id: "claude".into(),
            name: current.name,
            program: current.program,
            args: current.args,
            enabled: true,
            is_default: true,
            read_usage: Some(false),
        })
        .await
        .unwrap()
        .into_inner();
    assert!(off.usage_readable && !off.read_usage);
    // Saving without the field leaves it as it was.
    let again = connect(&mut client, "claude", true).await;
    assert!(!again.read_usage);

    client.agents.start(start(&wt, "", "x")).await.unwrap();
    assert_eq!(args_of(&daemon.bin(), "claude"), ["x"]);
}

#[tokio::test(flavor = "multi_thread")]
async fn codex_usage_is_read_from_its_rollout_file() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = worktree(&daemon, &mut client).await;
    let sessions = daemon.home().join(".codex/sessions");
    // Writes its rollout as codex-cli does: session_meta, then a turn.
    let token_count = r#"{"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":23823,"cached_input_tokens":21248,"output_tokens":260,"total_tokens":24083},"model_context_window":258400},"rate_limits":{"limit_id":"codex","primary":{"used_percent":25.0,"window_minutes":300,"resets_at":4102444800},"secondary":{"used_percent":4.0,"window_minutes":10080,"resets_at":4102444800},"plan_type":"plus"}}}"#;
    // (Agents get only the fake bin on their PATH.)
    let before = format!(
        "PATH=\"$PATH:/usr/bin:/bin\"; dir='{}'/$(date +%Y/%m/%d); mkdir -p \"$dir\"; f=\"$dir/rollout-test.jsonl\"; \
         now=$(date -u +%Y-%m-%dT%H:%M:%SZ); \
         printf '%s\\n' \"{{\\\"type\\\":\\\"session_meta\\\",\\\"payload\\\":{{\\\"timestamp\\\":\\\"$now\\\",\\\"cwd\\\":\\\"$(pwd)\\\"}}}}\" > \"$f\"; \
         printf '%s\\n' '{{\"type\":\"turn_context\",\"payload\":{{\"model\":\"gpt-6-sol\"}}}}' '{token_count}' >> \"$f\";",
        sessions.display()
    );
    recording_cli(&daemon.bin(), "codex", &before);
    connect(&mut client, "codex", true).await;

    let session = client
        .agents
        .start(start(&wt, "", "go"))
        .await
        .unwrap()
        .into_inner();
    assert_eq!(args_of(&daemon.bin(), "codex"), ["go"]);
    let report = usage_where(&mut client, |r| !r.sessions.is_empty()).await;
    let plan = &report.plans[0];
    assert_eq!(
        (plan.provider_id.as_str(), plan.plan.as_str()),
        ("codex", "ChatGPT Plus")
    );
    let labels: Vec<_> = plan
        .windows
        .iter()
        .map(|w| (w.label.as_str(), w.left))
        .collect();
    assert_eq!(labels, [("5-hour session", 75.0), ("Weekly", 96.0)]);
    let used = &report.sessions[0];
    assert_eq!(
        (used.model.as_str(), used.context_max, used.slices[0].tokens),
        ("gpt-6-sol", 258_400, 24_083)
    );

    let mut terminal = Attached::new(&mut client, &session.terminal_id, true).await;
    client
        .agents
        .compact(pb::CompactAgentRequest { id: session.id })
        .await
        .unwrap();
    terminal.read_until("typed: /compact").await;
}

#[tokio::test(flavor = "multi_thread")]
async fn compact_refuses_agents_without_a_compact_command() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let wt = worktree(&daemon, &mut client).await;
    recording_cli(&daemon.bin(), "copilot", "");
    connect(&mut client, "copilot", true).await;
    let session = client
        .agents
        .start(start(&wt, "", ""))
        .await
        .unwrap()
        .into_inner();
    let refused = client
        .agents
        .compact(pb::CompactAgentRequest { id: session.id })
        .await
        .unwrap_err();
    assert_eq!(
        refused.code(),
        tonic::Code::InvalidArgument,
        "{}",
        refused.message()
    );
    let unknown = client
        .agents
        .compact(pb::CompactAgentRequest { id: "nope".into() })
        .await
        .unwrap_err();
    assert_eq!(unknown.code(), tonic::Code::NotFound);
}
