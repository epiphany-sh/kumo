use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;

use futures::{Stream, StreamExt};
use kumo_application::test_runs::TestService;
use kumo_proto::v1 as pb;
use tokio_stream::wrappers::WatchStream;
use tonic::{Request, Response, Status};

use crate::mapping::{size_from, status_from, test_run_to, tests_snapshot_to, tests_status_from};

type SnapshotStream = Pin<Box<dyn Stream<Item = Result<pb::TestsSnapshot, Status>> + Send>>;

/// `kumo.v1.Tests`.
#[derive(Debug, Clone)]
pub struct TestsGrpc {
    service: Arc<TestService>,
}

impl TestsGrpc {
    pub fn new(service: Arc<TestService>) -> Self {
        Self { service }
    }
}

#[tonic::async_trait]
impl pb::tests_server::Tests for TestsGrpc {
    type WatchStream = SnapshotStream;

    async fn watch(
        &self,
        request: Request<pb::WatchTestsRequest>,
    ) -> Result<Response<Self::WatchStream>, Status> {
        let worktree = PathBuf::from(request.into_inner().worktree_path);
        let command = self
            .service
            .detect(&worktree)
            .await
            .map_err(tests_status_from)?;
        // Paths as the workspace knows them, to match runs.
        let worktree = self
            .service
            .known(&worktree)
            .await
            .map_err(tests_status_from)?;
        let mut last = None;
        let stream = WatchStream::new(self.service.watch()).filter_map(move |snapshot| {
            let message = tests_snapshot_to(command.as_ref(), &snapshot, &worktree);
            // Other worktrees' runs change the snapshot too.
            if last.as_ref() == Some(&message) {
                return futures::future::ready(None);
            }
            last = Some(message.clone());
            futures::future::ready(Some(Ok(message)))
        });
        Ok(Response::new(Box::pin(stream)))
    }

    async fn run(
        &self,
        request: Request<pb::RunTestsRequest>,
    ) -> Result<Response<pb::TestRun>, Status> {
        let r = request.into_inner();
        let size = size_from(r.cols, r.rows).map_err(status_from)?;
        let command = Some(r.command).filter(|c| !c.trim().is_empty());
        let run = self
            .service
            .run(&PathBuf::from(r.worktree_path), command.as_deref(), size)
            .await
            .map_err(tests_status_from)?;
        Ok(Response::new(test_run_to(&run)))
    }

    async fn stop(
        &self,
        request: Request<pb::StopTestsRequest>,
    ) -> Result<Response<pb::StopTestsResponse>, Status> {
        self.service
            .stop(&PathBuf::from(request.into_inner().worktree_path))
            .await
            .map_err(tests_status_from)?;
        Ok(Response::new(pb::StopTestsResponse {}))
    }
}
