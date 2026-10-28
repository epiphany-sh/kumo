//! Blocking PTY I/O, one OS thread per direction plus one to wait on the
//! child. They bridge into async code through bounded channels.

use std::io::{ErrorKind, Read, Write};
use std::thread;

use bytes::Bytes;
use kumo_domain::terminal::{ExitStatus, OutputChunk, PtyChild, TerminalId};
use kumo_domain::time::Timestamp;
use tokio::sync::{mpsc, oneshot};

/// Reads PTY output into chunks until EOF. A full queue blocks the reader,
/// which in turn blocks the child once the kernel buffer fills.
pub(super) fn spawn_reader(
    id: &TerminalId,
    mut reader: Box<dyn Read + Send>,
    chunks: mpsc::Sender<OutputChunk>,
    buffer_bytes: usize,
) {
    spawn_named(format!("pty-read-{id}"), move || {
        let mut buffer = vec![0_u8; buffer_bytes];
        loop {
            match reader.read(&mut buffer) {
                Ok(0) => break,
                Ok(n) => {
                    let chunk =
                        OutputChunk::new(Bytes::copy_from_slice(&buffer[..n]), Timestamp::now());
                    if chunks.blocking_send(chunk).is_err() {
                        break;
                    }
                }
                Err(e) if e.kind() == ErrorKind::Interrupted => continue,
                // On Unix, EIO after the child exits means end of output.
                Err(_) => break,
            }
        }
    });
}

/// Writes client input to the PTY until the session drops its sender.
pub(super) fn spawn_writer(
    id: &TerminalId,
    mut writer: Box<dyn Write + Send>,
    mut input: mpsc::Receiver<Bytes>,
) {
    spawn_named(format!("pty-write-{id}"), move || {
        while let Some(data) = input.blocking_recv() {
            if writer
                .write_all(&data)
                .and_then(|()| writer.flush())
                .is_err()
            {
                break;
            }
        }
    });
}

/// Waits for the child to exit and reports its status.
pub(super) fn spawn_waiter(
    id: &TerminalId,
    mut child: Box<dyn PtyChild>,
    exit: oneshot::Sender<ExitStatus>,
) {
    spawn_named(format!("pty-wait-{id}"), move || {
        let status = child.wait().unwrap_or(ExitStatus::UNKNOWN);
        let _ = exit.send(status);
    });
}

fn spawn_named(name: String, body: impl FnOnce() + Send + 'static) {
    if let Err(error) = thread::Builder::new().name(name.clone()).spawn(body) {
        tracing::error!(thread = name, %error, "failed to spawn PTY thread");
    }
}
