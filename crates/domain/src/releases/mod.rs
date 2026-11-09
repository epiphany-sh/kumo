//! Releases and tags of the workspace's repositories: tags from git,
//! releases from the host (same tokens as pull requests). Bitbucket has
//! tags only.

mod model;
mod ports;

pub use model::{
    GitTag, MergedPr, Release, ReleaseAsset, ReleaseEdit, ReleaseKind, ReleaseRange, ticket_in,
};
pub use ports::{GitTags, ReleaseClient};
