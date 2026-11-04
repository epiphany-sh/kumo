//! What each OS does its own way, behind one interface per need.
//!
//! Each OS has its own file (`unix.rs` for macOS and Linux, `windows.rs`)
//! implementing the same traits; the build picks one, so the code of one
//! OS never runs, nor needs to compile, on another. The rest of the crate
//! calls the functions here and never asks which OS it is on.

use std::ffi::OsStr;
use std::process::Command;

#[cfg(unix)]
mod unix;
#[cfg(windows)]
mod windows;

#[cfg(unix)]
use unix::Unix as Current;
#[cfg(windows)]
use windows::Windows as Current;

/// How the daemon starts programs the user never sees (git, gh,
/// ssh-keygen, an agent's `--version`). Terminals don't come through
/// here: the PTY gives them their own.
pub trait BackgroundPrograms {
    /// A [`Command`] for `program` that runs out of sight.
    fn command(program: &OsStr) -> Command;
}

/// `Command::new(program)` as this OS runs a background program.
pub fn background(program: impl AsRef<OsStr>) -> Command {
    <Current as BackgroundPrograms>::command(program.as_ref())
}
