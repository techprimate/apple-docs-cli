# apple-docs-cli

[![Latest release](https://img.shields.io/github/v/release/techprimate/apple-docs-cli)](https://github.com/techprimate/apple-docs-cli/releases/latest)
[![Tests](https://github.com/techprimate/apple-docs-cli/actions/workflows/test.yml/badge.svg)](https://github.com/techprimate/apple-docs-cli/actions/workflows/test.yml)

**Browse and search Apple Developer documentation from your terminal.**

- Read APIs, inspect declarations, platform availability, conformances, and documented members.
- Discover symbols, list technologies and search their documentation collections.
- Browse support articles, help guides, glossary definitions, agreements, and guidelines.
- Use in scripts and agents to retrieve structured results, agent Markdown, and bundled Agent Skills.

> [!NOTE]
> This project is not affiliated with, endorsed by, or sponsored by Apple Inc. It is an independent tool for accessing Apple Developer documentation.

## Installation

On macOS, install with Homebrew:

```bash
brew install techprimate/tap/apple-docs
apple-docs --version
```

For **Linux packages**, manual downloads, and checksums, see the [latest release notes](https://github.com/techprimate/apple-docs-cli/releases/latest). To build from source, see the [development guide](docs/DEVELOPMENT.md).

Fetching documentation requires internet access to Apple's documentation services.

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
| `apple-docs support articles list`                          | Discover categorized support resources.                     |
| `apple-docs support guides list`                            | Discover help resources and topic groups.                   |
| `apple-docs support guides contents --name <guide>`         | Browse a guide's table of contents.                         |
| `apple-docs support glossary list`                          | List or filter glossary terms and definitions.              |
| `apple-docs support glossary view --term <term>`            | Read one glossary definition.                               |
| `apple-docs support terms list`                             | Discover agreements and guidelines.                         |
| `apple-docs support terms view --name <entry>`              | Read an entry's document resources and translations.        |
| `apple-docs support view --path <path>`                     | Read a supported help or support HTML page.                 |
| `apple-docs cache clean`                                    | Clear cached documentation responses.                       |
| `apple-docs agent skills list`                              | List bundled Agent Skills.                                  |
| `apple-docs agent skills get <name>`                        | Print a bundled research skill.                             |
| `apple-docs agent skills install <name>`                    | Install a selected bundled skill.                           |
| `apple-docs agent skills uninstall <name>`                  | Remove an unchanged managed skill.                          |

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

No matches is a successful result with an empty `types` array in JSON. Search JSON also includes the resolved `technology` and `coverage`, with `isComplete` and typed `unavailableCollections`. If some collection pages cannot be fetched, available matches are still returned and an incomplete-coverage warning is written to stderr. Unexpected failures and cancellation stop the search instead of returning partial results.

### Type documentation

Pass the exact type and technology names:

```bash
apple-docs types view MXHangDiagnostic --technology MetricKit
```

The terminal output includes available information such as:

- Summary and declarations in the languages supplied by Apple
- Platform availability, deprecation, obsoleted versions, beta status, and unavailability
- Inheritance and protocol conformances
- Documented members and related APIs
- Canonical Apple Developer URL

Text rendering also supports sparse article and collection pages, resolves reference links, and strips remote terminal control characters. It uses normalized documentation content, which does not cover every upstream DocC field. JSON uses the same normalized content, not the original DocC document.

Every `types` command requires `--technology`. The CLI does not persist a selected framework. Nested symbols accept either dotted Swift spelling or slash-separated DocC paths:

```bash
apple-docs types view URLSession.AsyncBytes --technology Foundation
apple-docs types view URLSession/AsyncBytes --technology Foundation
```

### Support articles, guides, and glossary

Discover categorized support resources and browse help guides:

```bash
apple-docs support articles list
apple-docs support articles list --category membership
apple-docs support guides list
apple-docs support guides contents --name app-store-connect
```

Use category identifiers and guide names from returned resources or agent follow-up commands. Article catalogs contain resource links, not article bodies. Guide contents retain nested sections and page links. These commands are not full-text or exhaustive site search.

Read a supported HTML page by its path relative to `developer.apple.com`:

```bash
apple-docs support view --path support/fee-waiver
apple-docs support view --path help/app-store-connect/reference/app-information/screenshot-specifications
```

Paths must start with `help/` or `support/`. Do not pass full URLs, query strings, or fragments. The reader preserves available headings, lists, tables, code, links, images, breadcrumbs, and substantive notices. PDFs and unknown HTML layouts are unsupported. A link in a catalog does not guarantee that the CLI can read its contents.

Find a glossary term, then read its definition:

```bash
apple-docs support glossary list --query account
apple-docs support glossary view --term "Account Holder"
```

The query matches term names by case-insensitive substring, not definition text. Viewing a definition requires the exact displayed term, matched case-insensitively.

### Agreements and guidelines

```bash
apple-docs support terms list
apple-docs support terms list --category guidelines
apple-docs support terms view --name apple-developer-program-license-agreement
```

Copy category and entry identifiers from the catalog. An entry contains its description, document links, resource-specific translations, notices, and available update labels. It does not download the linked legal document or establish which agreement a user has accepted. Keep translations and notices associated with their original document resource.

All support commands are stateless and accept `--agent` and `--json` independently. They do not take `--technology`.

### Agent output

Use `--agent` on documentation and support commands for Markdown with explicit destinations, links, and safely quoted follow-up commands:

```bash
apple-docs types view String --technology Swift --agent
apple-docs types search Button --technology SwiftUI --agent
apple-docs technologies list --agent
apple-docs support guides contents --name app-store-connect --agent
apple-docs support view --path support/fee-waiver --agent
```

Agent output uses the same normalized documentation content as human text. Follow-up commands are included only for destinations the CLI can represent safely. All commands remain one-shot, even when run in a terminal.

`--agent` selects the audience and `--json` selects the format independently. Combine them for JSON with agent navigation commands.

### JSON output

The DocC documentation commands accept `--json` for normalized semantic output:

| Command             | JSON output                                                                                                                                                                             |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `types view`        | An object with `title`, `kind`, `technology`, `path`, `url`, `modules`, `abstract`, `deprecation`, `declarations`, `availability`, `content`, `relationships`, `topics`, and `seeAlso`. |
| `types list`        | An array with `name`, `kind`, `path`, and `url` fields.                                                                                                                                 |
| `types search`      | An object containing `technology`, a `types` array, and `coverage` with completeness and typed collection failures.                                                                     |
| `technologies list` | A sorted array of `name` and `identifier` objects.                                                                                                                                      |

Support commands return objects tagged with `kind`, including catalogs, guide contents, glossary definitions, terms entries, and articles. For example:

```bash
apple-docs support articles list --agent --json
apple-docs support glossary view --term "Account Holder" --json
apple-docs support view --path support/fee-waiver --agent --json
```

Support JSON has its own catalog and rich-content shapes, distinct from DocC pages. See [Output formats and JSON](docs/OUTPUT.md#support-json-result-shapes) for fields and examples.

Add `--agent` to include `navigation` commands for supported destinations. DocC content blocks retain semantic types and links distinguish documentation, external, and unavailable targets. Availability includes `introducedAt`, `deprecatedAt`, `obsoletedAt`, `isBeta`, and `isUnavailable` when applicable. Inapplicable optional fields are omitted.

```bash
apple-docs types view String --technology Swift --json
apple-docs types view String --technology Swift --agent --json
apple-docs types search Button --technology SwiftUI --agent --json
```

For example, extract the documented title using [jq](https://jqlang.org/), installed separately:

```bash
apple-docs types view String --technology Swift --json | jq -r '.title'
```

Page JSON is normalized rather than raw DocC. There is no raw-DocC export flag. Normalization does not preserve every upstream field, so missing normalized content is not evidence that Apple supplies no such information. JSON stdout contains only the result, with warnings and verbose diagnostics sent to stderr.

See [Output formats and JSON](docs/OUTPUT.md) for the complete normalized JSON shapes, link targets, and follow-up-command limitations.

### Cache

Stateless command selection does not mean responses are never cached. To clear cached Apple documentation responses:

```bash
apple-docs cache clean
```

## Agent Skills

The executable includes task-specific research guidance for coding agents. List available skills and their descriptions, then read the relevant skill before researching:

```bash
apple-docs agent skills list
```

Print the bundled skill without installing files:

```bash
apple-docs agent skills get apple-docs
```

Preview and install all bundled skills:

```bash
apple-docs agent skills install --all --dry-run
apple-docs agent skills install --all
```

The default destination is `~/.agents/skills`. Use `--project` for `.agents/skills` beneath the Git root, or beneath the current directory outside Git. Use `--dir <root>` for another `.agents` root. Installation does not configure individual agent tools, which must support this directory convention.

To remove managed skills, preview first:

```bash
apple-docs agent skills uninstall --all --dry-run
apple-docs agent skills uninstall --all --yes
```

`--force` replaces differing managed skill files during installation, never unmanaged files. Uninstall refuses to remove modified managed skills and preserves unrelated files. Bulk removal requires `--yes` unless previewing with `--dry-run`. Agents should obtain approval before installation or removal.

## Telemetry

macOS builds include Sentry telemetry for errors, crashes, command traces, logs, and metrics. API command metadata can include the requested technology and type. Support commands record their command name and JSON output mode, not lookup paths, filters, or terms. Linux builds do not include the Sentry SDK. See the [telemetry policy](docs/TELEMETRY.md) for details.

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
