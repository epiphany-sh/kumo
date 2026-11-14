use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt};
use kumo_application::terminal::{Attachment, TerminalService, TerminalSession};
use kumo_domain::terminal::TerminalId;
use kumo_proto::v1 as pb;
use tokio_stream::wrappers::WatchStream;
use tonic::{Request, Response, Status, Streaming};

use crate::mapping::{
    history_to, launch_spec_from, size_from, status_from, terminal_info_to, terminal_output_to,
    terminals_activity_to,
};
use crate::profile::{Profiles, services_of};

type OutputStream = Pin<Box<dyn Stream<Item = Result<pb::TerminalOutput, Status>> + Send>>;
type ActivityStream = Pin<Box<dyn Stream<Item = Result<pb::TerminalsActivity, Status>> + Send>>;

/// `kumo.v1.Terminals`.
///
/// Each call sees the terminals of the profile it names: `List` shows only
/// those, and attaching to or closing another profile's is not found.
#[derive(Debug, Clone)]
pub struct TerminalsGrpc {
    profiles: Arc<Profiles>,
}

impl TerminalsGrpc {
    pub fn new(profiles: Arc<Profiles>) -> Self {
        Self { profiles }
    }

    /// The terminals of the profile the call names.
    async fn service<T>(&self, request: &Request<T>) -> Result<Arc<TerminalService>, Status> {
        Ok(Arc::clone(
            &services_of(&self.profiles, request).await?.terminals,
        ))
    }
}

#[tonic::async_trait]
impl pb::terminals_server::Terminals for TerminalsGrpc {
    async fn open(
        &self,
        request: Request<pb::OpenRequest>,
    ) -> Result<Response<pb::OpenResponse>, Status> {
        let service = self.service(&request).await?;
        let request = request.into_inner();
        let shell = request.shell_integration;
        let remember = request.remember_commands;
        let spec = launch_spec_from(request).map_err(status_from)?;
        let id = if shell {
            service.open_shell(spec, remember)
        } else {
            service.open(spec)
        }
        .map_err(status_from)?;
        Ok(Response::new(pb::OpenResponse {
            terminal_id: id.to_string(),
        }))
    }

    type AttachStream = OutputStream;

    async fn attach(
        &self,
        request: Request<Streaming<pb::TerminalInput>>,
    ) -> Result<Response<Self::AttachStream>, Status> {
        let service = self.service(&request).await?;
        let mut inbound = request.into_inner();
        let target = match inbound.message().await? {
            Some(pb::TerminalInput {
                kind: Some(pb::terminal_input::Kind::Attach(target)),
            }) => target,
            _ => return Err(Status::invalid_argument("first message must be `attach`")),
        };
        let id = TerminalId::parse(&target.terminal_id).map_err(status_from)?;
        let Attachment { session, output } = service
            .attach(&id, target.replay_scrollback)
            .map_err(status_from)?;

        tokio::spawn(forward_input(session, inbound));
        let outbound = output
            .into_stream()
            .map(|event| Ok(terminal_output_to(event)));
        Ok(Response::new(Box::pin(outbound)))
    }

    async fn close(
        &self,
        request: Request<pb::CloseRequest>,
    ) -> Result<Response<pb::CloseResponse>, Status> {
        let service = self.service(&request).await?;
        let id = TerminalId::parse(&request.into_inner().terminal_id).map_err(status_from)?;
        service.close(&id).map_err(status_from)?;
        Ok(Response::new(pb::CloseResponse {}))
    }

    async fn list(
        &self,
        request: Request<pb::ListRequest>,
    ) -> Result<Response<pb::ListResponse>, Status> {
        let terminals = self
            .service(&request)
            .await?
            .list()
            .into_iter()
            .map(terminal_info_to)
            .collect();
        Ok(Response::new(pb::ListResponse { terminals }))
    }

    type WatchStream = ActivityStream;

    /// The changes are every profile's (one registry): a change elsewhere
    /// sends this profile's shells again, unchanged.
    async fn watch(
        &self,
        request: Request<pb::WatchTerminalsRequest>,
    ) -> Result<Response<Self::WatchStream>, Status> {
        let service = self.service(&request).await?;
        let changes = WatchStream::new(service.activity_changes());
        let shells = changes.map(move |_| Ok(terminals_activity_to(service.activity())));
        Ok(Response::new(Box::pin(shells)))
    }

    async fn history(
        &self,
        request: Request<pb::HistoryRequest>,
    ) -> Result<Response<pb::HistoryResponse>, Status> {
        let service = self.service(&request).await?;
        let request = request.into_inner();
        let id = TerminalId::parse(&request.terminal_id).map_err(status_from)?;
        let limit = match request.limit {
            0 => DEFAULT_HISTORY,
            n => (n as usize).min(MAX_HISTORY),
        };
        let (history, cwd) = service.history(&id, limit).await.map_err(status_from)?;
        Ok(Response::new(history_to(history, cwd)))
    }

    async fn forget_history(
        &self,
        request: Request<pb::ForgetHistoryRequest>,
    ) -> Result<Response<pb::ForgetHistoryResponse>, Status> {
        let service = self.service(&request).await?;
        let request = request.into_inner();
        let id = if request.terminal_id.is_empty() {
            if !request.everything {
                return Err(Status::invalid_argument(
                    "a terminal, or everything, to forget",
                ));
            }
            None
        } else {
            Some(TerminalId::parse(&request.terminal_id).map_err(status_from)?)
        };
        let forgotten = service
            .forget_history(id.as_ref(), request.everything)
            .await
            .map_err(status_from)?;
        Ok(Response::new(pb::ForgetHistoryResponse {
            forgotten: u32::try_from(forgotten).unwrap_or(u32::MAX),
        }))
    }
}

/// History entries returned when the client doesn't say, and at most.
const DEFAULT_HISTORY: usize = 1_000;
const MAX_HISTORY: usize = kumo_domain::terminal::HISTORY_LIMIT;

/// Feeds client input into the session until the client stops sending or
/// the session goes away.
async fn forward_input(session: Arc<TerminalSession>, mut inbound: Streaming<pb::TerminalInput>) {
    use pb::terminal_input::Kind;

    while let Ok(Some(message)) = inbound.message().await {
        match message.kind {
            Some(Kind::Data(data)) => {
                if session.write(data).await.is_err() {
                    break;
                }
            }
            Some(Kind::Resize(size)) => {
                let resized = size_from(size.cols, size.rows).and_then(|s| session.resize(s));
                if let Err(error) = resized {
                    tracing::warn!(terminal = %session.id(), %error, "resize failed");
                }
            }
            Some(Kind::Attach(_)) => {
                tracing::warn!(terminal = %session.id(), "ignoring repeated `attach` message");
            }
            None => {}
        }
    }
}
