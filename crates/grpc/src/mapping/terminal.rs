use std::path::PathBuf;

use kumo_domain::terminal::{
    LaunchSpec, TerminalError, TerminalEvent, TerminalInfo, TerminalSize, TerminalStatus,
};
use kumo_proto::v1 as pb;

/// `0x0` means "use the default size".
pub fn size_from(cols: u32, rows: u32) -> Result<TerminalSize, TerminalError> {
    if cols == 0 && rows == 0 {
        return Ok(TerminalSize::DEFAULT);
    }
    TerminalSize::new(cols, rows)
}

pub fn launch_spec_from(request: pb::OpenRequest) -> Result<LaunchSpec, TerminalError> {
    let cwd = (!request.cwd.is_empty()).then(|| PathBuf::from(request.cwd));
    Ok(LaunchSpec::new(request.program)?
        .with_args(request.args)
        .with_cwd(cwd)
        .with_env(request.env)
        .with_size(size_from(request.cols, request.rows)?))
}

pub fn terminal_output_to(event: TerminalEvent) -> pb::TerminalOutput {
    use pb::terminal_output::Kind;

    let kind = match event {
        TerminalEvent::Output(batch) => Kind::Output(pb::OutputBatch {
            seq: batch.seq,
            data: batch.data,
            first_read_unix_nanos: batch.first_read_at.as_unix_nanos(),
            chunks: batch.chunks,
        }),
        TerminalEvent::Exited(status) => Kind::Exited(pb::Exited {
            exit_code: status.code(),
        }),
    };
    pb::TerminalOutput { kind: Some(kind) }
}

pub fn terminal_info_to(info: TerminalInfo) -> pb::TerminalInfo {
    let exit = match info.status {
        TerminalStatus::Running => None,
        TerminalStatus::Exited(status) => Some(status.code()),
    };
    pb::TerminalInfo {
        terminal_id: info.id.to_string(),
        program: info.program,
        cwd: info
            .cwd
            .map(|p| p.display().to_string())
            .unwrap_or_default(),
        exited: exit.is_some(),
        exit_code: exit.unwrap_or_default(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_size_means_default() {
        assert_eq!(size_from(0, 0).unwrap(), TerminalSize::DEFAULT);
        assert!(size_from(0, 10).is_err());
    }

    #[test]
    fn empty_cwd_means_none() {
        let spec = launch_spec_from(pb::OpenRequest {
            program: "sh".into(),
            ..Default::default()
        })
        .unwrap();
        assert_eq!(spec.cwd(), None);
    }
}
