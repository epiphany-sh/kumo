use kumo_application::daemon::{DaemonControl, HelloService};
use kumo_domain::daemon::ApiVersion;
use kumo_proto::v1 as pb;
use tonic::{Request, Response, Status};

/// `kumo.v1.Core`.
#[derive(Debug, Clone)]
pub struct CoreGrpc {
    hello: HelloService,
    control: DaemonControl,
}

impl CoreGrpc {
    pub fn new(hello: HelloService, control: DaemonControl) -> Self {
        Self { hello, control }
    }
}

#[tonic::async_trait]
impl pb::core_server::Core for CoreGrpc {
    async fn hello(
        &self,
        request: Request<pb::HelloRequest>,
    ) -> Result<Response<pb::HelloResponse>, Status> {
        let request = request.into_inner();
        let reply = self.hello.hello(
            ApiVersion::new(request.client_api_version),
            &request.client_name,
        );
        Ok(Response::new(pb::HelloResponse {
            server_api_version: reply.api_version.get(),
            server_version: reply.server_version,
            server_time_unix_nanos: reply.server_time.as_unix_nanos(),
            outdated: reply.outdated,
        }))
    }

    async fn shutdown(
        &self,
        request: Request<pb::ShutdownRequest>,
    ) -> Result<Response<pb::ShutdownResponse>, Status> {
        self.control
            .shutdown(request.into_inner().if_idle)
            .map_err(|refused| Status::failed_precondition(refused.to_string()))?;
        Ok(Response::new(pb::ShutdownResponse {}))
    }
}
