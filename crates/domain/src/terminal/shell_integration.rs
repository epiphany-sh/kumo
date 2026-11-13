use super::LaunchSpec;

/// Has an interactive shell report its prompts and the commands run at
/// them (OSC 133), so the client can mark the lines you ran.
pub trait ShellIntegration: Send + Sync + 'static {
    /// `spec`, changed so the shell loads the integration on top of the
    /// user's own startup files; as it was for a program it doesn't know.
    fn apply(&self, spec: LaunchSpec) -> LaunchSpec;
}

/// Shells start as they are.
#[derive(Debug, Default, Clone, Copy)]
pub struct NoShellIntegration;

impl ShellIntegration for NoShellIntegration {
    fn apply(&self, spec: LaunchSpec) -> LaunchSpec {
        spec
    }
}
