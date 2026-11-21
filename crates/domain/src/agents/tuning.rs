//! The model and effort a known CLI can be started with, and the flags that
//! say so. Checked against the CLIs' own `--help` (Claude Code 2.1, Codex
//! 0.157, Copilot 1.0): CLIs Kumo hasn't checked take neither.
//!
//! Only models the CLI lists (or documents) are offered and taken: a name
//! typed by hand ("luna" for Codex's `gpt-6-luna`) fails inside the CLI,
//! after the worktree is made.

use super::AgentError;

/// A model a CLI can be started with, and the effort levels it takes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelChoice {
    /// As the CLI names it: `opus`, `gpt-6-luna`.
    pub id: String,
    /// As it shows it: "GPT-6-Luna".
    pub name: String,
    /// Lowest first; empty: the CLI's own levels.
    pub efforts: Vec<String>,
}

/// Where the models a CLI lists for the signed-in account are read (Codex
/// keeps them in its home). Blocks.
pub trait ModelCatalog: Send + Sync + 'static {
    /// Empty when it lists none (or Kumo can't read them).
    fn listed(&self, provider_id: &str) -> Vec<ModelChoice>;
}

/// No CLI lists its models.
#[derive(Debug, Clone, Copy, Default)]
pub struct NoModelCatalog;

impl ModelCatalog for NoModelCatalog {
    fn listed(&self, _provider_id: &str) -> Vec<ModelChoice> {
        Vec::new()
    }
}

/// How a CLI takes its effort level.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EffortArg {
    /// `<flag> <level>`.
    Flag(&'static str),
    /// Codex: `-c model_reasoning_effort="<level>"`.
    CodexConfig,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Tuning {
    /// Models it documents (Claude Code's aliases), offered when it lists
    /// none itself; empty: only what it lists.
    pub models: &'static [&'static str],
    pub model_flag: &'static str,
    /// Lowest first, for models that don't list their own; empty: no
    /// effort setting.
    pub efforts: &'static [&'static str],
    pub effort: Option<EffortArg>,
    /// A model with which it takes no effort: it picks both (Copilot's
    /// "auto", where `--reasoning-effort` fails).
    pub no_effort_with: &'static str,
}

const TUNINGS: &[(&str, Tuning)] = &[
    (
        "claude",
        Tuning {
            models: &["opus", "sonnet", "haiku", "fable"],
            model_flag: "--model",
            efforts: &["low", "medium", "high", "xhigh", "max"],
            effort: Some(EffortArg::Flag("--effort")),
            no_effort_with: "",
        },
    ),
    (
        "codex",
        Tuning {
            models: &[],
            model_flag: "-m",
            efforts: &["low", "medium", "high"],
            effort: Some(EffortArg::CodexConfig),
            no_effort_with: "",
        },
    ),
    (
        "copilot",
        Tuning {
            models: &["auto"],
            model_flag: "--model",
            efforts: &["low", "medium", "high", "xhigh", "max"],
            effort: Some(EffortArg::Flag("--reasoning-effort")),
            no_effort_with: "auto",
        },
    ),
    (
        "gemini",
        Tuning {
            models: &[],
            model_flag: "-m",
            efforts: &[],
            effort: None,
            no_effort_with: "",
        },
    ),
];

/// What the preset `id` takes; None for CLIs Kumo hasn't checked and for
/// custom agents.
pub fn tuning_for(id: &str) -> Option<&'static Tuning> {
    TUNINGS.iter().find(|(k, _)| *k == id).map(|(_, t)| t)
}

impl Tuning {
    /// What to offer: what the CLI lists, else the models it documents.
    pub fn choices(&self, listed: Vec<ModelChoice>) -> Vec<ModelChoice> {
        if !listed.is_empty() {
            return listed;
        }
        self.models
            .iter()
            .map(|m| ModelChoice {
                id: (*m).to_owned(),
                name: (*m).to_owned(),
                efforts: Vec::new(),
            })
            .collect()
    }

    /// The effort levels `model` takes ('': the CLI's default model): its
    /// own when it lists them, else the CLI's.
    pub fn efforts_for<'a>(&'a self, model: &str, choices: &'a [ModelChoice]) -> Vec<&'a str> {
        let own = choices
            .iter()
            .find(|c| c.id == model)
            .filter(|c| !c.efforts.is_empty());
        match own {
            Some(c) => c.efforts.iter().map(String::as_str).collect(),
            None => self.efforts.to_vec(),
        }
    }

    /// The arguments for `model` and `effort` (either may be empty: the
    /// CLI's own). `model` must be one of `choices`; the effort is left out
    /// where the model picks it.
    pub fn args(
        &self,
        model: &str,
        effort: &str,
        choices: &[ModelChoice],
    ) -> Result<Vec<String>, AgentError> {
        let (model, effort) = (model.trim(), effort.trim());
        let mut args = Vec::new();
        if !model.is_empty() {
            if !choices.iter().any(|c| c.id == model) {
                return Err(AgentError::Invalid(if choices.is_empty() {
                    format!(
                        "this agent lists no models Kumo can read, so \"{model}\" can't be checked: start it with its own"
                    )
                } else {
                    let ids: Vec<&str> = choices.iter().map(|c| c.id.as_str()).collect();
                    format!(
                        "\"{model}\" isn't one of the models this agent lists ({})",
                        ids.join(", ")
                    )
                }));
            }
            args.extend([self.model_flag.to_owned(), model.to_owned()]);
        }
        if effort.is_empty() {
            return Ok(args);
        }
        let allowed = self.efforts_for(model, choices);
        let Some(how) = self.effort.filter(|_| allowed.contains(&effort)) else {
            return Err(AgentError::Invalid(format!(
                "this model doesn't take the effort \"{effort}\""
            )));
        };
        if !self.no_effort_with.is_empty() && (model.is_empty() || model == self.no_effort_with) {
            // It picks the effort with the model: pick a model to set one.
            return Ok(args);
        }
        match how {
            EffortArg::Flag(flag) => args.extend([flag.to_owned(), effort.to_owned()]),
            EffortArg::CodexConfig => args.extend([
                "-c".to_owned(),
                format!("model_reasoning_effort=\"{effort}\""),
            ]),
        }
        Ok(args)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn choice(id: &str, efforts: &[&str]) -> ModelChoice {
        ModelChoice {
            id: id.into(),
            name: id.into(),
            efforts: efforts.iter().map(|e| (*e).to_owned()).collect(),
        }
    }

    fn args(id: &str, model: &str, effort: &str, listed: Vec<ModelChoice>) -> Vec<String> {
        let t = tuning_for(id).unwrap();
        t.args(model, effort, &t.choices(listed)).unwrap()
    }

    #[test]
    fn each_cli_gets_its_own_flags() {
        assert_eq!(
            args("claude", "opus", "high", vec![]),
            ["--model", "opus", "--effort", "high"]
        );
        let codex = vec![choice(
            "gpt-6-luna",
            &["low", "medium", "high", "xhigh", "max"],
        )];
        assert_eq!(
            args("codex", "gpt-6-luna", "xhigh", codex),
            ["-m", "gpt-6-luna", "-c", "model_reasoning_effort=\"xhigh\""]
        );
        let copilot = vec![choice("auto", &[]), choice("gpt-x", &[])];
        assert_eq!(
            args("copilot", "gpt-x", "xhigh", copilot),
            ["--model", "gpt-x", "--reasoning-effort", "xhigh"]
        );
        assert!(args("claude", "", "", vec![]).is_empty());
        assert_eq!(
            args("codex", "", "high", vec![]),
            ["-c", "model_reasoning_effort=\"high\""]
        );
    }

    #[test]
    fn copilot_takes_no_effort_with_auto() {
        assert_eq!(args("copilot", "auto", "high", vec![]), ["--model", "auto"]);
        assert!(args("copilot", "", "high", vec![]).is_empty());
    }

    #[test]
    fn only_listed_models_and_their_efforts() {
        let codex = tuning_for("codex").unwrap();
        let listed = codex.choices(vec![choice("gpt-6-luna", &["low", "medium"])]);
        // Typed by hand: Codex would refuse it after the worktree is made.
        let typed = codex.args("luna", "", &listed).unwrap_err();
        assert!(typed.to_string().contains("gpt-6-luna"), "{typed}");
        assert!(
            codex.args("gpt-6-luna", "high", &listed).is_err(),
            "this model stops at medium"
        );
        assert!(
            codex.args("gpt-x", "", &[]).is_err(),
            "nothing listed: nothing to check against"
        );
        let claude = tuning_for("claude").unwrap();
        let aliases = claude.choices(vec![]);
        assert!(claude.args("opus", "extreme", &aliases).is_err());
        assert!(claude.args("--dangerous", "", &aliases).is_err());
        assert!(tuning_for("gemini").unwrap().args("", "high", &[]).is_err());
        assert!(tuning_for("aider").is_none());
    }
}
