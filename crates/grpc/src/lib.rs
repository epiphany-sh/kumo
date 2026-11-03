//! Kumo gRPC transport (interface adapter).
//!
//! Exposes the application use cases as the `kumo.v1` gRPC API and provides
//! an authenticated client for the bench, tests and future CLI.
//!
//! - [`server`]: binds the services on a loopback listener.
//! - [`client`]: authenticated client with `TCP_NODELAY`.
//! - [`auth`]: bearer-token interceptors (server check, client header).
//! - [`profile`]: the `kumo-profile` header that picks a call's profile.
//! - [`services`]: tonic service implementations.
//! - [`mapping`]: proto ↔ domain conversions and error → status mapping.

pub mod auth;
pub mod client;
pub mod mapping;
pub mod profile;
pub mod server;
pub mod services;

pub use kumo_proto::v1 as proto;
