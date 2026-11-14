use super::LaunchSpec;

/// Has an interactive shell report its prompts and the commands run at
/// them (OSC 133, and 633 for the command line and its folder), so the
/// client can mark the lines you ran and Kumo can remember them.
pub trait ShellIntegration: Send + Sync + 'static {
    /// `spec`, changed so the shell loads the integration on top of the
    /// user's own startup files; as it was for a program it doesn't know.
    /// The shell signs the command lines it reports with `nonce` (see
    /// [`super::CommandMarks`]), which it keeps from what it runs.
    fn apply(&self, spec: LaunchSpec, nonce: &str) -> LaunchSpec;
}

/// Shells start as they are.
#[derive(Debug, Default, Clone, Copy)]
pub struct NoShellIntegration;

impl ShellIntegration for NoShellIntegration {
    fn apply(&self, spec: LaunchSpec, _nonce: &str) -> LaunchSpec {
        spec
    }
}
