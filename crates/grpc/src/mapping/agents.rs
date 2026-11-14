use kumo_application::agents::{AgentsSnapshot, ProviderView};
use kumo_domain::agents::{
    AgentContext, AgentEvent, AgentEventKind, AgentSession, AgentState, ContextKind, TerminalAgent,
};
use kumo_proto::v1 as pb;

pub fn provider_to(view: ProviderView) -> pb::AgentProvider {
    let ProviderView {
        provider,
        resolved,
        own_sign_in,
    } = view;
    pb::AgentProvider {
        takes_prompt_argument: provider.takes_prompt_argument(),
        has_login: provider.has_login(),
        usage_readable: provider.usage_readable(),
        read_usage: provider.read_usage,
        install_hint: provider
            .preset
            .map(|p| p.install_hint.to_owned())
            .unwrap_or_default(),
        id: provider.id,
        name: provider.name,
        short: provider.short,
        program: provider.program,
        args: provider.args,
        custom: provider.custom,
        enabled: provider.enabled,
        is_default: provider.is_default,
        installed: resolved.is_some(),
        resolved_path: resolved
            .map(|p| p.display().to_string())
            .unwrap_or_default(),
        own_sign_in,
    }
}

pub fn agent_session_to(session: AgentSession) -> pb::AgentSession {
    let (state, exit_code) = match session.state {
        AgentState::Working => (pb::AgentState::Working, 0),
        AgentState::NeedsInput => (pb::AgentState::NeedsInput, 0),
        AgentState::Exited(status) => (pb::AgentState::Exited, status.code()),
    };
    pb::AgentSession {
        id: session.id.to_string(),
        provider_id: session.provider_id,
        provider_name: session.provider_name,
        short: session.short,
        worktree_path: session.worktree.display().to_string(),
        terminal_id: session.terminal.to_string(),
        title: session.title,
        prompt: session.prompt,
        state: state.into(),
        exit_code,
        started_unix_ms: session.started_at.as_unix_nanos() / 1_000_000,
        state_since_unix_ms: session.state_since.as_unix_nanos() / 1_000_000,
        last_line: session.last_line,
        context: session.context.into_iter().map(agent_context_to).collect(),
        events: session.events.into_iter().map(agent_event_to).collect(),
        agent_name: session.agent_name.unwrap_or_default(),
        asked: session.asked,
        tells_asking: session.tells_asking,
        worked_ms: u64::try_from(session.worked.as_millis()).unwrap_or(u64::MAX),
        context_dir: session
            .context_dir
            .map(|d| d.display().to_string())
            .unwrap_or_default(),
    }
}

pub fn agent_context_to(context: AgentContext) -> pb::AgentContext {
    let kind = match context.kind {
        ContextKind::Task => pb::AgentContextKind::Task,
        ContextKind::Doc => pb::AgentContextKind::Doc,
        ContextKind::Code => pb::AgentContextKind::Code,
        ContextKind::PullRequest => pb::AgentContextKind::PullRequest,
        ContextKind::Files => pb::AgentContextKind::Files,
        ContextKind::Link => pb::AgentContextKind::Link,
    };
    pb::AgentContext {
        kind: kind.into(),
        title: context.title,
        detail: context.detail,
        url: context.url,
        id: context.id,
    }
}

pub fn agent_context_from(context: pb::AgentContext) -> AgentContext {
    AgentContext {
        kind: match context.kind() {
            pb::AgentContextKind::Task => ContextKind::Task,
            pb::AgentContextKind::Doc => ContextKind::Doc,
            pb::AgentContextKind::Code => ContextKind::Code,
            pb::AgentContextKind::PullRequest => ContextKind::PullRequest,
            pb::AgentContextKind::Files => ContextKind::Files,
            pb::AgentContextKind::Link => ContextKind::Link,
        },
        title: context.title,
        detail: context.detail,
        url: context.url,
        id: context.id,
    }
}

fn agent_event_to(event: AgentEvent) -> pb::AgentEvent {
    let kind = match event.kind {
        AgentEventKind::Started => pb::AgentEventKind::Started,
        AgentEventKind::Edited => pb::AgentEventKind::Edited,
        AgentEventKind::Ran => pb::AgentEventKind::Ran,
        AgentEventKind::Read => pb::AgentEventKind::Read,
        AgentEventKind::Searched => pb::AgentEventKind::Searched,
        AgentEventKind::Tool => pb::AgentEventKind::Tool,
        AgentEventKind::Waiting => pb::AgentEventKind::Waiting,
        AgentEventKind::Context => pb::AgentEventKind::Context,
        AgentEventKind::Exited => pb::AgentEventKind::Exited,
    };
    pb::AgentEvent {
        at_unix_ms: event.at.as_unix_nanos() / 1_000_000,
        kind: kind.into(),
        text: event.text,
    }
}

pub fn agents_snapshot_to(snapshot: &AgentsSnapshot) -> pb::AgentsSnapshot {
    pb::AgentsSnapshot {
        version: snapshot.version,
        sessions: snapshot
            .sessions
            .iter()
            .cloned()
            .map(agent_session_to)
            .collect(),
        terminal_agents: snapshot
            .terminal_agents
            .iter()
            .map(terminal_agent_to)
            .collect(),
    }
}

fn terminal_agent_to(agent: &TerminalAgent) -> pb::TerminalAgent {
    let state = match agent.state {
        AgentState::Working => pb::AgentState::Working,
        AgentState::NeedsInput => pb::AgentState::NeedsInput,
        AgentState::Exited(_) => pb::AgentState::Exited,
    };
    pb::TerminalAgent {
        terminal_id: agent.terminal.to_string(),
        provider_id: agent.provider_id.clone(),
        program: agent.program.clone(),
        cwd: agent.cwd.display().to_string(),
        state: state.into(),
        busy: agent.busy,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn context_kinds_come_back_as_sent() {
        for kind in [
            pb::AgentContextKind::Task,
            pb::AgentContextKind::Doc,
            pb::AgentContextKind::Code,
            pb::AgentContextKind::PullRequest,
            pb::AgentContextKind::Files,
            pb::AgentContextKind::Link,
        ] {
            let sent = pb::AgentContext {
                kind: kind.into(),
                title: "parse_key · lib.rs:12-30".into(),
                detail: "src/lib.rs".into(),
                url: String::new(),
                id: "t-1".into(),
            };
            assert_eq!(agent_context_to(agent_context_from(sent.clone())), sent);
        }
    }
}
