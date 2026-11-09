//! Your agents: Claude Code subagent files (`.claude/agents/<name>.md`),
//! personal and per repository, Kumo's own settings for them, their runs
//! and their test runs. The daemon never parses the files: the UI owns the
//! format.

mod cli;
mod command;
mod context;
mod model;
mod play;
mod ports;

pub use cli::{AgentCli, DEFAULT_CLI, agent_cli};
pub use command::{AgentFiles, PlayCommand, context_sentence, next_free, role_sentence};
pub use context::{
    ContextFile, RepoLink, WrittenContext, context_index, file_name, html_text, pull_number,
    task_key,
};
pub use model::{
    AgentDefFile, AgentDefKey, AgentDefScope, AgentDefSettings, AgentDefTrigger, FoundFile,
    agents_dir, check_agent_name,
};
pub use play::{PlayEvent, PlayEventKind, PlayRecord};
pub use ports::{
    AgentDefFiles, AgentDefStore, HeadlessKiller, HeadlessProcess, HeadlessRunner, HeadlessSpec,
    PageReader, RunGit,
};
