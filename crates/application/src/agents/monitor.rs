//! Follows one agent's terminal and turns its activity into state.

use std::sync::Arc;
use std::time::{Duration, Instant};

use bytes::Bytes;
use futures::StreamExt;
use kumo_domain::agents::{
    ActionReader, ActivityTracker, AgentEventKind, AgentSessionId, AgentState, LastLine,
};
use kumo_domain::terminal::{ExitStatus, TerminalEvent};
use kumo_domain::time::Timestamp;

use super::AgentService;
use super::service::{STOPPED, STOPPED_BY_TIME_LIMIT};
use crate::terminal::Attachment;

/// The last line on the card refreshes at most this often.
const LINE_EVERY: Duration = Duration::from_secs(1);
const TICK: Duration = Duration::from_millis(250);
/// How it exited: 130 when Kumo stopped it, 124 when its time limit did.
fn exit_of(service: &AgentService, id: &AgentSessionId, status: ExitStatus) -> ExitStatus {
    service.stopped_with(id).map_or(status, ExitStatus::new)
}

/// Runs until the agent exits. `typed` is a prompt to type in the first
/// time the agent waits for input.
pub(super) async fn run(
    service: Arc<AgentService>,
    id: AgentSessionId,
    attachment: Attachment,
    mut typed: Option<String>,
    quiet_after: Duration,
) {
    let Attachment {
        session: terminal,
        output,
    } = attachment;
    let mut events = Box::pin(output.into_stream());
    let mut tracker = ActivityTracker::new(Instant::now(), quiet_after);
    let mut last_line = LastLine::default();
    let mut actions = ActionReader::default();
    let mut shown = String::new();
    let mut shown_at = Instant::now();
    let mut ticker = tokio::time::interval(TICK);

    loop {
        let mut done = Vec::new();
        let change = tokio::select! {
            event = events.next() => match event {
                Some(TerminalEvent::Output(batch)) => {
                    last_line.push(&batch.data);
                    done = actions.push(&batch.data);
                    tracker.on_output(&batch.data, Instant::now())
                }
                Some(TerminalEvent::Exited(status)) => tracker.exited(exit_of(&service, &id, status)),
                None => tracker.exited(exit_of(&service, &id, ExitStatus::UNKNOWN)),
            },
            _ = ticker.tick() => tracker.tick(Instant::now()),
        };

        let line = last_line.get();
        let line_due = line != shown && shown_at.elapsed() >= LINE_EVERY;
        if change.is_some() || line_due || !done.is_empty() {
            shown.clone_from(&line);
            shown_at = Instant::now();
            service.update_session(&id, |session| {
                let now = Timestamp::now();
                for (kind, text) in done {
                    session.record(kind, text, now);
                }
                match change {
                    Some(AgentState::NeedsInput) => {
                        session.record(AgentEventKind::Waiting, line.clone(), now);
                    }
                    Some(AgentState::Exited(status)) => {
                        let how = match status.code() {
                            0 => "Finished".to_owned(),
                            -1 | STOPPED => "Stopped".to_owned(),
                            STOPPED_BY_TIME_LIMIT => "Stopped: its time limit".to_owned(),
                            code => format!("Exited with code {code}"),
                        };
                        session.record(AgentEventKind::Exited, how, now);
                    }
                    _ => {}
                }
                if let Some(state) = change {
                    session.state = state;
                    session.state_since = now;
                }
                session.last_line = line;
            });
        }

        match change {
            Some(AgentState::NeedsInput) => {
                if let Some(prompt) = typed.take() {
                    let _ = terminal.write(Bytes::from(format!("{prompt}\r"))).await;
                }
            }
            Some(AgentState::Exited(status)) => {
                tracing::info!(session = %id, code = status.code(), "agent exited");
                break;
            }
            _ => {}
        }
    }
}
