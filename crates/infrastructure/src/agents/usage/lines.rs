//! Following a file a CLI appends JSON lines to.

use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;

/// The complete lines of `path` from `offset` on, and how many bytes they
/// took: a line still being written waits for the next read.
pub(super) fn complete_lines(path: &Path, offset: u64) -> std::io::Result<(String, u64)> {
    let mut file = File::open(path)?;
    file.seek(SeekFrom::Start(offset))?;
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes)?;
    let complete = bytes.iter().rposition(|b| *b == b'\n').map_or(0, |i| i + 1);
    let text = String::from_utf8_lossy(&bytes[..complete]).into_owned();
    Ok((text, complete as u64))
}

#[cfg(test)]
mod tests {
    use std::io::Write;

    use super::*;

    #[test]
    fn a_line_still_being_written_waits() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("events.jsonl");
        std::fs::write(&path, "one\ntw").unwrap();
        let (text, read) = complete_lines(&path, 0).unwrap();
        assert_eq!((text.as_str(), read), ("one\n", 4));
        std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap()
            .write_all(b"o\n")
            .unwrap();
        let (text, read) = complete_lines(&path, 4).unwrap();
        assert_eq!((text.as_str(), read), ("two\n", 4));
    }
}
