//! The profile registry (`profiles.json`), each profile's data folder, and
//! the machine's SSH keys and `gh` accounts to pick from.

mod file_store;
mod machine;

pub use file_store::{FileProfileStore, profile_dir};
pub use machine::LocalMachineAccounts;
