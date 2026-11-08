//! Your agents (Claude Code subagents): their files, Kumo's settings for
//! them, runs in terminals of their own and headless test runs.

mod play;
mod run;
mod service;
mod sources;

pub use play::PlayStart;
pub use run::{RunStart, RunWhere};
pub use service::{AgentDefCapabilities, AgentDefPlaces, AgentDefPorts, AgentDefService};
pub use sources::{PullContext, RunSources, ServiceSources};
