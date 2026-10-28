//! Generated bindings for the Kumo daemon API (`kumo.v1`).
//!
//! This crate only contains generated code. Mapping to and from domain
//! types lives in `kumo-grpc`.

/// Version 1 of the API. Bump [`API_VERSION`] on breaking changes only.
pub mod v1 {
    tonic::include_proto!("kumo.v1");
}
