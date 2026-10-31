//! Ports implemented by the infrastructure layer. They block; the
//! application calls them off the async threads.

use crate::tasks::{TaskError, TaskSource};

use super::{Doc, DocKind, DocNode, DocSummary};

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
    /// One level: the top one when `parent` is None, else what is under
    /// the node whose key is `parent`. Folders/spaces first, then pages,
    /// each by title (case-insensitive). At most `limit` entries; the bool
    /// says whether there were more.
    fn browse(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        parent: Option<&str>,
        limit: usize,
    ) -> Result<(Vec<DocNode>, bool), TaskError>;
}
