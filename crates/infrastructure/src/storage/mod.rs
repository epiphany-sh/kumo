//! SQLite persistence (`kumo.db` in the user's data directory).

mod migrations;
mod workspace_store;

pub use workspace_store::SqliteWorkspaceStore;
