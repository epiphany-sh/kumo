//! Windows.

use std::ffi::OsStr;
use std::os::windows::process::CommandExt;
use std::process::Command;

use super::BackgroundPrograms;

/// The child gets a console nobody sees.
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

pub struct Windows;

impl BackgroundPrograms for Windows {
    /// `kumod` runs without a console (the UI starts it detached), so a
    /// console program it starts would open a window of its own: one per
    /// `git status`, and a refresh runs many. With `CREATE_NO_WINDOW` it
    /// gets a hidden console instead, which what it starts (ssh, git's
    /// credential helper) shares.
    fn command(program: &OsStr) -> Command {
        let mut command = Command::new(program);
        command.creation_flags(CREATE_NO_WINDOW);
        command
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn runs_the_program_and_reports_its_exit_code() {
        let status = Windows::command(OsStr::new("cmd"))
            .args(["/C", "exit 3"])
            .status()
            .unwrap();
        assert_eq!(status.code(), Some(3));
    }
}
