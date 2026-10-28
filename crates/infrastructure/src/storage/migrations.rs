use rusqlite::Connection;

/// Schema versions, applied in order and tracked with `PRAGMA user_version`.
/// Never edit a released step: append a new one.
const STEPS: &[&str] = &[
    // 1: workspace
    "CREATE TABLE repos (
        path        TEXT PRIMARY KEY,
        remote_url  TEXT
    );
    CREATE TABLE namespaces (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        collapsed   INTEGER NOT NULL DEFAULT 0,
        position    INTEGER NOT NULL
    );
    CREATE TABLE namespace_repos (
        namespace_id TEXT NOT NULL REFERENCES namespaces(id) ON DELETE CASCADE,
        repo_path    TEXT NOT NULL REFERENCES repos(path),
        position     INTEGER NOT NULL,
        PRIMARY KEY (namespace_id, repo_path)
    );",
    // 2: agents
    "CREATE TABLE agent_providers (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        program     TEXT NOT NULL,
        args        TEXT NOT NULL DEFAULT '',
        custom      INTEGER NOT NULL DEFAULT 0,
        enabled     INTEGER NOT NULL DEFAULT 0,
        is_default  INTEGER NOT NULL DEFAULT 0,
        position    INTEGER NOT NULL
    );",
];

pub(super) fn migrate(conn: &mut Connection) -> rusqlite::Result<()> {
    let current: i64 = conn.query_row("PRAGMA user_version", [], |row| row.get(0))?;
    for (version, step) in (1_i64..)
        .zip(STEPS)
        .skip(usize::try_from(current).unwrap_or(0))
    {
        let tx = conn.transaction()?;
        tx.execute_batch(step)?;
        tx.pragma_update(None, "user_version", version)?;
        tx.commit()?;
    }
    Ok(())
}
