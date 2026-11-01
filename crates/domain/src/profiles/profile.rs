use crate::time::Timestamp;

use super::{ProfileError, ProfileId};

/// A profile as the registry keeps it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Profile {
    pub id: ProfileId,
    /// Empty only for the default profile until the user names it.
    pub name: String,
    /// `#RRGGBB`.
    pub color: String,
    /// Order in the switcher, from 0.
    pub position: u32,
    /// Where new worktrees go: `<dir>/<repo>/<branch>`. `~/` is the home.
    pub worktrees_dir: String,
    /// Commit identity inside this profile; empty: the user's git config.
    pub git_name: String,
    pub git_email: String,
    pub created_at: Timestamp,
}

impl Profile {
    pub const DEFAULT_COLOR: &'static str = "#8C9BFF";
    /// Worktrees of the default profile, as before profiles existed.
    pub const DEFAULT_WORKTREES_DIR: &'static str = "~/wt";

    /// The default profile: Kumo's data from before profiles, unnamed.
    pub fn first(created_at: Timestamp) -> Self {
        Self {
            id: ProfileId::default_profile(),
            name: String::new(),
            color: Self::DEFAULT_COLOR.to_owned(),
            position: 0,
            worktrees_dir: Self::DEFAULT_WORKTREES_DIR.to_owned(),
            git_name: String::new(),
            git_email: String::new(),
            created_at,
        }
    }

    /// A new profile; its worktrees go to `~/wt/<id>`.
    pub fn new(
        id: ProfileId,
        name: &str,
        color: &str,
        position: u32,
        created_at: Timestamp,
    ) -> Result<Self, ProfileError> {
        let mut profile = Self {
            worktrees_dir: format!("{}/{id}", Self::DEFAULT_WORKTREES_DIR),
            id,
            name: String::new(),
            color: Self::DEFAULT_COLOR.to_owned(),
            position,
            git_name: String::new(),
            git_email: String::new(),
            created_at,
        };
        profile.apply(ProfileChanges {
            name: Some(name.to_owned()),
            color: Some(color.to_owned()).filter(|c| !c.trim().is_empty()),
            ..ProfileChanges::default()
        })?;
        Ok(profile)
    }

    pub fn is_default(&self) -> bool {
        self.id.is_default()
    }

    /// Applies the fields that are set, validating them first: on error
    /// nothing changes. Position is the registry's business.
    pub fn apply(&mut self, changes: ProfileChanges) -> Result<(), ProfileError> {
        let name = changes.name.map(|n| n.trim().to_owned());
        if name.as_deref() == Some("") {
            return Err(ProfileError::EmptyName);
        }
        let color = changes.color.map(|c| c.trim().to_owned());
        if let Some(color) = &color
            && !is_hex_color(color)
        {
            return Err(ProfileError::InvalidColor(color.clone()));
        }
        let worktrees_dir = changes
            .worktrees_dir
            .map(|d| d.trim().trim_end_matches('/').to_owned())
            .filter(|d| !d.is_empty());
        if let Some(name) = name {
            self.name = name;
        }
        if let Some(color) = color {
            self.color = color.to_uppercase();
        }
        if let Some(dir) = worktrees_dir {
            self.worktrees_dir = dir;
        }
        if let Some(git_name) = changes.git_name {
            self.git_name = git_name.trim().to_owned();
        }
        if let Some(git_email) = changes.git_email {
            self.git_email = git_email.trim().to_owned();
        }
        Ok(())
    }
}

/// Fields to change in a profile; None leaves one as is.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ProfileChanges {
    pub name: Option<String>,
    pub color: Option<String>,
    pub position: Option<u32>,
    /// Empty keeps the current folder.
    pub worktrees_dir: Option<String>,
    /// Empty clears it (back to the user's git config).
    pub git_name: Option<String>,
    pub git_email: Option<String>,
}

/// What a profile has and runs right now, for the switcher.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct ProfileActivity {
    pub agents_running: u32,
    /// Agents whose turn ended: they need the user.
    pub agents_waiting: u32,
    pub terminals_open: u32,
    pub namespaces: u32,
    pub repos: u32,
}

fn is_hex_color(color: &str) -> bool {
    color.len() == 7 && color.starts_with('#') && color[1..].bytes().all(|b| b.is_ascii_hexdigit())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn id(raw: &str) -> ProfileId {
        ProfileId::parse(raw).unwrap()
    }

    #[test]
    fn a_new_profile_is_named_and_worktrees_go_under_its_id() {
        let p = Profile::new(
            id("workspace-2"),
            " Workspace 2 ",
            "",
            2,
            Timestamp::from_unix_nanos(1),
        )
        .unwrap();
        assert_eq!(p.name, "Workspace 2");
        assert_eq!(p.color, Profile::DEFAULT_COLOR);
        assert_eq!(p.worktrees_dir, "~/wt/workspace-2");
        assert_eq!(p.position, 2);
        assert!(!p.is_default());
        assert_eq!(
            Profile::new(id("x"), "  ", "", 0, Timestamp::from_unix_nanos(1)),
            Err(ProfileError::EmptyName)
        );
    }

    #[test]
    fn the_first_profile_keeps_the_old_worktrees_folder() {
        let p = Profile::first(Timestamp::from_unix_nanos(1));
        assert!(p.is_default());
        assert!(p.name.is_empty());
        assert_eq!(p.worktrees_dir, "~/wt");
    }

    #[test]
    fn apply_validates_before_changing_anything() {
        let mut p = Profile::first(Timestamp::from_unix_nanos(1));
        let bad = ProfileChanges {
            name: Some("Workspace 1".into()),
            color: Some("blue".into()),
            ..ProfileChanges::default()
        };
        assert_eq!(p.apply(bad), Err(ProfileError::InvalidColor("blue".into())));
        assert!(p.name.is_empty());

        p.apply(ProfileChanges {
            name: Some("Workspace 1".into()),
            color: Some("#ff8800".into()),
            worktrees_dir: Some("~/work/".into()),
            git_email: Some(" me@workspace-1.test ".into()),
            ..ProfileChanges::default()
        })
        .unwrap();
        assert_eq!(p.name, "Workspace 1");
        assert_eq!(p.color, "#FF8800");
        assert_eq!(p.worktrees_dir, "~/work");
        assert_eq!(p.git_email, "me@workspace-1.test");

        // Empty folder keeps it; empty identity clears it.
        p.apply(ProfileChanges {
            worktrees_dir: Some(" ".into()),
            git_email: Some(String::new()),
            ..ProfileChanges::default()
        })
        .unwrap();
        assert_eq!(p.worktrees_dir, "~/work");
        assert!(p.git_email.is_empty());
    }
}
