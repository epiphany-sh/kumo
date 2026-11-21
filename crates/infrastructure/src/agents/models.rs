//! The models the CLIs list for the signed-in account.
//!
//! Codex keeps them in `<codex home>/models_cache.json` (fetched by the CLI
//! itself): each with its slug, the name it shows, whether it's listed or
//! hidden, its order and the reasoning levels it takes. The others don't
//! keep a list Kumo can read.

use std::path::{Path, PathBuf};

use kumo_domain::agents::{ModelCatalog, ModelChoice};
use serde_json::Value;

/// [`ModelCatalog`] reading the CLIs' own files in this profile's homes.
#[derive(Debug, Clone)]
pub struct CliModelCatalog {
    codex_home: PathBuf,
}

impl CliModelCatalog {
    pub fn new(codex_home: &Path) -> Self {
        Self {
            codex_home: codex_home.to_path_buf(),
        }
    }
}

impl ModelCatalog for CliModelCatalog {
    fn listed(&self, provider_id: &str) -> Vec<ModelChoice> {
        match provider_id {
            "codex" => std::fs::read_to_string(self.codex_home.join("models_cache.json"))
                .map(|raw| codex_models(&raw))
                .unwrap_or_default(),
            _ => Vec::new(),
        }
    }
}

/// Listed models (not hidden ones), in Codex's own order.
fn codex_models(raw: &str) -> Vec<ModelChoice> {
    let Ok(cache) = serde_json::from_str::<Value>(raw) else {
        return Vec::new();
    };
    let Some(models) = cache.get("models").and_then(Value::as_array) else {
        return Vec::new();
    };
    let mut listed: Vec<(i64, ModelChoice)> = models
        .iter()
        .filter(|m| m.get("visibility").and_then(Value::as_str) == Some("list"))
        .filter_map(|m| {
            let id = m.get("slug").and_then(Value::as_str)?.trim();
            // A slug becomes an argument: nothing that reads as an option.
            if id.is_empty() || id.starts_with('-') || id.chars().any(char::is_whitespace) {
                return None;
            }
            let name = m
                .get("display_name")
                .and_then(Value::as_str)
                .filter(|n| !n.trim().is_empty())
                .unwrap_or(id);
            let efforts = m
                .get("supported_reasoning_levels")
                .and_then(Value::as_array)
                .map(|levels| {
                    levels
                        .iter()
                        .filter_map(|l| {
                            l.get("effort")
                                .and_then(Value::as_str)
                                .or_else(|| l.as_str())
                        })
                        .filter(|e| e.chars().all(|c| c.is_ascii_alphanumeric()))
                        .map(str::to_owned)
                        .collect()
                })
                .unwrap_or_default();
            let priority = m
                .get("priority")
                .and_then(Value::as_i64)
                .unwrap_or(i64::MAX);
            Some((
                priority,
                ModelChoice {
                    id: id.to_owned(),
                    name: name.to_owned(),
                    efforts,
                },
            ))
        })
        .collect();
    listed.sort_by_key(|(priority, _)| *priority);
    listed.into_iter().map(|(_, m)| m).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    const CACHE: &str = r#"{
        "fetched_at": "2026-11-13T23:05:07Z",
        "models": [
            {"slug": "model-b", "display_name": "Model B", "visibility": "list", "priority": 2,
             "supported_reasoning_levels": [{"effort": "low"}, {"effort": "medium"}]},
            {"slug": "hidden-one", "display_name": "Hidden", "visibility": "hide", "priority": 0,
             "supported_reasoning_levels": [{"effort": "low"}]},
            {"slug": "model-a", "display_name": "Model A", "visibility": "list", "priority": 1,
             "supported_reasoning_levels": [{"effort": "low"}, {"effort": "x\"y"}, {"effort": "max"}]},
            {"slug": "--rm", "display_name": "Bad", "visibility": "list", "priority": 3}
        ]
    }"#;

    #[test]
    fn lists_codex_models_in_order_with_their_efforts() {
        let models = codex_models(CACHE);
        let ids: Vec<&str> = models.iter().map(|m| m.id.as_str()).collect();
        assert_eq!(ids, ["model-a", "model-b"]);
        assert_eq!(models[0].name, "Model A");
        assert_eq!(models[0].efforts, ["low", "max"]);
    }

    #[test]
    fn reads_the_cache_in_the_codex_home_only_for_codex() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("models_cache.json"), CACHE).unwrap();
        let catalog = CliModelCatalog::new(dir.path());
        assert_eq!(catalog.listed("codex").len(), 2);
        assert!(catalog.listed("claude").is_empty());
        assert!(
            CliModelCatalog::new(&dir.path().join("none"))
                .listed("codex")
                .is_empty()
        );
        assert!(codex_models("not json").is_empty());
    }
}
