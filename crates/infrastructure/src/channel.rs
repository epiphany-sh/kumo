//! The release channel, fixed at build time: `KUMO_CHANNEL=beta cargo build`.
//!
//! A channel build (`make sandbox`) keeps its data directory, discovery file
//! and keychain items apart from the stable app's, so both run side by side
//! without touching each other. Without it (releases, `make run`) the names
//! stay `kumo`.

use std::sync::LazyLock;

/// The channel, if this is not a stable build.
pub const CHANNEL: Option<&str> = match option_env!("KUMO_CHANNEL") {
    Some(channel) if !channel.is_empty() => Some(channel),
    _ => None,
};

/// `kumo`, or `kumo-<channel>`: the data directory and the keychain service.
pub fn app_name() -> &'static str {
    static NAME: LazyLock<String> = LazyLock::new(|| match CHANNEL {
        Some(channel) => format!("kumo-{channel}"),
        None => "kumo".to_owned(),
    });
    &NAME
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stable_builds_keep_the_plain_name() {
        let name = app_name();
        match CHANNEL {
            None => assert_eq!(name, "kumo"),
            Some(channel) => assert_eq!(name, format!("kumo-{channel}")),
        }
    }
}
