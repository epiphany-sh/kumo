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
    // 3: tasks
    "CREATE TABLE task_sources (
        id          TEXT PRIMARY KEY,
        kind        TEXT NOT NULL,
        name        TEXT NOT NULL,
        options     TEXT NOT NULL,
        enabled     INTEGER NOT NULL DEFAULT 1,
        position    INTEGER NOT NULL
    );
    CREATE TABLE tasks (
        source_id   TEXT NOT NULL REFERENCES task_sources(id) ON DELETE CASCADE,
        external_id TEXT NOT NULL,
        key         TEXT NOT NULL,
        ticket      TEXT,
        title       TEXT NOT NULL,
        status      INTEGER NOT NULL,
        priority    INTEGER NOT NULL,
        due         TEXT,
        url         TEXT,
        context     TEXT NOT NULL,
        labels      TEXT NOT NULL,
        updated     INTEGER,
        position    INTEGER NOT NULL,
        PRIMARY KEY (source_id, external_id)
    );
    CREATE TABLE task_links (
        task_id     TEXT NOT NULL,
        worktree    TEXT NOT NULL,
        branch      TEXT NOT NULL,
        created     INTEGER NOT NULL,
        PRIMARY KEY (task_id, worktree)
    );",
    // 4: richer task cards and cached ticket details
    "ALTER TABLE tasks ADD COLUMN kind INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE tasks ADD COLUMN type_name TEXT NOT NULL DEFAULT '';
    ALTER TABLE tasks ADD COLUMN source_status TEXT NOT NULL DEFAULT '';
    ALTER TABLE tasks ADD COLUMN assignee TEXT;
    ALTER TABLE tasks ADD COLUMN relations TEXT NOT NULL DEFAULT '[]';
    ALTER TABLE tasks ADD COLUMN mine INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE tasks ADD COLUMN points INTEGER;
    ALTER TABLE tasks ADD COLUMN subtasks_done INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE tasks ADD COLUMN subtasks_total INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE tasks ADD COLUMN comment_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE tasks ADD COLUMN parent TEXT;
    ALTER TABLE tasks ADD COLUMN blocked INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE tasks ADD COLUMN sprint TEXT;
    CREATE TABLE task_details (
        source_id   TEXT NOT NULL REFERENCES task_sources(id) ON DELETE CASCADE,
        external_id TEXT NOT NULL,
        detail      TEXT NOT NULL,
        fetched     INTEGER NOT NULL,
        PRIMARY KEY (source_id, external_id)
    );",
];

#[cfg(test)]
pub(super) fn steps() -> &'static [&'static str] {
    STEPS
}

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
