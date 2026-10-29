//! Reads a test runner's output as it comes: cargo, go test, gotestsum,
//! flutter / dart test, jest, vitest and pytest. Lines it doesn't know are
//! only kept as the last line.

use super::{SuiteResult, TestSummary};
use crate::terminal::LineSplitter;

const MAX_SUITES: usize = 300;
const MAX_FAILURES: usize = 50;
const MAX_LINE: usize = 160;

#[derive(Debug, Default)]
pub struct TestOutput {
    lines: LineSplitter,
    summary: TestSummary,
    /// cargo: the test binary whose results come next.
    cargo_suite: Option<String>,
}

/// Counts in a totals line.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
struct Counts {
    passed: Option<u32>,
    failed: Option<u32>,
    skipped: Option<u32>,
    total: Option<u32>,
}

impl TestOutput {
    pub fn push(&mut self, bytes: &[u8]) {
        for line in self.lines.push(bytes) {
            self.line(&line);
        }
    }

    /// Reads what's left once the run ends.
    pub fn finish(&mut self) {
        self.push(b"\n");
    }

    pub fn summary(&self) -> &TestSummary {
        &self.summary
    }

    fn line(&mut self, line: &str) {
        let t = line.trim();
        if t.is_empty() {
            return;
        }
        self.summary.last_line = clip(t);
        let _ = self.cargo(t)
            || self.go(t)
            || self.marked_suite(t)
            || self.dart(t)
            || self.js(t)
            || self.pytest(t);
    }

    fn cargo(&mut self, t: &str) -> bool {
        if let Some(rest) = t.strip_prefix("Running ")
            && let Some((path, binary)) = rest.split_once(" (")
        {
            let name = match path.strip_prefix("unittests ") {
                // The crate, from `target/debug/deps/kumo_domain-1a2b`.
                Some(_) => binary
                    .trim_end_matches(')')
                    .rsplit('/')
                    .next()
                    .and_then(|file| file.rsplit_once('-'))
                    .map_or_else(|| path.to_owned(), |(krate, _)| krate.to_owned()),
                None => path.to_owned(),
            };
            self.cargo_suite = Some(name);
            return true;
        }
        if let Some(krate) = t.strip_prefix("Doc-tests ") {
            self.cargo_suite = Some(format!("{krate} doc-tests"));
            return true;
        }
        if let Some(rest) = t.strip_prefix("test result: ") {
            let ok = rest.starts_with("ok");
            let counts = counts(rest);
            let (passed, failed) = (counts.passed.unwrap_or(0), counts.failed.unwrap_or(0));
            self.summary.passed += passed;
            self.summary.failed += failed;
            self.summary.skipped += counts.skipped.unwrap_or(0);
            if passed + failed > 0 {
                let name = self.cargo_suite.take().unwrap_or_else(|| "tests".into());
                self.suite(
                    name,
                    ok,
                    rest.split("finished in ").nth(1).and_then(duration_ms),
                    Some(passed + failed),
                );
            }
            return true;
        }
        if let Some(name) = t
            .strip_prefix("test ")
            .and_then(|r| r.strip_suffix(" ... FAILED"))
        {
            self.failure(name);
            return true;
        }
        false
    }

    fn go(&mut self, t: &str) -> bool {
        let words: Vec<&str> = t.split_whitespace().collect();
        match words.as_slice() {
            ["ok", package, rest @ ..] if go_tail(rest) => {
                let duration = rest.first().and_then(|d| duration_ms(d));
                self.suite((*package).to_owned(), true, duration, None);
                true
            }
            ["FAIL", package, rest @ ..] if go_tail(rest) => {
                let duration = rest.first().and_then(|d| duration_ms(d));
                self.suite((*package).to_owned(), false, duration, None);
                true
            }
            ["---", "FAIL:", name, ..] => {
                self.failure(name);
                true
            }
            ["---", "PASS:", ..] => {
                self.summary.passed += 1;
                true
            }
            ["---", "SKIP:", ..] => {
                self.summary.skipped += 1;
                true
            }
            // gotestsum: `=== FAIL: pkg TestName (0.00s)`.
            ["===", "FAIL:", _, name, ..] => {
                self.failure(name);
                true
            }
            // gotestsum: `DONE 148 tests, 3 skipped, 2 failures in 3.1s`.
            ["DONE", ..] => {
                let c = counts(t);
                if let Some(total) = c.total {
                    let failed = c.failed.unwrap_or(0);
                    let skipped = c.skipped.unwrap_or(0);
                    self.set(total.saturating_sub(failed + skipped), failed, skipped);
                }
                true
            }
            _ => false,
        }
    }

    /// `✓  internal/discount (412ms)` (gotestsum), `✓ src/a.test.ts (3
    /// tests) 12ms` / `❯ src/b.test.ts (3 tests | 1 failed)` (vitest).
    fn marked_suite(&mut self, t: &str) -> bool {
        let mut chars = t.chars();
        let passed = match chars.next() {
            Some('✓' | '✔') => true,
            Some('✖' | '✗' | '×' | '❯') => false,
            _ => return false,
        };
        let rest = chars.as_str().trim_start();
        let Some(name) = rest.split_whitespace().next() else {
            return false;
        };
        let after = &rest[name.len()..];
        let tests = after
            .split_once('(')
            .and_then(|(_, r)| r.split_whitespace().next())
            .and_then(|n| n.parse().ok());
        let duration = after
            .split(['(', ')', ' '])
            .filter(|w| !w.is_empty())
            .find_map(duration_ms);
        self.suite(name.to_owned(), passed, duration, tests);
        true
    }

    /// `00:12 +177 ~2 -3: test/a_test.dart: name [E]`.
    fn dart(&mut self, t: &str) -> bool {
        let Some((clock, rest)) = t.split_once(' ') else {
            return false;
        };
        let is_clock = clock.len() >= 5
            && clock
                .split(':')
                .all(|p| !p.is_empty() && p.chars().all(|c| c.is_ascii_digit()));
        if !is_clock || !rest.starts_with('+') {
            return false;
        }
        let (marks, what) = rest.split_once(": ").unwrap_or((rest, ""));
        let mut c = (0, 0, 0);
        for mark in marks.split_whitespace() {
            let (sign, n) = mark.split_at(1);
            let Ok(n) = n.parse::<u32>() else { continue };
            match sign {
                "+" => c.0 = n,
                "-" => c.1 = n,
                "~" => c.2 = n,
                _ => {}
            }
        }
        if c.1 > self.summary.failed {
            let name = what.trim_end_matches(" [E]").trim();
            if !name.is_empty() {
                self.failure(name);
            }
        }
        self.set(c.0, c.1, c.2);
        true
    }

    fn js(&mut self, t: &str) -> bool {
        // jest: `Tests:  2 failed, 146 passed, 148 total`; vitest: `Tests
        // 146 passed | 2 failed (148)`.
        if let Some(rest) = t
            .strip_prefix("Tests:")
            .or_else(|| t.strip_prefix("Tests "))
        {
            let c = counts(rest);
            if c.passed.is_some() || c.failed.is_some() {
                self.set(
                    c.passed.unwrap_or(0),
                    c.failed.unwrap_or(0),
                    c.skipped.unwrap_or(0),
                );
                return true;
            }
        }
        // vitest: `FAIL  src/b.test.ts > suite > name`.
        if let Some(rest) = t.strip_prefix("FAIL ")
            && rest.contains(" > ")
        {
            self.failure(rest.trim());
            return true;
        }
        // jest: `PASS src/a.test.ts (1.2 s)` / `FAIL src/b.test.ts`.
        for (prefix, passed) in [("PASS ", true), ("FAIL ", false)] {
            if let Some(rest) = t.strip_prefix(prefix) {
                let mut words = rest.split_whitespace();
                if let Some(name) = words.next() {
                    let duration = rest
                        .split_once('(')
                        .and_then(|(_, d)| duration_ms(&d.trim_end_matches(')').replace(' ', "")));
                    self.suite(name.to_owned(), passed, duration, None);
                    return true;
                }
            }
        }
        // jest: `● Suite › name`.
        if let Some(rest) = t.strip_prefix("● ")
            && rest.contains(" › ")
        {
            self.failure(rest);
            return true;
        }
        false
    }

    fn pytest(&mut self, t: &str) -> bool {
        // `===== 2 failed, 146 passed in 3.10s =====`.
        if t.starts_with('=') && t.ends_with('=') && t.contains(" in ") {
            let c = counts(t.trim_matches('='));
            if c.passed.is_some() || c.failed.is_some() {
                self.set(
                    c.passed.unwrap_or(0),
                    c.failed.unwrap_or(0),
                    c.skipped.unwrap_or(0),
                );
                return true;
            }
        }
        if let Some(rest) = t.strip_prefix("FAILED ") {
            self.failure(rest.split(" - ").next().unwrap_or(rest));
            return true;
        }
        false
    }

    fn set(&mut self, passed: u32, failed: u32, skipped: u32) {
        self.summary.passed = passed;
        self.summary.failed = failed;
        self.summary.skipped = skipped;
    }

    fn suite(&mut self, name: String, passed: bool, duration_ms: Option<u64>, tests: Option<u32>) {
        let suites = &mut self.summary.suites;
        if let Some(known) = suites.iter_mut().find(|s| s.name == name) {
            *known = SuiteResult {
                name,
                passed,
                duration_ms,
                tests,
            };
        } else if suites.len() < MAX_SUITES {
            suites.push(SuiteResult {
                name,
                passed,
                duration_ms,
                tests,
            });
        }
    }

    fn failure(&mut self, name: &str) {
        let failures = &mut self.summary.failures;
        if failures.len() < MAX_FAILURES && !failures.iter().any(|f| f == name) {
            failures.push(clip(name));
        }
    }
}

/// What follows the package on a go result line: its time, `(cached)`
/// or `[build failed]`.
fn go_tail(rest: &[&str]) -> bool {
    match rest.first() {
        None => true,
        Some(first) => {
            duration_ms(first).is_some() || first.starts_with('(') || first.starts_with('[')
        }
    }
}

/// `2 failed, 146 passed; 1 ignored, 148 total` in any order and joiner.
fn counts(text: &str) -> Counts {
    let mut c = Counts::default();
    let words: Vec<&str> = text
        .split(|ch: char| ch.is_whitespace() || matches!(ch, ',' | ';' | '|' | '(' | ')' | '.'))
        .filter(|w| !w.is_empty())
        .collect();
    for pair in words.windows(2) {
        let Ok(n) = pair[0].parse::<u32>() else {
            continue;
        };
        match pair[1] {
            "passed" => c.passed = Some(n),
            "failed" | "failures" | "failure" | "errors" | "error" => {
                c.failed = Some(c.failed.unwrap_or(0) + n);
            }
            "skipped" | "ignored" | "pending" | "todo" => {
                c.skipped = Some(c.skipped.unwrap_or(0) + n);
            }
            "total" | "tests" | "test" => c.total = Some(n),
            _ => {}
        }
    }
    c
}

/// `412ms`, `1.21s`, `0.01s`, `1.2s`; anything else is no duration.
fn duration_ms(text: &str) -> Option<u64> {
    let text = text.trim();
    let (number, scale) = match text.strip_suffix("ms") {
        Some(n) => (n, 1.0),
        None => (text.strip_suffix('s')?, 1000.0),
    };
    let value: f64 = number.parse().ok()?;
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    (value >= 0.0).then(|| (value * scale).round() as u64)
}

fn clip(text: &str) -> String {
    if text.chars().count() <= MAX_LINE {
        return text.to_owned();
    }
    format!("{}…", text.chars().take(MAX_LINE - 1).collect::<String>())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn read(output: &str) -> TestSummary {
        let mut reader = TestOutput::default();
        reader.push(output.as_bytes());
        reader.finish();
        reader.summary().clone()
    }

    fn suites(summary: &TestSummary) -> Vec<(&str, bool, Option<u64>, Option<u32>)> {
        summary
            .suites
            .iter()
            .map(|s| (s.name.as_str(), s.passed, s.duration_ms, s.tests))
            .collect()
    }

    #[test]
    fn cargo_adds_up_each_binary() {
        let s = read(
            "   Compiling kumo-domain v0.1.0\n     Running unittests src/lib.rs (target/debug/deps/kumo_domain-1a2b3c)\n\n\
             running 2 tests\ntest a::works ... ok\ntest a::breaks ... FAILED\n\n\
             test result: FAILED. 1 passed; 1 failed; 1 ignored; 0 measured; 0 filtered out; finished in 0.01s\n\n\
                  Running unittests src/main.rs (target/debug/deps/kumod-9f)\n\ntest result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s\n\
                  Running tests/git.rs (target/debug/deps/git-77)\n\ntest result: ok. 12 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 1.21s\n\
                Doc-tests kumo_domain\n\ntest result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.40s\n",
        );
        assert_eq!((s.passed, s.failed, s.skipped), (16, 1, 1));
        assert_eq!(
            suites(&s),
            [
                ("kumo_domain", false, Some(10), Some(2)),
                ("tests/git.rs", true, Some(1210), Some(12)),
                ("kumo_domain doc-tests", true, Some(400), Some(3)),
            ],
            "binaries without tests are left out"
        );
        assert_eq!(s.failures, ["a::breaks"]);
    }

    #[test]
    fn go_test_and_gotestsum() {
        let s = read(
            "--- FAIL: TestBulk (0.00s)\n    bulk_test.go:12: got 3\nFAIL\nFAIL\tacme/internal/discount\t0.412s\n\
             ok  \tacme/internal/http\t1.21s\nok  \tacme/internal/kafka\t(cached)\n?   \tacme/cmd\t[no test files]\nFAIL\n",
        );
        assert_eq!(
            suites(&s),
            [
                ("acme/internal/discount", false, Some(412), None),
                ("acme/internal/http", true, Some(1210), None),
                ("acme/internal/kafka", true, None, None),
            ]
        );
        assert_eq!(s.failures, ["TestBulk"]);

        let s = read(
            "✓  internal/discount (412ms)\n✖  internal/http (1.21s)\n∅  cmd\n\n=== FAIL: internal/http TestRoute (0.01s)\n\
             DONE 148 tests, 3 skipped, 2 failures in 3.100s\n",
        );
        assert_eq!(
            suites(&s),
            [
                ("internal/discount", true, Some(412), None),
                ("internal/http", false, Some(1210), None)
            ]
        );
        assert_eq!((s.passed, s.failed, s.skipped), (143, 2, 3));
        assert_eq!(s.failures, ["TestRoute"]);
    }

    #[test]
    fn flutter_progress_counts_last_and_names_failures() {
        let s = read(
            "00:01 +0: loading test/a_test.dart\r00:03 +10: test/a_test.dart: works\r\
             00:04 +10 -1: test/a_test.dart: breaks [E]\n  Expected: 1\n\r00:09 +177 ~2 -1: Some tests failed.\n",
        );
        assert_eq!((s.passed, s.failed, s.skipped), (177, 1, 2));
        assert_eq!(s.failures, ["test/a_test.dart: breaks"]);
        assert_eq!(s.last_line, "00:09 +177 ~2 -1: Some tests failed.");
    }

    #[test]
    fn jest_vitest_and_pytest_totals() {
        let s = read(
            "PASS src/a.test.ts (1.2 s)\nFAIL src/b.test.ts\n  ● Cart › adds\nTests:       1 failed, 1 skipped, 146 passed, 148 total\n",
        );
        assert_eq!((s.passed, s.failed, s.skipped), (146, 1, 1));
        assert_eq!(
            suites(&s),
            [
                ("src/a.test.ts", true, Some(1200), None),
                ("src/b.test.ts", false, None, None)
            ]
        );
        assert_eq!(s.failures, ["Cart › adds"]);

        let s = read(
            " ✓ src/a.test.ts (3 tests) 12ms\n ❯ src/b.test.ts (3 tests | 1 failed) 20ms\n FAIL  src/b.test.ts > cart > adds\n Tests  5 passed | 1 failed (6)\n",
        );
        assert_eq!((s.passed, s.failed), (5, 1));
        assert_eq!(
            suites(&s),
            [
                ("src/a.test.ts", true, Some(12), Some(3)),
                ("src/b.test.ts", false, Some(20), Some(3))
            ]
        );
        assert_eq!(s.failures, ["src/b.test.ts > cart > adds"]);

        let s = read(
            "FAILED tests/test_cart.py::test_adds - AssertionError\n==== 1 failed, 146 passed, 3 skipped in 3.10s ====\n",
        );
        assert_eq!((s.passed, s.failed, s.skipped), (146, 1, 3));
        assert_eq!(s.failures, ["tests/test_cart.py::test_adds"]);
    }
}
