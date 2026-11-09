//! Where a run's context is read from: tickets, pages and pull requests,
//! through the profile's other services.

use std::fmt::Write as _;
use std::path::Path;
use std::sync::Arc;

use futures::future::BoxFuture;
use kumo_domain::docs::DocId;
use kumo_domain::pulls::ReviewThread;
use kumo_domain::tasks::{TaskDetail, TaskId};

use crate::docs::DocsService;
use crate::pulls::PullRequestService;
use crate::tasks::TaskService;

/// A pull request, as a run is given it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PullContext {
    /// Title, link, branches, description and open review threads.
    pub markdown: String,
    /// The branch it merges into.
    pub base: String,
    /// Its branch.
    pub head: String,
}

/// What a run's context items are read from.
pub trait RunSources: Send + Sync + 'static {
    /// A ticket by its id (or, without one, its key on the board): its key
    /// and the whole ticket as Markdown.
    fn ticket<'a>(
        &'a self,
        id: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<(String, String), String>>;
    /// A page by its id, as Markdown.
    fn doc<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<String, String>>;
    /// Pull request `number` of the repository at `repo`.
    fn pull_request<'a>(
        &'a self,
        repo: &'a Path,
        outside_origin: Option<&'a str>,
        number: u64,
    ) -> BoxFuture<'a, Result<PullContext, String>>;
}

/// [`RunSources`] over the profile's services.
#[derive(Debug, Clone)]
pub struct ServiceSources {
    pub tasks: Arc<TaskService>,
    pub docs: Arc<DocsService>,
    pub pulls: Arc<PullRequestService>,
}

impl RunSources for ServiceSources {
    fn ticket<'a>(
        &'a self,
        id: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<(String, String), String>> {
        Box::pin(async move {
            let id = match TaskId::parse(id) {
                Ok(id) => id,
                Err(_) => {
                    let board = self.tasks.board();
                    board
                        .sources
                        .iter()
                        .flat_map(|v| v.tasks.iter())
                        .find(|t| t.key.eq_ignore_ascii_case(key))
                        .map(|t| t.id.clone())
                        .ok_or_else(|| format!("{key} isn't on your task board"))?
                }
            };
            let detail = self
                .tasks
                .get_task(&id, false)
                .await
                .map_err(|e| e.to_string())?;
            Ok((detail.task.key.clone(), ticket_markdown(&detail)))
        })
    }

    fn doc<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<String, String>> {
        Box::pin(async move {
            let id = DocId::parse(id).map_err(|e| e.to_string())?;
            let (_, doc) = self.docs.read(&id).await.map_err(|e| e.to_string())?;
            let mut out = format!("# {}\n\n", doc.summary.title);
            if !doc.path.is_empty() {
                let _ = writeln!(out, "In: {}\n", doc.path.join(" › "));
            }
            out.push_str(&doc.markdown);
            Ok(out)
        })
    }

    fn pull_request<'a>(
        &'a self,
        repo: &'a Path,
        outside_origin: Option<&'a str>,
        number: u64,
    ) -> BoxFuture<'a, Result<PullContext, String>> {
        Box::pin(async move {
            if let Some(origin) = outside_origin {
                self.pulls.adopt_clone(repo, origin);
            }
            let list = self
                .pulls
                .list(repo, false)
                .await
                .map_err(|e| e.to_string())?;
            let pr = list.pull_requests.into_iter().find(|p| p.number == number);
            let Some(pr) = pr else {
                let why = list
                    .problem
                    .map_or_else(|| "it isn't open".to_owned(), |p| p.detail);
                return Err(format!("pull request {number} couldn't be read: {why}"));
            };
            let threads = self.pulls.threads(repo, number).await.unwrap_or_default();
            let mut out = format!("# {} · {}\n\n", pr.label, pr.title);
            let _ = writeln!(out, "{}", pr.url);
            let _ = writeln!(out, "{} → {}, by {}\n", pr.branch, pr.base, pr.author.name);
            out.push_str("## Description\n\n");
            out.push_str(if pr.body.trim().is_empty() {
                "(none)"
            } else {
                pr.body.trim()
            });
            out.push('\n');
            let open: Vec<&ReviewThread> = threads.iter().filter(|t| !t.resolved).collect();
            if !open.is_empty() {
                out.push_str("\n## Open review threads\n");
                for t in open {
                    let at = t
                        .line
                        .map_or_else(|| t.path.clone(), |l| format!("{}:{l}", t.path));
                    let _ = write!(
                        out,
                        "\n- {at} · {}: {}\n",
                        t.author,
                        t.body.trim().replace('\n', "\n  ")
                    );
                }
            }
            Ok(PullContext {
                markdown: out,
                base: pr.base,
                head: pr.branch,
            })
        })
    }
}

fn ticket_markdown(detail: &TaskDetail) -> String {
    let task = &detail.task;
    let mut out = format!("# {} · {}\n\n", task.key, task.title);
    if let Some(url) = &task.url {
        let _ = writeln!(out, "{url}\n");
    }
    let _ = writeln!(out, "Status: {:?}\n", task.status);
    if !detail.description.trim().is_empty() {
        let _ = writeln!(out, "## Description\n\n{}\n", detail.description.trim());
    }
    if !detail.acceptance_criteria.trim().is_empty() {
        let _ = writeln!(
            out,
            "## Acceptance criteria\n\n{}\n",
            detail.acceptance_criteria.trim()
        );
    }
    if !detail.comments.is_empty() {
        out.push_str("## Comments\n");
        for c in &detail.comments {
            let who = c.author.as_ref().map_or("someone", |p| p.name.as_str());
            let _ = write!(out, "\n**{who}:** {}\n", c.body.trim());
        }
    }
    out
}
