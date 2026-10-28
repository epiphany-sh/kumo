//! Coding agents: CLIs the user installed and signed in to (Kumo never
//! proxies models), and the sessions they run inside worktrees.

mod activity;
mod args;
mod error;
mod ports;
mod presets;
mod provider;
mod session;

pub use activity::{ActivityTracker, LastLine};
pub use args::split_args;
pub use error::AgentError;
pub use ports::{AgentStore, ProgramLocator, StoredProvider};
pub use presets::{AgentPreset, PRESETS};
pub use provider::{AgentProvider, PromptStyle};
pub use session::{AgentSession, AgentSessionId, AgentState};
