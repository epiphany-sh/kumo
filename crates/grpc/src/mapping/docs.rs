use kumo_application::docs::{DocGroup, DocSource};
use kumo_domain::docs::{Doc, DocKind, DocNode, DocSummary};
use kumo_domain::tasks::TaskError;
use kumo_proto::v1 as pb;

pub fn doc_source_to(source: &DocSource) -> pb::DocSource {
    pb::DocSource {
        id: source.id.to_string(),
        kind: match source.kind {
            DocKind::Confluence => pb::DocKind::Confluence,
            DocKind::Obsidian => pb::DocKind::Obsidian,
        }
        .into(),
        name: source.name.clone(),
        location: source.location.clone(),
    }
}

pub fn doc_summary_to(doc: &DocSummary) -> pb::DocSummary {
    pb::DocSummary {
        id: doc.id.to_string(),
        title: doc.title.clone(),
        place: doc.place.clone(),
        updated_at: doc.updated_at.unwrap_or_default(),
        author: doc.author.clone().unwrap_or_default(),
        url: doc.url.clone(),
        excerpt: doc.excerpt.clone(),
    }
}

pub fn doc_list_to(groups: &[DocGroup]) -> pb::DocList {
    pb::DocList {
        groups: groups
            .iter()
            .map(|g| pb::DocGroup {
                source: Some(doc_source_to(&g.source)),
                docs: g.docs.iter().map(doc_summary_to).collect(),
                problem: g
                    .problem
                    .as_ref()
                    .map(ToString::to_string)
                    .unwrap_or_default(),
                problem_is_auth: matches!(g.problem, Some(TaskError::Auth(_))),
            })
            .collect(),
    }
}

pub fn doc_to(source: &DocSource, doc: &Doc) -> pb::Doc {
    pb::Doc {
        summary: Some(doc_summary_to(&doc.summary)),
        source: Some(doc_source_to(source)),
        markdown: doc.markdown.clone(),
        path: doc.path.clone(),
        file: doc
            .file
            .as_ref()
            .map(|f| f.display().to_string())
            .unwrap_or_default(),
    }
}

pub fn doc_level_to(nodes: &[DocNode], truncated: bool) -> pb::DocLevel {
    pb::DocLevel {
        nodes: nodes
            .iter()
            .map(|n| pb::DocNode {
                key: n.key.clone(),
                title: n.title.clone(),
                doc: n.doc.as_ref().map(doc_summary_to),
                children: n.children,
                note: n.note.clone(),
            })
            .collect(),
        truncated,
    }
}
