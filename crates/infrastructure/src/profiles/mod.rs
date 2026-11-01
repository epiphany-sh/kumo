//! The profile registry (`profiles.json`) and each profile's data folder.

mod file_store;

pub use file_store::{FileProfileStore, profile_dir};
