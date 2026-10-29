use std::path::Path;

use super::TestCommand;

/// Reads files of any worktree; implemented by the infrastructure. Blocks.
pub trait ProjectReader: Send + Sync + 'static {
    /// The text of `relative` in `worktree`, if it's a readable small file.
    fn read(&self, worktree: &Path, relative: &str) -> Option<String>;
}

/// A worktree's files, as far as finding its test command goes. Blocks.
pub trait ProjectFiles {
    /// A file's text, by path relative to the worktree.
    fn read(&self, relative: &str) -> Option<String>;
    fn exists(&self, relative: &str) -> bool {
        self.read(relative).is_some()
    }
    /// Whether `program` is installed.
    fn has_program(&self, program: &str) -> bool;
}

/// The project's own test command: a Makefile `test` target first, then
/// the usual one for its language.
pub fn detect_command(files: &dyn ProjectFiles) -> Option<TestCommand> {
    let found = |command: &str, origin: &str| {
        Some(TestCommand {
            command: command.to_owned(),
            origin: origin.to_owned(),
        })
    };
    for makefile in ["Makefile", "makefile", "GNUmakefile"] {
        if files
            .read(makefile)
            .is_some_and(|text| has_target(&text, "test"))
        {
            return found("make test", makefile);
        }
    }
    if let Some(cargo) = files.read("Cargo.toml") {
        let workspace = cargo.lines().any(|l| l.trim() == "[workspace]");
        return found(
            if workspace {
                "cargo test --workspace"
            } else {
                "cargo test"
            },
            "Cargo.toml",
        );
    }
    if files.exists("go.mod") {
        return if files.has_program("gotestsum") {
            found("gotestsum --format pkgname", "go.mod")
        } else {
            found("go test ./...", "go.mod")
        };
    }
    if let Some(pubspec) = files.read("pubspec.yaml") {
        let flutter = pubspec.lines().any(|l| l.trim() == "sdk: flutter");
        return found(
            if flutter { "flutter test" } else { "dart test" },
            "pubspec.yaml",
        );
    }
    if let Some(package) = files.read("package.json")
        && has_test_script(&package)
    {
        let runner = [
            ("pnpm-lock.yaml", "pnpm test"),
            ("yarn.lock", "yarn test"),
            ("bun.lockb", "bun run test"),
            ("bun.lock", "bun run test"),
        ]
        .into_iter()
        .find(|(lock, _)| files.exists(lock))
        .map_or("npm test", |(_, run)| run);
        return found(runner, "package.json");
    }
    for (file, needle) in [
        ("pytest.ini", ""),
        ("pyproject.toml", "pytest"),
        ("setup.cfg", "pytest"),
        ("tox.ini", "pytest"),
    ] {
        if files.read(file).is_some_and(|text| text.contains(needle)) {
            return found("pytest", file);
        }
    }
    if files.exists("mix.exs") {
        return found("mix test", "mix.exs");
    }
    None
}

/// A rule for `target` at the start of a line (`test:`, `test: deps`).
fn has_target(makefile: &str, target: &str) -> bool {
    makefile.lines().any(|line| {
        line.strip_prefix(target).is_some_and(|rest| {
            rest.trim_start().starts_with(':') && !rest.trim_start().starts_with(":=")
        })
    })
}

/// `"test": "…"` under `scripts`, other than npm's placeholder.
fn has_test_script(package: &str) -> bool {
    let Some(scripts) = package.find("\"scripts\"") else {
        return false;
    };
    let scripts = &package[scripts..];
    let scripts = &scripts[..scripts.find('}').unwrap_or(scripts.len())];
    scripts
        .find("\"test\"")
        .is_some_and(|at| !scripts[at..].contains("no test specified"))
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use super::*;

    struct Files(HashMap<&'static str, &'static str>, bool);

    impl ProjectFiles for Files {
        fn read(&self, relative: &str) -> Option<String> {
            self.0.get(relative).map(|s| (*s).to_owned())
        }
        fn has_program(&self, _: &str) -> bool {
            self.1
        }
    }

    fn detect(files: &[(&'static str, &'static str)], gotestsum: bool) -> Option<(String, String)> {
        detect_command(&Files(files.iter().copied().collect(), gotestsum))
            .map(|c| (c.command, c.origin))
    }

    fn pair(command: &str, origin: &str) -> Option<(String, String)> {
        Some((command.into(), origin.into()))
    }

    #[test]
    fn a_makefile_target_wins() {
        let make = "build:\n\tcargo build\ntest: build ## all tests\n\tcargo test\n";
        assert_eq!(
            detect(&[("Makefile", make), ("Cargo.toml", "")], false),
            pair("make test", "Makefile")
        );
        assert_eq!(
            detect(
                &[
                    ("Makefile", "TEST := x\ntests:\n"),
                    ("Cargo.toml", "[workspace]\n")
                ],
                false
            ),
            pair("cargo test --workspace", "Cargo.toml"),
            "no `test` target"
        );
    }

    #[test]
    fn each_language_has_its_runner() {
        assert_eq!(
            detect(&[("go.mod", "")], true),
            pair("gotestsum --format pkgname", "go.mod")
        );
        assert_eq!(
            detect(&[("go.mod", "")], false),
            pair("go test ./...", "go.mod")
        );
        assert_eq!(
            detect(
                &[(
                    "pubspec.yaml",
                    "dependencies:\n  flutter:\n    sdk: flutter\n"
                )],
                false
            ),
            pair("flutter test", "pubspec.yaml")
        );
        assert_eq!(
            detect(
                &[
                    ("package.json", r#"{"scripts": {"test": "vitest"}}"#),
                    ("pnpm-lock.yaml", "")
                ],
                false
            ),
            pair("pnpm test", "package.json")
        );
        assert_eq!(
            detect(
                &[(
                    "package.json",
                    r#"{"scripts": {"test": "echo \"Error: no test specified\" && exit 1"}}"#
                )],
                false
            ),
            None
        );
        assert_eq!(
            detect(&[("pyproject.toml", "[tool.pytest.ini_options]")], false),
            pair("pytest", "pyproject.toml")
        );
        assert_eq!(detect(&[("README.md", "")], false), None);
    }
}
