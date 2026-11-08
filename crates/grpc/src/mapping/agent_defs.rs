use std::path::PathBuf;

use kumo_application::agent_defs::AgentDefCapabilities;
use kumo_domain::agent_defs::{
    AgentDefFile, AgentDefScope, AgentDefSettings, AgentDefTrigger, PlayEvent, PlayEventKind,
    PlayRecord,
};
use kumo_proto::v1 as pb;

fn scope_to(scope: AgentDefScope) -> pb::AgentDefScope {
    match scope {
        AgentDefScope::Personal => pb::AgentDefScope::Personal,
        AgentDefScope::Project => pb::AgentDefScope::Project,
    }
}

fn settings_to(settings: AgentDefSettings) -> pb::AgentDefSettings {
    pb::AgentDefSettings {
        max_minutes: settings.max_minutes,
        max_cost_usd: settings.max_cost_usd,
        triggers: settings
            .triggers
            .into_iter()
            .map(|t| match t {
                AgentDefTrigger::PullRequest => pb::AgentDefTrigger::PullRequest,
                AgentDefTrigger::Schedule => pb::AgentDefTrigger::Schedule,
            } as i32)
            .collect(),
    }
}

fn settings_from(settings: pb::AgentDefSettings) -> AgentDefSettings {
    AgentDefSettings {
        max_minutes: settings.max_minutes,
        max_cost_usd: settings.max_cost_usd.filter(|c| c.is_finite() && *c >= 0.0),
        triggers: settings
            .triggers()
            .map(|t| match t {
                pb::AgentDefTrigger::PullRequest => AgentDefTrigger::PullRequest,
                pb::AgentDefTrigger::Schedule => AgentDefTrigger::Schedule,
            })
            .collect(),
    }
}

pub fn agent_def_to(file: AgentDefFile) -> pb::AgentDefFile {
    pb::AgentDefFile {
        scope: scope_to(file.scope).into(),
        repo_path: file
            .repo_path
            .map(|p| p.display().to_string())
            .unwrap_or_default(),
        repo_name: file.repo_name,
        name: file.name,
        markdown: file.markdown,
        settings: Some(settings_to(file.settings)),
        file_path: file.file_path.display().to_string(),
        modified_unix_ms: file.modified_unix_ms,
    }
}

pub fn agent_def_from(file: pb::AgentDefFile) -> AgentDefFile {
    let scope = match file.scope() {
        pb::AgentDefScope::Personal => AgentDefScope::Personal,
        pb::AgentDefScope::Project => AgentDefScope::Project,
    };
    AgentDefFile {
        scope,
        repo_path: match scope {
            AgentDefScope::Project if !file.repo_path.is_empty() => {
                Some(PathBuf::from(&file.repo_path))
            }
            _ => None,
        },
        repo_name: file.repo_name,
        name: file.name,
        markdown: file.markdown,
        settings: file.settings.map(settings_from).unwrap_or_default(),
        file_path: PathBuf::from(file.file_path),
        modified_unix_ms: file.modified_unix_ms,
    }
}

pub fn play_event_to(play_id: &str, event: PlayEvent) -> pb::PlayEvent {
    pb::PlayEvent {
        play_id: play_id.to_owned(),
        kind: Some(match event.kind {
            PlayEventKind::Line(line) => pb::play_event::Kind::Line(line),
            PlayEventKind::Exited(code) => pb::play_event::Kind::Exited(code),
        }),
        at_ms: event.at_ms,
    }
}

pub fn play_record_to(record: PlayRecord) -> pb::PlayRecord {
    let id = record.id;
    pb::PlayRecord {
        events: record
            .events
            .into_iter()
            .map(|e| play_event_to(&id, e))
            .collect(),
        play_id: id,
        task: record.task,
        draft: record.draft,
        started_unix_ms: record.started_unix_ms,
        running: record.running,
    }
}

pub fn capabilities_to(capabilities: AgentDefCapabilities) -> pb::AgentDefCapabilities {
    pb::AgentDefCapabilities {
        skills: capabilities.skills,
        mcp_servers: capabilities.mcp_servers,
        triggers_supported: capabilities.triggers_supported,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn files_come_back_as_sent() {
        let sent = pb::AgentDefFile {
            scope: pb::AgentDefScope::Project.into(),
            repo_path: "/w/app".into(),
            repo_name: "app".into(),
            name: "rev".into(),
            markdown: "---\nname: rev\n---\n".into(),
            settings: Some(pb::AgentDefSettings {
                max_minutes: Some(5),
                max_cost_usd: Some(1.0),
                triggers: vec![pb::AgentDefTrigger::Schedule.into()],
            }),
            file_path: "/w/app/.claude/agents/rev.md".into(),
            modified_unix_ms: 7,
        };
        assert_eq!(agent_def_to(agent_def_from(sent.clone())), sent);
        let personal = agent_def_from(pb::AgentDefFile {
            repo_path: "/ignored".into(),
            ..Default::default()
        });
        assert_eq!(personal.repo_path, None);
    }
}
