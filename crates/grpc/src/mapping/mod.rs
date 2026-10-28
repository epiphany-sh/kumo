//! Conversions between protobuf messages and domain types.

mod error;
mod terminal;

pub use error::status_from;
pub use terminal::{launch_spec_from, size_from, terminal_info_to, terminal_output_to};
