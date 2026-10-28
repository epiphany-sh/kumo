//! tonic service implementations. Thin: decode, call the use case, encode.

mod agents;
mod core;
mod git;
mod pipelines;
mod pulls;
mod tasks;
mod terminals;
mod workspace;

pub use self::agents::AgentsGrpc;
pub use self::core::CoreGrpc;
pub use self::git::GitGrpc;
pub use self::pipelines::PipelinesGrpc;
pub use self::pulls::PullRequestsGrpc;
pub use self::tasks::TasksGrpc;
pub use self::terminals::TerminalsGrpc;
pub use self::workspace::WorkspaceGrpc;
