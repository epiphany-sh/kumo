//! Ports implemented by the infrastructure layer. They block; the
//! application calls them off the async threads.

use crate::tasks::{TaskError, TaskSource};

use super::{Doc, DocKind, DocSummary};

/// Reads one kind of knowledge base through a task source's account or
/// folder. `secret` is that source's API token, when its kind needs one.
pub trait DocsConnector: Send + Sync + 'static {
    fn kind(&self) -> DocKind;
    /// The pages the user is most likely after: the ones they wrote or
    /// watch, else the latest edited. Newest first.
    fn recent(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        limit: usize,
    ) -> Result<Vec<DocSummary>, TaskError>;
    /// Pages whose title or text match `query`. Best first.
    fn search(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        query: &str,
        limit: usize,
    ) -> Result<Vec<DocSummary>, TaskError>;
    /// The page the source knows as `external`.
    fn read(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        external: &str,
    ) -> Result<Doc, TaskError>;
}
