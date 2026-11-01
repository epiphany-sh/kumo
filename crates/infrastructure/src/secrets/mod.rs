//! API tokens in the OS keychain (Keychain on macOS, Credential Manager on
//! Windows), never in Kumo's database: the task sources' and one per
//! repository host (pipelines).
//!
//! Each profile has its own: the default profile keeps the names from before
//! profiles (`task-source:<id>`, `host-token:<host>`), the others prefix
//! them with their id (`workspace-1/host-token:github.com`). A store is
//! scoped to one profile when it's made, so a service can't read another
//! profile's tokens.

use std::collections::HashMap;
use std::sync::{Arc, Mutex, PoisonError};

use keyring_core::{CredentialStore, Error as KeyringError};
use kumo_domain::pipelines::{HostTokens, PipelinesError};
use kumo_domain::profiles::ProfileId;
use kumo_domain::tasks::{SecretStore, SourceId, TaskError};

const SERVICE: &str = "kumo";

/// The keychain account names of one profile.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
struct Accounts {
    /// Empty for the default profile, `<id>/` for the others.
    prefix: String,
}

impl Accounts {
    fn of(profile: &ProfileId) -> Self {
        let prefix = if profile.is_default() {
            String::new()
        } else {
            format!("{profile}/")
        };
        Self { prefix }
    }

    fn source(&self, source: &SourceId) -> String {
        format!("{}task-source:{source}", self.prefix)
    }

    fn host(&self, host: &str) -> String {
        format!("{}host-token:{host}", self.prefix)
    }

    /// Whether `account` is one of this profile's. Only for prefixed
    /// profiles: the default one's names can't be told apart this way.
    fn owns(&self, account: &str) -> bool {
        !self.prefix.is_empty() && account.starts_with(&self.prefix)
    }
}

/// The accounts of a profile that's about to be forgotten. The default
/// profile's tokens are never removed in bulk.
fn purgeable(profile: &ProfileId) -> Result<Accounts, String> {
    if profile.is_default() {
        return Err("the default profile's tokens aren't removed in bulk".to_owned());
    }
    Ok(Accounts::of(profile))
}

/// [`SecretStore`] and [`HostTokens`] on the OS keychain.
#[derive(Clone)]
pub struct KeychainSecretStore {
    store: Option<Arc<CredentialStore>>,
    accounts: Accounts,
}

impl std::fmt::Debug for KeychainSecretStore {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("KeychainSecretStore")
            .field("available", &self.store.is_some())
            .field("prefix", &self.accounts.prefix)
            .finish()
    }
}

impl KeychainSecretStore {
    /// The default profile's tokens.
    pub fn new() -> Self {
        let store = native_store();
        if let Err(error) = &store {
            tracing::warn!(%error, "no keychain: API tokens can't be stored");
        }
        Self {
            store: store.ok(),
            accounts: Accounts::default(),
        }
    }

    /// The same keychain, with `profile`'s tokens.
    pub fn for_profile(&self, profile: &ProfileId) -> Self {
        Self {
            store: self.store.clone(),
            accounts: Accounts::of(profile),
        }
    }

    /// Deletes every token of `profile`; how many it deleted. Refused for
    /// the default profile.
    pub fn purge(&self, profile: &ProfileId) -> Result<usize, String> {
        let accounts = purgeable(profile)?;
        let Some(store) = &self.store else {
            return Ok(0);
        };
        let entries = store.search(&search_spec()).map_err(|e| e.to_string())?;
        let mut deleted = 0;
        for entry in entries {
            let Some((service, account)) = entry.get_specifiers() else {
                continue;
            };
            if service != SERVICE || !accounts.owns(&account) {
                continue;
            }
            match entry.delete_credential() {
                Ok(()) => deleted += 1,
                Err(KeyringError::NoEntry) => {}
                Err(error) => return Err(error.to_string()),
            }
        }
        Ok(deleted)
    }

    fn entry(&self, source: &SourceId) -> Result<keyring_core::Entry, TaskError> {
        self.account(&self.accounts.source(source))
            .map_err(TaskError::Secret)
    }

    fn account(&self, user: &str) -> Result<keyring_core::Entry, String> {
        let store = self
            .store
            .as_ref()
            .ok_or_else(|| "no keychain on this system".to_owned())?;
        store.build(SERVICE, user, None).map_err(|e| e.to_string())
    }

    fn host_entry(&self, host: &str) -> Result<keyring_core::Entry, PipelinesError> {
        self.account(&self.accounts.host(host))
            .map_err(PipelinesError::Secret)
    }
}

impl Default for KeychainSecretStore {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(target_os = "macos")]
fn native_store() -> Result<Arc<CredentialStore>, KeyringError> {
    Ok(apple_native_keyring_store::keychain::Store::new()?)
}

#[cfg(windows)]
fn native_store() -> Result<Arc<CredentialStore>, KeyringError> {
    Ok(windows_native_keyring_store::Store::new()?)
}

#[cfg(not(any(target_os = "macos", windows)))]
fn native_store() -> Result<Arc<CredentialStore>, KeyringError> {
    Err(KeyringError::NotSupportedByStore(
        "Linux keychains aren't supported yet".into(),
    ))
}

/// Kumo's keychain items, as each store searches them. The results are
/// still checked one by one.
#[cfg(target_os = "macos")]
fn search_spec() -> HashMap<&'static str, &'static str> {
    HashMap::from([("service", SERVICE)])
}

#[cfg(not(target_os = "macos"))]
fn search_spec() -> HashMap<&'static str, &'static str> {
    HashMap::from([("pattern", SERVICE)])
}

impl SecretStore for KeychainSecretStore {
    fn get(&self, source: &SourceId) -> Result<Option<String>, TaskError> {
        match self.entry(source)?.get_password() {
            Ok(secret) => Ok(Some(secret)),
            Err(KeyringError::NoEntry) => Ok(None),
            Err(error) => Err(secret_error(error)),
        }
    }

    fn set(&self, source: &SourceId, secret: &str) -> Result<(), TaskError> {
        self.entry(source)?
            .set_password(secret)
            .map_err(secret_error)
    }

    fn delete(&self, source: &SourceId) -> Result<(), TaskError> {
        match self.entry(source)?.delete_credential() {
            Ok(()) | Err(KeyringError::NoEntry) => Ok(()),
            Err(error) => Err(secret_error(error)),
        }
    }
}

impl HostTokens for KeychainSecretStore {
    fn get(&self, host: &str) -> Result<Option<String>, PipelinesError> {
        match self.host_entry(host)?.get_password() {
            Ok(token) => Ok(Some(token)),
            Err(KeyringError::NoEntry) => Ok(None),
            Err(error) => Err(PipelinesError::Secret(error.to_string())),
        }
    }

    fn set(&self, host: &str, token: &str) -> Result<(), PipelinesError> {
        self.host_entry(host)?
            .set_password(token)
            .map_err(|e| PipelinesError::Secret(e.to_string()))
    }

    fn delete(&self, host: &str) -> Result<(), PipelinesError> {
        match self.host_entry(host)?.delete_credential() {
            Ok(()) | Err(KeyringError::NoEntry) => Ok(()),
            Err(error) => Err(PipelinesError::Secret(error.to_string())),
        }
    }
}

fn secret_error(error: KeyringError) -> TaskError {
    TaskError::Secret(error.to_string())
}

/// [`SecretStore`] and [`HostTokens`] in memory, for tests and machines
/// without a keychain. Stores made with [`Self::for_profile`] share the
/// same items, under the same names as the keychain.
#[derive(Debug, Clone, Default)]
pub struct MemorySecretStore {
    items: Arc<Mutex<HashMap<String, String>>>,
    accounts: Accounts,
}

impl MemorySecretStore {
    /// The same items, with `profile`'s tokens.
    pub fn for_profile(&self, profile: &ProfileId) -> Self {
        Self {
            items: Arc::clone(&self.items),
            accounts: Accounts::of(profile),
        }
    }

    /// Deletes every token of `profile`; how many it deleted. Refused for
    /// the default profile.
    pub fn purge(&self, profile: &ProfileId) -> Result<usize, String> {
        let accounts = purgeable(profile)?;
        let mut items = self.items();
        let before = items.len();
        items.retain(|account, _| !accounts.owns(account));
        Ok(before - items.len())
    }

    /// How many tokens it holds, of every profile.
    pub fn len(&self) -> usize {
        self.items().len()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    fn items(&self) -> std::sync::MutexGuard<'_, HashMap<String, String>> {
        self.items.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

impl SecretStore for MemorySecretStore {
    fn get(&self, source: &SourceId) -> Result<Option<String>, TaskError> {
        Ok(self.items().get(&self.accounts.source(source)).cloned())
    }

    fn set(&self, source: &SourceId, secret: &str) -> Result<(), TaskError> {
        self.items()
            .insert(self.accounts.source(source), secret.to_owned());
        Ok(())
    }

    fn delete(&self, source: &SourceId) -> Result<(), TaskError> {
        self.items().remove(&self.accounts.source(source));
        Ok(())
    }
}

impl HostTokens for MemorySecretStore {
    fn get(&self, host: &str) -> Result<Option<String>, PipelinesError> {
        Ok(self.items().get(&self.accounts.host(host)).cloned())
    }

    fn set(&self, host: &str, token: &str) -> Result<(), PipelinesError> {
        self.items()
            .insert(self.accounts.host(host), token.to_owned());
        Ok(())
    }

    fn delete(&self, host: &str) -> Result<(), PipelinesError> {
        self.items().remove(&self.accounts.host(host));
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn id(raw: &str) -> ProfileId {
        ProfileId::parse(raw).unwrap()
    }

    fn source(raw: &str) -> SourceId {
        SourceId::parse(raw).unwrap()
    }

    #[test]
    fn the_default_profile_keeps_the_names_from_before_profiles() {
        let accounts = Accounts::of(&ProfileId::default_profile());
        assert_eq!(accounts.source(&source("s1")), "task-source:s1");
        assert_eq!(accounts.host("github.com"), "host-token:github.com");
    }

    #[test]
    fn other_profiles_prefix_their_names() {
        let accounts = Accounts::of(&id("workspace-1"));
        assert_eq!(accounts.source(&source("s1")), "workspace-1/task-source:s1");
        assert_eq!(
            accounts.host("github.com"),
            "workspace-1/host-token:github.com"
        );
    }

    #[test]
    fn profiles_dont_see_each_others_tokens() {
        let default = MemorySecretStore::default();
        let one = default.for_profile(&id("workspace-1"));
        let two = default.for_profile(&id("workspace-2"));
        HostTokens::set(&one, "github.com", "token-1").unwrap();
        SecretStore::set(&two, &source("s1"), "secret-2").unwrap();

        assert_eq!(
            HostTokens::get(&one, "github.com").unwrap().as_deref(),
            Some("token-1")
        );
        assert_eq!(HostTokens::get(&two, "github.com").unwrap(), None);
        assert_eq!(HostTokens::get(&default, "github.com").unwrap(), None);
        assert_eq!(SecretStore::get(&one, &source("s1")).unwrap(), None);
    }

    #[test]
    fn purge_removes_only_that_profiles_tokens() {
        let default = MemorySecretStore::default();
        let one = default.for_profile(&id("workspace-1"));
        let ten = default.for_profile(&id("workspace-10"));
        HostTokens::set(&default, "github.com", "token-0").unwrap();
        HostTokens::set(&one, "github.com", "token-1").unwrap();
        SecretStore::set(&one, &source("s1"), "secret-1").unwrap();
        HostTokens::set(&ten, "github.com", "token-10").unwrap();

        assert_eq!(default.purge(&id("workspace-1")), Ok(2));
        assert_eq!(default.len(), 2);
        assert!(HostTokens::get(&ten, "github.com").unwrap().is_some());
        assert!(HostTokens::get(&default, "github.com").unwrap().is_some());
    }

    #[test]
    fn the_default_profiles_tokens_are_never_purged() {
        let default = MemorySecretStore::default();
        HostTokens::set(&default, "github.com", "token-0").unwrap();
        assert!(default.purge(&ProfileId::default_profile()).is_err());
        assert_eq!(default.len(), 1);
    }
}
