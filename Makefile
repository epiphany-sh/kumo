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
  APP       := $(UI)/build/macos/Build/Products/Release/Kumo.app
  APP_BIN   := $(APP)/Contents/MacOS
  DISCOVERY := $(HOME)/Library/Application Support/kumo/daemon.json
endif

KUMOD := target/release/kumod$(EXE)

# macOS ties permissions ("Always Allow" on Keychain items, folder access)
# to the code signature. Ad-hoc signatures change with every build, so each
# rebuild looks like a new app and asks again. With a stable identity (make
# signing-cert, once) they're asked for once. Without it: ad-hoc, as before.
SIGN_NAME := Kumo Development
SIGN_ID   ?= $(if $(filter macos,$(PLATFORM)),$(shell security find-identity -p codesigning 2>/dev/null | grep -q '"$(SIGN_NAME)"' && echo '$(SIGN_NAME)'))
SIGN      := $(or $(SIGN_ID),-)

# Releases (docs/releasing.md): the GitHub repository that hosts them, their
# appcast (what Sparkle reads) and the Homebrew tap ($(RELEASE_ORG)/homebrew-kumo).
RELEASE_ORG  ?= epiphany-sh
RELEASE_REPO ?= $(RELEASE_ORG)/kumo
FEED_URL     := https://github.com/$(RELEASE_REPO)/releases/latest/download/appcast.xml
SPARKLE_VERSION := 2.10.0
SPARKLE_TOOLS   := target/sparkle-$(SPARKLE_VERSION)/bin
SPARKLE_KEY     := $(shell cat packaging/sparkle-public-key 2>/dev/null)
# CFBundleVersion: Sparkle compares it, so it only grows.
BUILD ?= $(shell git rev-list --count HEAD 2>/dev/null)

# protoc: the one vendored by Cargo (crates/proto) if present, else the system one.
PROTOC ?= $(firstword $(wildcard $(HOME)/.cargo/registry/src/*/protoc-bin-vendored-macos-*/bin/protoc) protoc)

.PHONY: help all engine ui app release sparkle-keys run dev stop status test check bench bench-ui proto clean signing-cert

help: ## Show this help
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}'

all: app ## Same as `app`

engine: ## Build kumod (release)
	$(if $(VERSION),KUMO_VERSION=$(VERSION)) $(CARGO) build --release -p kumod
ifeq ($(PLATFORM),macos)
	@# `make dev` runs this binary: with the stable identity, the keychain's
	@# "Always Allow" survives rebuilds (ad-hoc it would be a new program).
	$(if $(SIGN_ID),codesign --force --sign "$(SIGN_ID)" --identifier dev.kumo.kumod "$(KUMOD)")
endif

ui: ## Build the Flutter app (release)
	cd $(UI) && $(FLUTTER) pub get && $(FLUTTER) build $(PLATFORM) --release $(if $(VERSION),--build-name=$(VERSION) --build-number=$(BUILD))

app: engine ui ## Release app with kumod bundled next to the UI executable
	cp "$(KUMOD)" "$(APP_BIN)/"
ifeq ($(PLATFORM),macos)
	@# Only release builds know where updates are (FEED): a local build
	@# never replaces itself with the published one.
	$(if $(FEED),/usr/libexec/PlistBuddy -c "Add :SUFeedURL string $(FEED)" -c "Add :SUPublicEDKey string $(SPARKLE_KEY)" "$(APP)/Contents/Info.plist")
	@# Sparkle's helpers carry the app's identity, inside out.
	@set -e; S="$(APP)/Contents/Frameworks/Sparkle.framework"; if [ -d "$$S" ]; then \
		for p in Versions/B/XPCServices/Installer.xpc Versions/B/XPCServices/Downloader.xpc Versions/B/Autoupdate Versions/B/Updater.app; do \
			codesign --force --sign "$(SIGN)" --preserve-metadata=entitlements "$$S/$$p"; done; \
		codesign --force --sign "$(SIGN)" "$$S"; fi
	@# Adding a binary breaks the bundle seal: sign kumod (a fixed identifier,
	@# so macOS knows it's the same program), then re-seal the app.
	codesign --force --sign "$(SIGN)" --identifier dev.kumo.kumod "$(APP_BIN)/kumod"
	codesign --force --sign "$(SIGN)" --preserve-metadata=entitlements,requirements,flags,runtime "$(APP)"
	@$(if $(SIGN_ID),,echo "  (signed ad-hoc: macOS asks for permissions again after every build; run 'make signing-cert' once to stop that)")
endif
	@echo "✓ $(APP)"

release: ## Release build: make release VERSION=0.2.0 → dist/Kumo-0.2.0.zip + dist/appcast.xml
	@test -n "$(VERSION)" || { echo "make release VERSION=x.y.z"; exit 1; }
	@test -n "$(SPARKLE_KEY)" || { echo "packaging/sparkle-public-key is missing: run 'make sparkle-keys' once"; exit 1; }
	@test -n "$(SIGN_ID)" || { echo "No '$(SIGN_NAME)' signing identity: releases must keep one identity (make signing-cert)"; exit 1; }
	$(MAKE) app VERSION=$(VERSION) BUILD=$(BUILD) FEED="$(FEED_URL)"
	$(MAKE) $(SPARKLE_TOOLS)/sign_update
	mkdir -p dist
	rm -f dist/Kumo-$(VERSION).zip
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" dist/Kumo-$(VERSION).zip
	SIGN_UPDATE="$(SPARKLE_TOOLS)/sign_update" RELEASE_REPO=$(RELEASE_REPO) \
		packaging/appcast.sh $(VERSION) $(BUILD) dist/Kumo-$(VERSION).zip > dist/appcast.xml
	@# install.sh downloads the latest one by a fixed name.
	cp dist/Kumo-$(VERSION).zip dist/Kumo.zip
	sed -e 's|@RELEASE_REPO@|$(RELEASE_REPO)|g' packaging/install.sh.in > dist/install.sh
	sed -e 's|@RELEASE_REPO@|$(RELEASE_REPO)|g' -e 's|@RELEASE_ORG@|$(RELEASE_ORG)|g' -e 's|@VERSION@|$(VERSION)|g' \
		-e "s|@SHA256@|$$(shasum -a 256 dist/Kumo-$(VERSION).zip | cut -d' ' -f1)|g" packaging/homebrew/kumo.rb.in > dist/kumo.rb
	@echo "✓ dist/: Kumo-$(VERSION).zip, Kumo.zip, appcast.xml, install.sh, kumo.rb"

$(SPARKLE_TOOLS)/sign_update:
	mkdir -p target/sparkle-$(SPARKLE_VERSION)
	curl -fsSL https://github.com/sparkle-project/Sparkle/releases/download/$(SPARKLE_VERSION)/Sparkle-$(SPARKLE_VERSION).tar.xz \
		| tar -xJ -C target/sparkle-$(SPARKLE_VERSION)

sparkle-keys: $(SPARKLE_TOOLS)/sign_update ## Once: Sparkle's update key (private: your Keychain; public: packaging/)
	$(SPARKLE_TOOLS)/generate_keys
	mkdir -p packaging
	$(SPARKLE_TOOLS)/generate_keys -p > packaging/sparkle-public-key
	@echo "✓ packaging/sparkle-public-key. For CI: $(SPARKLE_TOOLS)/generate_keys -x sparkle-private-key, then the SPARKLE_PRIVATE_KEY secret"

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

signing-cert: ## macOS: create the "Kumo Development" signing identity (once)
ifeq ($(PLATFORM),macos)
	@if security find-identity -p codesigning | grep -q '"$(SIGN_NAME)"'; then echo "✓ '$(SIGN_NAME)' already exists"; exit 0; fi; \
	set -e; dir=$$(mktemp -d); trap 'rm -rf "$$dir"' EXIT; \
	printf '[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n[dn]\nCN=$(SIGN_NAME)\n[ext]\nbasicConstraints=critical,CA:false\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=critical,codeSigning\n' > "$$dir/cert.cnf"; \
	/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$$dir/cert.cnf" -keyout "$$dir/key.pem" -out "$$dir/cert.pem" 2>/dev/null; \
	/usr/bin/openssl pkcs12 -export -inkey "$$dir/key.pem" -in "$$dir/cert.pem" -name "$(SIGN_NAME)" -out "$$dir/id.p12" -passout pass:kumo; \
	security import "$$dir/id.p12" -k "$$HOME/Library/Keychains/login.keychain-db" -P kumo -T /usr/bin/codesign; \
	echo "✓ '$(SIGN_NAME)' created. The next 'make run' signs with it; allow Kumo once more and it sticks."
else
	@echo "Only needed on macOS."
endif

