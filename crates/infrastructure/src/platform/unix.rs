//! macOS and Linux.

use std::ffi::OsStr;
use std::process::Command;

use super::BackgroundPrograms;

pub struct Unix;

impl BackgroundPrograms for Unix {
    /// A plain `Command`: a program without a terminal shows nothing.
    fn command(program: &OsStr) -> Command {
        Command::new(program)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn runs_the_program_as_given() {
        let command = Unix::command(OsStr::new("sh"));
        assert_eq!(command.get_program(), "sh");
        assert_eq!(command.get_args().count(), 0);
        assert_eq!(command.get_envs().count(), 0);

        let status = Unix::command(OsStr::new("sh"))
            .args(["-c", "exit 3"])
            .status()
            .unwrap();
        assert_eq!(status.code(), Some(3));
    }
}
