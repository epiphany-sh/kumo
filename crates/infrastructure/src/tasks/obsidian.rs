//! Obsidian: checkboxes in the Markdown notes of a vault. Files are re-read
//! only when they change; status changes rewrite just the checkbox's mark.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, PoisonError};
use std::time::SystemTime;

use kumo_domain::tasks::{
    Checkbox, Detected, SourceId, SourceKind, SourceOptions, Task, TaskConnector, TaskDetail,
    TaskError, TaskId, TaskSource, TaskStatus, parse_checkboxes, section_around, set_checkbox,
};

/// Notes bigger than this are skipped (exports, logs pasted in a note).
const MAX_NOTE_BYTES: u64 = 4 * 1024 * 1024;

/// Parsed checkboxes of one note, valid while its mtime and size hold.
#[derive(Debug)]
struct Parsed {
    modified: Option<SystemTime>,
    size: u64,
    boxes: Vec<Checkbox>,
}

#[derive(Debug)]
pub struct ObsidianConnector {
    home: PathBuf,
    /// Per source: note (relative path) → parsed checkboxes.
    cache: Mutex<HashMap<SourceId, HashMap<PathBuf, Parsed>>>,
}

impl ObsidianConnector {
    /// `home` is where Obsidian's own settings (the list of vaults) live.
    pub fn new(home: impl Into<PathBuf>) -> Self {
        Self {
            home: home.into(),
            cache: Mutex::new(HashMap::new()),
        }
    }

    fn vault(source: &TaskSource) -> Result<&Path, TaskError> {
        match &source.options {
            SourceOptions::Obsidian { vault } => Ok(vault),
            _ => Err(TaskError::Invalid("not an Obsidian source".into())),
        }
    }

    /// Obsidian's list of vaults (`obsidian.json`).
    fn settings_file(&self) -> PathBuf {
        if cfg!(target_os = "macos") {
            self.home
                .join("Library/Application Support/obsidian/obsidian.json")
        } else if cfg!(windows) {
            self.home.join("AppData/Roaming/obsidian/obsidian.json")
        } else {
            self.home.join(".config/obsidian/obsidian.json")
        }
    }
}

impl TaskConnector for ObsidianConnector {
    fn kind(&self) -> SourceKind {
        SourceKind::Obsidian
    }

    fn fetch(&self, source: &TaskSource, _secret: Option<&str>) -> Result<Vec<Task>, TaskError> {
        let vault = Self::vault(source)?;
        if !vault.is_dir() {
            return Err(TaskError::Unavailable(format!(
                "the vault folder is gone: {}",
                vault.display()
            )));
        }
        let mut notes = Vec::new();
        collect_notes(vault, vault, &mut notes);
        notes.sort();

        let mut cache = self.cache.lock().unwrap_or_else(PoisonError::into_inner);
        let parsed = cache.entry(source.id.clone()).or_default();
        parsed.retain(|note, _| notes.binary_search(note).is_ok());
        let vault_name = vault
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_default();

        let mut tasks = Vec::new();
        for note in &notes {
            let path = vault.join(note);
            let Ok(meta) = fs::metadata(&path) else {
                continue;
            };
            if meta.len() > MAX_NOTE_BYTES {
                continue;
            }
            let modified = meta.modified().ok();
            let fresh = parsed.get(note).is_some_and(|p| {
                p.modified == modified && modified.is_some() && p.size == meta.len()
            });
            if !fresh {
                let Ok(text) = fs::read_to_string(&path) else {
                    continue;
                };
                parsed.insert(
                    note.clone(),
                    Parsed {
                        modified,
                        size: meta.len(),
                        boxes: parse_checkboxes(&text),
                    },
                );
            }
            let boxes = parsed
                .get(note)
                .map(|p| p.boxes.as_slice())
                .unwrap_or_default();
            tasks.extend(
                boxes
                    .iter()
                    .map(|b| to_task(&source.id, &vault_name, note, b)),
            );
        }
        Ok(tasks)
    }

    fn set_status(
        &self,
        source: &TaskSource,
        _secret: Option<&str>,
        task: &Task,
        status: TaskStatus,
    ) -> Result<(), TaskError> {
        let vault = Self::vault(source)?;
        let (note, id) = task
            .id
            .external()
            .rsplit_once('#')
            .ok_or_else(|| TaskError::UnknownTask(task.id.to_string()))?;
        let note = safe_note(note)?;
        let path = vault.join(note);
        let text = fs::read_to_string(&path)
            .map_err(|e| TaskError::Unavailable(format!("can't read {}: {e}", note.display())))?;
        let updated =
            set_checkbox(&text, id, status).ok_or(TaskError::Conflict(SourceKind::Obsidian))?;
        if updated != text {
            write_atomically(&path, updated.as_bytes()).map_err(|e| {
                TaskError::Unavailable(format!("can't write {}: {e}", note.display()))
            })?;
        }
        Ok(())
    }

    /// The checkbox with the section of the note it's in.
    fn detail(
        &self,
        source: &TaskSource,
        _secret: Option<&str>,
        id: &TaskId,
        _known: Option<&Task>,
    ) -> Result<TaskDetail, TaskError> {
        let vault = Self::vault(source)?;
        let (note, checkbox) = id
            .external()
            .rsplit_once('#')
            .ok_or_else(|| TaskError::UnknownTask(id.to_string()))?;
        let note = safe_note(note)?;
        let text = match fs::read_to_string(vault.join(note)) {
            Ok(text) => text,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound && vault.is_dir() => {
                return Err(TaskError::UnknownTask(id.to_string()));
            }
            Err(e) => {
                return Err(TaskError::Unavailable(format!(
                    "can't read {}: {e}",
                    note.display()
                )));
            }
        };
        let found = parse_checkboxes(&text)
            .into_iter()
            .find(|b| b.id == checkbox)
            .ok_or_else(|| TaskError::UnknownTask(id.to_string()))?;
        let vault_name = vault
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_default();
        Ok(TaskDetail {
            description: section_around(&text, found.line),
            location: format!(
                "{} · line {}",
                note.to_string_lossy().replace('\\', "/"),
                found.line + 1
            ),
            ..TaskDetail::basic(to_task(&source.id, &vault_name, note, &found))
        })
    }

    fn test(&self, source: &TaskSource, secret: Option<&str>) -> Result<String, TaskError> {
        let vault = Self::vault(source)?;
        if !vault.join(".obsidian").is_dir() && !vault.is_dir() {
            return Err(TaskError::Invalid(format!(
                "{} isn't a folder",
                vault.display()
            )));
        }
        let probe = TaskSource {
            id: SourceId::generate(),
            ..source.clone()
        };
        let tasks = self.fetch(&probe, secret)?;
        self.cache
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(&probe.id);
        let open = tasks
            .iter()
            .filter(|t| t.status != TaskStatus::Done)
            .count();
        Ok(format!("{open} open tasks, {} in total", tasks.len()))
    }

    fn watched_paths(&self, source: &TaskSource) -> Vec<PathBuf> {
        Self::vault(source)
            .map(|v| vec![v.to_owned()])
            .unwrap_or_default()
    }

    fn detect(&self) -> Vec<Detected> {
        let Ok(text) = fs::read_to_string(self.settings_file()) else {
            return vec![];
        };
        let Ok(settings) = serde_json::from_str::<serde_json::Value>(&text) else {
            return vec![];
        };
        let Some(vaults) = settings.get("vaults").and_then(|v| v.as_object()) else {
            return vec![];
        };
        let mut found: Vec<(i64, Detected)> = vaults
            .values()
            .filter_map(|vault| {
                let path = PathBuf::from(vault.get("path")?.as_str()?);
                let opened = vault
                    .get("ts")
                    .and_then(serde_json::Value::as_i64)
                    .unwrap_or(0);
                path.is_dir().then(|| {
                    let name = path.file_name().map(|n| n.to_string_lossy().into_owned());
                    (
                        opened,
                        Detected {
                            name: name.unwrap_or_else(|| "Obsidian".into()),
                            options: SourceOptions::Obsidian { vault: path },
                        },
                    )
                })
            })
            .collect();
        found.sort_by_key(|(opened, _)| std::cmp::Reverse(*opened));
        found.into_iter().map(|(_, d)| d).collect()
    }
}

/// `.md` files under `dir`, relative to `vault`, skipping hidden folders
/// (`.obsidian`, `.trash`, `.git`) and symlinked ones.
fn collect_notes(vault: &Path, dir: &Path, notes: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
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
        if kind.is_dir() {
            if name != "node_modules" {
                collect_notes(vault, &path, notes);
            }
        } else if kind.is_file()
            && path
                .extension()
                .is_some_and(|e| e.eq_ignore_ascii_case("md"))
            && let Ok(relative) = path.strip_prefix(vault)
        {
            notes.push(relative.to_owned());
        }
    }
}

fn to_task(source: &SourceId, vault: &str, note: &Path, b: &Checkbox) -> Task {
    let note_name = note
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default();
    let folder = note
        .parent()
        .map(|p| p.to_string_lossy().replace('\\', "/"))
        .unwrap_or_default();
    let relative = note.to_string_lossy().replace('\\', "/");
    Task {
        key: note_name,
        status: b.status,
        priority: b.priority,
        due: b.due.clone(),
        url: Some(format!(
            "obsidian://open?vault={}&file={}",
            encode(vault),
            encode(relative.trim_end_matches(".md"))
        )),
        context: folder,
        labels: b.tags.clone(),
        ..Task::new(
            TaskId::new(source, &format!("{relative}#{}", b.id)),
            b.title.clone(),
        )
    }
    .personal()
}

/// A relative path inside the vault (task ids come from clients).
fn safe_note(note: &str) -> Result<&Path, TaskError> {
    let path = Path::new(note);
    let inside = path
        .components()
        .all(|c| matches!(c, std::path::Component::Normal(_)));
    if inside
        && path
            .extension()
            .is_some_and(|e| e.eq_ignore_ascii_case("md"))
    {
        Ok(path)
    } else {
        Err(TaskError::UnknownTask(note.to_owned()))
    }
}

/// Writes next to the file and renames over it, so Obsidian (or a sync
/// tool) never sees half a note.
fn write_atomically(path: &Path, bytes: &[u8]) -> std::io::Result<()> {
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    let temp = path.with_file_name(format!(".{name}.kumo-tmp"));
    if let Ok(meta) = fs::metadata(path) {
        fs::write(&temp, bytes)?;
        fs::set_permissions(&temp, meta.permissions())?;
    } else {
        fs::write(&temp, bytes)?;
    }
    fs::rename(&temp, path).inspect_err(|_| {
        let _ = fs::remove_file(&temp);
    })
}

/// Percent-encodes for a URL query value.
fn encode(raw: &str) -> String {
    raw.bytes()
        .map(|b| match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' | b'/' => {
                char::from(b).to_string()
            }
            _ => format!("%{b:02X}"),
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn source(vault: &Path) -> TaskSource {
        TaskSource {
            id: SourceId::parse("ob").unwrap(),
            name: "Vault".into(),
            options: SourceOptions::Obsidian {
                vault: vault.to_owned(),
            },
            enabled: true,
        }
    }

    fn write(path: &Path, text: &str) {
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(path, text).unwrap();
    }

    #[test]
    fn reads_checkboxes_from_notes_and_writes_status_back() {
        let dir = tempfile::tempdir().unwrap();
        let vault = dir.path().join("My Vault");
        write(
            &vault.join("Inbox.md"),
            "- [ ] Call Ana ⏫ #work\n- [x] Old\n",
        );
        write(
            &vault.join("Projects/Kumo plan.md"),
            "Notes\n\n* [/] Ship tasks 📅 2026-11-02\n",
        );
        write(
            &vault.join(".obsidian/workspace.md"),
            "- [ ] settings, not a note\n",
        );
        write(&vault.join(".trash/Gone.md"), "- [ ] deleted\n");
        write(&vault.join("image.png"), "- [ ] not markdown\n");

        let connector = ObsidianConnector::new(dir.path());
        let src = source(&vault);
        let tasks = connector.fetch(&src, None).unwrap();
        let summary: Vec<_> = tasks
            .iter()
            .map(|t| {
                (
                    t.key.as_str(),
                    t.title.as_str(),
                    t.status,
                    t.context.as_str(),
                )
            })
            .collect();
        assert_eq!(
            summary,
            [
                ("Inbox", "Call Ana", TaskStatus::Todo, ""),
                ("Inbox", "Old", TaskStatus::Done, ""),
                ("Kumo plan", "Ship tasks", TaskStatus::Doing, "Projects"),
            ]
        );
        assert_eq!(tasks[0].labels, ["work"]);
        assert_eq!(tasks[2].due.as_deref(), Some("2026-11-02"));
        assert_eq!(
            tasks[2].url.as_deref(),
            Some("obsidian://open?vault=My%20Vault&file=Projects/Kumo%20plan")
        );

        connector
            .set_status(&src, None, &tasks[2], TaskStatus::Done)
            .unwrap();
        assert_eq!(
            fs::read_to_string(vault.join("Projects/Kumo plan.md")).unwrap(),
            "Notes\n\n* [x] Ship tasks 📅 2026-11-02\n"
        );
        let again = connector.fetch(&src, None).unwrap();
        assert_eq!(
            again[2].status,
            TaskStatus::Done,
            "re-read after the change"
        );
        assert_eq!(again[2].id, tasks[2].id);

        // Edited elsewhere in the meantime: refuse instead of guessing.
        write(&vault.join("Inbox.md"), "- [ ] Call Ana tomorrow\n");
        let stale = connector.set_status(&src, None, &tasks[0], TaskStatus::Done);
        assert_eq!(stale, Err(TaskError::Conflict(SourceKind::Obsidian)));
    }

    #[test]
    fn details_say_where_the_checkbox_is_and_what_surrounds_it() {
        let dir = tempfile::tempdir().unwrap();
        let vault = dir.path().join("Vault");
        write(
            &vault.join("Weekly.md"),
            "# Weekly\n\n## Semana 44\n- [x] Mandar resumen\n- [ ] Revisar costos de AWS 📅 2026-10-31\n\n## Semana 45\n- [ ] Otra\n",
        );
        let connector = ObsidianConnector::new(dir.path());
        let src = source(&vault);
        let tasks = connector.fetch(&src, None).unwrap();
        let aws = tasks
            .iter()
            .find(|t| t.title == "Revisar costos de AWS")
            .unwrap();
        assert!(aws.mine && aws.kind == kumo_domain::tasks::TaskType::Todo);
        let detail = connector.detail(&src, None, &aws.id, Some(aws)).unwrap();
        assert_eq!(detail.location, "Weekly.md · line 5");
        assert_eq!(
            detail.description,
            "## Semana 44\n- [x] Mandar resumen\n- [ ] Revisar costos de AWS 📅 2026-10-31"
        );
        assert_eq!(&detail.task, aws);

        let gone = TaskId::new(&src.id, "Weekly.md#0000");
        assert!(matches!(
            connector.detail(&src, None, &gone, None),
            Err(TaskError::UnknownTask(_))
        ));
        let outside = TaskId::new(&src.id, "../x.md#0000");
        assert!(matches!(
            connector.detail(&src, None, &outside, None),
            Err(TaskError::UnknownTask(_))
        ));
    }

    #[test]
    fn refuses_paths_outside_the_vault() {
        let dir = tempfile::tempdir().unwrap();
        let connector = ObsidianConnector::new(dir.path());
        let src = source(dir.path());
        let mut task = connector
            .fetch(&src, None)
            .unwrap()
            .pop()
            .unwrap_or_else(|| Task::new(TaskId::new(&src.id, "../outside.md#abc"), ""));
        assert!(matches!(
            connector.set_status(&src, None, &task, TaskStatus::Done),
            Err(TaskError::UnknownTask(_))
        ));
        task.id = TaskId::new(&src.id, "/etc/hosts.md#abc");
        assert!(
            connector
                .set_status(&src, None, &task, TaskStatus::Done)
                .is_err()
        );
    }

    #[test]
    fn detects_vaults_from_obsidian_settings() {
        let dir = tempfile::tempdir().unwrap();
        let (a, b) = (dir.path().join("Work"), dir.path().join("Personal"));
        fs::create_dir_all(&a).unwrap();
        fs::create_dir_all(&b).unwrap();
        let connector = ObsidianConnector::new(dir.path());
        let settings = serde_json::json!({"vaults": {
            "1": {"path": a, "ts": 10},
            "2": {"path": b, "ts": 20, "open": true},
            "3": {"path": dir.path().join("Missing"), "ts": 30},
        }});
        write(&connector.settings_file(), &settings.to_string());
        let names: Vec<_> = connector.detect().into_iter().map(|d| d.name).collect();
        assert_eq!(
            names,
            ["Personal", "Work"],
            "most recently opened first, missing ones skipped"
        );
    }
}
