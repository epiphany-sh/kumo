//! Secure randomness.

use kumo_domain::daemon::AuthToken;

/// A fresh token from the OS CSPRNG.
pub fn generate_auth_token() -> Result<AuthToken, getrandom::Error> {
    let mut bytes = [0_u8; AuthToken::BYTES];
    getrandom::fill(&mut bytes)?;
    Ok(AuthToken::from_bytes(bytes))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tokens_are_random() {
        assert_ne!(
            generate_auth_token().unwrap(),
            generate_auth_token().unwrap()
        );
    }
}
