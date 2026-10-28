use std::fmt;

use super::TerminalError;

/// Opaque, unique identifier of a terminal session.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct TerminalId(String);

impl TerminalId {
    /// A new random identifier.
    pub fn generate() -> Self {
        Self(uuid::Uuid::new_v4().simple().to_string())
    }

    /// Parses an identifier received from a client.
    pub fn parse(raw: &str) -> Result<Self, TerminalError> {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            return Err(TerminalError::InvalidId);
        }
        Ok(Self(trimmed.to_owned()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for TerminalId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generated_ids_are_unique() {
        assert_ne!(TerminalId::generate(), TerminalId::generate());
    }

    #[test]
    fn rejects_blank_ids() {
        assert!(TerminalId::parse("  ").is_err());
        assert_eq!(TerminalId::parse(" abc ").unwrap().as_str(), "abc");
    }
}
