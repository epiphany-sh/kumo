//! `Docs` service end to end: an Obsidian vault source's notes, listed,
//! searched, browsed and read; ids from outside the vault are refused.

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

#[tokio::test]
async fn browses_a_vault_level_by_level() {
    let daemon = TestDaemon::start().await;
    let mut client = daemon.client().await;
    let vault = daemon.home().join("notes/work");
    std::fs::create_dir_all(vault.join("eng/runbooks")).unwrap();
    std::fs::create_dir_all(vault.join(".obsidian")).unwrap();
    std::fs::write(vault.join("Inbox.md"), "todo\n").unwrap();
    std::fs::write(vault.join("eng/ADR-014 Kafka naming.md"), "# Topics\n").unwrap();
    std::fs::write(
        vault.join("eng/runbooks/Deploy.md"),
        "One region at a time.\n",
    )
    .unwrap();
    std::fs::write(vault.join(".obsidian/app.md"), "hidden").unwrap();

    let unknown = client
        .docs
        .browse(pb::BrowseDocsRequest {
            source_id: "nope".into(),
            ..Default::default()
        })
        .await
        .unwrap_err();
    assert_eq!(unknown.code(), Code::NotFound);

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
    let browse = |parent: &str| pb::BrowseDocsRequest {
        source_id: source.id.clone(),
        parent: parent.into(),
        ..Default::default()
    };

    let top = client.docs.browse(browse("")).await.unwrap().into_inner();
    let entries: Vec<_> = top
        .nodes
        .iter()
        .map(|n| (n.title.as_str(), n.children, n.doc.is_some()))
        .collect();
    assert_eq!(entries, [("eng", 2, false), ("Inbox", 0, true)]);
    assert!(!top.truncated);

    let eng = client
        .docs
        .browse(browse(&top.nodes[0].key))
        .await
        .unwrap()
        .into_inner();
    let titles: Vec<_> = eng.nodes.iter().map(|n| n.title.as_str()).collect();
    assert_eq!(titles, ["runbooks", "ADR-014 Kafka naming"]);
    let doc = client
        .docs
        .read(pb::ReadDocRequest {
            id: eng.nodes[1].doc.as_ref().unwrap().id.clone(),
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(doc.markdown, "# Topics");

    let one = client
        .docs
        .browse(pb::BrowseDocsRequest {
            limit: 1,
            ..browse("")
        })
        .await
        .unwrap()
        .into_inner();
    assert_eq!(one.nodes.len(), 1);
    assert!(one.truncated);

    let outside = client.docs.browse(browse("../")).await.unwrap_err();
    assert_eq!(outside.code(), Code::InvalidArgument);
}
