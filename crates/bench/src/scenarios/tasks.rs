//! Tasks: budget ≤ 50 ms to list and filter 10,000 tasks from the local
//! cache (kumo.md §4, M4). Uses an Obsidian vault on disk, so nothing here
//! touches the network.

use std::collections::HashMap;
use std::path::Path;
use std::time::{Duration, Instant};

use kumo_domain::tasks::{SourceId, SourceOptions, TaskFilter, TaskSource, TaskStatus, TaskStore};
use kumo_grpc::client::KumoClient;
use kumo_grpc::proto as pb;
use kumo_infrastructure::storage::SqliteTaskStore;
use tokio_stream::StreamExt;

use crate::report;

const NOTES: usize = 500;
const PER_NOTE: usize = 20;
const TOTAL: usize = NOTES * PER_NOTE;
const BUDGET: Duration = Duration::from_millis(50);

pub async fn run(client: &mut KumoClient) -> anyhow::Result<()> {
    let dir = tempfile::tempdir()?;
    let vault = dir.path().join("Vault");
    write_vault(&vault)?;
    println!("\n## tasks ({TOTAL} tasks in {NOTES} notes)");

    // Adding the source: scan, parse, cache and push.
    let mut first = client
        .tasks
        .watch(pb::WatchTasksRequest {})
        .await?
        .into_inner();
    first.next().await;
    let started = Instant::now();
    let source = client
        .tasks
        .save_source(pb::SaveSourceRequest {
            kind: pb::TaskSourceKind::Obsidian.into(),
            options: HashMap::from([("vault".to_owned(), vault.display().to_string())]),
            enabled: true,
            ..Default::default()
        })
        .await?
        .into_inner();
    let mut held = 0;
    while held < TOTAL {
        let update = first
            .next()
            .await
            .ok_or_else(|| anyhow::anyhow!("watch ended"))??;
        if let Some(list) = update.changed.iter().find(|c| c.source_id == source.id) {
            held = list.tasks.len();
        }
    }
    println!(
        "  first read of the vault (scan + parse + cache + push): {:.1} ms",
        ms(started.elapsed())
    );

    // Opening the Tasks view: the whole board from the daemon's memory.
    let mut open = report::latency_histogram();
    for _ in 0..20 {
        let started = Instant::now();
        let mut stream = client
            .tasks
            .watch(pb::WatchTasksRequest {})
            .await?
            .into_inner();
        let update = stream
            .next()
            .await
            .ok_or_else(|| anyhow::anyhow!("watch ended"))??;
        anyhow::ensure!(update.changed.iter().map(|c| c.tasks.len()).sum::<usize>() == TOTAL);
        report::record(&mut open, started.elapsed());
    }
    report::print_latency("open the board over gRPC (10k tasks)", &open, Some(BUDGET));

    // A note edited elsewhere: re-read (only that file) and pushed.
    let note = vault.join("Area 3/Note 123.md");
    let mut text = std::fs::read_to_string(&note)?;
    text.push_str("- [ ] One more\n");
    let started = Instant::now();
    std::fs::write(&note, text)?;
    loop {
        let update = first
            .next()
            .await
            .ok_or_else(|| anyhow::anyhow!("watch ended"))??;
        if update.changed.iter().any(|c| c.tasks.len() == TOTAL + 1) {
            break;
        }
    }
    println!(
        "  edit pushed (includes the 150 ms settle for bursts): {:.1} ms",
        ms(started.elapsed())
    );

    // The cache itself: daemon start serves from it.
    let store = SqliteTaskStore::open(&dir.path().join("bench.db"))?;
    let id = SourceId::parse("bench")?;
    store.save_source(&TaskSource {
        id: id.clone(),
        name: "Bench".into(),
        options: SourceOptions::Obsidian {
            vault: vault.clone(),
        },
        enabled: true,
    })?;
    let mut stream = client
        .tasks
        .watch(pb::WatchTasksRequest {})
        .await?
        .into_inner();
    let board = stream
        .next()
        .await
        .ok_or_else(|| anyhow::anyhow!("watch ended"))??;
    let tasks = to_domain(&id, &board);
    store.replace_tasks(&id, &tasks)?;
    let mut load = report::latency_histogram();
    for _ in 0..20 {
        let started = Instant::now();
        anyhow::ensure!(store.tasks(&id)?.len() == tasks.len());
        report::record(&mut load, started.elapsed());
    }
    report::print_latency("load 10k tasks from SQLite", &load, Some(BUDGET));

    let mut filter = report::latency_histogram();
    let filters = [
        TaskFilter::new("deploy"),
        TaskFilter::new("kafka area"),
        TaskFilter::new("").with_status([TaskStatus::Done]),
        TaskFilter::new("ñandú"),
    ];
    for _ in 0..50 {
        for f in &filters {
            let started = Instant::now();
            std::hint::black_box(f.apply(&tasks).count());
            report::record(&mut filter, started.elapsed());
        }
    }
    report::print_latency("filter 10k tasks (text + status)", &filter, Some(BUDGET));

    client
        .tasks
        .delete_source(pb::DeleteSourceRequest { id: source.id })
        .await?;
    Ok(())
}

fn write_vault(vault: &Path) -> anyhow::Result<()> {
    let words = [
        "deploy", "kafka", "pricing", "review", "rotate", "invoice", "migrate", "cache",
    ];
    for n in 0..NOTES {
        let folder = vault.join(format!("Area {}", n % 10));
        std::fs::create_dir_all(&folder)?;
        let mut text = format!("# Note {n}\n\nSome prose before the tasks.\n\n");
        for i in 0..PER_NOTE {
            let mark = if i % 4 == 0 { 'x' } else { ' ' };
            let word = words[(n + i) % words.len()];
            text.push_str(&format!(
                "- [{mark}] {word} item {n}-{i} for the area 📅 2026-11-{:02} #tag{}\n",
                1 + i % 28,
                i % 5
            ));
        }
        std::fs::write(folder.join(format!("Note {n}.md")), text)?;
    }
    Ok(())
}

fn to_domain(id: &SourceId, update: &pb::TasksUpdate) -> Vec<kumo_domain::tasks::Task> {
    use kumo_domain::tasks::{Priority, Task, TaskId};
    update
        .changed
        .iter()
        .flat_map(|c| &c.tasks)
        .enumerate()
        .map(|(n, t)| Task {
            id: TaskId::new(id, &format!("{n}")),
            key: t.key.clone(),
            ticket: None,
            title: t.title.clone(),
            status: if t.status() == pb::TaskStatus::Done {
                TaskStatus::Done
            } else {
                TaskStatus::Todo
            },
            priority: Priority::None,
            due: Some(t.due.clone()),
            url: Some(t.url.clone()),
            context: t.context.clone(),
            labels: t.labels.clone(),
            updated: None,
        })
        .collect()
}

fn ms(d: Duration) -> f64 {
    d.as_secs_f64() * 1000.0
}
