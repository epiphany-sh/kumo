//! Git through the `git` command line: the most compatible way to manage
//! worktrees (kumo.md §6), with machine-readable porcelain output.

mod branch;
mod changes;
mod cli;
mod history;
mod repo_finder;
mod runs;
mod tags;

pub use cli::GitCli;
pub use repo_finder::FsRepoFinder;
