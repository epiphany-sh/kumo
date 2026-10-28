//! tonic service implementations. Thin: decode, call the use case, encode.

mod core;
mod terminals;
mod workspace;

pub use self::core::CoreGrpc;
pub use self::terminals::TerminalsGrpc;
pub use self::workspace::WorkspaceGrpc;
