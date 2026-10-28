/// How a terminal's process ended.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ExitStatus {
    code: i32,
}

impl ExitStatus {
    /// Used when the exit code could not be determined.
    pub const UNKNOWN: Self = Self { code: -1 };

    pub const fn new(code: i32) -> Self {
        Self { code }
    }

    pub const fn code(self) -> i32 {
        self.code
    }

    pub const fn success(self) -> bool {
        self.code == 0
    }
}
