use std::fmt;

use super::ProfileError;

/// A profile's stable id: a short slug (`workspace-1`, `client-2`). Renaming a
/// profile never changes it, and it names the profile's data folder.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct ProfileId(String);

impl ProfileId {
    /// The first profile: the data Kumo had before profiles existed.
    pub const DEFAULT: &'static str = "default";
    const MAX_LEN: usize = 32;
    /// Room left for a `-N` suffix when a slug is taken.
    const SLUG_LEN: usize = 24;

    pub fn default_profile() -> Self {
        Self(Self::DEFAULT.to_owned())
    }

    /// Lowercase ASCII letters, digits and inner dashes, at most 32.
    pub fn parse(raw: &str) -> Result<Self, ProfileError> {
        let valid = !raw.is_empty()
            && raw.len() <= Self::MAX_LEN
            && raw
                .bytes()
                .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
            && !raw.starts_with('-')
            && !raw.ends_with('-');
        if valid {
            Ok(Self(raw.to_owned()))
        } else {
            Err(ProfileError::InvalidId(raw.to_owned()))
        }
    }

    /// A slug for `name` that isn't `taken`: "Workspace One" → `workspace-one`,
    /// then `workspace-one-2`, …
    pub fn from_name(name: &str, taken: impl Fn(&ProfileId) -> bool) -> Self {
        let mut slug = String::new();
        for c in name
            .trim()
            .chars()
            .flat_map(char::to_lowercase)
            .map(unaccent)
        {
            if c.is_ascii_alphanumeric() {
                slug.push(c);
            } else if !slug.is_empty() && !slug.ends_with('-') {
                slug.push('-');
            }
            if slug.len() >= Self::SLUG_LEN {
                break;
            }
        }
        let slug = slug.trim_end_matches('-');
        let base = if slug.is_empty() { "workspace" } else { slug };
        let mut candidate = Self(base.to_owned());
        let mut n = 2;
        while taken(&candidate) {
            candidate = Self(format!("{base}-{n}"));
            n += 1;
        }
        candidate
    }

    pub fn is_default(&self) -> bool {
        self.0 == Self::DEFAULT
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// The plain letter of the accented ones common in names ("Señal Única").
fn unaccent(c: char) -> char {
    match c {
        'á' | 'à' | 'ä' | 'â' | 'ã' | 'å' => 'a',
        'é' | 'è' | 'ë' | 'ê' => 'e',
        'í' | 'ì' | 'ï' | 'î' => 'i',
        'ó' | 'ò' | 'ö' | 'ô' | 'õ' | 'ø' => 'o',
        'ú' | 'ù' | 'ü' | 'û' => 'u',
        'ñ' => 'n',
        'ç' => 'c',
        other => other,
    }
}

impl fmt::Display for ProfileId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_slugs_only() {
        assert!(ProfileId::parse("workspace-1").is_ok());
        assert!(ProfileId::parse("w2").is_ok());
        for bad in [
            "",
            "Workspace-1",
            "-a",
            "a-",
            "a/b",
            "..",
            "a b",
            &"a".repeat(33),
        ] {
            assert!(ProfileId::parse(bad).is_err(), "{bad:?}");
        }
    }

    #[test]
    fn slugs_names_and_avoids_taken_ones() {
        let none = |_: &ProfileId| false;
        assert_eq!(
            ProfileId::from_name("Workspace One", none).as_str(),
            "workspace-one"
        );
        assert_eq!(
            ProfileId::from_name("  Señal Única!! ", none).as_str(),
            "senal-unica"
        );
        assert_eq!(ProfileId::from_name("✨", none).as_str(), "workspace");
        let taken = |id: &ProfileId| matches!(id.as_str(), "workspace-1" | "workspace-1-2");
        assert_eq!(
            ProfileId::from_name("Workspace 1", taken).as_str(),
            "workspace-1-3"
        );
        let long = ProfileId::from_name(&"x".repeat(80), none);
        assert!(ProfileId::parse(long.as_str()).is_ok());
    }
}
