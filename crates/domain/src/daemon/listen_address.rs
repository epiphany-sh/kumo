use std::net::{Ipv4Addr, SocketAddr};

use super::DaemonError;

/// Address the daemon listens on. The daemon runs commands, so it only ever
/// listens on loopback: any other interface is rejected at startup.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ListenAddress(SocketAddr);

impl ListenAddress {
    /// `127.0.0.1` on an ephemeral port.
    pub const fn ephemeral() -> Self {
        Self(SocketAddr::new(
            std::net::IpAddr::V4(Ipv4Addr::LOCALHOST),
            0,
        ))
    }

    pub fn new(addr: SocketAddr) -> Result<Self, DaemonError> {
        if !addr.ip().is_loopback() {
            return Err(DaemonError::NonLoopbackAddress(addr));
        }
        Ok(Self(addr))
    }

    pub const fn socket_addr(self) -> SocketAddr {
        self.0
    }
}

impl Default for ListenAddress {
    fn default() -> Self {
        Self::ephemeral()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_loopback_only() {
        assert!(ListenAddress::new("127.0.0.1:0".parse().unwrap()).is_ok());
        assert!(ListenAddress::new("[::1]:5000".parse().unwrap()).is_ok());
        assert!(ListenAddress::new("0.0.0.0:0".parse().unwrap()).is_err());
        assert!(ListenAddress::new("192.168.1.10:80".parse().unwrap()).is_err());
    }
}
