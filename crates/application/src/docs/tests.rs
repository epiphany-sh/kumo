use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use kumo_domain::docs::{Doc, DocId, DocKind, DocNode, DocSummary, DocsConnector};
use kumo_domain::tasks::{
    SecretStore, SourceId, SourceOptions, Task, TaskDetail, TaskError, TaskId, TaskLink,
    TaskSource, TaskStore,
};

use super::{DocsPorts, DocsService};

struct Sources(Vec<TaskSource>);

impl TaskStore for Sources {
    fn sources(&self) -> Result<Vec<TaskSource>, TaskError> {
        Ok(self.0.clone())
    }
    fn save_source(&self, _: &TaskSource) -> Result<(), TaskError> {
        unimplemented!()
    }
    fn delete_source(&self, _: &SourceId) -> Result<(), TaskError> {
        unimplemented!()
    }
    fn tasks(&self, _: &SourceId) -> Result<Vec<Task>, TaskError> {
        unimplemented!()
    }
    fn replace_tasks(&self, _: &SourceId, _: &[Task]) -> Result<(), TaskError> {
        unimplemented!()
    }
    fn links(&self) -> Result<Vec<TaskLink>, TaskError> {
        unimplemented!()
    }
    fn save_link(&self, _: &TaskLink) -> Result<(), TaskError> {
        unimplemented!()
    }
    fn delete_link(&self, _: &TaskLink) -> Result<(), TaskError> {
        unimplemented!()
    }
    fn detail(&self, _: &TaskId) -> Result<Option<TaskDetail>, TaskError> {
        unimplemented!()
    }
    fn save_detail(&self, _: &TaskDetail) -> Result<(), TaskError> {
        unimplemented!()
    }
    fn delete_details(&self, _: &SourceId) -> Result<(), TaskError> {
        unimplemented!()
    }
}

struct Secrets;

impl SecretStore for Secrets {
    fn get(&self, source: &SourceId) -> Result<Option<String>, TaskError> {
        Ok((source.as_str() == "jira1").then(|| "tok".to_owned()))
    }
    fn set(&self, _: &SourceId, _: &str) -> Result<(), TaskError> {
        unimplemented!()
    }
    fn delete(&self, _: &SourceId) -> Result<(), TaskError> {
        unimplemented!()
    }
}

/// Answers with one page per call, named after what was asked.
struct Fake {
    kind: DocKind,
    calls: AtomicUsize,
    secrets: Mutex<Vec<Option<String>>>,
}

impl Fake {
    fn new(kind: DocKind) -> Arc<Self> {
        Arc::new(Self {
            kind,
            calls: AtomicUsize::new(0),
            secrets: Mutex::new(Vec::new()),
        })
    }

    fn page(source: &TaskSource, title: &str) -> DocSummary {
        DocSummary {
            id: DocId::new(&source.id, "1"),
            title: title.into(),
            place: String::new(),
            updated_at: None,
            author: None,
            url: String::new(),
            excerpt: String::new(),
        }
    }
}

impl DocsConnector for Fake {
    fn kind(&self) -> DocKind {
        self.kind
    }
    fn recent(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        _: usize,
    ) -> Result<Vec<DocSummary>, TaskError> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        self.secrets.lock().unwrap().push(secret.map(str::to_owned));
        if source.id.as_str() == "jira2" {
            return Err(TaskError::Auth(
                "Confluence rejected the credentials".into(),
            ));
        }
        Ok(vec![Self::page(source, "recent")])
    }
    fn search(
        &self,
        source: &TaskSource,
        _: Option<&str>,
        query: &str,
        _: usize,
    ) -> Result<Vec<DocSummary>, TaskError> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        Ok(vec![Self::page(source, query)])
    }
    fn read(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        external: &str,
    ) -> Result<Doc, TaskError> {
        Ok(Doc {
            summary: Self::page(source, &format!("{external} with {secret:?}")),
            markdown: "# Hi".into(),
            path: Vec::new(),
            file: None,
        })
    }
    fn browse(
        &self,
        source: &TaskSource,
        secret: Option<&str>,
        parent: Option<&str>,
        limit: usize,
    ) -> Result<(Vec<DocNode>, bool), TaskError> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        self.secrets.lock().unwrap().push(secret.map(str::to_owned));
        let node = DocNode {
            key: format!("{}>{}", parent.unwrap_or("top"), source.id),
            title: "node".into(),
            doc: None,
            children: 1,
            note: String::new(),
        };
        Ok((vec![node], limit < 2))
    }
}

fn source(id: &str, options: SourceOptions, enabled: bool) -> TaskSource {
    TaskSource {
        id: SourceId::parse(id).unwrap(),
        name: id.into(),
        options,
        enabled,
    }
}

fn jira(id: &str, site: &str) -> TaskSource {
    source(
        id,
        SourceOptions::Jira {
            site: site.into(),
            email: "ana@acme.com".into(),
            jql: String::new(),
        },
        true,
    )
}

fn service(confluence: &Arc<Fake>, vault: &Arc<Fake>) -> DocsService {
    let sources = vec![
        jira("jira1", "https://acme.atlassian.net"),
        source(
            "todo1",
            SourceOptions::Todoist {
                project: String::new(),
            },
            true,
        ),
        jira("jira9", "https://ACME.atlassian.net"),
        source(
            "ob1",
            SourceOptions::Obsidian {
                vault: PathBuf::from("/notes/work"),
            },
            true,
        ),
        source(
            "ob2",
            SourceOptions::Obsidian {
                vault: PathBuf::from("/notes/off"),
            },
            false,
        ),
        jira("jira2", "https://other.atlassian.net"),
    ];
    DocsService::new(
        DocsPorts {
            sources: Arc::new(Sources(sources)),
            secrets: Arc::new(Secrets),
            connectors: vec![confluence.clone(), vault.clone()],
        },
        Duration::from_secs(60),
    )
}

#[tokio::test]
async fn lists_each_knowledge_base_once_in_the_sources_order() {
    let (confluence, vault) = (Fake::new(DocKind::Confluence), Fake::new(DocKind::Obsidian));
    let docs = service(&confluence, &vault);
    let groups = docs.list("", 20, false).await.unwrap();
    let names: Vec<_> = groups
        .iter()
        .map(|g| (g.source.kind, g.source.name.as_str()))
        .collect();
    assert_eq!(
        names,
        [
            (DocKind::Confluence, "acme.atlassian.net"),
            (DocKind::Obsidian, "work"),
            (DocKind::Confluence, "other.atlassian.net"),
        ],
        "one per site, no disabled sources, no kinds without docs"
    );
    assert_eq!(groups[0].docs[0].title, "recent");
    assert_eq!(groups[1].source.location, "/notes/work");
    assert!(matches!(groups[2].problem, Some(TaskError::Auth(_))));
    assert!(groups[2].docs.is_empty());
    assert_eq!(
        vault.secrets.lock().unwrap().as_slice(),
        [None],
        "vaults need no token"
    );
    assert!(
        confluence
            .secrets
            .lock()
            .unwrap()
            .contains(&Some("tok".into()))
    );
}

#[tokio::test]
async fn searches_and_reuses_recent_answers() {
    let (confluence, vault) = (Fake::new(DocKind::Confluence), Fake::new(DocKind::Obsidian));
    let docs = service(&confluence, &vault);
    let groups = docs.list("  kafka ", 20, false).await.unwrap();
    assert_eq!(groups[0].docs[0].title, "kafka");
    let calls = confluence.calls.load(Ordering::SeqCst);
    docs.list("kafka", 20, false).await.unwrap();
    assert_eq!(confluence.calls.load(Ordering::SeqCst), calls, "cached");
    docs.list("kafka", 20, true).await.unwrap();
    assert_eq!(
        confluence.calls.load(Ordering::SeqCst),
        calls + 2,
        "refresh asks again"
    );
}

#[tokio::test]
async fn reads_a_page_through_its_source() {
    let (confluence, vault) = (Fake::new(DocKind::Confluence), Fake::new(DocKind::Obsidian));
    let docs = service(&confluence, &vault);
    let (source, doc) = docs
        .read(&DocId::parse("jira1/98311").unwrap())
        .await
        .unwrap();
    assert_eq!(source.name, "acme.atlassian.net");
    assert_eq!(doc.summary.title, "98311 with Some(\"tok\")");
    assert!(matches!(
        docs.read(&DocId::parse("ob2/a.md").unwrap()).await,
        Err(TaskError::UnknownSource(_))
    ));
}

#[tokio::test]
async fn browses_a_level_and_reuses_it_unless_refreshed() {
    let (confluence, vault) = (Fake::new(DocKind::Confluence), Fake::new(DocKind::Obsidian));
    let docs = service(&confluence, &vault);
    let jira1 = SourceId::parse("jira1").unwrap();
    let (source, nodes, truncated) = docs
        .browse(&jira1, Some("space:1"), 200, false)
        .await
        .unwrap();
    assert_eq!(source.name, "acme.atlassian.net");
    assert_eq!(nodes[0].key, "space:1>jira1");
    assert!(!truncated);
    assert_eq!(
        confluence.secrets.lock().unwrap().as_slice(),
        [Some("tok".into())]
    );
    docs.browse(&jira1, Some("space:1"), 200, false)
        .await
        .unwrap();
    assert_eq!(confluence.calls.load(Ordering::SeqCst), 1, "cached");
    let (_, top, truncated) = docs.browse(&jira1, None, 1, false).await.unwrap();
    assert_eq!(top[0].key, "top>jira1");
    assert!(truncated);
    assert_eq!(
        confluence.calls.load(Ordering::SeqCst),
        2,
        "another parent or limit asks"
    );
    docs.browse(&jira1, Some("space:1"), 200, true)
        .await
        .unwrap();
    assert_eq!(
        confluence.calls.load(Ordering::SeqCst),
        3,
        "refresh asks again"
    );
}

#[tokio::test]
async fn browses_only_enabled_known_sources() {
    let (confluence, vault) = (Fake::new(DocKind::Confluence), Fake::new(DocKind::Obsidian));
    let docs = service(&confluence, &vault);
    for id in ["nope1", "ob2", "todo1", "jira9"] {
        assert!(
            matches!(
                docs.browse(&SourceId::parse(id).unwrap(), None, 200, false)
                    .await,
                Err(TaskError::UnknownSource(_))
            ),
            "{id}: unknown, disabled, without docs, or a site already read"
        );
    }
    let (source, _, _) = docs
        .browse(&SourceId::parse("ob1").unwrap(), None, 200, false)
        .await
        .unwrap();
    assert_eq!(source.name, "work");
    assert_eq!(vault.secrets.lock().unwrap().as_slice(), [None]);
    assert_eq!(confluence.calls.load(Ordering::SeqCst), 0);
}
