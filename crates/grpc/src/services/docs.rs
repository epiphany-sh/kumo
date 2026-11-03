use std::sync::Arc;

use kumo_application::docs::DocsService;
use kumo_domain::docs::DocId;
use kumo_domain::tasks::SourceId;
use kumo_proto::v1 as pb;
use tonic::{Request, Response, Status};

use crate::mapping::{doc_level_to, doc_list_to, doc_to, tasks_status_from};
use crate::profile::{Profiles, services_of};

/// Pages per knowledge base when the client doesn't say.
const LIMIT: usize = 30;
/// Entries per level when the client doesn't say, and at most.
const LEVEL_LIMIT: usize = 200;
const LEVEL_MAX: usize = 1000;

/// `kumo.v1.Docs`.
#[derive(Debug, Clone)]
pub struct DocsGrpc {
    profiles: Arc<Profiles>,
}

impl DocsGrpc {
    pub fn new(profiles: Arc<Profiles>) -> Self {
        Self { profiles }
    }

    /// The docs service of the profile the call names.
    async fn service<T>(&self, request: &Request<T>) -> Result<Arc<DocsService>, Status> {
        Ok(Arc::clone(
            &services_of(&self.profiles, request).await?.docs,
        ))
    }
}

#[tonic::async_trait]
impl pb::docs_server::Docs for DocsGrpc {
    async fn list(
        &self,
        request: Request<pb::ListDocsRequest>,
    ) -> Result<Response<pb::DocList>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let limit = match r.limit {
            0 => LIMIT,
            n => usize::try_from(n).unwrap_or(LIMIT).min(100),
        };
        let groups = service
            .list(&r.query, limit, r.refresh)
            .await
            .map_err(tasks_status_from)?;
        Ok(Response::new(doc_list_to(&groups)))
    }

    async fn read(
        &self,
        request: Request<pb::ReadDocRequest>,
    ) -> Result<Response<pb::Doc>, Status> {
        let service = self.service(&request).await?;
        let id = DocId::parse(&request.into_inner().id).map_err(tasks_status_from)?;
        let (source, doc) = service.read(&id).await.map_err(tasks_status_from)?;
        Ok(Response::new(doc_to(&source, &doc)))
    }

    async fn browse(
        &self,
        request: Request<pb::BrowseDocsRequest>,
    ) -> Result<Response<pb::DocLevel>, Status> {
        let service = self.service(&request).await?;
        let r = request.into_inner();
        let source = SourceId::parse(&r.source_id).map_err(tasks_status_from)?;
        let limit = match r.limit {
            0 => LEVEL_LIMIT,
            n => usize::try_from(n).unwrap_or(LEVEL_LIMIT).min(LEVEL_MAX),
        };
        let parent = Some(r.parent.as_str()).filter(|p| !p.is_empty());
        let (_, nodes, truncated) = service
            .browse(&source, parent, limit, r.refresh)
            .await
            .map_err(tasks_status_from)?;
        Ok(Response::new(doc_level_to(&nodes, truncated)))
    }
}
