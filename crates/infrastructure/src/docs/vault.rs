//! Obsidian: the notes of a vault source, read only. Newest first; search
//! looks at names, then at the text.

use std::fs;
use std::path::{Path, PathBuf};
use std::time::UNIX_EPOCH;

use kumo_domain::docs::{Doc, DocId, DocKind, DocNode, DocSummary, DocsConnector};
use kumo_domain::tasks::{SourceOptions, TaskError, TaskSource};

use crate::tasks::obsidian::{MAX_NOTE_BYTES, collect_notes, encode, safe_note};

/// Characters of text around a match.
const EXCERPT: usize = 160;

#[derive(Debug, Default)]
pub struct VaultDocs;

struct Note {
    relative: PathBuf,
    modified: Option<i64>,
}

fn vault(source: &TaskSource) -> Result<&Path, TaskError> {
    match &source.options {
        SourceOptions::Obsidian { vault } if vault.is_dir() => Ok(vault),
        SourceOptions::Obsidian { vault } => Err(TaskError::Unavailable(format!(
            "the vault folder is gone: {}",
            vault.display()
        ))),
        _ => Err(TaskError::Invalid("not an Obsidian source".into())),
    }
}

fn vault_name(vault: &Path) -> String {
    vault
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default()
}

/// Every readable note, newest first.
fn notes(vault: &Path) -> Vec<Note> {
    let mut found = Vec::new();
    collect_notes(vault, vault, &mut found);
    let mut notes: Vec<Note> = found
        .into_iter()
        .filter_map(|relative| {
            let meta = fs::metadata(vault.join(&relative)).ok()?;
            (meta.len() <= MAX_NOTE_BYTES).then(|| Note {
                modified: modified_ms(&meta),
                relative,
            })
        })
        .collect();
    notes.sort_by(|a, b| {
        b.modified
            .cmp(&a.modified)
            .then(a.relative.cmp(&b.relative))
    });
    notes
}

fn modified_ms(meta: &fs::Metadata) -> Option<i64> {
    meta.modified()
        .ok()
        .and_then(|m| m.duration_since(UNIX_EPOCH).ok())
        .and_then(|d| i64::try_from(d.as_millis()).ok())
}

/// A folder inside the vault, from a client: plain names only, none hidden,
/// and no symlink on the way (the same notes `collect_notes` would see).
fn safe_folder<'a>(vault: &Path, folder: &'a str) -> Result<&'a Path, TaskError> {
    let path = Path::new(folder);
    if path.as_os_str().is_empty() {
        return Err(TaskError::Invalid("not a vault folder".into()));
    }
    let mut at = vault.to_owned();
    for part in path.components() {
        let std::path::Component::Normal(name) = part else {
            return Err(TaskError::Invalid(format!("not a vault folder: {folder}")));
        };
        if name.to_string_lossy().starts_with('.') {
            return Err(TaskError::Invalid(format!("not a vault folder: {folder}")));
        }
        at.push(name);
        if !fs::symlink_metadata(&at).is_ok_and(|m| m.is_dir()) {
            return Err(TaskError::Invalid(format!("not a vault folder: {folder}")));
        }
    }
    Ok(path)
}

/// What one folder shows: its visible subfolders that hold notes somewhere
/// below, and its readable notes, unsorted.
fn level(vault: &Path, dir: &Path) -> (Vec<PathBuf>, Vec<(PathBuf, fs::Metadata)>) {
    let (mut folders, mut notes) = (Vec::new(), Vec::new());
    let Ok(entries) = fs::read_dir(dir) else {
        return (folders, notes);
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        if name.to_string_lossy().starts_with('.') {
            continue;
        }
        let Ok(kind) = entry.file_type() else {
            continue;
        };
        let path = entry.path();
        let Ok(relative) = path.strip_prefix(vault) else {
            continue;
        };
        if kind.is_dir() {
            let mut below = Vec::new();
            if name != "node_modules" {
                collect_notes(vault, &path, &mut below);
            }
            if !below.is_empty() {
                folders.push(relative.to_owned());
            }
        } else if kind.is_file()
            && path
                .extension()
                .is_some_and(|e| e.eq_ignore_ascii_case("md"))
            && let Ok(meta) = entry.metadata()
            && meta.len() <= MAX_NOTE_BYTES
        {
            notes.push((relative.to_owned(), meta));
        }
    }
    (folders, notes)
}

fn summary(source: &TaskSource, vault: &Path, note: &Note, excerpt: String) -> DocSummary {
    let relative = note.relative.to_string_lossy().replace('\\', "/");
    let folder = note
        .relative
        .parent()
        .map(|p| p.to_string_lossy().replace('\\', "/"))
        .unwrap_or_default();
    let name = vault_name(vault);
    DocSummary {
        id: DocId::new(&source.id, &relative),
        title: title_of(&note.relative),
        place: if folder.is_empty() {
            name.clone()
        } else {
            folder
        },
        updated_at: note.modified,
        author: None,
        url: format!(
            "obsidian://open?vault={}&file={}",
            encode(&name),
            encode(relative.trim_end_matches(".md"))
        ),
        excerpt,
    }
}

fn title_of(note: &Path) -> String {
    note.file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default()
}

/// The note without its YAML front matter.
fn body(text: &str) -> &str {
    let Some(rest) = text
        .strip_prefix("---\n")
        .or_else(|| text.strip_prefix("---\r\n"))
    else {
        return text;
    };
    let mut at = 0;
    for line in rest.split_inclusive('\n') {
        at += line.len();
        if line.trim_end() == "---" {
            return rest[at..].trim_start_matches(['\r', '\n']);
        }
    }
    text
}

/// The line holding `needle` (lowercase), cut around it.
fn excerpt_of(text: &str, needle: &str) -> Option<String> {
    let line = body(text)
        .lines()
        .find(|l| l.to_lowercase().contains(needle))?
        .trim();
    let line = line.trim_start_matches(['#', '-', '*', '>', ' ']);
    if line.chars().count() <= EXCERPT {
        return Some(line.to_owned());
    }
    let lower = line.to_lowercase();
    let hit = lower.find(needle).map_or(0, |b| lower[..b].chars().count());
    let start = hit.saturating_sub(EXCERPT / 3);
    let cut: String = line.chars().skip(start).take(EXCERPT).collect();
    Some(format!("{}{cut}…", if start > 0 { "…" } else { "" }))
}

impl DocsConnector for VaultDocs {
    fn kind(&self) -> DocKind {
        DocKind::Obsidian
    }

    fn recent(
        &self,
        source: &TaskSource,
        _secret: Option<&str>,
        limit: usize,
    ) -> Result<Vec<DocSummary>, TaskError> {
        let vault = vault(source)?;
        Ok(notes(vault)
            .iter()
            .take(limit)
            .map(|n| summary(source, vault, n, String::new()))
            .collect())
    }

    fn search(
        &self,
        source: &TaskSource,
        _secret: Option<&str>,
        query: &str,
        limit: usize,
    ) -> Result<Vec<DocSummary>, TaskError> {
        let vault = vault(source)?;
        let needle = query.trim().to_lowercase();
        if needle.is_empty() {
            return self.recent(source, None, limit);
        }
        let notes = notes(vault);
        // Names first, then text; each newest first.
        let (named, rest): (Vec<&Note>, Vec<&Note>) = notes.iter().partition(|n| {
            n.relative
                .to_string_lossy()
                .to_lowercase()
                .contains(&needle)
        });
        let mut found: Vec<DocSummary> = named
            .into_iter()
            .take(limit)
            .map(|n| summary(source, vault, n, String::new()))
            .collect();
        for note in rest {
            if found.len() >= limit {
                break;
            }
            let Ok(text) = fs::read_to_string(vault.join(&note.relative)) else {
                continue;
            };
            if let Some(excerpt) = excerpt_of(&text, &needle) {
                found.push(summary(source, vault, note, excerpt));
            }
        }
        Ok(found)
    }

    fn read(
        &self,
        source: &TaskSource,
        _secret: Option<&str>,
        external: &str,
    ) -> Result<Doc, TaskError> {
        let vault = vault(source)?;
        let relative = safe_note(external)?;
        let file = vault.join(relative);
        let meta = fs::metadata(&file)
            .map_err(|_| TaskError::Invalid(format!("the note is gone: {external}")))?;
        if meta.len() > MAX_NOTE_BYTES {
            return Err(TaskError::Invalid(format!("{external} is too big to show")));
        }
        let text = fs::read_to_string(&file)
            .map_err(|e| TaskError::Unavailable(format!("can't read {external}: {e}")))?;
        let note = Note {
            relative: relative.to_owned(),
            modified: modified_ms(&meta),
        };
        let mut path = vec![vault_name(vault)];
        if let Some(folder) = relative.parent() {
            path.extend(
                folder
                    .components()
                    .map(|c| c.as_os_str().to_string_lossy().into_owned()),
            );
        }
        Ok(Doc {
            summary: summary(source, vault, &note, String::new()),
            markdown: body(&text).trim_end().to_owned(),
            path,
            file: Some(file),
        })
    }

    /// Keys are paths relative to the vault: a folder's for folders, the
    /// note's for notes.
    fn browse(
        &self,
        source: &TaskSource,
        _secret: Option<&str>,
        parent: Option<&str>,
        limit: usize,
    ) -> Result<(Vec<DocNode>, bool), TaskError> {
        let vault = vault(source)?;
        let dir = match parent {
            None => vault.to_owned(),
            Some(folder) => vault.join(safe_folder(vault, folder)?),
        };
        let (folders, notes) = level(vault, &dir);
        let mut nodes: Vec<DocNode> = folders
            .into_iter()
            .map(|folder| {
                let (below, notes) = level(vault, &vault.join(&folder));
                DocNode {
                    key: folder.to_string_lossy().replace('\\', "/"),
                    title: folder
                        .file_name()
                        .map(|n| n.to_string_lossy().into_owned())
                        .unwrap_or_default(),
                    doc: None,
                    children: u32::try_from(below.len() + notes.len()).unwrap_or(u32::MAX),
                    note: String::new(),
                }
            })
            .collect();
        nodes.extend(notes.into_iter().map(|(relative, meta)| {
            let note = Note {
                modified: modified_ms(&meta),
                relative,
            };
            let doc = summary(source, vault, &note, String::new());
            DocNode {
                key: note.relative.to_string_lossy().replace('\\', "/"),
                title: doc.title.clone(),
                doc: Some(doc),
                children: 0,
                note: String::new(),
            }
        }));
        DocNode::sort(&mut nodes);
        let truncated = nodes.len() > limit;
        nodes.truncate(limit);
        Ok((nodes, truncated))
    }
}

#[cfg(test)]
mod tests {
    use kumo_domain::tasks::SourceId;

    use super::*;

    fn source(vault: &Path) -> TaskSource {
        TaskSource {
            id: SourceId::parse("ob1").unwrap(),
            name: "work".into(),
            options: SourceOptions::Obsidian {
                vault: vault.to_owned(),
            },
            enabled: true,
        }
    }

    fn write(path: &Path, text: &str, age_secs: u64) {
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(path, text).unwrap();
        let when = std::time::SystemTime::now() - std::time::Duration::from_secs(age_secs);
        fs::File::options()
            .write(true)
            .open(path)
            .unwrap()
            .set_modified(when)
            .unwrap();
    }

    fn vault_dir() -> tempfile::TempDir {
        let dir = tempfile::tempdir().unwrap();
        let v = dir.path();
        write(
            &v.join("PRC-412 scratchpad.md"),
            "---\ntags: [prc]\n---\n# Bulk\n\nDiscounts by category.\n",
            10,
        );
        write(
            &v.join("eng/pgx CopyFrom notes.md"),
            "Use CopyFrom for bulk inserts.\n",
            100,
        );
        write(
            &v.join("eng/runbooks/Deploy.md"),
            "Roll out one region at a time.\n",
            1000,
        );
        write(&v.join(".obsidian/workspace.md"), "hidden", 1);
        write(&v.join("eng/old.txt"), "not a note", 1);
        fs::create_dir_all(v.join("drafts")).unwrap();
        dir
    }

    #[test]
    fn lists_notes_newest_first() {
        let dir = vault_dir();
        let docs = VaultDocs.recent(&source(dir.path()), None, 10).unwrap();
        let titles: Vec<_> = docs
            .iter()
            .map(|d| (d.title.as_str(), d.place.as_str()))
            .collect();
        let name = vault_name(dir.path());
        assert_eq!(
            titles,
            [
                ("PRC-412 scratchpad", name.as_str()),
                ("pgx CopyFrom notes", "eng"),
                ("Deploy", "eng/runbooks")
            ]
        );
        assert_eq!(docs[1].id.as_str(), "ob1/eng/pgx CopyFrom notes.md");
        assert!(docs[1].url.starts_with("obsidian://open?vault="));
        assert!(docs[1].url.ends_with("&file=eng/pgx%20CopyFrom%20notes"));
    }

    #[test]
    fn search_matches_names_then_text() {
        let dir = vault_dir();
        let src = source(dir.path());
        let docs = VaultDocs.search(&src, None, "BULK", 10).unwrap();
        assert_eq!(docs.len(), 2);
        // Neither name says "bulk": both by text, newest first.
        assert_eq!(docs[0].excerpt, "Bulk");
        assert_eq!(docs[1].excerpt, "Use CopyFrom for bulk inserts.");
        let named = VaultDocs.search(&src, None, "pgx", 10).unwrap();
        assert_eq!(
            (named[0].title.as_str(), named[0].excerpt.as_str()),
            ("pgx CopyFrom notes", "")
        );
        assert!(
            VaultDocs.search(&src, None, "tags", 10).unwrap().is_empty(),
            "front matter isn't text"
        );
    }

    #[test]
    fn reads_a_note_without_front_matter_and_stays_in_the_vault() {
        let dir = vault_dir();
        let src = source(dir.path());
        let doc = VaultDocs.read(&src, None, "PRC-412 scratchpad.md").unwrap();
        assert_eq!(doc.markdown, "# Bulk\n\nDiscounts by category.");
        assert_eq!(
            doc.file.as_deref(),
            Some(dir.path().join("PRC-412 scratchpad.md").as_path())
        );
        let nested = VaultDocs
            .read(&src, None, "eng/pgx CopyFrom notes.md")
            .unwrap();
        assert_eq!(nested.path, [vault_name(dir.path()), "eng".into()]);
        assert!(VaultDocs.read(&src, None, "../secret.md").is_err());
        assert!(VaultDocs.read(&src, None, "eng/old.txt").is_err());
    }

    fn titles(nodes: &[DocNode]) -> Vec<(&str, &str, u32, bool)> {
        nodes
            .iter()
            .map(|n| {
                (
                    n.key.as_str(),
                    n.title.as_str(),
                    n.children,
                    n.doc.is_some(),
                )
            })
            .collect()
    }

    #[test]
    fn browses_folders_first_then_notes() {
        let dir = vault_dir();
        let src = source(dir.path());
        let (root, truncated) = VaultDocs.browse(&src, None, None, 200).unwrap();
        assert_eq!(
            titles(&root),
            [
                ("eng", "eng", 2, false),
                ("PRC-412 scratchpad.md", "PRC-412 scratchpad", 0, true)
            ],
            "no .obsidian, no folder without notes"
        );
        assert!(!truncated);
        let (eng, _) = VaultDocs.browse(&src, None, Some("eng"), 200).unwrap();
        assert_eq!(
            titles(&eng),
            [
                ("eng/runbooks", "runbooks", 1, false),
                ("eng/pgx CopyFrom notes.md", "pgx CopyFrom notes", 0, true)
            ]
        );
        let doc = eng[1].doc.as_ref().unwrap();
        assert_eq!(doc.id.as_str(), "ob1/eng/pgx CopyFrom notes.md");
        assert_eq!(doc.place, "eng");
        let read = VaultDocs.read(&src, None, doc.id.external()).unwrap();
        assert_eq!(read.markdown, "Use CopyFrom for bulk inserts.");
        let (deep, _) = VaultDocs
            .browse(&src, None, Some("eng/runbooks"), 200)
            .unwrap();
        assert_eq!(
            titles(&deep),
            [("eng/runbooks/Deploy.md", "Deploy", 0, true)]
        );
    }

    #[test]
    fn browse_stays_in_the_vault_and_caps_the_level() {
        let dir = vault_dir();
        let src = source(dir.path());
        for parent in [
            "../",
            "..",
            "eng/../..",
            "/etc",
            ".obsidian",
            "eng/old.txt",
            "nope",
            "",
        ] {
            assert!(
                matches!(
                    VaultDocs.browse(&src, None, Some(parent), 200),
                    Err(TaskError::Invalid(_))
                ),
                "{parent:?}"
            );
        }
        let (one, truncated) = VaultDocs.browse(&src, None, None, 1).unwrap();
        assert_eq!(titles(&one), [("eng", "eng", 2, false)]);
        assert!(truncated);
    }

    #[cfg(unix)]
    #[test]
    fn browse_skips_symlinks_out_of_the_vault() {
        let dir = vault_dir();
        let outside = tempfile::tempdir().unwrap();
        write(&outside.path().join("secret.md"), "s", 1);
        std::os::unix::fs::symlink(outside.path(), dir.path().join("linked")).unwrap();
        let src = source(dir.path());
        let (root, _) = VaultDocs.browse(&src, None, None, 200).unwrap();
        assert!(root.iter().all(|n| n.key != "linked"));
        assert!(VaultDocs.browse(&src, None, Some("linked"), 200).is_err());
    }
}
