use super::TerminalError;

/// Visible size of a terminal, in character cells.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct TerminalSize {
    cols: u16,
    rows: u16,
}

impl TerminalSize {
    pub const DEFAULT: Self = Self { cols: 80, rows: 24 };

    /// Both dimensions must be in `1..=u16::MAX`.
    pub fn new(cols: u32, rows: u32) -> Result<Self, TerminalError> {
        let invalid = || TerminalError::InvalidSize { cols, rows };
        let cols = u16::try_from(cols)
            .ok()
            .filter(|c| *c > 0)
            .ok_or_else(invalid)?;
        let rows = u16::try_from(rows)
            .ok()
            .filter(|r| *r > 0)
            .ok_or_else(invalid)?;
        Ok(Self { cols, rows })
    }

    pub const fn cols(self) -> u16 {
        self.cols
    }

    pub const fn rows(self) -> u16 {
        self.rows
    }
}

impl Default for TerminalSize {
    fn default() -> Self {
        Self::DEFAULT
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_valid_sizes() {
        let size = TerminalSize::new(120, 40).unwrap();
        assert_eq!((size.cols(), size.rows()), (120, 40));
    }

    #[test]
    fn rejects_zero_and_overflow() {
        assert!(TerminalSize::new(0, 24).is_err());
        assert!(TerminalSize::new(80, 0).is_err());
        assert!(TerminalSize::new(70_000, 24).is_err());
    }
}
