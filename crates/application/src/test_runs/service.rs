use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::Duration;

use futures::StreamExt;
use kumo_domain::agents::ProgramLocator;
use kumo_domain::terminal::{ExitStatus, LaunchSpec, TerminalEvent, TerminalSize};
use kumo_domain::test_runs::{
    ProjectFiles, ProjectReader, TestCommand, TestError, TestOutput, TestRun, TestState,
    detect_command,
};
use kumo_domain::time::Timestamp;
use tokio::sync::watch;

use crate::terminal::{Attachment, TerminalService};
use crate::workspace::WorkspaceService;

/// What a run's card shows refreshes at most this often.
const PUBLISH_EVERY: Duration = Duration::from_millis(300);

#[derive(Clone)]
pub struct TestPorts {
    pub files: Arc<dyn ProjectReader>,
    pub locator: Arc<dyn ProgramLocator>,
}

impl std::fmt::Debug for TestPorts {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TestPorts").finish_non_exhaustive()
    }
}

/// The latest run of every worktree that ran its tests, pushed whole on
/// each change.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct TestsSnapshot {
    pub version: u64,
    pub runs: Vec<TestRun>,
}

impl TestsSnapshot {
    pub fn run_of(&self, worktree: &Path) -> Option<&TestRun> {
        self.runs.iter().find(|r| r.worktree == worktree)
    }
}

/// Runs a worktree's tests in a terminal of its own and reads the output
/// as it comes. One run per worktree: a new one replaces the last.
#[derive(Debug)]
pub struct TestService {
    ports: TestPorts,
    terminals: Arc<TerminalService>,
    workspace: Arc<WorkspaceService>,
    runs: Mutex<TestsSnapshot>,
    /// Worktrees whose run the user stopped.
    stopped: Mutex<HashSet<PathBuf>>,
    published: watch::Sender<Arc<TestsSnapshot>>,
}

impl TestService {
    pub fn new(
        ports: TestPorts,
        terminals: Arc<TerminalService>,
        workspace: Arc<WorkspaceService>,
    ) -> Self {
        let (published, _) = watch::channel(Arc::new(TestsSnapshot::default()));
        Self {
            ports,
            terminals,
            workspace,
            runs: Mutex::new(TestsSnapshot::default()),
            stopped: Mutex::new(HashSet::new()),
            published,
        }
    }

    /// The command the worktree's files point to, if any.
    pub async fn detect(&self, worktree: &Path) -> Result<Option<TestCommand>, TestError> {
        let worktree = self.worktree(worktree).await?;
        let ports = self.ports.clone();
        tokio::task::spawn_blocking(move || {
            detect_command(&Files {
                ports: &ports,
                root: &worktree,
            })
        })
        .await
        .map_err(|e| TestError::Launch(format!("blocking task failed: {e}")))
    }

    /// Runs `command` (None: the detected one) in the worktree, stopping a
    /// run still going there.
    pub async fn run(
        self: &Arc<Self>,
        worktree: &Path,
        command: Option<&str>,
        size: TerminalSize,
    ) -> Result<TestRun, TestError> {
        let command = match command.map(str::trim).filter(|c| !c.is_empty()) {
            Some(command) => command.to_owned(),
            None => {
                self.detect(worktree)
                    .await?
                    .ok_or(TestError::NoCommand)?
                    .command
            }
        };
        let worktree = self.worktree(worktree).await?;
        if let Some(previous) = self.lock().run_of(&worktree) {
            let _ = self.terminals.close(&previous.terminal);
        }
        let spec = LaunchSpec::new("/bin/sh")
            .map_err(launch_error)?
            .with_args(["-c".to_owned(), command.clone()])
            .with_cwd(Some(worktree.clone()))
            .with_env([("PATH".to_owned(), self.ports.locator.search_path())])
            .with_size(size);
        let terminal = self.terminals.open(spec).map_err(launch_error)?;
        let attachment = self
            .terminals
            .attach(&terminal, false)
            .map_err(launch_error)?;
        let run = TestRun {
            worktree: worktree.clone(),
            command,
            terminal,
            state: TestState::Running,
            exit_code: None,
            started_at: Timestamp::now(),
            finished_at: None,
            summary: Default::default(),
        };
        self.stopped_lock().remove(&worktree);
        self.update(|snapshot| {
            snapshot.runs.retain(|r| r.worktree != worktree);
            snapshot.runs.push(run.clone());
        });
        tracing::info!(worktree = %worktree.display(), command = run.command, "tests started");
        tokio::spawn(follow(Arc::clone(self), run.clone(), attachment));
        Ok(run)
    }

    /// Stops the worktree's run; it ends as stopped.
    pub async fn stop(&self, worktree: &Path) -> Result<(), TestError> {
        let worktree = self.worktree(worktree).await?;
        let run = self
            .lock()
            .run_of(&worktree)
            .cloned()
            .ok_or_else(|| TestError::NoRun(worktree.clone()))?;
        if run.state == TestState::Running {
            self.stopped_lock().insert(worktree);
            let _ = self.terminals.close(&run.terminal);
        }
        Ok(())
    }

    pub fn watch(&self) -> watch::Receiver<Arc<TestsSnapshot>> {
        self.published.subscribe()
    }

    /// The worktree's path as the workspace knows it.
    pub async fn known(&self, worktree: &Path) -> Result<PathBuf, TestError> {
        self.worktree(worktree).await
    }

    async fn worktree(&self, worktree: &Path) -> Result<PathBuf, TestError> {
        self.workspace
            .known_worktree(worktree)
            .await
            .ok_or_else(|| TestError::UnknownWorktree(worktree.into()))
    }

    fn finish(&self, run: &TestRun, output: &TestOutput, status: ExitStatus) {
        let stopped = self.stopped_lock().remove(&run.worktree);
        let state = if stopped {
            TestState::Stopped
        } else if status.success() {
            TestState::Passed
        } else {
            TestState::Failed
        };
        tracing::info!(worktree = %run.worktree.display(), code = status.code(), ?state, "tests finished");
        self.update_run(run, |r| {
            r.state = state;
            r.exit_code = Some(status.code());
            r.finished_at = Some(Timestamp::now());
            r.summary = output.summary().clone();
        });
    }

    /// Changes `run` if it's still the worktree's latest.
    fn update_run(&self, run: &TestRun, change: impl FnOnce(&mut TestRun)) {
        self.update(|snapshot| {
            if let Some(current) = snapshot
                .runs
                .iter_mut()
                .find(|r| r.worktree == run.worktree && r.terminal == run.terminal)
            {
                change(current);
            }
        });
    }

    fn update(&self, change: impl FnOnce(&mut TestsSnapshot)) {
        let snapshot = {
            let mut snapshot = self.lock();
            change(&mut snapshot);
            snapshot.version += 1;
            snapshot.clone()
        };
        self.published.send_replace(Arc::new(snapshot));
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, TestsSnapshot> {
        self.runs.lock().unwrap_or_else(PoisonError::into_inner)
    }

    fn stopped_lock(&self) -> std::sync::MutexGuard<'_, HashSet<PathBuf>> {
        self.stopped.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

/// Reads the run's output until it ends.
async fn follow(service: Arc<TestService>, run: TestRun, attachment: Attachment) {
    let mut events = Box::pin(attachment.output.into_stream());
    let mut output = TestOutput::default();
    let mut ticker = tokio::time::interval(PUBLISH_EVERY);
    let mut dirty = false;
    let status = loop {
        tokio::select! {
            event = events.next() => match event {
                Some(TerminalEvent::Output(batch)) => {
                    output.push(&batch.data);
                    dirty = true;
                }
                Some(TerminalEvent::Exited(status)) => break status,
                None => break ExitStatus::UNKNOWN,
            },
            _ = ticker.tick() => {
                if std::mem::take(&mut dirty) {
                    service.update_run(&run, |r| r.summary = output.summary().clone());
                }
            }
        }
    };
    output.finish();
    service.finish(&run, &output, status);
}

/// One worktree's files, for [`detect_command`].
struct Files<'a> {
    ports: &'a TestPorts,
    root: &'a Path,
}

impl ProjectFiles for Files<'_> {
    fn read(&self, relative: &str) -> Option<String> {
        self.ports.files.read(self.root, relative)
    }
    fn has_program(&self, program: &str) -> bool {
        self.ports.locator.locate(program).is_some()
    }
}

fn launch_error(error: kumo_domain::terminal::TerminalError) -> TestError {
    TestError::Launch(error.to_string())
}
