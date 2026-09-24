# ============================================================================
# APPLE DOCS CLI MAKEFILE
# ============================================================================
# This Makefile provides automation for building, testing, and developing
# the apple-docs CLI. Run 'make help' to see all available commands.
# ============================================================================

# Default target - show help when running 'make' without arguments
.DEFAULT_GOAL := help

# ============================================================================
# BUILD CONFIGURATION
# ============================================================================

# Configurable build variables
CLI_NAME := apple-docs
DIST_DIR := dist
CLI_BINARY := $(DIST_DIR)/$(CLI_NAME)
RELEASE_BIN_DIR = $(shell swift build -c release --show-bin-path)
LINUX_SWIFT_IMAGE := swift:6.4.0
LINUX_DOCKER_FLAGS ?=
LINUX_BUILD_VOLUME ?= apple-docs-cli-linux-build
LINUX_SDK_VOLUME ?= apple-docs-cli-linux-sdks
LINUX_CONTAINER = docker run --rm $(LINUX_DOCKER_FLAGS) \
	--mount "type=bind,source=$(CURDIR),target=/workspace,readonly" \
	--volume "$(LINUX_BUILD_VOLUME):/workspace/.build" \
	--volume "$(LINUX_SDK_VOLUME):/root/.swiftpm/swift-sdks" \
	--workdir /workspace $(LINUX_SWIFT_IMAGE)
LINUX_RELEASE_BIN_DIR = $(shell $(LINUX_CONTAINER) swift build -c release --show-bin-path)
INTEGRATION_FILTER ?= CLIIntegrationTests
SWIFT_SDK ?= x86_64-swift-linux-musl
# Official URL and checksum from https://www.swift.org/install/linux/.
LINUX_SDK_URL := https://download.swift.org/swift-6.4.0-release/static-sdk/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE_static-linux-0.1.0.artifactbundle.tar.gz
LINUX_SDK_CHECKSUM := 47d2fd89eebfdf9eb4d536b6710414297f755c17926cdebc4742c08982b40a9e

# Source files used to determine when the distribution binary needs rebuilding
SWIFT_SOURCES := $(shell find Sources Tests -type f -name '*.swift')
PACKAGE_FILES := Package.swift Package.resolved

# Ensure the distribution directory exists
$(DIST_DIR):
	@mkdir -p $(DIST_DIR)

# ============================================================================
# SETUP & DEPENDENCIES
# ============================================================================

## Initialize the project for development
#
# Installs development tools from Brewfile and resolves SwiftPM dependencies.
# Run this once after cloning the repository.
.PHONY: init
init:
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "Homebrew is required to install development tools."; \
		exit 1; \
	fi
	brew bundle
	swift package resolve

## Resolve SwiftPM dependencies
#
# Downloads package dependencies using the versions recorded in Package.resolved.
.PHONY: resolve
resolve:
	swift package resolve

## Install the matching Swift 6.4.0 static Linux SDK
#
# Requires the Swift.org 6.4.0 toolchain, not the compiler bundled with Xcode.
.PHONY: install-linux-sdk
install-linux-sdk:
	swift sdk install "$(LINUX_SDK_URL)" --checksum "$(LINUX_SDK_CHECKSUM)"

## Install the static Linux SDK in the verification container
#
# Persists the SDK in LINUX_SDK_VOLUME, without changing the host toolchain.
.PHONY: install-linux-sdk-container
install-linux-sdk-container:
	$(LINUX_CONTAINER) swift sdk install "$(LINUX_SDK_URL)" --checksum "$(LINUX_SDK_CHECKSUM)"

# ============================================================================
# BUILDING & RUNNING
# ============================================================================

## Build the release CLI binary
#
# Creates a standalone optimized binary at dist/apple-docs.
.PHONY: build
build: $(CLI_BINARY)

$(CLI_BINARY): $(SWIFT_SOURCES) $(PACKAGE_FILES) | $(DIST_DIR)
	swift build -c release
	cp "$(RELEASE_BIN_DIR)/$(CLI_NAME)" "$@"

## Build a static Linux release binary
#
# Run make install-linux-sdk first. Defaults to x86_64-swift-linux-musl.
# For arm64, use make build-linux SWIFT_SDK=aarch64-swift-linux-musl.
# Leaves the binary in the selected SDK's SwiftPM release output directory.
.PHONY: build-linux
build-linux:
	swift build -c release --swift-sdk "$(SWIFT_SDK)"

## Build a static Linux release binary in the verification container
#
# Run make install-linux-sdk-container first. Select either architecture with SWIFT_SDK.
.PHONY: build-linux-container
build-linux-container:
	$(LINUX_CONTAINER) swift build -c release --swift-sdk "$(SWIFT_SDK)" --disable-automatic-resolution

## Build the native Linux release CLI in the verification container
#
# Builds against the container's libc for native CLI integration tests.
.PHONY: build-linux-native
build-linux-native:
	$(LINUX_CONTAINER) swift build -c release --disable-automatic-resolution

## Run a command in the Linux verification container
#
# For example: make run-linux ARGS="swift sdk list".
.PHONY: run-linux
run-linux:
	$(LINUX_CONTAINER) $(ARGS)

## Build and run the CLI
#
# Pass command arguments through ARGS, for example:
#   make run ARGS="types view MXHangDiagnostic --technology MetricKit"
.PHONY: run
run:
	swift run $(CLI_NAME) $(ARGS)

# ============================================================================
# TESTING & QUALITY ASSURANCE
# ============================================================================

## Run all tests
#
# Executes the complete Swift Testing suite.
# Narrow a run with TEST_ARGS="--filter SuiteName".
.PHONY: test
test:
	swift test $(TEST_ARGS)

## Run Linux tests on both amd64 and arm64
#
# Each architecture has an isolated build volume. Both accept TEST_ARGS.
.PHONY: test-linux
test-linux: test-linux-amd64 test-linux-arm64

## Run tests in the amd64 Linux container
#
# Uses an isolated amd64 SwiftPM build volume. Accepts TEST_ARGS.
.PHONY: test-linux-amd64
test-linux-amd64:
	$(MAKE) run-linux LINUX_DOCKER_FLAGS="$(LINUX_DOCKER_FLAGS) --platform=linux/amd64" \
		LINUX_BUILD_VOLUME=apple-docs-cli-linux-amd64-build \
		ARGS="swift test --disable-automatic-resolution $(TEST_ARGS)"

## Run tests in the arm64 Linux container
#
# Uses an isolated arm64 SwiftPM build volume. Accepts TEST_ARGS.
.PHONY: test-linux-arm64
test-linux-arm64:
	$(MAKE) run-linux LINUX_DOCKER_FLAGS="$(LINUX_DOCKER_FLAGS) --platform=linux/arm64" \
		LINUX_BUILD_VOLUME=apple-docs-cli-linux-arm64-build \
		ARGS="swift test --disable-automatic-resolution $(TEST_ARGS)"

## Run live CLI integration tests
#
# Builds the release executable and runs network-dependent command tests against Apple documentation.
.PHONY: test-integration
test-integration: build
	APPLE_DOCS_EXECUTABLE="$(CURDIR)/$(CLI_BINARY)" swift test --no-parallel --filter "$(INTEGRATION_FILTER)"

## Run live release CLI tests in the Linux verification container
#
# Disables telemetry. Narrow the integration suite with INTEGRATION_FILTER=SuiteName.
.PHONY: test-integration-linux
test-integration-linux: build-linux-native
	$(LINUX_CONTAINER) env TELEMETRY_DISABLED=true \
		APPLE_DOCS_EXECUTABLE="$(LINUX_RELEASE_BIN_DIR)/$(CLI_NAME)" \
		swift test --disable-automatic-resolution --no-parallel --filter "$(INTEGRATION_FILTER)"

## Run SwiftLint
#
# Checks project-owned Swift files using .swiftlint.yml. Warnings fail the target.
.PHONY: lint
lint:
	swiftlint lint --strict --config .swiftlint.yml

## Check project formatting
#
# Verifies Swift, JSON, YAML, Markdown, TOML, and GitHub Actions workflows without modifying them.
.PHONY: format-check
format-check:
	swift format lint \
		--configuration .swift-format.json \
		--recursive \
		--parallel \
		--strict \
		Sources Tests Package.swift
	dprint check
	actionlint

## Run all static quality checks
#
# Runs SwiftLint and verifies swift-format and dprint output.
.PHONY: analyze
analyze: lint format-check

## Format project files
#
# Rewrites Swift files with swift-format and supported config/docs with dprint.
.PHONY: format
format:
	swift format format \
		--configuration .swift-format.json \
		--in-place \
		--recursive \
		--parallel \
		Sources Tests Package.swift
	dprint fmt

# ============================================================================
# MAINTENANCE
# ============================================================================

## Clean generated build artifacts
#
# Removes SwiftPM and distribution build output.
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf "$(DIST_DIR)"
	@echo "Clean complete."

# ============================================================================
# HELP & DOCUMENTATION
# ============================================================================

## Show this help message with all available commands
#
# Displays a formatted list of make targets generated from the comments above.
.PHONY: help
help:
	@echo "=============================================="
	@echo "APPLE DOCS CLI DEVELOPMENT COMMANDS"
	@echo "=============================================="
	@echo ""
	@awk 'BEGIN { desc = ""; target = "" } \
	/^## / { desc = substr($$0, 4) } \
	/^\.PHONY: / && desc != "" { \
		target = $$2; \
		printf "\033[36m%-32s\033[0m %s\n", target, desc; \
		desc = ""; target = "" \
	}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Use 'make <command>' to run any command above."
	@echo "For detailed information, see comments in the Makefile."
	@echo ""
