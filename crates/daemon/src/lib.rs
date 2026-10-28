//! `kumod`, the Kumo daemon.
//!
//! The composition root: builds the infrastructure adapters, injects them
//! into the application services and serves them over gRPC. Also owns the
//! daemon lifecycle (single instance, discovery file, shutdown).

mod config;
mod daemon;
mod single_instance;

pub use config::{DaemonConfig, SecretsBackend};
pub use daemon::Daemon;
