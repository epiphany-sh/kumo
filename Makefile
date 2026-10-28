# Kumo — build, test and run the whole app (engine + UI).
#
#   make run     release build of kumod + Flutter app, kumod bundled inside, launched
#   make dev     kumod (release) + `flutter run` in debug with hot reload
#   make help    everything else

.DEFAULT_GOAL := help
SHELL := /bin/bash

# rustup installs to ~/.cargo/bin: use it when a shell opened before the
# install (or a GUI) doesn't have it on PATH.
CARGO   ?= $(or $(shell command -v cargo 2>/dev/null),$(wildcard $(HOME)/.cargo/bin/cargo),cargo)
FLUTTER ?= flutter
DART    ?= dart
UI      := kumo-ui

ifeq ($(OS),Windows_NT)
  PLATFORM  := windows
  EXE       := .exe
  APP       := $(UI)/build/windows/x64/runner/Release
  APP_BIN   := $(APP)
  DISCOVERY := $(LOCALAPPDATA)/kumo/daemon.json
else
  PLATFORM  := macos
  EXE       :=
  APP       := $(UI)/build/macos/Build/Products/Release/kumo_ui.app
  APP_BIN   := $(APP)/Contents/MacOS
  DISCOVERY := $(HOME)/Library/Application Support/kumo/daemon.json
endif

KUMOD := target/release/kumod$(EXE)

# protoc: the one vendored by Cargo (crates/proto) if present, else the system one.
PROTOC ?= $(firstword $(wildcard $(HOME)/.cargo/registry/src/*/protoc-bin-vendored-macos-*/bin/protoc) protoc)

.PHONY: help all engine ui app run dev stop status test check bench bench-ui proto clean

help: ## Show this help
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}'

all: app ## Same as `app`

engine: ## Build kumod (release)
	$(CARGO) build --release -p kumod

ui: ## Build the Flutter app (release)
	cd $(UI) && $(FLUTTER) pub get && $(FLUTTER) build $(PLATFORM) --release

app: engine ui ## Release app with kumod bundled next to the UI executable
	cp "$(KUMOD)" "$(APP_BIN)/"
ifeq ($(PLATFORM),macos)
	@# Adding a binary breaks the bundle seal: sign kumod, then re-seal the app (ad-hoc).
	codesign --force --sign - "$(APP_BIN)/kumod"
	codesign --force --sign - --preserve-metadata=entitlements,requirements,flags,runtime "$(APP)"
endif
	@echo "✓ $(APP)"

run: app stop ## Build everything, restart the daemon and open the app
ifeq ($(PLATFORM),macos)
	open "$(APP)"
else
	"$(APP_BIN)/kumo_ui.exe"
endif

dev: engine ## kumod (release) + Flutter in debug mode with hot reload
	cd $(UI) && KUMOD_PATH="$(abspath $(KUMOD))" $(FLUTTER) run -d $(PLATFORM)

stop: ## Stop the running daemon (its terminals end with it)
ifeq ($(PLATFORM),macos)
	@pid=$$(sed -n 's/.*"pid": *\([0-9]*\).*/\1/p' "$(DISCOVERY)" 2>/dev/null); \
	if [ -n "$$pid" ] && kill -0 $$pid 2>/dev/null; then \
		kill $$pid && echo "✓ kumod (pid $$pid) stopped"; \
	else echo "kumod is not running"; fi
else
	-taskkill /IM kumod.exe /F
endif

status: ## Show the daemon discovery file and whether it is alive
	@if [ -f "$(DISCOVERY)" ]; then \
		pid=$$(sed -n 's/.*"pid": *\([0-9]*\).*/\1/p' "$(DISCOVERY)"); \
		addr=$$(sed -n 's/.*"addr": *"\([^"]*\)".*/\1/p' "$(DISCOVERY)"); \
		if kill -0 $$pid 2>/dev/null; then echo "kumod running · pid $$pid · $$addr"; \
		else echo "stale discovery file (pid $$pid is gone)"; fi; \
	else echo "kumod is not running"; fi

test: ## Rust and Flutter tests
	$(CARGO) test --workspace
	cd $(UI) && $(FLUTTER) test

check: ## Formatting and lints (Rust + Dart)
	$(CARGO) fmt --all --check
	$(CARGO) clippy --workspace --all-targets -- -D warnings
	cd $(UI) && $(DART) analyze lib/engine lib/terminal

bench: ## Daemon benchmarks (kumo.md §4)
	$(CARGO) build --release --workspace
	./target/release/kumo-bench$(EXE) all

bench-ui: ## Terminal render benchmark (Flutter, profile mode)
	cd $(UI) && $(FLUTTER) run -d $(PLATFORM) --profile -t benchmark/render_bench.dart

proto: ## Regenerate the Dart client from proto/ (needs `dart pub global activate protoc_plugin`)
	mkdir -p $(UI)/lib/engine/generated
	PATH="$(HOME)/.pub-cache/bin:$$PATH" "$(PROTOC)" --dart_out=grpc:$(UI)/lib/engine/generated -I proto proto/kumo/v1/kumo.proto

clean: ## Remove Rust and Flutter build outputs
	$(CARGO) clean
	cd $(UI) && $(FLUTTER) clean
