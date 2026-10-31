use kumo_application::agents::{AgentsSnapshot, ProviderView};
use kumo_domain::agents::{
    AgentContext, AgentEvent, AgentEventKind, AgentSession, AgentState, ContextKind,
};
use kumo_proto::v1 as pb;

pub fn provider_to(view: ProviderView) -> pb::AgentProvider {
    let ProviderView { provider, resolved } = view;
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
    }
}

pub fn agent_context_to(context: AgentContext) -> pb::AgentContext {
    let kind = match context.kind {
        ContextKind::Task => pb::AgentContextKind::Task,
        ContextKind::Doc => pb::AgentContextKind::Doc,
    };
    pb::AgentContext {
        kind: kind.into(),
        title: context.title,
        detail: context.detail,
        url: context.url,
    }
}

pub fn agent_context_from(context: pb::AgentContext) -> AgentContext {
    AgentContext {
        kind: match context.kind() {
            pb::AgentContextKind::Task => ContextKind::Task,
            pb::AgentContextKind::Doc => ContextKind::Doc,
        },
        title: context.title,
        detail: context.detail,
        url: context.url,
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
    }
}
