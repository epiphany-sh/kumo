//! The user's TODOs: adding and editing them, recording where each runs once
//! handed to an agent, and moving it through its statuses.

mod service;

pub use service::{StatusChange, TodoEdit, TodoService};

#[cfg(test)]
mod tests;
