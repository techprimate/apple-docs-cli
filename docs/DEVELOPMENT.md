# Development

## Prerequisites

- Swift 6.3 or later and Make. CI uses Swift 6.3.3.
- Homebrew for `make init`, which installs actionlint, dprint, pre-commit, and SwiftLint.
- Docker only if you want to run `make test-linux`.

## Build from source

Clone the repository and build:

```bash
git clone https://github.com/techprimate/apple-docs-cli.git
cd apple-docs-cli
make build
./dist/apple-docs --help
```

The release binary is written to `dist/apple-docs`. You can run it directly or install it into a directory on your `PATH`.

## Setup

From the repository root, install development tools and resolve SwiftPM dependencies:

```bash
make init
```

Install the Git hooks separately:

```bash
pre-commit install
```

`make init` requires Homebrew. If you manage development tools yourself, install the tools listed above and run `make resolve` to resolve SwiftPM dependencies.

## Development commands

| Command                                                  | Purpose                                                                                            |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `make run ARGS="types view Button --technology SwiftUI"` | Run the executable through SwiftPM.                                                                |
| `make build`                                             | Build the release binary at `dist/apple-docs`.                                                     |
| `make test`                                              | Run the test suite.                                                                                |
| `make test-linux`                                        | Run tests in a pinned Swift 6.3.3 Linux container using Docker.                                    |
| `make test-integration`                                  | Build the release binary and run live tests against Apple documentation. Requires internet access. |
| `make analyze`                                           | Run SwiftLint, formatting checks, and actionlint.                                                  |
| `make format`                                            | Format Swift with `swift format` and JSON, YAML, Markdown, and TOML with dprint.                   |
| `make help`                                              | Show all development commands.                                                                     |

## Before submitting

Follow the [repository instructions](../AGENTS.md), keep changes focused, and add a regression test for behavior changes and bug fixes.

Run `make test`, `make analyze`, and `make build`. After Swift edits, run `make format` and rerun `make analyze`. For command-facing changes, also exercise the affected release command directly.
