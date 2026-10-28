//! Follows one agent's terminal and turns its activity into state.

use std::sync::Arc;
use std::time::{Duration, Instant};

use bytes::Bytes;
use futures::StreamExt;
use kumo_domain::agents::{ActivityTracker, AgentSessionId, AgentState, LastLine};
use kumo_domain::terminal::{ExitStatus, TerminalEvent};
use kumo_domain::time::Timestamp;

use super::AgentService;
use crate::terminal::Attachment;

/// The last line on the card refreshes at most this often.
const LINE_EVERY: Duration = Duration::from_secs(1);
const TICK: Duration = Duration::from_millis(250);

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
    let mut shown = String::new();
    let mut shown_at = Instant::now();
    let mut ticker = tokio::time::interval(TICK);

    loop {
        let change = tokio::select! {
            event = events.next() => match event {
                Some(TerminalEvent::Output(batch)) => {
                    last_line.push(&batch.data);
                    tracker.on_output(&batch.data, Instant::now())
                }
                Some(TerminalEvent::Exited(status)) => tracker.exited(status),
                None => tracker.exited(ExitStatus::UNKNOWN),
            },
            _ = ticker.tick() => tracker.tick(Instant::now()),
        };

        let line = last_line.get();
        let line_due = line != shown && shown_at.elapsed() >= LINE_EVERY;
        if change.is_some() || line_due {
            shown.clone_from(&line);
            shown_at = Instant::now();
            service.update_session(&id, |session| {
                if let Some(state) = change {
                    session.state = state;
                    session.state_since = Timestamp::now();
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
