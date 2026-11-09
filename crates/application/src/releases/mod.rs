//! Release use cases: a repository's tags and releases, what changed
//! between two of them, and writing a release's notes. Tags come from git,
//! releases from the host with the same tokens as pull requests.

mod service;

pub use service::{ReleaseList, ReleasePorts, ReleaseService};

#[cfg(test)]
mod tests;
