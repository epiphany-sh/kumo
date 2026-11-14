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
        kumo_infrastructure::platform::canonical(raw.trim())
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

/// Waits for `path` to have something in it (the fake writes it once it
/// starts). The shell creates the file before it writes, so existing is
/// not enough: read too early, it is still empty.
async fn appears(path: &Path) {
    let written = |p: &Path| std::fs::metadata(p).is_ok_and(|m| m.len() > 0);
    tokio::time::timeout(TIMEOUT, async {
        while !written(path) {
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
            title: "TSK-1 · Nowhere".into(),
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
            "--",
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
        index.contains("- Ticket: TSK-1 · Nowhere · couldn’t be read:"),
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
    let scratch = kumo_infrastructure::platform::canonical(s.profile_dir().join("scratch/rev-1"));
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

/// A local repository with a pull request 7, standing in for a host.
fn host_repo(s: &Setup) -> PathBuf {
    let origin = git_repo(&s.daemon.home().join("origin"), None);
    let head = git(&origin, &["rev-parse", "HEAD"]);
    git(&origin, &["update-ref", "refs/pull/7/head", head.trim()]);
    origin
}

/// Git fetches the workspace's repository's `origin` from `host` instead.
fn serve_origin(s: &Setup, host: &Path) {
    git(
        &s.repo,
        &[
            "config",
            &format!("url.{}.insteadOf", host.display()),
            "https://github.com/acme/app.git",
        ],
    );
}

/// Moves pull request 7 forward.
fn push_to_pull(origin: &Path) {
    git(origin, &["commit", "--allow-empty", "-q", "-m", "more"]);
    let head = git(origin, &["rev-parse", "HEAD"]);
    git(origin, &["update-ref", "refs/pull/7/head", head.trim()]);
}

/// A pull request's link is its head, not whatever a branch of that name has.
#[tokio::test(flavor = "multi_thread")]
async fn a_pull_request_runs_at_its_head() {
    use pb::run_agent_def_request::Where;
    let mut s = Setup::new().await;
    let origin = host_repo(&s);
    serve_origin(&s, &origin);
    let link = "https://github.com/acme/app/pull/7";
    let agent = personal("rev");
    s.client
        .agent_defs
        .run(run(agent.clone(), Where::LinkUrl(link.into()), ""))
        .await
        .unwrap();
    appears(&s.log.join("run.cwd")).await;
    let first = s.cwd("run");
    let head = |dir: &Path| git(dir, &["rev-parse", "HEAD"]).trim().to_owned();
    assert_eq!(head(&first), head(&origin));

    // Same head: the same worktree. A new one once the head moved.
    std::fs::remove_file(s.log.join("run.cwd")).unwrap();
    s.client
        .agent_defs
        .run(run(agent.clone(), Where::LinkUrl(link.into()), ""))
        .await
        .unwrap();
    appears(&s.log.join("run.cwd")).await;
    assert_eq!(s.cwd("run"), first);

    push_to_pull(&origin);
    std::fs::remove_file(s.log.join("run.cwd")).unwrap();
    s.client
        .agent_defs
        .run(run(agent, Where::LinkUrl(link.into()), ""))
        .await
        .unwrap();
    appears(&s.log.join("run.cwd")).await;
    let moved = s.cwd("run");
    assert_ne!(moved, first);
    assert_eq!(head(&moved), head(&origin));
}

/// A second run on a link outside the workspace leaves the first one's files.
#[tokio::test(flavor = "multi_thread")]
async fn a_second_run_on_a_link_leaves_the_first_ones_worktree() {
    use pb::run_agent_def_request::Where;
    let mut s = Setup::new().await;
    // Already cloned: only fetching from it is left.
    let origin = host_repo(&s);
    let clone = s.profile_dir().join("clones/host.example/acme/other");
    std::fs::create_dir_all(clone.parent().unwrap()).unwrap();
    git(
        &s.daemon.home(),
        &[
            "clone",
            "-q",
            &origin.display().to_string(),
            &clone.display().to_string(),
        ],
    );
    let link = "https://host.example/acme/other/pull/7";
    let agent = personal("rev");
    s.client
        .agent_defs
        .run(run(agent.clone(), Where::LinkUrl(link.into()), ""))
        .await
        .unwrap();
    appears(&s.log.join("run.cwd")).await;
    let first = s.cwd("run");
    let work = first.join("uncommitted.txt");
    std::fs::write(&work, "work").unwrap();

    std::fs::remove_file(s.log.join("run.cwd")).unwrap();
    s.client
        .agent_defs
        .run(run(agent, Where::LinkUrl(link.into()), ""))
        .await
        .unwrap();
    appears(&s.log.join("run.cwd")).await;
    assert_ne!(s.cwd("run"), first);
    assert_eq!(std::fs::read_to_string(&work).unwrap(), "work");
}

/// A pull request of another repository isn't the same number of this one.
#[tokio::test(flavor = "multi_thread")]
async fn a_linked_pull_request_is_read_from_its_own_repository() {
    use pb::run_agent_def_request::Where;
    let mut s = Setup::new().await;
    let item = |url: &str| pb::AgentContext {
        kind: pb::AgentContextKind::PullRequest.into(),
        title: "#7".into(),
        url: url.into(),
        ..Default::default()
    };
    // Running here, handed one of a repository it isn't: it says it couldn't.
    let origin = host_repo(&s);
    let other = "https://host.example/acme/other/pull/7";
    let mut here = run(
        personal("rev"),
        Where::WorktreePath(s.repo.display().to_string()),
        "",
    );
    here.context = vec![item(other)];
    let session = s.client.agent_defs.run(here).await.unwrap().into_inner();
    let context = PathBuf::from(&session.context_dir);
    assert!(!context.join("pr-7.diff").exists());
    let index = std::fs::read_to_string(context.join("context.md")).unwrap();
    assert!(index.contains("couldn’t be read"), "{index}");

    // Running on its link: read from the clone.
    let clone = s.profile_dir().join("clones/host.example/acme/other");
    std::fs::create_dir_all(clone.parent().unwrap()).unwrap();
    git(
        &s.daemon.home(),
        &[
            "clone",
            "-q",
            &origin.display().to_string(),
            &clone.display().to_string(),
        ],
    );
    let url = "https://host.example/acme/other.git";
    git(&clone, &["remote", "set-url", "origin", url]);
    git(
        &clone,
        &[
            "config",
            &format!("url.{}.insteadOf", origin.display()),
            url,
        ],
    );
    // The default branch moved on after the clone, and the pull request
    // came from there: what's on it isn't the pull request's.
    let main = git(&origin, &["rev-parse", "--abbrev-ref", "HEAD"]);
    std::fs::write(origin.join("on_main.txt"), "later\n").unwrap();
    git(&origin, &["add", "."]);
    git(&origin, &["commit", "-q", "-m", "on main"]);
    git(&origin, &["checkout", "-q", "-b", "feature"]);
    std::fs::write(origin.join("in_the_pr.txt"), "mine\n").unwrap();
    git(&origin, &["add", "."]);
    git(&origin, &["commit", "-q", "-m", "the change"]);
    let head = git(&origin, &["rev-parse", "HEAD"]);
    git(&origin, &["update-ref", "refs/pull/7/head", head.trim()]);
    git(&origin, &["checkout", "-q", main.trim()]);
    let mut linked = run(personal("rev"), Where::LinkUrl(other.into()), "");
    linked.context = vec![item(other)];
    let session = s.client.agent_defs.run(linked).await.unwrap().into_inner();
    let context = PathBuf::from(&session.context_dir);
    let diff = std::fs::read_to_string(context.join("pr-7.diff")).unwrap();
    assert!(diff.contains("in_the_pr.txt"), "{diff}");
    assert!(!diff.contains("on_main.txt"), "{diff}");
    // No host to ask here: the agent is told, not left guessing.
    let about = std::fs::read_to_string(context.join("pr-7.md")).unwrap();
    assert!(about.contains("couldn't be read"), "{about}");
}

fn alive(pid: &str) -> bool {
    std::process::Command::new("/bin/kill")
        .args(["-0", pid.trim()])
        .output()
        .unwrap()
        .status
        .success()
}

/// Stop ends what the agent started, like Claude Code's tools: they run in
/// process groups of their own, which killing the agent doesn't reach.
#[tokio::test(flavor = "multi_thread")]
async fn stopping_an_agent_ends_its_tools() {
    use pb::run_agent_def_request::Where;
    let mut s = Setup::new().await;
    let pid_file = s.daemon.home().join("tool.pid");
    std::fs::write(
        s.daemon.bin().join("claude"),
        format!(
            "#!/bin/sh\nif [ \"$1\" = \"--version\" ]; then echo \"2.1.0 (Claude Code)\"; exit 0; fi\nif [ \"$1\" = \"--help\" ]; then echo '  --max-budget-usd <amount>'; exit 0; fi\nset -m\n/bin/sleep 300 &\necho $! > '{}'\nwait\n",
            pid_file.display()
        ),
    )
    .unwrap();
    let session = s
        .client
        .agent_defs
        .run(run(
            personal("rev"),
            Where::WorktreePath(s.repo.display().to_string()),
            "",
        ))
        .await
        .unwrap()
        .into_inner();
    appears(&pid_file).await;
    tokio::time::sleep(std::time::Duration::from_millis(200)).await;
    let tool = std::fs::read_to_string(&pid_file).unwrap();
    assert!(alive(&tool));
    s.client
        .agents
        .stop(pb::StopAgentRequest {
            id: session.id.clone(),
        })
        .await
        .unwrap();
    let ended = session_where(&mut s.client, &session.id, |x| {
        x.state == pb::AgentState::Exited as i32
    })
    .await;
    assert_eq!(ended.exit_code, 130);
    tokio::time::sleep(std::time::Duration::from_millis(300)).await;
    assert!(!alive(&tool), "its tool is still running");
}

/// Stopping a test run isn't its failing.
#[tokio::test(flavor = "multi_thread")]
async fn a_stopped_test_run_ends_with_130_and_no_failure() {
    let mut s = Setup::new().await;
    let path = s.daemon.bin().join("claude");
    std::fs::write(
        &path,
        "#!/bin/sh\nif [ \"$1\" = \"--version\" ]; then echo \"2.1.0 (Claude Code)\"; exit 0; fi\nif [ \"$1\" = \"--help\" ]; then echo '  --max-budget-usd <amount>'; exit 0; fi\necho '{\"type\":\"system\",\"subtype\":\"init\"}'\nexec /bin/sleep 30\n",
    )
    .unwrap();
    let mut stream = s
        .client
        .agent_defs
        .play(pb::PlayRequest {
            name: "rev".into(),
            agent: Some(personal("rev")),
            inline_json: r#"{"rev":{}}"#.into(),
            task: "go".into(),
            worktree_path: s.repo.display().to_string(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    let first = stream.message().await.unwrap().unwrap();
    s.client
        .agent_defs
        .stop_play(pb::StopPlayRequest {
            play_id: first.play_id.clone(),
        })
        .await
        .unwrap();
    let mut failed = false;
    let mut exit = None;
    while let Some(event) = tokio::time::timeout(TIMEOUT, stream.message())
        .await
        .unwrap()
        .unwrap()
    {
        match event.kind {
            Some(pb::play_event::Kind::Line(line)) => failed |= line.contains("is_error"),
            Some(pb::play_event::Kind::Exited(code)) => exit = Some(code),
            _ => {}
        }
    }
    assert!(!failed);
    assert_eq!(exit, Some(130));
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
    // A minute lasts 300 ms in tests: 3 s, so it gets to ask first (starting
    // up counts as working).
    let agent = pb::AgentDefFile {
        settings: Some(pb::AgentDefSettings {
            max_minutes: Some(10),
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

    // Past its whole limit, waiting.
    tokio::time::sleep(std::time::Duration::from_millis(4000)).await;
    let waiting = session_where(&mut s.client, &session.id, |_| true).await;
    assert_eq!(waiting.state(), pb::AgentState::NeedsInput, "{waiting:?}");

    let terminal = Attached::new(&mut s.client, &session.terminal_id, false).await;
    terminal.send(b"yes\r").await;
    let ended = session_where(&mut s.client, &session.id, |x| {
        x.state == pb::AgentState::Exited as i32
    })
    .await;
    assert_eq!(ended.exit_code, 124);
    assert!(ended.worked_ms >= 2500, "{ended:?}");
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
async fn runs_say_the_cli_they_ran_on_and_refuse_one_that_cant_run_agents() {
    let mut s = Setup::new().await;
    let owner = save(&mut s.client, personal("rev"), None).await;
    let request = pb::PlayRequest {
        name: "rev".into(),
        inline_json: r#"{"rev":{}}"#.into(),
        task: "Review #521".into(),
        worktree_path: s.repo.display().to_string(),
        agent: Some(owner.clone()),
        ..Default::default()
    };

    // Naming the default is the same as not naming one.
    play(&mut s.client, request.clone()).await;
    play(
        &mut s.client,
        pb::PlayRequest {
            provider_id: "claude".into(),
            ..request.clone()
        },
    )
    .await;
    let kept = s
        .client
        .agent_defs
        .list_plays(pb::ListPlaysRequest {
            agent: Some(owner.clone()),
        })
        .await
        .unwrap()
        .into_inner()
        .plays;
    assert_eq!(kept.len(), 2);
    assert!(kept.iter().all(|p| p.provider_id == "claude"), "{kept:?}");
    assert_eq!(s.logged("play")[..2], ["-p", "--agents"]);

    let refused = s
        .client
        .agent_defs
        .play(pb::PlayRequest {
            provider_id: "not-a-cli".into(),
            ..request
        })
        .await
        .unwrap_err();
    assert_eq!(refused.code(), Code::InvalidArgument);
    let refused = s
        .client
        .agent_defs
        .run(pb::RunAgentDefRequest {
            provider_id: "not-a-cli".into(),
            ..run(owner, pb::run_agent_def_request::Where::Scratch(true), "go")
        })
        .await
        .unwrap_err();
    assert_eq!(refused.code(), Code::InvalidArgument);
    assert!(
        !s.profile_dir().join("scratch").exists(),
        "refused before doing anything"
    );
}

#[tokio::test(flavor = "multi_thread")]
async fn ask_goes_to_the_cli_it_names() {
    let mut s = Setup::with_codex().await;
    let answer = s
        .client
        .agent_defs
        .ask(pb::AskRequest {
            prompt: "Write a subagent".into(),
            provider_id: "codex".into(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner()
        .text;
    assert!(answer.contains("PONG"), "{answer}");
    assert_eq!(
        s.logged("codex-play"),
        [
            "exec",
            "--skip-git-repo-check",
            "-s",
            "read-only",
            "-c",
            "approval_policy=\"never\"",
            "--",
            "Write a subagent"
        ]
    );
    assert!(!s.log.join("ask.args").exists(), "Claude Code wasn't asked");

    let refused = s
        .client
        .agent_defs
        .ask(pb::AskRequest {
            prompt: "Write a subagent".into(),
            provider_id: "gemini".into(),
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(refused.code(), Code::InvalidArgument);
}

#[tokio::test(flavor = "multi_thread")]
async fn ask_answers_in_plan_mode() {
    let mut s = Setup::new().await;
    let answer = s
        .client
        .agent_defs
        .ask(pb::AskRequest {
            prompt: "Write a subagent".into(),
            cwd: String::new(),
            ..Default::default()
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

/// A fake Codex CLI. `exec` prints JSONL (or fails when `<log>/codex-fail`
/// exists); otherwise it says "ready" and waits. Each call writes its
/// arguments and folder to `<log>/codex-<run|play>.{args,cwd}`.
fn fake_codex(bin: &Path, log: &Path) {
    let log = log.display();
    let script = format!(
        r#"#!/bin/sh
kind=run
if [ "$1" = "exec" ]; then kind=play; fi
: > "{log}/codex-$kind.args"
for a in "$@"; do printf '%s\n' "$a" >> "{log}/codex-$kind.args"; done
pwd > "{log}/codex-$kind.cwd"
if [ "$kind" = play ]; then
  if [ -f "{log}/codex-fail" ]; then echo "Error: not signed in" >&2; exit 1; fi
  echo '{{"type":"thread.started","thread_id":"t1"}}'
  echo '{{"type":"item.completed","item":{{"id":"item_0","type":"agent_message","text":"PONG"}}}}'
  echo '{{"type":"turn.completed","usage":{{"input_tokens":10,"cached_input_tokens":0,"output_tokens":2}}}}'
  exit 0
fi
echo ready
while read line; do :; done
"#
    );
    let path = bin.join("codex");
    std::fs::write(&path, script).unwrap();
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
}

/// A fake GitHub Copilot CLI. With `--prompt=` it prints JSONL (or fails
/// when `<log>/copilot-fail` exists); otherwise it says "ready" and waits.
/// Each call writes its arguments and folder to
/// `<log>/copilot-<run|play>.{args,cwd}`, and the agent file `--agent` named
/// in the first `--add-dir` to `<log>/copilot-<run|play>.agent`, as Copilot
/// would read it.
fn fake_copilot(bin: &Path, log: &Path) {
    let log = log.display();
    let script = format!(
        r#"#!/bin/sh
kind=run; agent=; dir=; prev=
for a in "$@"; do
  case "$a" in --prompt=*) kind=play;; esac
  if [ "$prev" = --agent ]; then agent="$a"; fi
  if [ "$prev" = --add-dir ] && [ -z "$dir" ]; then dir="$a"; fi
  prev="$a"
done
: > "{log}/copilot-$kind.args"
for a in "$@"; do printf '%s\n' "$a" >> "{log}/copilot-$kind.args"; done
f="$dir/.github/agents/$agent.agent.md"
: > "{log}/copilot-$kind.agent"
if [ -f "$f" ]; then while IFS= read -r l; do printf '%s\n' "$l"; done < "$f" > "{log}/copilot-$kind.agent"; fi
pwd > "{log}/copilot-$kind.cwd"
if [ "$kind" = play ]; then
  if [ -f "{log}/copilot-fail" ]; then echo 'Error: Model "x" from --model flag is not available.' >&2; exit 1; fi
  echo '{{"type":"assistant.message","data":{{"content":"PONG","toolRequests":[]}}}}'
  echo '{{"type":"result","exitCode":0,"usage":{{"premiumRequests":1}}}}'
  exit 0
fi
echo ready
while read line; do :; done
"#
    );
    let path = bin.join("copilot");
    std::fs::write(&path, script).unwrap();
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
}

/// The agent as the UI sends it with every run (`agentInlineJson`).
const REV_JSON: &str = r#"{"rev":{"description":"Reviews things. Use it when asked.","prompt":"You review.","tools":["Read"],"model":"sonnet"}}"#;

impl Setup {
    /// Codex connected too, faked.
    async fn with_codex() -> Self {
        let mut s = Self::new().await;
        fake_codex(&s.daemon.bin(), &s.log);
        s.client
            .agents
            .save_provider(pb::SaveProviderRequest {
                id: "codex".into(),
                name: "Codex CLI".into(),
                program: "codex".into(),
                enabled: true,
                ..Default::default()
            })
            .await
            .unwrap();
        s
    }

    /// GitHub Copilot CLI connected too, faked.
    async fn with_copilot() -> Self {
        let mut s = Self::new().await;
        fake_copilot(&s.daemon.bin(), &s.log);
        s.client
            .agents
            .save_provider(pb::SaveProviderRequest {
                id: "copilot".into(),
                name: "GitHub Copilot CLI".into(),
                program: "copilot".into(),
                enabled: true,
                ..Default::default()
            })
            .await
            .unwrap();
        s
    }

    fn copilot_logged(&self, what: &str) -> Vec<String> {
        std::fs::read_to_string(self.log.join(format!("copilot-{what}.args")))
            .unwrap()
            .lines()
            .map(str::to_owned)
            .collect()
    }

    fn codex_logged(&self, what: &str) -> Vec<String> {
        std::fs::read_to_string(self.log.join(format!("codex-{what}.args")))
            .unwrap()
            .lines()
            .map(str::to_owned)
            .collect()
    }
}

/// `-c key=value` pairs and plain flags, as one list to look things up in.
fn has_pair(args: &[String], a: &str, b: &str) -> bool {
    args.windows(2).any(|w| w[0] == a && w[1] == b)
}

#[tokio::test(flavor = "multi_thread")]
async fn an_agent_runs_on_codex_read_only_and_with_nothing_of_the_users() {
    use pb::run_agent_def_request::Where;
    let mut s = Setup::with_codex().await;
    let agent = save(&mut s.client, personal("rev"), None).await;
    let session = s
        .client
        .agent_defs
        .run(pb::RunAgentDefRequest {
            provider_id: "codex".into(),
            inline_json: REV_JSON.into(),
            ..run(
                agent.clone(),
                Where::WorktreePath(s.repo.display().to_string()),
                "-review the branch",
            )
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(session.provider_id, "codex");
    assert_eq!(session.agent_name, "rev");
    appears(&s.log.join("codex-run.cwd")).await;
    let args = s.codex_logged("run");
    assert!(has_pair(&args, "-s", "read-only"), "{args:#?}");
    for config in [
        "approval_policy=\"never\"",
        "mcp_servers={}",
        "features.apps=false",
        "features.plugins=false",
        "skills.include_instructions=false",
        "web_search=\"disabled\"",
        "model_reasoning_effort=\"medium\"",
    ] {
        assert!(has_pair(&args, "-c", config), "{config} in {args:#?}");
    }
    assert!(
        args.iter().any(|a| a.starts_with(
            "developer_instructions=\"You review.\\n\\nYou are running as the agent `rev`."
        )),
        "{args:#?}"
    );
    assert!(
        !args
            .iter()
            .any(|a| a == "--agent" || a == "--add-dir" || a == "-m")
    );
    assert_eq!(&args[args.len() - 2..], ["--", "-review the branch"]);
    assert_eq!(
        s.cwd("codex-run"),
        kumo_infrastructure::platform::canonical(&s.repo)
    );
    s.client
        .agents
        .stop(pb::StopAgentRequest { id: session.id })
        .await
        .unwrap();

    // Without the agent's definition Codex has nothing to run: refused
    // before a scratch folder is made.
    let refused = s
        .client
        .agent_defs
        .run(pb::RunAgentDefRequest {
            provider_id: "codex".into(),
            ..run(agent, Where::Scratch(true), "go")
        })
        .await
        .unwrap_err();
    assert_eq!(refused.code(), Code::InvalidArgument, "{refused:?}");
    assert!(!s.profile_dir().join("scratch").exists());
}

#[tokio::test(flavor = "multi_thread")]
async fn a_test_run_on_codex_streams_its_events_and_keeps_its_cli() {
    use pb::play_event::Kind;
    let mut s = Setup::with_codex().await;
    let owner = save(&mut s.client, personal("rev"), None).await;
    let request = pb::PlayRequest {
        provider_id: "codex".into(),
        name: "rev".into(),
        inline_json: REV_JSON.into(),
        task: "Review #521".into(),
        worktree_path: s.repo.display().to_string(),
        max_turns: Some(8),
        max_cost_usd: Some(0.5),
        agent: Some(owner.clone()),
        ..Default::default()
    };
    let events = play(&mut s.client, request.clone()).await;
    let kinds: Vec<_> = events.iter().filter_map(|e| e.kind.as_ref()).collect();
    assert_eq!(kinds.len(), 4, "{kinds:#?}");
    assert_eq!(kinds.last(), Some(&&Kind::Exited(0)));
    let args = s.codex_logged("play");
    assert_eq!(args[..2], ["exec", "--json"]);
    assert!(
        has_pair(&args, "-c", "approval_policy=\"never\""),
        "{args:#?}"
    );
    assert!(
        !args
            .iter()
            .any(|a| a.contains("max-turns") || a.contains("budget"))
    );
    assert_eq!(&args[args.len() - 2..], ["--", "Review #521"]);

    // A failure without a result line comes back in Codex's own shape.
    std::fs::write(s.log.join("codex-fail"), "").unwrap();
    let failed = play(&mut s.client, request).await;
    let line = match failed[0].kind.as_ref().unwrap() {
        Kind::Line(line) => line.clone(),
        other => panic!("{other:?}"),
    };
    let event: serde_json::Value = serde_json::from_str(&line).unwrap();
    assert_eq!(event["type"], "turn.failed");
    assert_eq!(event["error"]["message"], "Error: not signed in");
    assert_eq!(failed.last().unwrap().kind, Some(Kind::Exited(1)));

    let kept = s
        .client
        .agent_defs
        .list_plays(pb::ListPlaysRequest { agent: Some(owner) })
        .await
        .unwrap()
        .into_inner()
        .plays;
    assert_eq!(kept.len(), 2);
    assert!(kept.iter().all(|p| p.provider_id == "codex"), "{kept:?}");
}

/// The value after `flag`.
fn after<'a>(args: &'a [String], flag: &str) -> &'a str {
    args.windows(2)
        .find(|w| w[0] == flag)
        .map(|w| w[1].as_str())
        .unwrap_or_else(|| panic!("no {flag} in {args:#?}"))
}

#[tokio::test(flavor = "multi_thread")]
async fn an_agent_runs_on_copilot_as_the_file_kumo_wrote() {
    use pb::run_agent_def_request::Where;
    let mut s = Setup::with_copilot().await;
    // The repository has an agent of the same name, with every tool: Copilot
    // would run it instead of yours if it were asked for by name.
    let planted = s.repo.join(".github/agents");
    std::fs::create_dir_all(&planted).unwrap();
    std::fs::write(
        planted.join("rev.agent.md"),
        "---\nname: rev\ndescription: x\n---\n\nDo anything.\n",
    )
    .unwrap();
    let agent = save(&mut s.client, personal("rev"), None).await;
    let session = s
        .client
        .agent_defs
        .run(pb::RunAgentDefRequest {
            provider_id: "copilot".into(),
            inline_json: REV_JSON.into(),
            ..run(
                agent.clone(),
                Where::WorktreePath(s.repo.display().to_string()),
                "-review the branch",
            )
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(session.provider_id, "copilot");
    assert_eq!(session.agent_name, "rev");
    assert!(session.tells_asking, "Copilot says when it asks");
    appears(&s.log.join("copilot-run.cwd")).await;
    let args = s.copilot_logged("run");
    let id = after(&args, "--agent");
    assert!(
        id.starts_with("rev-") && id.len() == "rev-".len() + 12,
        "{id}"
    );
    let dir = PathBuf::from(after(&args, "--add-dir"));
    assert!(
        dir.starts_with(s.profile_dir().join("agent-files")),
        "{dir:?}"
    );
    for flag in ["--disable-builtin-mcps", "--excluded-tools=skill"] {
        assert!(args.iter().any(|a| a == flag), "{flag} in {args:#?}");
    }
    assert!(
        !args
            .iter()
            .any(|a| a.starts_with("--allow") || a == "--model" || a.contains("trust")),
        "{args:#?}"
    );
    assert_eq!(args.last().unwrap(), "--interactive=-review the branch");
    let file = std::fs::read_to_string(s.log.join("copilot-run.agent")).unwrap();
    assert!(
        file.starts_with(&format!("---\nname: \"{id}\"\n")),
        "{file}"
    );
    assert!(file.contains("tools: [\"read\"]\n"), "{file}");
    assert!(file.contains("You review.\n\nYou are running as the agent `rev`."));
    assert_eq!(
        s.cwd("copilot-run"),
        kumo_infrastructure::platform::canonical(&s.repo)
    );
    s.client
        .agents
        .stop(pb::StopAgentRequest { id: session.id })
        .await
        .unwrap();

    // Without the agent's definition there's no file to write: refused
    // before a scratch folder is made.
    let refused = s
        .client
        .agent_defs
        .run(pb::RunAgentDefRequest {
            provider_id: "copilot".into(),
            ..run(agent, Where::Scratch(true), "go")
        })
        .await
        .unwrap_err();
    assert_eq!(refused.code(), Code::InvalidArgument, "{refused:?}");
    assert!(!s.profile_dir().join("scratch").exists());
}

#[tokio::test(flavor = "multi_thread")]
async fn a_test_run_on_copilot_streams_its_events_and_leaves_no_file() {
    use pb::play_event::Kind;
    let mut s = Setup::with_copilot().await;
    let owner = save(&mut s.client, personal("rev"), None).await;
    let request = pb::PlayRequest {
        provider_id: "copilot".into(),
        name: "rev".into(),
        inline_json: REV_JSON.into(),
        task: "Review #521".into(),
        worktree_path: s.repo.display().to_string(),
        max_turns: Some(8),
        max_cost_usd: Some(0.5),
        agent: Some(owner.clone()),
        ..Default::default()
    };
    let events = play(&mut s.client, request.clone()).await;
    let kinds: Vec<_> = events.iter().filter_map(|e| e.kind.as_ref()).collect();
    assert_eq!(kinds.len(), 3, "{kinds:#?}");
    assert_eq!(kinds.last(), Some(&&Kind::Exited(0)));
    let args = s.copilot_logged("play");
    assert_eq!(args[0], "--prompt=Review #521");
    assert_eq!(after(&args, "--output-format"), "json");
    assert!(args.iter().any(|a| a == "--no-ask-user"));
    assert!(
        !args
            .iter()
            .any(|a| a.starts_with("--allow") || a.contains("max-turns") || a.contains("credits")),
        "{args:#?}"
    );
    let file = std::fs::read_to_string(s.log.join("copilot-play.agent")).unwrap();
    assert!(file.contains("You review."), "{file}");
    // Read when it started, removed when it ended.
    let dir = PathBuf::from(after(&args, "--add-dir"));
    assert!(!dir.exists(), "{dir:?}");

    // A failure without a result line comes back in Copilot's own shape.
    std::fs::write(s.log.join("copilot-fail"), "").unwrap();
    let failed = play(&mut s.client, request).await;
    let line = match failed[0].kind.as_ref().unwrap() {
        Kind::Line(line) => line.clone(),
        other => panic!("{other:?}"),
    };
    let event: serde_json::Value = serde_json::from_str(&line).unwrap();
    assert_eq!(event["type"], "result");
    assert_eq!(
        event["error"]["message"],
        "Error: Model \"x\" from --model flag is not available."
    );
    assert_eq!(failed.last().unwrap().kind, Some(Kind::Exited(1)));

    let kept = s
        .client
        .agent_defs
        .list_plays(pb::ListPlaysRequest { agent: Some(owner) })
        .await
        .unwrap()
        .into_inner()
        .plays;
    assert_eq!(kept.len(), 2);
    assert!(kept.iter().all(|p| p.provider_id == "copilot"), "{kept:?}");
}
