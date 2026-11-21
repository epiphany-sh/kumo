//! `kumod todo <status> [note]`: how an agent working on a TODO tells Kumo
//! how it goes, from its own terminal.
//!
//! Kumo starts such an agent with `KUMO_TODO` (the TODO) and `KUMO_PROFILE`
//! (its workspace) set, and tells it in its prompt to run this when it
//! starts, when it runs the tests and when it's done. It may only report
//! working, testing and review: pushing waits for the user's approval.

use std::path::Path;

use kumo_domain::daemon::DiscoveryStore;
use kumo_domain::todos::TodoStatus;
use kumo_grpc::client::KumoClient;
use kumo_grpc::mapping::todo_status_to;
use kumo_grpc::services::AGENT_REPORT;
use kumo_infrastructure::discovery::FileDiscoveryStore;
use kumo_proto::v1 as pb;

/// Reports `status` for the TODO in `KUMO_TODO`. The result goes to the
/// agent's terminal: a line on stdout, or the problem on stderr.
pub async fn run(data_dir: &Path, status: &str, note: &str) -> bool {
    let Some(todo) = std::env::var("KUMO_TODO")
        .ok()
        .filter(|t| !t.trim().is_empty())
    else {
        eprintln!(
            "kumod todo: KUMO_TODO isn't set: only an agent Kumo started on a TODO can report"
        );
        return false;
    };
    let Some(status) = TodoStatus::from_word(status).filter(|s| s.agent_may_report()) else {
        eprintln!("kumod todo: report working, testing or review (not \"{status}\")");
        return false;
    };
    let profile = std::env::var("KUMO_PROFILE").ok();
    match report(data_dir, profile.as_deref(), &todo, status, note).await {
        Ok(title) => {
            println!("Kumo: \"{title}\" is now {status}.");
            true
        }
        Err(error) => {
            eprintln!("kumod todo: {error}");
            false
        }
    }
}

async fn report(
    data_dir: &Path,
    profile: Option<&str>,
    todo: &str,
    status: TodoStatus,
    note: &str,
) -> anyhow::Result<String> {
    let endpoint = FileDiscoveryStore::in_dir(data_dir)
        .load()?
        .ok_or_else(|| anyhow::anyhow!("Kumo isn't running"))?;
    let mut client = KumoClient::connect(endpoint.addr, &endpoint.token)
        .await?
        .with_profile(profile);
    let todo = client
        .todos
        .set_status(pb::SetTodoStatusRequest {
            id: todo.trim().to_owned(),
            status: todo_status_to(status) as i32,
            by: AGENT_REPORT.to_owned(),
            note: note.to_owned(),
            ..pb::SetTodoStatusRequest::default()
        })
        .await
        .map_err(|s| anyhow::anyhow!("{}", s.message()))?
        .into_inner();
    Ok(todo.title)
}
