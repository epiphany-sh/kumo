//! Git: how many `git` processes the daemon starts for what happens on disk
//! (performance report 2026-11-14, H1–H4). A repository with a linked
//! worktree, in a namespace, with the changes panel open on it:
//!
//! - a build writing its output to an ignored folder (`target/`), which
//!   doesn't change `git status`;
//! - single edits to a tracked file, which do.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{Duration, Instant};

use anyhow::{Context, bail};
use kumo_grpc::client::KumoClient;
use kumo_grpc::proto as pb;
use tokio_stream::StreamExt;

use crate::daemon_process::GitCounter;

const TRACKED: usize = 200;
/// How long the build writes, and how often.
const BUILD: Duration = Duration::from_secs(10);
const BUILD_TICK: Duration = Duration::from_millis(20);
const FILES_PER_TICK: usize = 10;
const EDITS: usize = 5;
/// Long enough for both watch loops (150 ms and 300 ms settle) to finish.
const QUIET: Duration = Duration::from_millis(1_500);
const TIMEOUT: Duration = Duration::from_secs(10);

pub async fn run(client: &mut KumoClient, trace: PathBuf) -> anyhow::Result<()> {
    let dir = tempfile::tempdir()?;
    let repo = write_repo(&dir.path().join("app"))?;
    let linked = dir.path().join("app-fix");
    git(
        &repo,
        &[
            "worktree",
            "add",
            "-q",
            "-b",
            "fix",
            &linked.display().to_string(),
        ],
    )?;
    println!("\n## git ({TRACKED} tracked files, 2 worktrees, changes panel open)");

    let mut workspace = client
        .workspace
        .watch(pb::WatchWorkspaceRequest {})
        .await?
        .into_inner();
    let namespace = client
        .workspace
        .save_namespace(pb::SaveNamespaceRequest {
            name: "bench".into(),
            repo_paths: vec![repo.display().to_string()],
            ..Default::default()
        })
        .await?
        .into_inner()
        .id;
    tokio::time::timeout(TIMEOUT, async {
        while let Some(snapshot) = workspace.next().await {
            if snapshot?
                .repositories
                .iter()
                .any(|r| r.worktrees.len() == 2)
            {
                return anyhow::Ok(());
            }
        }
        bail!("workspace watch ended")
    })
    .await
    .context("the repository never showed with its worktrees")??;

    // The changes panel, drained on its own so the daemon never waits on us.
    let mut panel = client
        .git
        .watch_status(pb::WatchStatusRequest {
            worktree_path: repo.display().to_string(),
        })
        .await?
        .into_inner();
    panel.next().await.context("no first status")??;
    let updates = Arc::new(AtomicUsize::new(0));
    let drain = {
        let updates = Arc::clone(&updates);
        tokio::spawn(async move {
            while let Some(Ok(_)) = panel.next().await {
                updates.fetch_add(1, Ordering::SeqCst);
            }
        })
    };

    let mut counter = GitCounter::new(trace);
    tokio::time::sleep(QUIET).await;
    counter.take()?;

    // Idle: nothing changes, nothing should run.
    tokio::time::sleep(Duration::from_secs(3)).await;
    report("idle, 3 s", &counter.take()?, None);

    // A build: new and rewritten files under `target/`, all ignored.
    let before = updates.load(Ordering::SeqCst);
    let out = repo.join("target/debug/deps");
    std::fs::create_dir_all(&out)?;
    let started = Instant::now();
    let mut tick = 0usize;
    while started.elapsed() < BUILD {
        for n in 0..FILES_PER_TICK {
            let file = out.join(format!("unit-{}.o", (tick * FILES_PER_TICK + n) % 2_000));
            std::fs::write(file, tick.to_le_bytes())?;
        }
        tick += 1;
        tokio::time::sleep(BUILD_TICK).await;
    }
    tokio::time::sleep(QUIET).await;
    report(
        &format!(
            "build, {} s, {} writes to target/",
            BUILD.as_secs(),
            tick * FILES_PER_TICK
        ),
        &counter.take()?,
        Some(BUILD),
    );
    println!(
        "  changes panel updates during the build: {} (status doesn't change)",
        updates.load(Ordering::SeqCst) - before
    );

    // Edits to a tracked file. Each adds a line, so each changes what the
    // panel shows (it sends only when that changes).
    let mut latencies = Vec::new();
    let mut per_edit = Vec::new();
    for n in 0..EDITS {
        let seen = updates.load(Ordering::SeqCst);
        let started = Instant::now();
        std::fs::write(repo.join("src/file-0.txt"), "edit\n".repeat(n + 2))?;
        tokio::time::timeout(TIMEOUT, async {
            while updates.load(Ordering::SeqCst) == seen {
                tokio::time::sleep(Duration::from_millis(2)).await;
            }
        })
        .await
        .context("the panel never showed the edit")?;
        latencies.push(started.elapsed());
        tokio::time::sleep(QUIET).await;
        per_edit.push(counter.take()?);
    }
    let all: Vec<String> = per_edit.iter().flatten().cloned().collect();
    report(&format!("{EDITS} edits to a tracked file"), &all, None);
    println!(
        "  per edit: {:.1} git processes; edit → panel: {}",
        all.len() as f64 / EDITS as f64,
        latencies
            .iter()
            .map(|d| format!("{:.0} ms", d.as_secs_f64() * 1e3))
            .collect::<Vec<_>>()
            .join(", ")
    );

    drain.abort();
    client
        .workspace
        .delete_namespace(pb::DeleteNamespaceRequest { id: namespace })
        .await?;
    Ok(())
}

fn report(name: &str, commands: &[String], over: Option<Duration>) {
    let mut by_name: BTreeMap<&str, usize> = BTreeMap::new();
    for command in commands {
        *by_name.entry(command).or_default() += 1;
    }
    let rate = over
        .map(|d| format!(" ({:.1}/s)", commands.len() as f64 / d.as_secs_f64()))
        .unwrap_or_default();
    let detail = by_name
        .iter()
        .map(|(name, n)| format!("{name} {n}"))
        .collect::<Vec<_>>()
        .join(", ");
    println!(
        "  {name:<40} {:>5} git processes{rate}  [{detail}]",
        commands.len()
    );
}

/// A repository whose build output is ignored, as in Rust, Node or Flutter.
fn write_repo(dir: &Path) -> anyhow::Result<PathBuf> {
    std::fs::create_dir_all(dir.join("src"))?;
    git(dir, &["init", "-q", "-b", "main"])?;
    git(dir, &["config", "user.email", "bench@kumo.dev"])?;
    git(dir, &["config", "user.name", "Kumo Bench"])?;
    std::fs::write(dir.join(".gitignore"), "target/\nnode_modules/\n")?;
    for n in 0..TRACKED {
        std::fs::write(dir.join(format!("src/file-{n}.txt")), format!("line {n}\n"))?;
    }
    git(dir, &["add", "."])?;
    git(dir, &["commit", "-q", "-m", "init"])?;
    Ok(kumo_infrastructure::platform::canonical(dir))
}

fn git(dir: &Path, args: &[&str]) -> anyhow::Result<()> {
    let out = std::process::Command::new("git")
        .arg("-C")
        .arg(dir)
        .args(args)
        .output()?;
    if !out.status.success() {
        bail!("git {args:?}: {}", String::from_utf8_lossy(&out.stderr));
    }
    Ok(())
}
