use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt};
use kumo_application::terminal::{Attachment, TerminalService, TerminalSession};
use kumo_domain::terminal::TerminalId;
use kumo_proto::v1 as pb;
use tonic::{Request, Response, Status, Streaming};

use crate::mapping::{
    launch_spec_from, size_from, status_from, terminal_info_to, terminal_output_to,
};
use crate::profile::{Profiles, services_of};

type OutputStream = Pin<Box<dyn Stream<Item = Result<pb::TerminalOutput, Status>> + Send>>;

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
        let spec = launch_spec_from(request.into_inner()).map_err(status_from)?;
        let id = service.open(spec).map_err(status_from)?;
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
}

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
