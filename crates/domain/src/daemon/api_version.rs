use std::fmt;

/// Version of the client/daemon API. Clients refuse to operate on mismatch.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct ApiVersion(u32);

impl ApiVersion {
    /// Bump only on breaking changes to `proto/kumo/v1`.
    pub const CURRENT: Self = Self(1);

    pub const fn new(version: u32) -> Self {
        Self(version)
    }

    pub const fn get(self) -> u32 {
        self.0
    }

    pub fn is_compatible_with(self, other: ApiVersion) -> bool {
        self == other
    }
}

impl fmt::Display for ApiVersion {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "v{}", self.0)
    }
}
