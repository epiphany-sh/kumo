use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::{Duration, Instant};

use kumo_domain::docs::{Doc, DocId, DocKind, DocNode, DocSummary, DocsConnector};
use kumo_domain::tasks::{SecretStore, SourceId, SourceOptions, TaskError, TaskSource, TaskStore};

pub struct DocsPorts {
    /// The task sources, whose accounts and folders docs read through.
    pub sources: Arc<dyn TaskStore>,
    pub secrets: Arc<dyn SecretStore>,
    pub connectors: Vec<Arc<dyn DocsConnector>>,
}

impl std::fmt::Debug for DocsPorts {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DocsPorts")
            .field("connectors", &self.connectors.len())
            .finish_non_exhaustive()
    }
}

/// A knowledge base, as the user knows it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DocSource {
    /// The task source it reads through.
    pub id: SourceId,
    pub kind: DocKind,
    /// `acme.atlassian.net`, the vault's folder name.
    pub name: String,
    /// The site URL or the vault's path.
    pub location: String,
}

/// One knowledge base's pages, or why they can't be read.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DocGroup {
    pub source: DocSource,
    pub docs: Vec<DocSummary>,
    pub problem: Option<TaskError>,
}

pub struct DocsService {
    ports: DocsPorts,
    /// How long a list is reused.
    fresh: Duration,
    lists: Mutex<HashMap<String, (Instant, Vec<DocGroup>)>>,
    /// Levels, by source, parent and limit.
    levels: Mutex<HashMap<LevelKey, (Instant, Level)>>,
}

type LevelKey = (SourceId, Option<String>, usize);
type Level = (DocSource, Vec<DocNode>, bool);

impl std::fmt::Debug for DocsService {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DocsService").finish_non_exhaustive()
    }
}

impl DocsService {
    pub fn new(ports: DocsPorts, fresh: Duration) -> Self {
        Self {
            ports,
            fresh,
            lists: Mutex::new(HashMap::new()),
            levels: Mutex::new(HashMap::new()),
        }
    }

    /// Each knowledge base's recent pages, or the ones matching `query`.
    /// [refresh] asks again even if the last answer is recent.
    pub async fn list(
        &self,
        query: &str,
        limit: usize,
        refresh: bool,
    ) -> Result<Vec<DocGroup>, TaskError> {
        let query = query.trim().to_owned();
        let key = format!("{limit}\n{query}");
        if !refresh
            && let Some((at, groups)) = self.lists().get(&key)
            && at.elapsed() < self.fresh
        {
            return Ok(groups.clone());
        }
        let sources = self.sources().await?;
        let mut tasks = tokio::task::JoinSet::new();
        for (index, (source, doc_source, connector)) in sources.into_iter().enumerate() {
            let secrets = Arc::clone(&self.ports.secrets);
            let query = query.clone();
            tasks.spawn_blocking(move || {
                let found = secret_of(&*secrets, &source).and_then(|secret| {
                    if query.is_empty() {
                        connector.recent(&source, secret.as_deref(), limit)
                    } else {
                        connector.search(&source, secret.as_deref(), &query, limit)
                    }
                });
                let (docs, problem) = match found {
                    Ok(docs) => (docs, None),
                    Err(e) => (Vec::new(), Some(e)),
                };
                (
                    index,
                    DocGroup {
                        source: doc_source,
                        docs,
                        problem,
                    },
                )
            });
        }
        let mut groups: Vec<(usize, DocGroup)> = tasks.join_all().await.into_iter().collect();
        groups.sort_by_key(|(index, _)| *index);
        let groups: Vec<DocGroup> = groups.into_iter().map(|(_, g)| g).collect();
        let mut lists = self.lists();
        lists.retain(|_, (at, _)| at.elapsed() < self.fresh);
        lists.insert(key, (Instant::now(), groups.clone()));
        Ok(groups)
    }

    /// The whole page `id`, with the knowledge base it's in.
    pub async fn read(&self, id: &DocId) -> Result<(DocSource, Doc), TaskError> {
        let (source, doc_source, connector) = self.source(&id.source()).await?;
        let secrets = Arc::clone(&self.ports.secrets);
        let external = id.external().to_owned();
        let doc = blocking(move || {
            let secret = secret_of(&*secrets, &source)?;
            connector.read(&source, secret.as_deref(), &external)
        })
        .await?;
        Ok((doc_source, doc))
    }

    /// One level of knowledge base `source`: its top one without `parent`,
    /// else what is under that node. Whether there were more than `limit`.
    /// [refresh] asks again even if the last answer is recent.
    pub async fn browse(
        &self,
        source: &SourceId,
        parent: Option<&str>,
        limit: usize,
        refresh: bool,
    ) -> Result<(DocSource, Vec<DocNode>, bool), TaskError> {
        let key = (source.clone(), parent.map(str::to_owned), limit);
        if !refresh
            && let Some((at, level)) = self.levels().get(&key)
            && at.elapsed() < self.fresh
        {
            return Ok(level.clone());
        }
        let (task_source, doc_source, connector) = self.source(source).await?;
        let secrets = Arc::clone(&self.ports.secrets);
        let parent = key.1.clone();
        let (nodes, truncated) = blocking(move || {
            let secret = secret_of(&*secrets, &task_source)?;
            connector.browse(&task_source, secret.as_deref(), parent.as_deref(), limit)
        })
        .await?;
        let level = (doc_source, nodes, truncated);
        let mut levels = self.levels();
        levels.retain(|_, (at, _)| at.elapsed() < self.fresh);
        levels.insert(key, (Instant::now(), level.clone()));
        Ok(level)
    }

    fn levels(&self) -> std::sync::MutexGuard<'_, HashMap<LevelKey, (Instant, Level)>> {
        self.levels.lock().unwrap_or_else(PoisonError::into_inner)
    }

    fn lists(&self) -> std::sync::MutexGuard<'_, HashMap<String, (Instant, Vec<DocGroup>)>> {
        self.lists.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// The knowledge base `id` reads through, if it's one of [sources].
    async fn source(
        &self,
        id: &SourceId,
    ) -> Result<(TaskSource, DocSource, Arc<dyn DocsConnector>), TaskError> {
        self.sources()
            .await?
            .into_iter()
            .find(|(s, _, _)| s.id == *id)
            .ok_or_else(|| TaskError::UnknownSource(id.to_string()))
    }

    /// Enabled task sources that lead to docs, one per Atlassian site.
    async fn sources(
        &self,
    ) -> Result<Vec<(TaskSource, DocSource, Arc<dyn DocsConnector>)>, TaskError> {
        let store = Arc::clone(&self.ports.sources);
        let all = blocking(move || store.sources()).await?;
        let mut sites = HashSet::new();
        let mut found = Vec::new();
        for source in all.into_iter().filter(|s| s.enabled) {
            let Some(kind) = DocKind::from_source(source.kind()) else {
                continue;
            };
            let Some(connector) = self.ports.connectors.iter().find(|c| c.kind() == kind) else {
                continue;
            };
            let (name, location) = match &source.options {
                SourceOptions::Jira { site, .. } => {
                    if !sites.insert(site.to_lowercase()) {
                        continue;
                    }
                    let host = site.split_once("://").map_or(site.as_str(), |(_, h)| h);
                    (host.trim_end_matches('/').to_owned(), site.clone())
                }
                SourceOptions::Obsidian { vault } => (
                    vault
                        .file_name()
                        .map_or_else(|| source.name.clone(), |n| n.to_string_lossy().into_owned()),
                    vault.display().to_string(),
                ),
                _ => continue,
            };
            let doc_source = DocSource {
                id: source.id.clone(),
                kind,
                name,
                location,
            };
            found.push((source, doc_source, Arc::clone(connector)));
        }
        Ok(found)
    }
}

fn secret_of(secrets: &dyn SecretStore, source: &TaskSource) -> Result<Option<String>, TaskError> {
    if source.kind().needs_secret() {
        secrets.get(&source.id)
    } else {
        Ok(None)
    }
}

async fn blocking<T: Send + 'static>(
    f: impl FnOnce() -> Result<T, TaskError> + Send + 'static,
) -> Result<T, TaskError> {
    tokio::task::spawn_blocking(f)
        .await
        .map_err(|e| TaskError::Store(format!("docs worker failed: {e}")))?
}
