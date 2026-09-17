# Development

## Prerequisites

- Swift 6.4 or later and Make. macOS builds require macOS 15 or later. CI and Linux containers use Swift 6.4.0.
- Homebrew for `make init`, which installs actionlint, dprint, pre-commit, and SwiftLint.
- Docker for container-based Linux build and test targets.

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
| `make test-linux`                                        | Run tests in pinned Swift 6.4.0 containers for amd64 and arm64.                                    |
| `make test-integration`                                  | Build the release binary and run live tests against Apple documentation. Requires internet access. |
| `make analyze`                                           | Run SwiftLint, formatting checks, and actionlint.                                                  |
| `make format`                                            | Format Swift with `swift format` and JSON, YAML, Markdown, and TOML with dprint.                   |
| `make help`                                              | Show all development commands.                                                                     |

## Linux workflows

Container commands mount the source read-only and keep build products in Docker volumes, separate from the host build directory. The two test architectures use isolated volumes. Select one architecture or narrow the tests when needed:

```bash
make test-linux-amd64
make test-linux-arm64 TEST_ARGS="--filter AppleDocumentationClientSearchTests"
make build-linux-native
make test-integration-linux
```

Live integration tests require internet access. Both integration targets accept `INTEGRATION_FILTER=SuiteName`. `make test` also accepts `TEST_ARGS`.

For static release builds, use the matching Swift.org 6.4.0 toolchain, not Xcode's bundled compiler:

```bash
make install-linux-sdk
make build-linux SWIFT_SDK=x86_64-swift-linux-musl
make build-linux SWIFT_SDK=aarch64-swift-linux-musl
```

Alternatively, install the SDK and build inside the container without changing the host toolchain:

```bash
make install-linux-sdk-container
make build-linux-container SWIFT_SDK=x86_64-swift-linux-musl
make run-linux ARGS="swift sdk list"
```

Container targets accept `LINUX_DOCKER_FLAGS`. Direct container targets also accept `LINUX_BUILD_VOLUME` and `LINUX_SDK_VOLUME` to isolate build and SDK storage. Static outputs remain in SwiftPM's SDK-specific release directory. `make build-linux-native` uses the container's libc for release CLI integration tests.

## Before submitting

Follow the [repository instructions](../AGENTS.md), keep changes focused, and add a regression test for behavior changes and bug fixes.

Run `make test`, `make analyze`, and `make build`. After Swift edits, run `make format` and rerun `make analyze`. For command-facing changes, also exercise the affected release command directly.
