# Engine: your agents, terminals inside Agents, hand-started CLIs

## Why

Branch `feat/git-history` (same branch as the Git work) adds to kumo-ui, built and tested against mocks:

1. **Agents › Your agents**: Claude Code subagents (`.claude/agents/<name>.md`) to list, create (template, "describe it", import a `.md`), edit (all subagent fields plus Kumo's own: time and cost limits, triggers), **run in a terminal of their own inside Agents** (where: a worktree, a new worktree, a repo/PR link, a folder or a scratch folder; context saved next to the run), and **try in a playground** (headless run, step by step, flag a step and Claude suggests a change to the instructions).
2. **Agents › Sessions**: "Terminal" on a card now opens the session's terminal **inside Agents** (tabs for every session, approvals, Stop/Dismiss). The Terminal view still has it; opening it there is optional.
3. **New agent** lists your agents next to the CLIs, shows the context it will get (the branch's PR and tickets), and opens the run in Agents.
4. **Ask agent** (selected code) can send to a CLI the user **typed by hand** in one of the worktree's terminals (e.g. `claude` in zsh 2), and holds a message for an agent waiting on an approval until it's answered.

Only Claude Code: other CLIs have no subagent files.

What the UI reads:
- `AgentDefsSource` (`kumo-ui/lib/data/agent_defs_source.dart`): today `main.dart` gets `UnsupportedAgentDefs`, so a real build shows "Your agents need a newer engine". The design uses `MockAgentDefs`.
- `AgentsSource` (`kumo-ui/lib/data/agents_source.dart`): new `terminalAgents` and `sendToTerminal` (defaults: none / false), new `AgentRun.agent`, and three new `AgentContextKind`s.

**Read `kumo-ui/lib/data/agent_defs.dart` first.** It owns the file format (`readAgentFile` / `AgentDef.toMarkdown`), the checks, the commands and the prompts, all tested. **The daemon never parses frontmatter.** It moves Markdown text, runs processes and streams their output. One parser, in Dart, with tests.

---

## 1. `AgentDefs` service (new)

```proto
service AgentDefs {
  // Every agent file of the workspace: personal, then each repository's.
  rpc List(ListAgentDefsRequest) returns (AgentDefList);
  // Writes the file (and Kumo's settings for it). With `previous`, a rename
  // or move: the old file goes once the new one is written.
  rpc Save(SaveAgentDefRequest) returns (AgentDefFile);
  rpc Delete(DeleteAgentDefRequest) returns (DeleteAgentDefResponse);
  // Starts it in a terminal of its own; the session shows in Agents.Watch.
  rpc Run(RunAgentDefRequest) returns (AgentSession);
  // A headless test run: Claude Code's stream-json lines, as they come.
  rpc Play(PlayRequest) returns (stream PlayEvent);
  rpc StopPlay(StopPlayRequest) returns (StopPlayResponse);
  // The last 10 test runs of an agent, kept across restarts.
  rpc ListPlays(ListPlaysRequest) returns (PlayList);
  // One-shot `claude -p`: drafts an agent, improves instructions.
  rpc Ask(AskClaudeRequest) returns (AskClaudeResponse);
  // Skills and MCP servers an agent can be given; whether triggers run.
  rpc Capabilities(AgentDefCapabilitiesRequest) returns (AgentDefCapabilities);
}

enum AgentDefScope {
  AGENT_DEF_SCOPE_PERSONAL = 0;
  AGENT_DEF_SCOPE_PROJECT = 1;
}

// Kumo's own settings for an agent: not subagent fields, kept by the daemon.
message AgentDefSettings {
  optional uint32 max_minutes = 1;
  optional double max_cost_usd = 2;
  repeated AgentTrigger triggers = 3;
}

enum AgentTrigger {
  AGENT_TRIGGER_PULL_REQUEST = 0;
  AGENT_TRIGGER_SCHEDULE = 1;
}

message AgentDefFile {
  AgentDefScope scope = 1;
  // Project agents: the repository (main checkout path and name).
  string repo_path = 2;
  string repo_name = 3;
  // The file's stem: what `claude --agent <name>` takes.
  string name = 4;
  // The whole file, as is.
  string markdown = 5;
  AgentDefSettings settings = 6;
  string file_path = 7;
  int64 modified_unix_ms = 8;
}

message ListAgentDefsRequest {}
message AgentDefList { repeated AgentDefFile agents = 1; }

message SaveAgentDefRequest {
  AgentDefFile agent = 1;          // markdown + settings; file_path ignored
  optional AgentDefFile previous = 2;
}
message DeleteAgentDefRequest { AgentDefFile agent = 1; }
message DeleteAgentDefResponse {}
```

**Where the files are**
- Personal: the workspace's Claude Code folder, `<CLAUDE_CONFIG_DIR>/agents/` (the profile's home for `claude`, see `crates/domain/src/agents/homes.rs`). It's `~/.claude/agents/` when the workspace shares the Mac's sign-in.
- Project: `<repo main checkout>/.claude/agents/` for every repository of the workspace. Worktrees get them through git.
- Only `*.md` directly in those folders. Skip unreadable files and log them. A file Claude Code would reject still lists: the UI shows what's wrong.

**Saving**
- Write atomically: temp file, then rename. Create the folder if needed.
- A project save changes the main checkout: Git shows it as a change, and that's intended.
- `previous` with another name or scope: write the new file, then delete the old one, and move its settings.
- Refuse `..`, `/` and anything that isn't `^[a-z][a-z0-9-]*$` as a name. The UI checks too.
- Settings live in the daemon's store, keyed by (scope, repo_path, name).

**Capabilities**
- `skills`: folder names under `<CLAUDE_CONFIG_DIR>/skills/` and `<repo>/.claude/skills/`.
- `mcp_servers`: the workspace's MCP server names, from Claude Code's config.
- `triggers_supported`: false until triggers run (out of scope here). Saving them must still work.

## 2. Running one (`Run`)

```proto
message RunAgentDefRequest {
  AgentDefFile agent = 1;
  // Set when it isn't found by name where it runs (a project agent outside
  // its repo): passed as `--agents`. Built by the UI (agentInlineJson).
  string inline_json = 2;
  oneof where {
    string worktree_path = 3;
    string new_worktree_repo = 4;   // repo main checkout path: a new worktree from the default branch
    string link_url = 5;            // repo, branch or PR/MR link
    string folder = 6;
    bool scratch = 7;
  }
  string prompt = 8;
  repeated AgentContext context = 9;
  uint32 cols = 10;
  uint32 rows = 11;
}
```

**Where it runs (the working directory)**
- `worktree_path`: as is.
- `new_worktree_repo`: a worktree named `<name>-<n>` on a new branch of the same name, from the default branch. Same code path as `Workspace.CreateWorktree`, so the sidebar shows it.
- `link_url`: parse it the way `parseRepoLink` does (`agent_defs_source.dart`).
  - If the repository is in the workspace (its remote matches), use it. Otherwise clone it into the workspace's clones folder with the workspace's host token.
  - For a PR/MR, fetch `pull/N/head` (GitHub) or `merge-requests/N/head` (GitLab). Reuse the worktree already on that branch, else create one.
  - For a branch link, use that branch.
- `folder`: must exist. The first time it's outside the workspace's repos, the UI asks; the daemon just runs.
- `scratch`: `<data dir>/scratch/<name>-<n>/`, created empty and removed after 7 days.

**Context**
- Create `<data dir>/runs/<name>-<n>/` and write each item into it:

  | Kind | What gets written |
  |---|---|
  | `TASK` | the ticket, from the tasks cache (`Tasks.Get`), as `<KEY>.md` |
  | `PULL_REQUEST` | `pr-<n>.diff` (base...head) and `pr-<n>.md` (title, description, open threads) |
  | `DOC` | the page text (`Docs.Read`) |
  | `LINK` | the page fetched once and saved as text |
  | `FILES` | nothing copied: the absolute paths are listed |

- Write an index, `context.md`, that lists everything.
- Its knowledge needs nothing here: it's in its instructions.

**The command**
```
claude [--agents '<inline_json>'] --agent <name> --add-dir <run dir> "<prompt>\n\nWhat you were given for this run is in <run dir>: start with context.md."
```
- Use the workspace's env (CLAUDE_CONFIG_DIR…), like `Agents.Start`.
- With no prompt, start it with no positional argument: the user types.
- With no context, leave out both `--add-dir` and the sentence.
- `AgentSession` gains `string agent_name = N;` and `string context_dir = N+1;`.
- The session streams in `Agents.Watch` like any other: title = the prompt's first line, or `Run <n>`.

**Limits**
- `settings.max_minutes`: the daemon stops the process when it's up. Use exit code 124 and an `EXITED` event "Stopped: its time limit".
- `maxTurns` is Claude Code's own (in the file).
- Stop is exit code 130; the UI shows "stopped".

**Add to `AgentContextKind`:** `AGENT_CONTEXT_KIND_PULL_REQUEST = 3; FILES = 4; LINK = 5;`. Then replace the temporary mapping to `DOC` in `kumo-ui/lib/engine/engine_agents_source.dart` (`_contextTo`, and the reverse switch in `_run`).

## 3. Playground (`Play`)

```proto
message PlayRequest {
  string name = 1;
  string inline_json = 2;    // the draft as the UI has it (unsaved edits included)
  string task = 3;
  string worktree_path = 4;
  bool throwaway = 5;        // it can change files: run in a detached worktree of HEAD, removed after
  repeated AgentContext context = 6;
  optional uint32 max_turns = 7;
  optional uint32 max_minutes = 8;
  AgentDefFile agent = 9;    // which agent's history it goes in
}
message PlayEvent {
  string play_id = 1;
  oneof kind {
    string line = 2;        // one stdout line of stream-json, as is
    int32 exited = 3;       // exit code; the stream ends after it
  }
  int64 at_ms = 4;          // since the start
}
message StopPlayRequest { string play_id = 1; }
message StopPlayResponse {}
message ListPlaysRequest { AgentDefFile agent = 1; }
message PlayRecord { string play_id = 1; string task = 2; bool draft = 3; int64 started_unix_ms = 4; repeated PlayEvent events = 5; }
message PlayList { repeated PlayRecord plays = 1; }
```

**Command**
```
claude -p "<task>" --agents '<inline_json>' --agent <name> --output-format stream-json --verbose [--max-turns N]
```
- Run it in `worktree_path`. With `throwaway`, use `git worktree add --detach <tmp> HEAD`, and remove it when the run ends, even if it fails.
- The UI folds the lines with `foldStreamJson` (`agent_playground.dart`). Don't interpret them, just forward them.

**Limits and history**
- Time limit: kill the process when it's up.
- **Cost: don't promise a cap.** If the installed Claude Code has a budget flag, pass `max_cost_usd` to it. Otherwise only report it: the `result` line has `total_cost_usd`.
- Keep the last 10 runs per agent with their lines. The UI shows the history and the timeline of each one.

**Check against the installed CLI:** `--agent`, `--agents` (inline JSON with `description`, `prompt`, `tools`, `model`, `permissionMode`, `maxTurns`), `--output-format stream-json --verbose`, `--max-turns`. Adjust `agentInlineJson` if a field name differs.

## 4. `Ask` (drafts and fixes)

```proto
message AskClaudeRequest { string prompt = 1; string cwd = 2; }
message AskClaudeResponse { string text = 1; }
```
- Run `claude -p "<prompt>" --output-format text --permission-mode plan` in `cwd`. Without a `cwd`, use an empty temp dir.
- Time out after 2 minutes.
- The UI builds the prompts (`draftAgentPrompt`, `improveInstructionsPrompt`) and parses the answers.

## 5. Terminals inside Agents

- The Agents view **attaches to an agent's terminal** with `GrpcTerminalSurface.attach(..., killOnClose: false)` while the Terminal view may have it attached too.
- `Terminals.Attach` must take several attachments of one terminal:
  - each gets the replay, then live output;
  - input from any of them goes in;
  - on a resize, the last one wins.
- Check what it does today. If a second attach drops the first, fix that.

## 6. CLIs started by hand (`terminalAgents`, `sendToTerminal`)

The daemon runs every terminal's PTY, so it can see what's in the foreground:
- `tcgetpgrp(master)` gives the process group; read the leader's executable with `proc_pidpath` on macOS or `/proc/<pid>/exe` on Linux. Skip Windows for now.
- Match it against the known providers' programs. Claude Code runs as `node …/claude`, so also look at argv[1]'s basename.
- For a match, report a `TerminalAgent`:
  ```proto
  message TerminalAgent { string terminal_id = 1; string provider_id = 2; string program = 3; string cwd = 4; AgentState state = 5; bool busy = 6; }
  ```
  Put it in `AgentsSnapshot` as `repeated TerminalAgent terminal_agents`.
  - `state` and `busy` come from the same screen reading that agent sessions use; reuse it.
  - `cwd` is the process's working directory. The UI uses it to tell which worktree the terminal is in.
  - Recheck on output, at most once a second per terminal.
- `rpc SendToTerminal(SendToTerminalRequest { terminal_id, text, submit }) returns (SendToTerminalResponse)` types `text` as a bracketed paste (`ESC[200~…ESC[201~`) when the terminal enabled bracketed paste, plain otherwise. Then it sends `\r` if `submit`. Reuse what `AddContext` does.

The UI shows the terminal's title as "in <shell>": fill `terminalTitle` in `EngineAgentsSource` from the terminal's program (or the tab title, if the Terminal view registers it).

## 7. Dart wiring

- `kumo-ui/lib/engine/engine_agent_defs.dart`: `EngineAgentDefs extends AgentDefsSource` (constructor takes the engine and the `AgentsSource`).
  - `load` calls `List`, then `readAgentFile(markdown, scope:, repo:)`, then applies settings (`maxMinutes`, `maxCostUsd`, `triggers`).
  - `save` sends `toMarkdown()` and the settings. `delete` calls `Delete`.
  - `run` calls `Run` with `inline_json = agentFoundIn(...) ? '' : agentInlineJson(a)`.
  - `runsOf` reads `agents.runs` filtered on `agent == name`.
  - `play` streams events through `foldStreamJson`; `playRuns` comes from `ListPlays`, then the live ones.
  - `draft` and `improve` call `Ask` with the prompts from `agent_defs.dart`. A draft goes through `readAgentFile`.
  - `error` carries the last gRPC error, readable.
  - `supported` is false when the daemon answers UNIMPLEMENTED.
- `main.dart` `stateFor`: pass `agentDefs: EngineAgentDefs(engine, agents)`.
- `EngineAgentsSource`:
  - `AgentRun.agent` comes from `agent_name`;
  - `terminalAgents` comes from the snapshot;
  - `sendToTerminal` calls the RPC;
  - the context kinds map one to one.

## 8. Tests

**Daemon:**
- List / Save / rename / Delete in both scopes, in a temp CLAUDE_CONFIG_DIR and a temp repo.
- `Run` builds the argv:
  - inline vs by name;
  - context dir and `context.md`;
  - each kind of where.
- The time limit kills with exit code 124.
- `Play` streams lines and ends with `exited`; the throwaway worktree is removed even on failure.
- The foreground detection sees a fake `claude` started in a shell.
- `SendToTerminal` with and without bracketed paste.

**UI:** add a test for `EngineAgentDefs` mapping, like the other `engine_*` tests.

## Out of scope

- Running triggers: they're saved, and the UI says they need a newer engine while `triggers_supported` is false.
- Fine-grained permission rules.
- A skills playground (the Agents view has a "Skills · soon" tab).
- Agent orchestration from the UI.
