//! Agent use cases: configure providers, start agents in worktrees and
//! follow what they are doing.

mod monitor;
mod service;

pub use service::{AgentPorts, AgentService, AgentsSnapshot, ProviderView};
