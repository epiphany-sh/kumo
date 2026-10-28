//! CI pipelines of a worktree's branch, read from the repository's host
//! (GitHub Actions, GitLab CI, Bitbucket Pipelines) with the user's token.
//! Problems are classified by what the user can do about them; the UI
//! words them.

mod error;
mod host;
mod model;
mod ports;

pub use error::PipelinesError;
pub use host::{CiHost, CiTarget};
pub use model::{
    CiJob, CiProblem, CiProblemKind, CiProvider, CiRun, CiState, HostInfo, PipelinesSnapshot,
};
pub use ports::{BranchReader, CiClient, HostTokens, LocalBranch, TokenFallback};
