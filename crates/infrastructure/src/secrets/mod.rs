//! API tokens in the OS keychain (Keychain on macOS, Credential Manager on
//! Windows), never in Kumo's database.

use std::collections::HashMap;
use std::sync::{Arc, Mutex, PoisonError};

use keyring_core::{CredentialStore, Error as KeyringError};
use kumo_domain::tasks::{SecretStore, SourceId, TaskError};

const SERVICE: &str = "kumo";

/// [`SecretStore`] on the OS keychain.
pub struct KeychainSecretStore {
    store: Option<Arc<CredentialStore>>,
}

impl std::fmt::Debug for KeychainSecretStore {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("KeychainSecretStore")
            .field("available", &self.store.is_some())
            .finish()
    }
}

impl KeychainSecretStore {
    pub fn new() -> Self {
        let store = native_store();
        if let Err(error) = &store {
            tracing::warn!(%error, "no keychain: API tokens can't be stored");
        }
        Self { store: store.ok() }
    }

    fn entry(&self, source: &SourceId) -> Result<keyring_core::Entry, TaskError> {
        let store = self
            .store
            .as_ref()
            .ok_or_else(|| TaskError::Secret("no keychain on this system".into()))?;
        store
            .build(SERVICE, &format!("task-source:{source}"), None)
            .map_err(secret_error)
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

fn secret_error(error: KeyringError) -> TaskError {
    TaskError::Secret(error.to_string())
}

/// [`SecretStore`] in memory, for tests and machines without a keychain.
#[derive(Debug, Default)]
pub struct MemorySecretStore(Mutex<HashMap<SourceId, String>>);

impl SecretStore for MemorySecretStore {
    fn get(&self, source: &SourceId) -> Result<Option<String>, TaskError> {
        Ok(self.lock().get(source).cloned())
    }

    fn set(&self, source: &SourceId, secret: &str) -> Result<(), TaskError> {
        self.lock().insert(source.clone(), secret.to_owned());
        Ok(())
    }

    fn delete(&self, source: &SourceId) -> Result<(), TaskError> {
        self.lock().remove(source);
        Ok(())
    }
}

impl MemorySecretStore {
    fn lock(&self) -> std::sync::MutexGuard<'_, HashMap<SourceId, String>> {
        self.0.lock().unwrap_or_else(PoisonError::into_inner)
    }
}
