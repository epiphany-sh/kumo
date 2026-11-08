//! Agent files and the folders runs work in, on the local disk.

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use kumo_domain::agent_defs::{AgentDefFiles, FoundFile, check_agent_name};
use kumo_domain::agents::AgentError;
use serde_json::Value;

/// [`AgentDefFiles`] on the local file system.
#[derive(Debug, Clone, Copy, Default)]
pub struct LocalAgentDefFiles;

fn io_error(what: &str, path: &Path, error: std::io::Error) -> AgentError {
    AgentError::Store(format!("can't {what} {}: {error}", path.display()))
}

fn modified_ms(meta: &fs::Metadata) -> i64 {
    meta.modified()
        .ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map_or(0, |d| i64::try_from(d.as_millis()).unwrap_or(i64::MAX))
}

fn read_one(path: &Path) -> std::io::Result<FoundFile> {
    let markdown = fs::read_to_string(path)?;
    let meta = fs::metadata(path)?;
    Ok(FoundFile {
        name: path
            .file_stem()
            .map(|s| s.to_string_lossy().into_owned())
            .unwrap_or_default(),
        markdown,
        path: path.to_owned(),
        modified_unix_ms: modified_ms(&meta),
    })
}

/// The names in `object` (a JSON object), if it is one.
fn keys(object: Option<&Value>) -> impl Iterator<Item = String> + '_ {
    object
        .and_then(Value::as_object)
        .into_iter()
        .flat_map(|o| o.keys().cloned())
}

fn json(path: &Path) -> Option<Value> {
    serde_json::from_str(&fs::read_to_string(path).ok()?).ok()
}

impl AgentDefFiles for LocalAgentDefFiles {
    fn list(&self, dir: &Path) -> Result<Vec<FoundFile>, AgentError> {
        let entries = match fs::read_dir(dir) {
            Ok(entries) => entries,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
            Err(e) => return Err(io_error("read", dir, e)),
        };
        let mut found = Vec::new();
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().is_none_or(|e| e != "md") || !path.is_file() {
                continue;
            }
            match read_one(&path) {
                Ok(file) => found.push(file),
                Err(error) => {
                    tracing::warn!(path = %path.display(), %error, "agent file skipped");
                }
            }
        }
        found.sort_by(|a, b| a.name.cmp(&b.name));
        Ok(found)
    }

    fn write(&self, dir: &Path, name: &str, markdown: &str) -> Result<FoundFile, AgentError> {
        check_agent_name(name)?;
        fs::create_dir_all(dir).map_err(|e| io_error("create", dir, e))?;
        let path = dir.join(format!("{name}.md"));
        let temp = dir.join(format!(".{name}.md.kumo-tmp"));
        let written = fs::File::create(&temp)
            .and_then(|mut f| f.write_all(markdown.as_bytes()).and_then(|()| f.sync_all()))
            .and_then(|()| fs::rename(&temp, &path));
        if let Err(error) = written {
            let _ = fs::remove_file(&temp);
            return Err(io_error("write", &path, error));
        }
        read_one(&path).map_err(|e| io_error("read", &path, e))
    }

    fn remove(&self, dir: &Path, name: &str) -> Result<(), AgentError> {
        check_agent_name(name)?;
        let path = dir.join(format!("{name}.md"));
        match fs::remove_file(&path) {
            Ok(()) => Ok(()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
            Err(e) => Err(io_error("remove", &path, e)),
        }
    }

    fn folders(&self, dir: &Path) -> Vec<String> {
        let mut names: Vec<String> = fs::read_dir(dir)
            .into_iter()
            .flatten()
            .flatten()
            .filter(|e| e.path().is_dir())
            .map(|e| e.file_name().to_string_lossy().into_owned())
            .filter(|n| !n.starts_with('.'))
            .collect();
        names.sort();
        names
    }

    fn mcp_servers(&self, config: &Path, repos: &[PathBuf]) -> Vec<String> {
        let mut names = Vec::new();
        if let Some(config) = json(config) {
            names.extend(keys(config.get("mcpServers")));
            let projects = config.get("projects");
            for repo in repos {
                let project = projects.and_then(|p| p.get(repo.display().to_string()));
                names.extend(keys(project.and_then(|p| p.get("mcpServers"))));
            }
        }
        for repo in repos {
            if let Some(shared) = json(&repo.join(".mcp.json")) {
                names.extend(keys(shared.get("mcpServers")));
            }
        }
        names.sort();
        names.dedup();
        names
    }

    fn create_dir(&self, dir: &Path) -> Result<(), AgentError> {
        fs::create_dir_all(dir).map_err(|e| io_error("create", dir, e))
    }

    fn write_file(&self, path: &Path, text: &str) -> Result<(), AgentError> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|e| io_error("create", parent, e))?;
        }
        fs::write(path, text).map_err(|e| io_error("write", path, e))
    }

    fn exists(&self, path: &Path) -> bool {
        path.exists()
    }

    fn remove_dir(&self, dir: &Path) {
        if let Err(error) = fs::remove_dir_all(dir)
            && error.kind() != std::io::ErrorKind::NotFound
        {
            tracing::warn!(dir = %dir.display(), %error, "folder left behind");
        }
    }

    fn sweep(&self, dir: &Path, age: Duration) -> usize {
        let Some(cutoff) = SystemTime::now().checked_sub(age) else {
            return 0;
        };
        let mut removed = 0;
        for entry in fs::read_dir(dir).into_iter().flatten().flatten() {
            let path = entry.path();
            let old = entry
                .metadata()
                .and_then(|m| m.modified())
                .is_ok_and(|t| t < cutoff);
            if path.is_dir() && old && fs::remove_dir_all(&path).is_ok() {
                removed += 1;
            }
        }
        removed
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn writes_lists_and_removes_agent_files() {
        let dir = tempfile::tempdir().unwrap();
        let agents = dir.path().join("agents");
        let files = LocalAgentDefFiles;
        assert!(files.list(&agents).unwrap().is_empty(), "no folder yet");
        let saved = files
            .write(&agents, "rev", "---\nname: rev\n---\nHi\n")
            .unwrap();
        assert_eq!(saved.path, agents.join("rev.md"));
        fs::write(agents.join("notes.txt"), "x").unwrap();
        fs::create_dir(agents.join("sub.md")).unwrap();
        let listed = files.list(&agents).unwrap();
        assert_eq!(listed.len(), 1);
        assert_eq!(
            (listed[0].name.as_str(), listed[0].markdown.as_str()),
            ("rev", "---\nname: rev\n---\nHi\n")
        );
        assert!(listed[0].modified_unix_ms > 0);
        assert!(files.write(&agents, "../x", "").is_err());
        assert!(!dir.path().join("x.md").exists());
        files.remove(&agents, "rev").unwrap();
        files.remove(&agents, "rev").unwrap();
        assert!(files.list(&agents).unwrap().is_empty());
        assert!(
            fs::read_dir(&agents)
                .unwrap()
                .flatten()
                .all(|e| !e.file_name().to_string_lossy().contains("kumo-tmp")),
            "no temp file left"
        );
    }

    #[test]
    fn skills_and_mcp_servers() {
        let dir = tempfile::tempdir().unwrap();
        let skills = dir.path().join("skills");
        fs::create_dir_all(skills.join("go-tests")).unwrap();
        fs::create_dir_all(skills.join(".hidden")).unwrap();
        fs::write(skills.join("file.md"), "").unwrap();
        assert_eq!(LocalAgentDefFiles.folders(&skills), ["go-tests"]);

        let repo = dir.path().join("app");
        fs::create_dir_all(&repo).unwrap();
        fs::write(repo.join(".mcp.json"), r#"{"mcpServers":{"postgres":{}}}"#).unwrap();
        let config = dir.path().join(".claude.json");
        let project = repo.display().to_string();
        fs::write(
            &config,
            serde_json::json!({"mcpServers": {"jira": {}}, "projects": {project: {"mcpServers": {"gitlab": {}, "jira": {}}}}}).to_string(),
        )
        .unwrap();
        assert_eq!(
            LocalAgentDefFiles.mcp_servers(&config, &[repo]),
            ["gitlab", "jira", "postgres"]
        );
        assert!(
            LocalAgentDefFiles
                .mcp_servers(&dir.path().join("none.json"), &[])
                .is_empty()
        );
    }

    #[test]
    fn sweep_removes_old_folders_only() {
        let dir = tempfile::tempdir().unwrap();
        fs::create_dir(dir.path().join("fresh")).unwrap();
        assert_eq!(
            LocalAgentDefFiles.sweep(dir.path(), Duration::from_secs(3600)),
            0
        );
        assert_eq!(LocalAgentDefFiles.sweep(dir.path(), Duration::ZERO), 1);
        assert!(!dir.path().join("fresh").exists());
    }
}
