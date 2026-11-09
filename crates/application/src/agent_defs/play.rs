//! Test runs (headless, step by step) and one-shot questions to a CLI.

use std::collections::HashSet;
use std::path::PathBuf;
use std::sync::atomic::{AtomicI32, Ordering};
use std::sync::{Arc, PoisonError};
use std::time::{Duration, Instant};

use kumo_domain::agent_defs::{
    AgentCli, AgentDefFile, AgentDefKey, HeadlessKiller, HeadlessSpec, PlayCommand, PlayEvent,
    PlayEventKind, PlayRecord, check_agent_name,
};
use kumo_domain::agents::{AgentContext, AgentError, AgentSessionId};
use kumo_domain::time::Timestamp;
use tokio::sync::mpsc;

use super::service::{AgentDefService, blocking, cli_for};
use crate::agents::{STOPPED, STOPPED_BY_TIME_LIMIT};

/// How long a question to a CLI may take.
const ASK_TIMEOUT: Duration = Duration::from_secs(120);

/// A test run going on.
pub(super) struct LivePlay {
    pub key: AgentDefKey,
    pub record: PlayRecord,
    pub killer: Arc<dyn HeadlessKiller>,
    /// The exit code it ends with because Kumo stopped it; 0 until then.
    pub stopped: Arc<AtomicI32>,
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
    /// The CLI it runs on; empty: the default.
    pub provider_id: String,
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

impl AgentDefService {
    /// Whether the installed CLI takes a budget; asked once.
    async fn budget_flag(
        &self,
        cli: &'static dyn AgentCli,
        program: &std::path::Path,
        env: &[(String, String)],
    ) -> bool {
        let Some(flag) = cli.budget_flag() else {
            return false;
        };
        let known = self
            .budget_flags
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .get(cli.provider_id())
            .copied();
        if let Some(known) = known {
            return known;
        }
        let (headless, program, env) = (
            Arc::clone(&self.ports.headless),
            program.to_owned(),
            env.to_vec(),
        );
        let has = blocking(move || Ok(headless.has_flag(&program, flag, &env)))
            .await
            .unwrap_or(None);
        match has {
            Some(has) => {
                self.budget_flags
                    .lock()
                    .unwrap_or_else(PoisonError::into_inner)
                    .insert(cli.provider_id(), has);
                has
            }
            // Asked again next time: a hiccup isn't its answer.
            None => {
                tracing::warn!("couldn't tell if {} takes a budget", cli.name());
                false
            }
        }
    }

    /// Starts a test run: its id, and its events as they come (the last
    /// one is `Exited`). It goes on, and into the history, if the
    /// receiver is dropped.
    pub async fn play(
        self: &Arc<Self>,
        start: PlayStart,
    ) -> Result<(String, mpsc::Receiver<PlayEvent>), AgentError> {
        check_agent_name(&start.name)?;
        let cli = cli_for(&start.provider_id)?;
        if start.task.trim().is_empty() {
            return Err(AgentError::Invalid("give it a task to try".into()));
        }
        // Refused before a throwaway worktree is made for it.
        cli.check(&start.name, &start.inline_json)?;
        let worktree = self
            .workspace
            .known_worktree(&start.worktree)
            .await
            .ok_or_else(|| AgentError::UnknownWorktree(start.worktree.clone()))?;
        let (program, env) = self.agents.program_env(cli.provider_id()).await?;
        let budget = self.budget_flag(cli, &program, &env).await;
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
            let agent_files = self
                .write_agent_files(cli, &start.name, &start.inline_json, context_dir.as_deref())
                .await?;
            let written = agent_files.as_ref().map(|f| f.dir.clone());
            let command = PlayCommand {
                name: start.name.clone(),
                inline_json: start.inline_json.clone(),
                task: start.task.clone(),
                context_dir,
                agent_files,
                max_turns: start.max_turns,
                max_cost_usd: start.max_cost_usd,
            };
            let spec = HeadlessSpec {
                program,
                args: cli.play_args(&command, budget)?,
                cwd: cwd.clone(),
                env,
            };
            let headless = Arc::clone(&self.ports.headless);
            let process = blocking(move || headless.start(&spec)).await;
            Ok((process, written))
        }
        .await;
        let (process, written) = match started {
            Ok((Ok(process), written)) => (process, written),
            Ok((Err(error), written)) => {
                self.drop_agent_files(written).await;
                self.drop_throwaway(throwaway).await;
                return Err(error);
            }
            Err(error) => {
                self.drop_throwaway(throwaway).await;
                return Err(error);
            }
        };

        let killer: Arc<dyn HeadlessKiller> = Arc::from(process.killer);
        let record = PlayRecord {
            id: id.clone(),
            provider_id: cli.provider_id().to_owned(),
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
                stopped: Arc::new(AtomicI32::new(0)),
            },
        );
        tracing::info!(play = %id, agent = start.name, "test run started");

        if let Some(minutes) = start.max_minutes.filter(|m| *m > 0) {
            let (service, play) = (Arc::clone(self), id.clone());
            tokio::spawn(async move {
                tokio::time::sleep(service.minutes(minutes)).await;
                if service.stop_play_with(&play, STOPPED_BY_TIME_LIMIT) {
                    tracing::info!(play = %play, "test run reached its time limit");
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
                        result_seen |= cli.is_result_line(&line);
                        let at_ms = elapsed_ms(since);
                        service.push_line(&play_id, line.clone(), at_ms);
                        let _ = tx.blocking_send(PlayEvent {
                            kind: PlayEventKind::Line(line),
                            at_ms,
                        });
                    }
                    let (code, stderr) = wait();
                    let at_ms = elapsed_ms(since);
                    let stopped = service.stopped_play(&play_id);
                    let code = stopped.unwrap_or(code);
                    if code != 0 && !result_seen && stopped.is_none() {
                        let line = cli.failure_line(code, &stderr);
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
            service
                .finish_play(&play_id, code, at_ms, throwaway, written)
                .await;
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
        written: Option<PathBuf>,
    ) {
        self.drop_agent_files(written).await;
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

    /// Removes the agent written for a test run: it's read when it starts.
    async fn drop_agent_files(&self, dir: Option<PathBuf>) {
        if let Some(dir) = dir {
            let files = Arc::clone(&self.ports.files);
            let _ = blocking(move || {
                files.remove_dir(&dir);
                Ok(())
            })
            .await;
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
        self.stop_play_with(id, STOPPED);
    }

    /// Stops it, to end with `code`; false if it isn't running.
    fn stop_play_with(&self, id: &str, code: i32) -> bool {
        let live = self
            .plays_lock()
            .get(id)
            .map(|p| (Arc::clone(&p.killer), Arc::clone(&p.stopped)));
        let Some((killer, stopped)) = live else {
            return false;
        };
        stopped.store(code, Ordering::SeqCst);
        killer.kill();
        true
    }

    /// The exit code of a test run Kumo stopped.
    fn stopped_play(&self, id: &str) -> Option<i32> {
        self.plays_lock()
            .get(id)
            .map(|p| p.stopped.load(Ordering::SeqCst))
            .filter(|code| *code != 0)
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

    /// One answer from a CLI (empty: the default), changing nothing, run in
    /// `cwd` or an empty folder.
    pub async fn ask(
        &self,
        prompt: &str,
        cwd: Option<PathBuf>,
        provider_id: &str,
    ) -> Result<String, AgentError> {
        if prompt.trim().is_empty() {
            return Err(AgentError::Invalid("nothing to ask".into()));
        }
        let cli = cli_for(provider_id)?;
        let (program, env) = self.agents.program_env(cli.provider_id()).await?;
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
            args: cli.ask_args(prompt),
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
                    Ok(_) if timed_out => Err(AgentError::Launch(format!(
                        "{} didn't answer within 2 minutes",
                        cli.speaker()
                    ))),
                    Ok((text, 0, _)) => Ok(text.trim().to_owned()),
                    Ok((_, code, stderr)) => Err(AgentError::Launch(if stderr.is_empty() {
                        format!("{} exited with code {code}", cli.name())
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
