//! Test runs (headless, step by step) and one-shot questions to Claude.

use std::collections::HashSet;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, Instant};

use kumo_domain::agent_defs::{
    AgentDefFile, AgentDefKey, HeadlessKiller, HeadlessSpec, PlayCommand, PlayEvent, PlayEventKind,
    PlayRecord, ask_args, check_agent_name, play_args,
};
use kumo_domain::agents::{AgentContext, AgentError, AgentSessionId};
use kumo_domain::time::Timestamp;
use tokio::sync::mpsc;

use super::service::{AgentDefService, CLAUDE, blocking};

/// How long a question to Claude may take.
const ASK_TIMEOUT: Duration = Duration::from_secs(120);

/// A test run going on.
pub(super) struct LivePlay {
    pub key: AgentDefKey,
    pub record: PlayRecord,
    pub killer: Arc<dyn HeadlessKiller>,
}

impl std::fmt::Debug for LivePlay {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("LivePlay")
            .field("id", &self.record.id)
            .finish_non_exhaustive()
    }
}

/// What a test run is started with.
#[derive(Debug, Clone, Default)]
pub struct PlayStart {
    /// The name it runs under (the draft's).
    pub name: String,
    /// The draft as `--agents` takes it.
    pub inline_json: String,
    pub task: String,
    pub worktree: PathBuf,
    /// It can change files: a detached worktree of HEAD, removed after.
    pub throwaway: bool,
    pub context: Vec<AgentContext>,
    pub max_turns: Option<u32>,
    pub max_minutes: Option<u32>,
    pub max_cost_usd: Option<f64>,
    /// The agent whose history it joins (as saved).
    pub owner: AgentDefFile,
    pub draft: bool,
}

fn now_ms() -> i64 {
    i64::try_from(Timestamp::now().as_unix_nanos() / 1_000_000).unwrap_or(i64::MAX)
}

fn elapsed_ms(since: Instant) -> i64 {
    i64::try_from(since.elapsed().as_millis()).unwrap_or(i64::MAX)
}

/// What the timeline shows when Claude Code ended without a result line
/// (it refused a flag, it wasn't signed in): its error, as a failed result.
fn failure_line(code: i32, stderr: &str) -> String {
    let text = if stderr.trim().is_empty() {
        format!("Claude Code exited with code {code}.")
    } else {
        stderr.trim().to_owned()
    };
    serde_json::json!({ "type": "result", "subtype": "error", "is_error": true, "result": text })
        .to_string()
}

impl AgentDefService {
    /// Whether the installed Claude Code takes a budget; asked once.
    async fn budget_flag(&self, program: &std::path::Path) -> bool {
        if let Some(known) = self.budget_flag.get() {
            return *known;
        }
        let (headless, program) = (Arc::clone(&self.ports.headless), program.to_owned());
        let has = blocking(move || Ok(headless.has_flag(&program, "--max-budget-usd")))
            .await
            .unwrap_or(false);
        *self.budget_flag.get_or_init(|| has)
    }

    /// Starts a test run: its id, and its events as they come (the last
    /// one is `Exited`). It goes on, and into the history, if the
    /// receiver is dropped.
    pub async fn play(
        self: &Arc<Self>,
        start: PlayStart,
    ) -> Result<(String, mpsc::Receiver<PlayEvent>), AgentError> {
        check_agent_name(&start.name)?;
        if start.task.trim().is_empty() {
            return Err(AgentError::Invalid("give it a task to try".into()));
        }
        let worktree = self
            .workspace
            .known_worktree(&start.worktree)
            .await
            .ok_or_else(|| AgentError::UnknownWorktree(start.worktree.clone()))?;
        let (program, env) = self.agents.program_env(CLAUDE).await?;
        let budget = self.budget_flag(&program).await;
        let id = format!("play-{}", AgentSessionId::generate());

        let cwd = if start.throwaway {
            let path = self.places.data_dir.join("plays").join(&id);
            let (git, from, at) = (Arc::clone(&self.ports.git), worktree.clone(), path.clone());
            blocking(move || {
                git.add_detached(&from, &at, "HEAD").map_err(|e| {
                    AgentError::Launch(format!("can't make a throwaway worktree: {e}"))
                })
            })
            .await?;
            path
        } else {
            worktree.clone()
        };
        let throwaway = start.throwaway.then(|| (worktree.clone(), cwd.clone()));

        let started = async {
            let context_dir = if start.context.is_empty() {
                None
            } else {
                let dir = self.places.data_dir.join("runs").join(&id);
                let repo = self.repo_of(&worktree);
                self.write_context(&start.context, repo.as_deref(), &cwd, &dir)
                    .await?;
                Some(dir)
            };
            let command = PlayCommand {
                name: start.name.clone(),
                inline_json: start.inline_json.clone(),
                task: start.task.clone(),
                context_dir,
                max_turns: start.max_turns,
                max_cost_usd: start.max_cost_usd,
            };
            let spec = HeadlessSpec {
                program,
                args: play_args(&command, budget),
                cwd: cwd.clone(),
                env,
            };
            let headless = Arc::clone(&self.ports.headless);
            blocking(move || headless.start(&spec)).await
        }
        .await;
        let process = match started {
            Ok(process) => process,
            Err(error) => {
                self.drop_throwaway(throwaway).await;
                return Err(error);
            }
        };

        let killer: Arc<dyn HeadlessKiller> = Arc::from(process.killer);
        let record = PlayRecord {
            id: id.clone(),
            task: start.task.trim().to_owned(),
            draft: start.draft,
            started_unix_ms: now_ms(),
            events: Vec::new(),
            running: true,
        };
        self.plays_lock().insert(
            id.clone(),
            LivePlay {
                key: start.owner.key(),
                record,
                killer: Arc::clone(&killer),
            },
        );
        tracing::info!(play = %id, agent = start.name, "test run started");

        if let Some(minutes) = start.max_minutes.filter(|m| *m > 0) {
            let (service, play) = (Arc::clone(self), id.clone());
            tokio::spawn(async move {
                tokio::time::sleep(service.minutes(minutes)).await;
                let live = service
                    .plays_lock()
                    .get(&play)
                    .map(|p| Arc::clone(&p.killer));
                if let Some(killer) = live {
                    tracing::info!(play = %play, "test run reached its time limit");
                    killer.kill();
                }
            });
        }

        let (tx, rx) = mpsc::channel(256);
        let (service, play_id) = (Arc::clone(self), id.clone());
        let (lines, wait) = (process.lines, process.wait);
        tokio::spawn(async move {
            let reading = {
                let (service, play_id, tx) = (Arc::clone(&service), play_id.clone(), tx.clone());
                tokio::task::spawn_blocking(move || {
                    let since = Instant::now();
                    let mut result_seen = false;
                    for line in lines {
                        if line.trim().is_empty() {
                            continue;
                        }
                        result_seen |= line.contains("\"type\":\"result\"");
                        let at_ms = elapsed_ms(since);
                        service.push_line(&play_id, line.clone(), at_ms);
                        let _ = tx.blocking_send(PlayEvent {
                            kind: PlayEventKind::Line(line),
                            at_ms,
                        });
                    }
                    let (code, stderr) = wait();
                    let at_ms = elapsed_ms(since);
                    if code != 0 && !result_seen {
                        let line = failure_line(code, &stderr);
                        service.push_line(&play_id, line.clone(), at_ms);
                        let _ = tx.blocking_send(PlayEvent {
                            kind: PlayEventKind::Line(line),
                            at_ms,
                        });
                    }
                    (code, at_ms)
                })
            };
            let (code, at_ms) = reading.await.unwrap_or((-1, 0));
            service.finish_play(&play_id, code, at_ms, throwaway).await;
            let _ = tx
                .send(PlayEvent {
                    kind: PlayEventKind::Exited(code),
                    at_ms,
                })
                .await;
        });
        Ok((id, rx))
    }

    fn push_line(&self, id: &str, line: String, at_ms: i64) {
        if let Some(live) = self.plays_lock().get_mut(id) {
            live.record.push_line(line, at_ms);
        }
    }

    async fn finish_play(
        &self,
        id: &str,
        code: i32,
        at_ms: i64,
        throwaway: Option<(PathBuf, PathBuf)>,
    ) {
        self.drop_throwaway(throwaway).await;
        let Some(mut live) = self.plays_lock().remove(id) else {
            return;
        };
        live.record.exit(code, at_ms);
        tracing::info!(play = %id, code, "test run ended");
        let store = Arc::clone(&self.ports.store);
        let saved =
            blocking(move || store.save_play(&live.key, &live.record, PlayRecord::KEEP)).await;
        if let Err(error) = saved {
            tracing::warn!(play = %id, %error, "test run not kept");
        }
    }

    /// Removes a throwaway worktree, whatever it changed.
    async fn drop_throwaway(&self, throwaway: Option<(PathBuf, PathBuf)>) {
        let Some((repo, path)) = throwaway else {
            return;
        };
        let git = Arc::clone(&self.ports.git);
        let removed = blocking(move || {
            git.remove_worktree(&repo, &path)
                .map_err(AgentError::Launch)
        })
        .await;
        if let Err(error) = removed {
            tracing::warn!(%error, "throwaway worktree left behind");
        }
    }

    /// Stops a test run; fine when it already ended.
    pub fn stop_play(&self, id: &str) {
        let killer = self.plays_lock().get(id).map(|p| Arc::clone(&p.killer));
        if let Some(killer) = killer {
            killer.kill();
        }
    }

    /// The test runs of `agent`, newest first: the running ones, then the
    /// kept ones.
    pub async fn plays(&self, agent: &AgentDefFile) -> Result<Vec<PlayRecord>, AgentError> {
        let key = agent.key();
        let mut live: Vec<PlayRecord> = self
            .plays_lock()
            .values()
            .filter(|p| p.key == key)
            .map(|p| p.record.clone())
            .collect();
        live.sort_by_key(|p| std::cmp::Reverse(p.started_unix_ms));
        let store = Arc::clone(&self.ports.store);
        let kept = blocking(move || store.plays(&key)).await?;
        let running: HashSet<String> = live.iter().map(|l| l.id.clone()).collect();
        live.extend(kept.into_iter().filter(|k| !running.contains(&k.id)));
        Ok(live)
    }

    /// One answer from Claude (`claude -p`, plan mode: it changes nothing),
    /// run in `cwd` or an empty folder.
    pub async fn ask(&self, prompt: &str, cwd: Option<PathBuf>) -> Result<String, AgentError> {
        if prompt.trim().is_empty() {
            return Err(AgentError::Invalid("nothing to ask".into()));
        }
        let (program, env) = self.agents.program_env(CLAUDE).await?;
        let files = Arc::clone(&self.ports.files);
        let (cwd, temp) = match cwd {
            Some(cwd) if files.exists(&cwd) => (cwd, None),
            Some(cwd) => {
                return Err(AgentError::Invalid(format!(
                    "{} doesn't exist",
                    cwd.display()
                )));
            }
            None => {
                let dir = self
                    .places
                    .data_dir
                    .join("ask")
                    .join(AgentSessionId::generate().to_string());
                files.create_dir(&dir)?;
                (dir.clone(), Some(dir))
            }
        };
        let spec = HeadlessSpec {
            program,
            args: ask_args(prompt),
            cwd,
            env,
        };
        let headless = Arc::clone(&self.ports.headless);
        let process = blocking(move || headless.start(&spec)).await;
        let answer = match process {
            Err(error) => Err(error),
            Ok(process) => {
                let killer: Arc<dyn HeadlessKiller> = Arc::from(process.killer);
                let timer = {
                    let killer = Arc::clone(&killer);
                    tokio::spawn(async move {
                        tokio::time::sleep(ASK_TIMEOUT).await;
                        killer.kill();
                        true
                    })
                };
                let (lines, wait) = (process.lines, process.wait);
                let read = blocking(move || {
                    let text: Vec<String> = lines.collect();
                    let (code, stderr) = wait();
                    Ok((text.join("\n"), code, stderr))
                })
                .await;
                timer.abort();
                let timed_out = timer.await.unwrap_or(false);
                match read {
                    Ok(_) if timed_out => Err(AgentError::Launch(
                        "Claude didn't answer within 2 minutes".into(),
                    )),
                    Ok((text, 0, _)) => Ok(text.trim().to_owned()),
                    Ok((_, code, stderr)) => Err(AgentError::Launch(if stderr.is_empty() {
                        format!("Claude Code exited with code {code}")
                    } else {
                        stderr
                    })),
                    Err(error) => Err(error),
                }
            }
        };
        if let Some(dir) = temp {
            self.ports.files.remove_dir(&dir);
        }
        answer
    }
}
