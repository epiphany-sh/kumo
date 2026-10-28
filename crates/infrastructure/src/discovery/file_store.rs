use std::fs::{self, File, OpenOptions};
use std::io::{ErrorKind, Write};
use std::net::SocketAddr;
use std::path::{Path, PathBuf};

use kumo_domain::daemon::{ApiVersion, AuthToken, DaemonEndpoint, DaemonError, DiscoveryStore};
use serde::{Deserialize, Serialize};

const FILE_NAME: &str = "daemon.json";
const APP_DIR: &str = "kumo";

/// `daemon.json` in the user's local data directory, owner-only on Unix.
#[derive(Debug, Clone)]
pub struct FileDiscoveryStore {
    path: PathBuf,
}

impl FileDiscoveryStore {
    /// Store inside `dir` (created on save if missing).
    pub fn in_dir(dir: impl AsRef<Path>) -> Self {
        Self {
            path: dir.as_ref().join(FILE_NAME),
        }
    }

    /// The per-user default: `<data_local_dir>/kumo/daemon.json`.
    pub fn default_location() -> Option<Self> {
        dirs::data_local_dir().map(|dir| Self::in_dir(dir.join(APP_DIR)))
    }

    pub fn path(&self) -> &Path {
        &self.path
    }
}

/// On-disk shape. Kept separate from the domain type so the file format can
/// evolve on its own.
#[derive(Debug, Serialize, Deserialize)]
struct Record {
    api_version: u32,
    pid: u32,
    addr: SocketAddr,
    token: String,
}

impl DiscoveryStore for FileDiscoveryStore {
    fn load(&self) -> Result<Option<DaemonEndpoint>, DaemonError> {
        let raw = match fs::read(&self.path) {
            Ok(raw) => raw,
            Err(e) if e.kind() == ErrorKind::NotFound => return Ok(None),
            Err(e) => return Err(discovery_error(&self.path, e)),
        };
        let record: Record =
            serde_json::from_slice(&raw).map_err(|e| discovery_error(&self.path, e))?;
        Ok(Some(DaemonEndpoint {
            api_version: ApiVersion::new(record.api_version),
            pid: record.pid,
            addr: record.addr,
            token: AuthToken::parse(&record.token)?,
        }))
    }

    fn save(&self, endpoint: &DaemonEndpoint) -> Result<(), DaemonError> {
        let record = Record {
            api_version: endpoint.api_version.get(),
            pid: endpoint.pid,
            addr: endpoint.addr,
            token: endpoint.token.as_str().to_owned(),
        };
        let json =
            serde_json::to_vec_pretty(&record).map_err(|e| discovery_error(&self.path, e))?;
        if let Some(dir) = self.path.parent() {
            fs::create_dir_all(dir).map_err(|e| discovery_error(dir, e))?;
        }

        // Write to a temporary sibling, then rename: atomic on the same volume.
        let tmp = self
            .path
            .with_extension(format!("json.tmp-{}", std::process::id()));
        let written = create_private(&tmp).and_then(|mut file| {
            file.write_all(&json)?;
            file.sync_all()
        });
        if let Err(e) = written.and_then(|()| fs::rename(&tmp, &self.path)) {
            let _ = fs::remove_file(&tmp);
            return Err(discovery_error(&self.path, e));
        }
        Ok(())
    }

    fn remove(&self) -> Result<(), DaemonError> {
        match fs::remove_file(&self.path) {
            Ok(()) => Ok(()),
            Err(e) if e.kind() == ErrorKind::NotFound => Ok(()),
            Err(e) => Err(discovery_error(&self.path, e)),
        }
    }
}

/// Creates a file readable and writable only by its owner (Unix `0600`).
fn create_private(path: &Path) -> std::io::Result<File> {
    let mut options = OpenOptions::new();
    options.write(true).create(true).truncate(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    options.open(path)
}

fn discovery_error(path: &Path, error: impl std::fmt::Display) -> DaemonError {
    DaemonError::Discovery(format!("{}: {error}", path.display()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn endpoint() -> DaemonEndpoint {
        DaemonEndpoint {
            api_version: ApiVersion::CURRENT,
            pid: 42,
            addr: "127.0.0.1:4242".parse().unwrap(),
            token: AuthToken::from_bytes([9; AuthToken::BYTES]),
        }
    }

    #[test]
    fn save_load_remove_round_trip() {
        let dir = tempfile::tempdir().unwrap();
        let store = FileDiscoveryStore::in_dir(dir.path().join("nested"));

        assert_eq!(store.load().unwrap(), None);
        store.save(&endpoint()).unwrap();
        assert_eq!(store.load().unwrap(), Some(endpoint()));
        store.remove().unwrap();
        assert_eq!(store.load().unwrap(), None);
        store.remove().unwrap();
    }

    #[cfg(unix)]
    #[test]
    fn file_is_owner_only() {
        use std::os::unix::fs::PermissionsExt;

        let dir = tempfile::tempdir().unwrap();
        let store = FileDiscoveryStore::in_dir(dir.path());
        store.save(&endpoint()).unwrap();
        let mode = fs::metadata(store.path()).unwrap().permissions().mode();
        assert_eq!(mode & 0o777, 0o600);
    }
}
