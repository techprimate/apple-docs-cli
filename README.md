# apple-docs-cli

[![Latest release](https://img.shields.io/github/v/release/techprimate/apple-docs-cli)](https://github.com/techprimate/apple-docs-cli/releases/latest)
[![Tests](https://github.com/techprimate/apple-docs-cli/actions/workflows/test.yml/badge.svg)](https://github.com/techprimate/apple-docs-cli/actions/workflows/test.yml)

**Browse and search Apple Developer documentation from your terminal.**

- Read APIs, inspect declarations, platform availability, conformances, and documented members.
- Discover symbols, list technologies and search their documentation collections.
- Use in scripts and agents to retrieve structured results, unchanged DocC documents, and bundled Agent Skills.

> [!NOTE]
> This project is not affiliated with, endorsed by, or sponsored by Apple Inc. It is an independent tool for accessing Apple Developer documentation.

## Installation

On **macOS 13+**, install with Homebrew:

```bash
brew install techprimate/tap/apple-docs
apple-docs --version
```

For **Linux packages**, manual downloads, and checksums, see the [latest release notes](https://github.com/techprimate/apple-docs-cli/releases/latest). To build from source, see the [development guide](docs/DEVELOPMENT.md).

Fetching documentation requires internet access to Apple's documentation service.

## Quick start

Find a technology, search its symbols, then read a type:

```bash
apple-docs technologies list
apple-docs types search Button --technology SwiftUI
apple-docs types view Button --technology SwiftUI
```

Example output from the last command, abbreviated with `[...]`:

```text
Button
Structure · SwiftUI

A control that initiates an action.

Declaration

    nonisolated struct Button<Label> where Label : View

Availability

  iOS 13.0+
  iPadOS 13.0+
  Mac Catalyst 13.0+
  macOS 10.15+
  tvOS 13.0+
  visionOS 1.0+
  watchOS 6.0+

[...]

https://developer.apple.com/documentation/swiftui/button
```

Output reflects Apple's documentation and can change as Apple updates it.

## Commands

| Command                                                     | Purpose                                                     |
| ----------------------------------------------------------- | ----------------------------------------------------------- |
| `apple-docs technologies list`                              | List Apple's documentation technologies.                    |
| `apple-docs types list --technology <technology>`           | List symbols linked directly from a technology's root page. |
| `apple-docs types search <query> --technology <technology>` | Search symbols in a technology's documentation collections. |
| `apple-docs types view <type> --technology <technology>`    | Read a type's documentation.                                |
| `apple-docs cache clean`                                    | Clear cached documentation responses.                       |
| `apple-docs agent skills list`                              | List bundled Agent Skills.                                  |
| `apple-docs agent skills get apple-docs`                    | Print the bundled documentation skill.                      |

Use `apple-docs --help` or append `--help` to a command for its arguments and options.

### Technologies

```bash
apple-docs technologies list
apple-docs technologies list --json
```

The default output is a two-column table containing each technology's display name and full documentation identifier. Use a technology name such as `SwiftUI`, `Foundation`, or `MetricKit` with the `types` commands.

### Type discovery

List the API symbols referenced directly by a technology's root DocC page:

```bash
apple-docs types list --technology MetricKit
```

Each result includes the symbol name, kind, command-ready DocC path, and canonical Apple Developer URL. Apple's root pages are curated, so large frameworks may link to collection pages instead of listing every API directly.

Search a technology's root page and recursively linked collection groups by symbol name or path:

```bash
apple-docs types search Button --technology SwiftUI
```

Search deliberately does not crawl individual symbol pages, which keeps requests bounded. Collection pages can directly reference some nested members, so those may appear, but search is not an exhaustive nested-member index. A missing search result does not necessarily mean the API is undocumented. If you know the exact type or DocC path, try `types view` directly.

### Type documentation

Pass the exact type and technology names:

```bash
apple-docs types view MXHangDiagnostic --technology MetricKit
```

The terminal output includes available information such as:

- Summary and declaration
- Platform availability and deprecation
- Inheritance and protocol conformances
- Documented members and related APIs
- Canonical Apple Developer URL

Every `types` command requires `--technology`. The CLI does not persist a selected framework. Nested symbols accept either dotted Swift spelling or slash-separated DocC paths:

```bash
apple-docs types view URLSession.AsyncBytes --technology Foundation
apple-docs types view URLSession/AsyncBytes --technology Foundation
```

### JSON output

The documentation commands accept `--json`, but their output contracts differ:

| Command                       | JSON output                                                               |
| ----------------------------- | ------------------------------------------------------------------------- |
| `types view`                  | Apple's upstream DocC document, with its response bytes unchanged.        |
| `types list` / `types search` | An array of symbol results with `name`, `kind`, `path`, and `url` fields. |
| `technologies list`           | The sorted catalog as an array of `name` and `identifier` objects.        |

```bash
apple-docs types view MXHangDiagnostic --technology MetricKit --json
apple-docs types list --technology MetricKit --json
apple-docs types search Button --technology SwiftUI --json
```

For example, extract the documented title using [jq](https://jqlang.org/), installed separately:

```bash
apple-docs types view MXHangDiagnostic --technology MetricKit --json \
  | jq -r '.metadata.title'
```

### Cache

Stateless command selection does not mean responses are never cached. To clear cached Apple documentation responses:

```bash
apple-docs cache clean
```

## Agent Skills

The executable includes task-specific guidance for coding agents. Ask your agent to read the bundled skill when using `apple-docs` to look up APIs. The root help points agents to the catalog:

```bash
apple-docs agent skills list
```

Print the bundled skill without installing files:

```bash
apple-docs agent skills get apple-docs
```

## Telemetry

macOS builds include Sentry telemetry for errors, crashes, command traces, logs, and metrics. Command metadata can include the requested technology and type. Linux builds do not include the Sentry SDK.

Disable telemetry for a command:

```bash
TELEMETRY_DISABLED=true apple-docs types view Button --technology SwiftUI
```

Or set `export TELEMETRY_DISABLED=true` in your shell configuration. Disabling telemetry does not stop documentation requests to Apple.

## Support and contributing

Maintained by [Philip Niedertscheider](https://github.com/philprime), co-founder of [techprimate](https://github.com/techprimate).

- [Report a bug or request a feature](https://github.com/techprimate/apple-docs-cli/issues). Include your CLI version, OS and architecture, command, and expected versus actual behavior.
- Contributions are welcome. Follow the [development guide](docs/DEVELOPMENT.md) and [repository instructions](AGENTS.md).

## License

Licensed under the [Functional Source License 1.1 with an MIT future license (FSL-1.1-MIT)](LICENSE.md). This is source-available software with restrictions on competing commercial uses, not currently MIT-licensed software. Each version becomes available under the MIT license on the second anniversary of its release. See the license for the full terms.
