use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt};
use kumo_application::todos::{StatusChange, TodoEdit, TodoService};
use kumo_domain::todos::{TodoId, TodoStatus};
use kumo_proto::v1 as pb;
use tokio_stream::wrappers::WatchStream;
use tonic::{Request, Response, Status};

use crate::mapping::{todo_list_to, todo_run_from, todo_status_from, todo_to, todos_status_from};
use crate::profile::{Profiles, services_of};

type ListStream = Pin<Box<dyn Stream<Item = Result<pb::TodoList, Status>> + Send>>;

/// `by` of a status set from an agent's terminal (`kumod todo`): it may only
/// report working, testing or review, as the TODO's agent.
pub const AGENT_REPORT: &str = "kumod todo";

/// `kumo.v1.Todos`.
#[derive(Debug, Clone)]
pub struct TodosGrpc {
    profiles: Arc<Profiles>,
}

impl TodosGrpc {
    pub fn new(profiles: Arc<Profiles>) -> Self {
        Self { profiles }
    }

    async fn service<T>(&self, request: &Request<T>) -> Result<Arc<TodoService>, Status> {
        Ok(Arc::clone(
            &services_of(&self.profiles, request).await?.todos,
        ))
    }
}

fn id(raw: &str) -> Result<TodoId, Status> {
    TodoId::parse(raw).map_err(todos_status_from)
}

/// Empty: any repository.
fn repo(raw: String) -> Option<PathBuf> {
    Some(raw)
        .filter(|r| !r.trim().is_empty())
        .map(PathBuf::from)
}

#[tonic::async_trait]
impl pb::todos_server::Todos for TodosGrpc {
    type WatchStream = ListStream;

    async fn watch(
        &self,
        request: Request<pb::WatchTodosRequest>,
    ) -> Result<Response<Self::WatchStream>, Status> {
        let service = self.service(&request).await?;
        let lists = WatchStream::new(service.watch()).map(|todos| Ok(todo_list_to(&todos)));
        Ok(Response::new(Box::pin(lists)))
    }

    async fn add(
        &self,
        request: Request<pb::AddTodoRequest>,
    ) -> Result<Response<pb::Todo>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let todo = service
            .add(&r.title, &r.notes, repo(r.repo_path))
            .await
            .map_err(todos_status_from)?;
        Ok(Response::new(todo_to(&todo)))
    }

    async fn update(
        &self,
        request: Request<pb::UpdateTodoRequest>,
    ) -> Result<Response<pb::Todo>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        // Every field is sent: the UI edits from the whole TODO.
        let edit = TodoEdit {
            title: Some(r.title),
            notes: Some(r.notes),
            repo_path: Some(repo(r.repo_path)),
            done: Some(r.done),
        };
        let todo = service
            .update(&id(&r.id)?, edit)
            .await
            .map_err(todos_status_from)?;
        Ok(Response::new(todo_to(&todo)))
    }

    async fn delete(
        &self,
        request: Request<pb::DeleteTodoRequest>,
    ) -> Result<Response<pb::DeleteTodoResponse>, Status> {
        let service = self.service(&request).await?;
        service
            .delete(&id(&request.get_ref().id)?)
            .await
            .map_err(todos_status_from)?;
        Ok(Response::new(pb::DeleteTodoResponse {}))
    }

    async fn attach(
        &self,
        request: Request<pb::AttachTodoRequest>,
    ) -> Result<Response<pb::Todo>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let run = r
            .run
            .ok_or_else(|| Status::invalid_argument("a run is needed"))?;
        let todo = service
            .attach(&id(&r.id)?, todo_run_from(run))
            .await
            .map_err(todos_status_from)?;
        Ok(Response::new(todo_to(&todo)))
    }

    async fn set_status(
        &self,
        request: Request<pb::SetTodoStatusRequest>,
    ) -> Result<Response<pb::Todo>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let status = pb::TodoStatus::try_from(r.status)
            .map(todo_status_from)
            .map_err(|_| Status::invalid_argument("unknown TODO status"))?;
        let todo_id = id(&r.id)?;
        // An agent's terminal reports through `kumod todo`, which says so.
        let todo = if r.by == AGENT_REPORT {
            service.report(&todo_id, status.word(), "", &r.note).await
        } else {
            let pr = (status == TodoStatus::PullRequest && r.pr_number > 0)
                .then_some((r.pr_number, r.pr_url));
            service
                .set_status(
                    &todo_id,
                    StatusChange {
                        status,
                        by: r.by,
                        note: r.note,
                        pr,
                        clear_run: r.clear_run,
                    },
                )
                .await
        }
        .map_err(todos_status_from)?;
        Ok(Response::new(todo_to(&todo)))
    }
}
