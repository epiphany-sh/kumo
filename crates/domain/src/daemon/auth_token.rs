use std::fmt;

use subtle::ConstantTimeEq;

use super::DaemonError;

/// Shared secret every client must present as `authorization: Bearer <token>`.
///
/// 32 random bytes, hex-encoded. A new token is generated on every daemon
/// start. `Debug` never prints the secret.
#[derive(Clone, PartialEq, Eq)]
pub struct AuthToken(String);

impl AuthToken {
    pub const BYTES: usize = 32;

    pub fn from_bytes(bytes: [u8; Self::BYTES]) -> Self {
        Self(hex::encode(bytes))
    }

    pub fn parse(raw: &str) -> Result<Self, DaemonError> {
        let valid = raw.len() == Self::BYTES * 2 && raw.bytes().all(|b| b.is_ascii_hexdigit());
        if !valid {
            return Err(DaemonError::InvalidToken);
        }
        Ok(Self(raw.to_ascii_lowercase()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// Constant-time comparison against a presented credential.
    pub fn matches(&self, presented: &str) -> bool {
        self.0.as_bytes().ct_eq(presented.as_bytes()).into()
    }
}

impl fmt::Debug for AuthToken {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("AuthToken(<redacted>)")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips_through_hex() {
        let token = AuthToken::from_bytes([0xab; AuthToken::BYTES]);
        assert_eq!(token.as_str().len(), 64);
        assert_eq!(AuthToken::parse(token.as_str()).unwrap(), token);
    }

    #[test]
    fn matches_only_the_exact_token() {
        let token = AuthToken::from_bytes([1; AuthToken::BYTES]);
        assert!(token.matches(token.as_str()));
        assert!(!token.matches(&token.as_str()[1..]));
        assert!(!token.matches(""));
    }

    #[test]
    fn rejects_malformed_tokens() {
        assert!(AuthToken::parse("abc").is_err());
        assert!(AuthToken::parse(&"z".repeat(64)).is_err());
    }

    #[test]
    fn debug_hides_secret() {
        let token = AuthToken::from_bytes([7; AuthToken::BYTES]);
        assert!(!format!("{token:?}").contains(token.as_str()));
    }
}
