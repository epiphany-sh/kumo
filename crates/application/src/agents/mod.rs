//! Agent use cases: configure providers, start agents in worktrees and
//! follow what they are doing.

mod monitor;
mod service;
mod usage;

pub use service::{AgentPorts, AgentService, AgentsSnapshot, ProviderSettings, ProviderView};
