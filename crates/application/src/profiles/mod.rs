//! Profiles (the UI's workspaces): the registry, and one bundle of
//! services per profile, opened the first time a request names it.

mod bundle;
mod git_env;
mod service;
#[cfg(test)]
mod tests;

pub use bundle::ProfileServices;
pub use git_env::GitEnvironment;
pub use service::{OpenProfile, ProfileBundle, ProfileService, ProfileView, Window};
