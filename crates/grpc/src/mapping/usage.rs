use kumo_domain::agents::{
    ContextSlice, ContextSliceKind, PlanUsage, SessionUsage, UsageReport, UsageUnit, UsageWindow,
};
use kumo_domain::time::Timestamp;
use kumo_proto::v1 as pb;

pub fn usage_report_to(report: UsageReport) -> pb::UsageReport {
    pb::UsageReport {
        plans: report.plans.into_iter().map(plan_usage_to).collect(),
        sessions: report.sessions.into_iter().map(session_usage_to).collect(),
    }
}

fn plan_usage_to(plan: PlanUsage) -> pb::PlanUsage {
    pb::PlanUsage {
        provider_id: plan.provider_id,
        plan: plan.plan,
        windows: plan.windows.into_iter().map(usage_window_to).collect(),
        problem: plan.problem,
        read_at: unix_ms(plan.read_at),
    }
}

fn usage_window_to(window: UsageWindow) -> pb::UsageWindow {
    let unit = match window.unit {
        UsageUnit::Percent => pb::UsageUnit::Percent,
        UsageUnit::Requests => pb::UsageUnit::Requests,
        UsageUnit::Dollars => pb::UsageUnit::Dollars,
    };
    pb::UsageWindow {
        label: window.label,
        short: window.short,
        left: window.left,
        of: window.of,
        unit: unit.into(),
        resets_at: window.resets_at.map_or(0, unix_ms),
    }
}

fn session_usage_to(session: SessionUsage) -> pb::SessionUsage {
    pb::SessionUsage {
        session_id: session.session_id.to_string(),
        model: session.model,
        context_max: session.context_max,
        slices: session.slices.into_iter().map(context_slice_to).collect(),
        turns: session.turns,
        compact_command: session.compact_command,
        read_at: unix_ms(session.read_at),
    }
}

fn context_slice_to(slice: ContextSlice) -> pb::ContextSlice {
    let kind = match slice.kind {
        ContextSliceKind::Total => pb::ContextSliceKind::ContextSliceTotal,
        ContextSliceKind::System => pb::ContextSliceKind::ContextSliceSystem,
        ContextSliceKind::Files => pb::ContextSliceKind::ContextSliceFiles,
        ContextSliceKind::Conversation => pb::ContextSliceKind::ContextSliceConversation,
    };
    pb::ContextSlice {
        kind: kind.into(),
        tokens: slice.tokens,
    }
}

fn unix_ms(at: Timestamp) -> i64 {
    i64::try_from(at.as_unix_nanos() / 1_000_000).unwrap_or(i64::MAX)
}
