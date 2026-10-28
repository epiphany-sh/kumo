//! Minimal terminal client for the scenarios.

use bytes::Bytes;
use kumo_grpc::client::KumoClient;
use kumo_grpc::proto as pb;
use pb::terminal_input::Kind as InputKind;
use pb::terminal_output::Kind as OutputKind;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;

/// One event from the terminal.
pub enum Output {
    Batch(pb::OutputBatch),
    Exited(i32),
}

pub struct BenchTerminal {
    pub id: String,
    input: mpsc::Sender<pb::TerminalInput>,
    output: tonic::Streaming<pb::TerminalOutput>,
}

impl BenchTerminal {
    pub async fn open(
        client: &mut KumoClient,
        program: &str,
        args: &[&str],
    ) -> anyhow::Result<Self> {
        let request = pb::OpenRequest {
            program: program.into(),
            args: args.iter().map(|a| (*a).to_owned()).collect(),
            cols: 120,
            rows: 40,
            ..Default::default()
        };
        let id = client
            .terminals
            .open(request)
            .await?
            .into_inner()
            .terminal_id;

        let (input, rx) = mpsc::channel(64);
        input
            .send(message(InputKind::Attach(pb::AttachTo {
                terminal_id: id.clone(),
                replay_scrollback: true,
            })))
            .await?;
        let output = client
            .terminals
            .attach(ReceiverStream::new(rx))
            .await?
            .into_inner();
        Ok(Self { id, input, output })
    }

    pub async fn send(&self, data: Bytes) -> anyhow::Result<()> {
        self.input.send(message(InputKind::Data(data))).await?;
        Ok(())
    }

    pub async fn next(&mut self) -> anyhow::Result<Option<Output>> {
        loop {
            let Some(message) = self.output.message().await? else {
                return Ok(None);
            };
            match message.kind {
                Some(OutputKind::Output(batch)) => return Ok(Some(Output::Batch(batch))),
                Some(OutputKind::Exited(exited)) => {
                    return Ok(Some(Output::Exited(exited.exit_code)));
                }
                None => continue,
            }
        }
    }

    /// Reads until the accumulated output contains `needle`.
    pub async fn wait_for(&mut self, needle: &[u8]) -> anyhow::Result<()> {
        let mut seen = Vec::new();
        while !seen.windows(needle.len()).any(|w| w == needle) {
            match self.next().await? {
                Some(Output::Batch(batch)) => seen.extend_from_slice(&batch.data),
                Some(Output::Exited(code)) => anyhow::bail!("exited ({code}) before {needle:?}"),
                None => anyhow::bail!("stream ended before {needle:?}"),
            }
        }
        Ok(())
    }

    pub async fn close(self, client: &mut KumoClient) -> anyhow::Result<()> {
        client
            .terminals
            .close(pb::CloseRequest {
                terminal_id: self.id,
            })
            .await?;
        Ok(())
    }
}

fn message(kind: InputKind) -> pb::TerminalInput {
    pb::TerminalInput { kind: Some(kind) }
}
