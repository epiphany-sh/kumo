//! Bearer-token authentication for every call.

use kumo_domain::daemon::AuthToken;
use tonic::metadata::{AsciiMetadataValue, MetadataValue};
use tonic::service::Interceptor;
use tonic::{Request, Status};

const AUTHORIZATION: &str = "authorization";
const BEARER_PREFIX: &str = "Bearer ";

/// Server side: rejects calls without the daemon's token. Comparison is
/// constant-time.
#[derive(Debug, Clone)]
pub struct RequireBearer {
    token: AuthToken,
}

impl RequireBearer {
    pub fn new(token: AuthToken) -> Self {
        Self { token }
    }
}

impl Interceptor for RequireBearer {
    fn call(&mut self, request: Request<()>) -> Result<Request<()>, Status> {
        let presented = request
            .metadata()
            .get(AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .and_then(|value| value.strip_prefix(BEARER_PREFIX));
        match presented {
            Some(token) if self.token.matches(token) => Ok(request),
            _ => Err(Status::unauthenticated("missing or invalid bearer token")),
        }
    }
}

/// Client side: attaches `authorization: Bearer <token>` to every call.
#[derive(Debug, Clone)]
pub struct AttachBearer {
    header: AsciiMetadataValue,
}

impl AttachBearer {
    pub fn new(token: &AuthToken) -> Self {
        // A hex token is always valid ASCII metadata.
        let header = MetadataValue::try_from(format!("{BEARER_PREFIX}{}", token.as_str()))
            .expect("hex token is valid ASCII metadata");
        Self { header }
    }
}

impl Interceptor for AttachBearer {
    fn call(&mut self, mut request: Request<()>) -> Result<Request<()>, Status> {
        request
            .metadata_mut()
            .insert(AUTHORIZATION, self.header.clone());
        Ok(request)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn token(byte: u8) -> AuthToken {
        AuthToken::from_bytes([byte; AuthToken::BYTES])
    }

    #[test]
    fn accepts_the_right_token() {
        let request = AttachBearer::new(&token(1)).call(Request::new(())).unwrap();
        assert!(RequireBearer::new(token(1)).call(request).is_ok());
    }

    #[test]
    fn rejects_wrong_or_missing_token() {
        let request = AttachBearer::new(&token(2)).call(Request::new(())).unwrap();
        let wrong = RequireBearer::new(token(1)).call(request).unwrap_err();
        assert_eq!(wrong.code(), tonic::Code::Unauthenticated);

        let missing = RequireBearer::new(token(1))
            .call(Request::new(()))
            .unwrap_err();
        assert_eq!(missing.code(), tonic::Code::Unauthenticated);
    }
}
