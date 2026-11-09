//! An agent as the UI sends it with every run: the JSON `claude --agents`
//! takes (`agentInlineJson`). CLIs that can't take it read it here and turn it
//! into their own flags. Unknown fields are ignored, so nothing in it can ask
//! for more than these fields say.

use serde_json::Value;

use crate::agents::AgentError;

/// The fields of an agent other CLIs can use.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub(super) struct AgentSpec {
    /// Its instructions: the file's body.
    pub instructions: String,
    /// When to use it, as its file says.
    pub description: String,
    /// None: the file has no tools line, which means every tool.
    pub tools: Option<Vec<String>>,
    /// `inherit`, `haiku`, `sonnet`, `opus` or a model id.
    pub model: String,
    /// Claude Code's `permissionMode`; empty is `default`.
    pub permission_mode: String,
    pub max_turns: Option<u64>,
    pub skills: Vec<String>,
    /// Its connectors: `mcpServers`, and `mcp__<server>` in its tools.
    pub mcp_servers: Vec<String>,
    pub memory: String,
}

fn strings(value: &Value) -> Vec<String> {
    match value {
        Value::Array(items) => items
            .iter()
            .filter_map(Value::as_str)
            .map(str::to_owned)
            .collect(),
        // A file may say "A, B" where `--agents` wants a list.
        Value::String(s) => s
            .split(',')
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(str::to_owned)
            .collect(),
        _ => Vec::new(),
    }
}

impl AgentSpec {
    /// Reads agent `name` out of `inline_json`.
    pub fn from_inline(name: &str, inline_json: &str) -> Result<Self, AgentError> {
        let invalid = |why: &str| AgentError::Invalid(format!("agent {name}: {why}"));
        if inline_json.trim().is_empty() {
            return Err(invalid("nothing was sent to run it with"));
        }
        let all: Value =
            serde_json::from_str(inline_json).map_err(|_| invalid("its definition isn't JSON"))?;
        let agent = all
            .get(name)
            .and_then(Value::as_object)
            .ok_or_else(|| invalid("its definition doesn't name it"))?;
        let text = |key: &str| {
            agent
                .get(key)
                .and_then(Value::as_str)
                .unwrap_or_default()
                .trim()
                .to_owned()
        };
        let instructions = text("prompt");
        if instructions.is_empty() {
            return Err(invalid("it has no instructions"));
        }
        let listed = agent.get("tools").map(strings);
        let mut mcp_servers = agent.get("mcpServers").map(strings).unwrap_or_default();
        for tool in listed.iter().flatten() {
            if let Some(server) = tool.strip_prefix("mcp__") {
                let server = server.split("__").next().unwrap_or(server).to_owned();
                if !mcp_servers.contains(&server) {
                    mcp_servers.push(server);
                }
            }
        }
        Ok(Self {
            instructions,
            description: text("description"),
            tools: listed.map(|tools| {
                tools
                    .into_iter()
                    .filter(|t| !t.starts_with("mcp__"))
                    .collect()
            }),
            model: text("model"),
            permission_mode: text("permissionMode"),
            max_turns: agent.get("maxTurns").and_then(Value::as_u64),
            skills: agent.get("skills").map(strings).unwrap_or_default(),
            mcp_servers,
            memory: text("memory"),
        })
    }

    /// It has `tool`, by name or by having every tool.
    pub fn has(&self, tool: &str) -> bool {
        self.tools
            .as_ref()
            .is_none_or(|tools| tools.iter().any(|t| t == tool))
    }

    /// It can change files with its own tools.
    pub fn edits(&self) -> bool {
        ["Edit", "Write", "MultiEdit", "NotebookEdit"]
            .iter()
            .any(|t| self.has(t))
    }

    /// The Claude tier its model names (`haiku`, `sonnet`, `opus`), as an
    /// alias or a full Claude id.
    pub fn claude_tier(&self) -> Option<&'static str> {
        let lower = self.model.to_ascii_lowercase();
        ["haiku", "sonnet", "opus"]
            .into_iter()
            .find(|tier| lower.contains(tier))
    }

    /// A model of another CLI's, to give it as is: not `inherit`, not a
    /// Claude model, nothing a flag could be read from.
    pub fn own_model(&self) -> Option<String> {
        let model = self.model.as_str();
        let lower = model.to_ascii_lowercase();
        let ok = !model.is_empty()
            && !model.starts_with('-')
            && model
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '-' | ':' | '/'));
        (ok && lower != "inherit" && !lower.starts_with("claude") && self.claude_tier().is_none())
            .then(|| model.to_owned())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_what_the_ui_sends() {
        let json = r#"{"rev":{"description":"d","prompt":" Review it. ","tools":["Read","Bash","mcp__github__get_pr"],"model":"sonnet","permissionMode":"plan","maxTurns":8,"skills":["sql"],"mcpServers":["jira"],"memory":"project","sandbox":"danger-full-access"}}"#;
        let spec = AgentSpec::from_inline("rev", json).unwrap();
        assert_eq!(spec.instructions, "Review it.");
        assert_eq!(
            spec.tools.as_deref(),
            Some(&["Read".into(), "Bash".into()][..])
        );
        assert_eq!(spec.mcp_servers, ["jira", "github"]);
        assert_eq!(
            (
                spec.model.as_str(),
                spec.permission_mode.as_str(),
                spec.max_turns
            ),
            ("sonnet", "plan", Some(8))
        );
        assert!(spec.has("Bash") && !spec.edits());
    }

    #[test]
    fn no_tools_line_means_every_tool() {
        let spec = AgentSpec::from_inline("a", r#"{"a":{"prompt":"x"}}"#).unwrap();
        assert!(spec.tools.is_none() && spec.has("Bash") && spec.edits());
    }

    #[test]
    fn claude_models_are_told_apart_from_others() {
        let with = |model: &str| AgentSpec {
            model: model.into(),
            ..Default::default()
        };
        for (model, tier) in [
            ("haiku", "haiku"),
            ("Sonnet", "sonnet"),
            ("claude-opus-5-5", "opus"),
        ] {
            assert_eq!(with(model).claude_tier(), Some(tier));
            assert_eq!(with(model).own_model(), None, "{model}");
        }
        assert_eq!(with("gpt-6-sol").own_model().as_deref(), Some("gpt-6-sol"));
        for none in [
            "",
            "inherit",
            "claude-next",
            "--yolo",
            "-x",
            "a b",
            "a;b",
            "a\nb",
        ] {
            assert_eq!(with(none).own_model(), None, "{none:?}");
        }
    }

    #[test]
    fn refuses_what_it_cant_run() {
        for json in [
            "",
            "not json",
            r#"{"other":{"prompt":"x"}}"#,
            r#"{"a":{"prompt":"  "}}"#,
            r#"{"a":"x"}"#,
        ] {
            assert!(AgentSpec::from_inline("a", json).is_err(), "{json}");
        }
    }
}
