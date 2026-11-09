import 'agent_defs.dart' show AgentCli;
import 'ai_usage_source.dart';

/// When a CLI's plan runs out, your agents can go on in another one: the
/// agent is one file, and each CLI runs it (`docs/agents-en-otras-clis.md`).
/// What's here tells a used-up plan apart, by what Kumo reads of its usage
/// or by what the CLI said when it stopped.

/// The window of [plan] that's used up and hasn't started over by [now];
/// null while there's some left (or Kumo can't read it).
UsageWindow? usedUp(AgentPlanUsage? plan, DateTime now) {
  for (final w in plan?.windows ?? const <UsageWindow>[]) {
    if (w.left <= 0 && (w.resets == null || w.resets!.isAfter(now))) return w;
  }
  return null;
}

/// How the CLIs say they stopped at their plan's limit: Claude Code ("Claude
/// AI usage limit reached", "5-hour limit reached ∙ resets 3pm", "You've hit
/// your limit"), Codex ("You've hit your usage limit"), Copilot (premium
/// requests, AI credits, quota).
final _limitWords = RegExp(
  r'usage limit|rate limit|hit your (usage )?limit|limit reached|limit exceeded|exceeded your|quota|premium requests? (allowance|limit)|no (remaining )?(ai )?credits|out of (ai )?credits',
  caseSensitive: false,
);

/// [text] (an error, a terminal's last line) says it stopped at its limit.
bool saysLimitReached(String text) => _limitWords.hasMatch(text);

/// Which CLIs are out, as Kumo reads their usage now.
Map<AgentCli, UsageWindow> usedUpClis(List<AgentCli> clis, AiUsageSource usage, DateTime now) => {
      for (final cli in clis)
        if (usedUp(usage.planOf(cli.id), now) case final w?) cli: w,
    };

/// The CLI to go on with instead of [from]: the first connected one (the
/// default first) that isn't out.
AgentCli? goOnWith(List<AgentCli> clis, AgentCli from, Map<AgentCli, UsageWindow> out) {
  for (final cli in clis) {
    if (cli != from && !out.containsKey(cli)) return cli;
  }
  return null;
}

/// The CLI to start with: [picked] if there's one, else the first that isn't
/// out (the default when all are).
AgentCli? startWith(List<AgentCli> clis, AgentCli? picked, Map<AgentCli, UsageWindow> out) {
  if (picked != null && clis.contains(picked)) return picked;
  for (final cli in clis) {
    if (!out.containsKey(cli)) return cli;
  }
  return clis.firstOrNull;
}

/// "Claude Code’s 5-hour session is used up: resets in 2 h 10 min."
String usedUpText(AgentCli cli, UsageWindow w, String resets) => '${cli.label}’s ${w.label.toLowerCase()} is used up: ${resets[0].toLowerCase()}${resets.substring(1)}.';

/// The first message a run that goes on elsewhere starts with: what it was
/// asked, and that part of it may be done already.
String goOnPrompt(String prompt, AgentCli from) {
  final note = 'Another AI (${from.label}) started this here and stopped at its plan’s limit. Check what’s already done in this folder before going on.';
  final p = prompt.trim();
  return p.isEmpty ? note : '$p\n\n$note';
}
