//! Kumo application layer: the use cases the daemon exposes.
//!
//! Depends only on the domain and its ports; the infrastructure adapters
//! and the gRPC transport are plugged in from outside.
//!
//! - [`terminal`]: open, attach to, drive and close terminal sessions.
//! - [`daemon`]: daemon-level use cases (handshake).

pub mod daemon;
pub mod terminal;
