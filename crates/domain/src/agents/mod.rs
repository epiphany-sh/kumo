//! Coding agents: CLIs the user installed and signed in to (Kumo never
//! proxies models), and the sessions they run inside worktrees.

mod actions;
mod activity;
mod args;
mod error;
mod homes;
mod ports;
mod presets;
mod provider;
mod session;
mod usage;

pub use actions::{ActionReader, action_of};
pub use activity::{ActivityTracker, LastLine};
pub use args::split_args;
pub use error::AgentError;
pub use homes::{CLI_HOMES, CliHome, cli_home};
pub use ports::{
    AgentStore, CliHomes, ProcessDetails, ProcessInspector, ProgramLocator, SharedCliHomes,
    StoredProvider,
};
pub use presets::{AgentPreset, PRESETS};
pub use provider::{AgentProvider, PromptStyle, args_for_cmd, runs_through_cmd};
pub use session::{
    AgentContext, AgentEvent, AgentEventKind, AgentSession, AgentSessionId, AgentState,
    ContextKind, TerminalAgent, agent_program,
};
pub use usage::{
    ContextReading, ContextSlice, ContextSliceKind, PlanReading, PlanUsage, PlanUsageStore,
    SessionUsage, UsageReading, UsageReport, UsageSource, UsageTarget, UsageUnit, UsageWindow,
};
