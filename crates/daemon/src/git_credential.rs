//! `kumod git-credential`: git's credential helper inside a profile.
//!
//! A profile's git config points `credential.https://<host>.helper` here
//! (see `GitSetup`). Git sends `protocol=https` and `host=…` on stdin; this
//! asks the running daemon for the token of the profile in `KUMO_PROFILE`
//! and prints it back. Only `get` answers: `store` and `erase` do nothing,
//! tokens stay where the profile keeps them.

use std::collections::HashMap;
use std::io::{BufRead, Write};
use std::path::Path;

use kumo_domain::daemon::DiscoveryStore;
use kumo_grpc::client::KumoClient;
use kumo_infrastructure::discovery::FileDiscoveryStore;
use kumo_proto::v1 as pb;

/// Answers one request from git. Problems go to stderr and print no
/// credential, so git goes on as if the helper had none.
pub async fn run(data_dir: &Path, operation: &str) {
    let request = read_request(std::io::stdin().lock());
    if operation != "get" {
        return;
    }
    let profile = std::env::var("KUMO_PROFILE").ok();
    match answer(data_dir, profile.as_deref(), &request).await {
        Ok(Some(credential)) => {
            let mut out = std::io::stdout().lock();
            let _ = writeln!(out, "username={}", credential.username);
            let _ = writeln!(out, "password={}", credential.password);
        }
        Ok(None) => {}
        Err(error) => eprintln!("kumod git-credential: {error}"),
    }
}

async fn answer(
    data_dir: &Path,
    profile: Option<&str>,
    request: &HashMap<String, String>,
) -> anyhow::Result<Option<pb::GitCredentialResponse>> {
    // Tokens only go over HTTPS.
    if request.get("protocol").map(String::as_str) != Some("https") {
        return Ok(None);
    }
    let Some(host) = request.get("host").filter(|h| !h.is_empty()) else {
        return Ok(None);
    };
    let endpoint = FileDiscoveryStore::in_dir(data_dir)
        .load()?
        .ok_or_else(|| anyhow::anyhow!("Kumo isn't running"))?;
    let mut client = KumoClient::connect(endpoint.addr, &endpoint.token)
        .await?
        .with_profile(profile);
    let credential = client
        .profiles
        .git_credential(pb::GitCredentialRequest { host: host.clone() })
        .await?
        .into_inner();
    Ok((!credential.password.is_empty()).then_some(credential))
}

/// `key=value` lines up to a blank line or the end.
fn read_request(input: impl BufRead) -> HashMap<String, String> {
    input
        .lines()
        .map_while(Result::ok)
        .take_while(|line| !line.is_empty())
        .filter_map(|line| {
            line.split_once('=')
                .map(|(k, v)| (k.to_owned(), v.to_owned()))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_until_the_blank_line() {
        let request = read_request("protocol=https\nhost=github.com\n\nignored=1\n".as_bytes());
        assert_eq!(request["protocol"], "https");
        assert_eq!(request["host"], "github.com");
        assert!(!request.contains_key("ignored"));
    }
}
