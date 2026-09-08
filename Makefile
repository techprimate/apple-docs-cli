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

## Build and run the CLI
#
# Pass command arguments through ARGS, for example:
#   make run ARGS="type MXHangDiagnostic --technology MetricKit"
.PHONY: run
run:
	swift run $(CLI_NAME) $(ARGS)

# ============================================================================
# TESTING & QUALITY ASSURANCE
# ============================================================================

## Run all tests
#
# Executes the complete Swift Testing suite.
.PHONY: test
test:
	swift test

## Run SwiftLint
#
# Checks project-owned Swift files using .swiftlint.yml. Warnings fail the target.
.PHONY: lint
lint:
	swiftlint lint --strict --config .swiftlint.yml

## Check Swift formatting
#
# Verifies project-owned Swift files without modifying them.
.PHONY: format-check
format-check:
	swift format lint \
		--configuration .swift-format.json \
		--recursive \
		--parallel \
		--strict \
		Sources Tests Package.swift

## Run all static quality checks
#
# Runs SwiftLint and verifies swift-format output.
.PHONY: analyze
analyze: lint format-check

## Format Swift source files
#
# Rewrites project-owned Swift files using .swift-format.json.
.PHONY: format
format:
	swift format format \
		--configuration .swift-format.json \
		--in-place \
		--recursive \
		--parallel \
		Sources Tests Package.swift

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
		printf "\033[36m%-20s\033[0m %s\n", target, desc; \
		desc = ""; target = "" \
	}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Use 'make <command>' to run any command above."
	@echo "For detailed information, see comments in the Makefile."
	@echo ""
