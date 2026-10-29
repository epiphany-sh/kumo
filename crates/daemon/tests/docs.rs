//! `Docs` service end to end: an Obsidian vault source's notes, listed,
//! searched and read; ids from outside the vault are refused.

mod common;

use common::TestDaemon;
use kumo_proto::v1 as pb;
use tonic::Code;

#[tokio::test]
async fn reads_a_vault_sources_notes() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let vault = daemon.home().join("notes/work");
    std::fs::create_dir_all(vault.join("eng")).unwrap();
    std::fs::write(
        vault.join("eng/ADR-014 Kafka naming.md"),
        "# Topics\n\nUse `team.entity.v1`.\n",
    )
    .unwrap();

    let empty = client
        .docs
        .list(pb::ListDocsRequest::default())
        .await
        .unwrap()
        .into_inner();
    assert!(empty.groups.is_empty(), "no sources, no docs");

    let source = client
        .tasks
        .save_source(pb::SaveSourceRequest {
            kind: pb::TaskSourceKind::Obsidian.into(),
            name: "Work".into(),
            options: [("vault".to_owned(), vault.display().to_string())].into(),
            enabled: true,
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();

    let list = client
        .docs
        .list(pb::ListDocsRequest {
            refresh: true,
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    let group = &list.groups[0];
    let doc_source = group.source.as_ref().unwrap();
    assert_eq!(
        (doc_source.kind(), doc_source.name.as_str()),
        (pb::DocKind::Obsidian, "work")
    );
    assert_eq!(group.problem, "");
    assert_eq!(group.docs[0].title, "ADR-014 Kafka naming");
    assert_eq!(group.docs[0].place, "eng");

    let found = client
        .docs
        .list(pb::ListDocsRequest {
            query: "team.entity".into(),
            ..Default::default()
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(found.groups[0].docs[0].excerpt, "Use `team.entity.v1`.");

    let doc = client
        .docs
        .read(pb::ReadDocRequest {
            id: group.docs[0].id.clone(),
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(doc.markdown, "# Topics\n\nUse `team.entity.v1`.");
    assert_eq!(doc.path, ["work", "eng"]);
    assert!(doc.file.ends_with("eng/ADR-014 Kafka naming.md"));

    let outside = client
        .docs
        .read(pb::ReadDocRequest {
            id: format!("{}/../../secret.md", source.id),
        })
        .await
        .unwrap_err();
    assert_ne!(outside.code(), Code::Ok);
}
