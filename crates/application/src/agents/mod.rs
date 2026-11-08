//! Agent use cases: configure providers, start agents in worktrees and
//! follow what they are doing.

mod monitor;
mod service;
mod terminal_agents;
mod usage;

pub use service::{
    AgentLaunch, AgentPorts, AgentService, AgentsSnapshot, ProviderSettings, ProviderView,
};
pub(crate) use service::{STOPPED, STOPPED_BY_TIME_LIMIT};
