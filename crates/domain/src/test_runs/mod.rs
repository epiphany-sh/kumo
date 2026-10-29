//! Test runs of a worktree: the project's own test command, found from
//! its files, run in a terminal and read as it goes.

mod detect;
mod model;
mod summary;

pub use detect::{ProjectFiles, ProjectReader, detect_command};
pub use model::{SuiteResult, TestCommand, TestError, TestRun, TestState, TestSummary};
pub use summary::TestOutput;
