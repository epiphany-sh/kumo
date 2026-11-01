use std::fs::{self, File};
use std::io::{ErrorKind, Write};
use std::path::{Path, PathBuf};

use kumo_domain::profiles::{Profile, ProfileError, ProfileId, ProfileStore};
use kumo_domain::time::Timestamp;
use serde::{Deserialize, Serialize};

const FILE_NAME: &str = "profiles.json";
const PROFILES_DIR: &str = "profiles";
const FORMAT: u32 = 1;

/// Where a profile keeps its `kumo.db`, `agents/` and `cli/`: Kumo's data
/// folder itself for the default profile (its data from before profiles
/// stays where it was), `<data>/profiles/<id>` for the others.
pub fn profile_dir(data_dir: &Path, id: &ProfileId) -> PathBuf {
    if id.is_default() {
        data_dir.to_owned()
    } else {
        data_dir.join(PROFILES_DIR).join(id.as_str())
    }
}

/// `<data>/profiles.json`, written atomically.
#[derive(Debug, Clone)]
pub struct FileProfileStore {
    data_dir: PathBuf,
}

impl FileProfileStore {
    pub fn in_dir(data_dir: impl Into<PathBuf>) -> Self {
        Self {
            data_dir: data_dir.into(),
        }
    }

    fn path(&self) -> PathBuf {
        self.data_dir.join(FILE_NAME)
    }
}

/// On-disk shape, separate from the domain type.
#[derive(Debug, Serialize, Deserialize)]
struct Registry {
    format: u32,
    profiles: Vec<Record>,
}

#[derive(Debug, Serialize, Deserialize)]
struct Record {
    id: String,
    name: String,
    color: String,
    position: u32,
    worktrees_dir: String,
    #[serde(default)]
    git_name: String,
    #[serde(default)]
    git_email: String,
    created_at_unix_nanos: u64,
}

impl ProfileStore for FileProfileStore {
    fn load(&self) -> Result<Option<Vec<Profile>>, ProfileError> {
        let path = self.path();
        let raw = match fs::read(&path) {
            Ok(raw) => raw,
            Err(e) if e.kind() == ErrorKind::NotFound => return Ok(None),
            Err(e) => return Err(storage_error(&path, e)),
        };
        let registry: Registry =
            serde_json::from_slice(&raw).map_err(|e| storage_error(&path, e))?;
        if registry.format > FORMAT {
            return Err(storage_error(&path, "written by a newer Kumo"));
        }
        registry
            .profiles
            .into_iter()
            .map(|r| {
                Ok(Profile {
                    id: ProfileId::parse(&r.id)?,
                    name: r.name,
                    color: r.color,
                    position: r.position,
                    worktrees_dir: r.worktrees_dir,
                    git_name: r.git_name,
                    git_email: r.git_email,
                    created_at: Timestamp::from_unix_nanos(r.created_at_unix_nanos),
                })
            })
            .collect::<Result<_, _>>()
            .map(Some)
    }

    fn save(&self, profiles: &[Profile]) -> Result<(), ProfileError> {
        let registry = Registry {
            format: FORMAT,
            profiles: profiles
                .iter()
                .map(|p| Record {
                    id: p.id.to_string(),
                    name: p.name.clone(),
                    color: p.color.clone(),
                    position: p.position,
                    worktrees_dir: p.worktrees_dir.clone(),
                    git_name: p.git_name.clone(),
                    git_email: p.git_email.clone(),
                    created_at_unix_nanos: p.created_at.as_unix_nanos(),
                })
                .collect(),
        };
        let path = self.path();
        let json = serde_json::to_vec_pretty(&registry).map_err(|e| storage_error(&path, e))?;
        fs::create_dir_all(&self.data_dir).map_err(|e| storage_error(&self.data_dir, e))?;
        // A temporary sibling, then rename: atomic on the same volume.
        let tmp = path.with_extension(format!("json.tmp-{}", std::process::id()));
        let written = File::create(&tmp).and_then(|mut file| {
            file.write_all(&json)?;
            file.sync_all()
        });
        if let Err(e) = written.and_then(|()| fs::rename(&tmp, &path)) {
            let _ = fs::remove_file(&tmp);
            return Err(storage_error(&path, e));
        }
        Ok(())
    }

    fn remove_data(&self, id: &ProfileId) -> Result<(), ProfileError> {
        if id.is_default() {
            return Err(ProfileError::DefaultProfile);
        }
        // The id is a slug (no `/` or `..`): the folder is inside `profiles/`.
        let dir = profile_dir(&self.data_dir, id);
        match fs::remove_dir_all(&dir) {
            Ok(()) => Ok(()),
            Err(e) if e.kind() == ErrorKind::NotFound => Ok(()),
            Err(e) => Err(storage_error(&dir, e)),
        }
    }
}

fn storage_error(path: &Path, error: impl std::fmt::Display) -> ProfileError {
    ProfileError::Storage(format!("{}: {error}", path.display()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn id(raw: &str) -> ProfileId {
        ProfileId::parse(raw).unwrap()
    }

    #[test]
    fn round_trips_the_registry() {
        let dir = tempfile::tempdir().unwrap();
        let store = FileProfileStore::in_dir(dir.path().join("data"));
        assert_eq!(store.load().unwrap(), None);

        let mut second = Profile::new(
            id("workspace-1"),
            "Workspace 1",
            "#123456",
            1,
            Timestamp::from_unix_nanos(5),
        )
        .unwrap();
        second.git_email = "me@workspace-1.test".into();
        let profiles = vec![Profile::first(Timestamp::from_unix_nanos(1)), second];
        store.save(&profiles).unwrap();
        assert_eq!(store.load().unwrap(), Some(profiles));
    }

    #[test]
    fn the_default_profile_lives_in_the_data_folder_itself() {
        let data = Path::new("/data/kumo");
        assert_eq!(profile_dir(data, &ProfileId::default_profile()), data);
        assert_eq!(
            profile_dir(data, &id("workspace-1")),
            data.join("profiles/workspace-1")
        );
    }

    #[test]
    fn remove_data_deletes_only_that_profile_folder() {
        let dir = tempfile::tempdir().unwrap();
        let data = dir.path();
        fs::write(data.join("kumo.db"), b"default").unwrap();
        for p in ["workspace-1", "workspace-2"] {
            fs::create_dir_all(data.join("profiles").join(p)).unwrap();
            fs::write(data.join("profiles").join(p).join("kumo.db"), b"x").unwrap();
        }
        let store = FileProfileStore::in_dir(data);
        store.remove_data(&id("workspace-1")).unwrap();
        store.remove_data(&id("workspace-1")).unwrap();
        assert!(!data.join("profiles/workspace-1").exists());
        assert!(data.join("profiles/workspace-2/kumo.db").exists());
        assert_eq!(
            store.remove_data(&ProfileId::default_profile()),
            Err(ProfileError::DefaultProfile)
        );
        assert!(data.join("kumo.db").exists());
    }
}
