SHELL := /bin/bash

# Keep FILTER literal, including Make expressions, shell syntax, and apostrophes.
unexport FILTER
test_filter_arg = $(if $(value FILTER),--filter '$(subst ','"'"',$(value FILTER))')

.PHONY: build check docs-list format install lint release restart start start-debug start-release stop test test-fast test-skip-build test-live test-tty

start:
	./Scripts/run_linux.sh

start-debug:
	./Scripts/run_linux.sh

start-release:
	./Scripts/package_app.sh release
	pkill -x CodexBar || pkill -f CodexBar.app || true
	cd /Users/steipete/Projects/codexbar && open -n /Users/steipete/Projects/codexbar/CodexBar.app

restart: start

# Ask the running desktop to quit over its own IPC before falling back to a signal.
stop:
	@-$(HOME)/.local/bin/codexbar-linux --quit >/dev/null 2>&1
	@-./.local/linux-build/codexbar-linux --quit >/dev/null 2>&1
	@-pkill -x codexbar-linux >/dev/null 2>&1
	@echo "CodexBar stopped."

check lint:
	./Scripts/lint.sh lint

format:
	./Scripts/lint.sh format

docs-list:
	node Scripts/docs-list.mjs

build:
	swift build

# Builds the CLI and the Qt desktop, then installs both plus the launcher entry for this
# user. Pass installer flags through INSTALL_ARGS, e.g. INSTALL_ARGS=--no-autostart.
install:
	./Scripts/install_linux.sh $(INSTALL_ARGS)

test:
	./Scripts/test.sh

test-fast:
	./Scripts/test_fast.sh $(test_filter_arg)

test-skip-build:
	./Scripts/test_fast.sh --skip-build $(test_filter_arg)

test-tty:
	CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS=1 swift test --filter TTYIntegrationTests

test-live:
	LIVE_TEST=1 CODEXBAR_ALLOW_TEST_KEYCHAIN_ACCESS=1 swift test --filter LiveAccountTests

release:
	./Scripts/package_app.sh release
