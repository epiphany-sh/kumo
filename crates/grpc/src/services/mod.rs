//! tonic service implementations. Thin: decode, call the use case, encode.

mod core;
mod terminals;

pub use self::core::CoreGrpc;
pub use self::terminals::TerminalsGrpc;
