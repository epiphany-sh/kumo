use kumo_application::daemon::HelloService;
use kumo_domain::daemon::ApiVersion;
use kumo_proto::v1 as pb;
use tonic::{Request, Response, Status};

/// `kumo.v1.Core`.
#[derive(Debug, Clone)]
pub struct CoreGrpc {
    hello: HelloService,
}

impl CoreGrpc {
    pub fn new(hello: HelloService) -> Self {
        Self { hello }
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
        }))
    }
}
