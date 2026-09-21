# Output modes and JSON

Documentation commands select interaction, audience, and format independently. The browser, human text, agent Markdown, and JSON share normalized documentation content.

## Mode, audience, and format selection

| Invocation                                       | Audience | Format                        | Interaction |
| ------------------------------------------------ | -------- | ----------------------------- | ----------- |
| No output flags, both stdin and stdout are TTYs  | Human    | Terminal UI                   | Interactive |
| No output flags, either descriptor is redirected | Human    | Text or discovery tables      | One-shot    |
| `--non-interactive`                              | Human    | Text or discovery tables      | One-shot    |
| `--json`                                         | Human    | JSON                          | One-shot    |
| `--agent`                                        | Agent    | Markdown                      | One-shot    |
| `--agent --json`                                 | Agent    | JSON with navigation commands | One-shot    |

`--agent` and `--json` each prevent interactive execution. Adding `--non-interactive` to either is valid and redundant. Flag order does not matter. These output options belong to `types view`, `types list`, `types search`, and `technologies list`, not to cache or skill commands.

Mode selection happens before terminal resources are initialized, raw mode is entered, or interactive input is read.

Successful one-shot output goes to stdout. Errors, partial-search warnings, and requested verbose diagnostics go to stderr. Unhandled command failures exit nonzero. JSON stdout contains only the structured result, without terminal escape sequences or progress messages.

```bash
apple-docs types view String --technology Swift --non-interactive
apple-docs types view String --technology Swift --agent
apple-docs types view String --technology Swift --json
apple-docs types view String --technology Swift --agent --json
```

## Human and agent content

Human text uses section headings, declarations, availability tables, prose, and grouped references. Agent Markdown uses predictable headings, explicit technology and path information, and copyable follow-up commands. Agent output does not deliberately summarize or remove content to save tokens.

Parity means the representations share normalized content. It does not promise support for every upstream DocC field or identical fields in every output format. Missing normalized content is not evidence that Apple supplies no such content.

Agent navigation uses supported CLI commands, explicit technology arguments, `--agent`, and shell-quoted values. Technology roots use `types list`. Representable document paths use `types view`. External or unavailable targets have no CLI navigation command.

Named CLI input interprets dots as hierarchy separators and lowercases paths. Normalized documentation links preserve Apple's path spelling and punctuation. The presenter omits follow-up commands for paths that cannot round-trip through named input rather than fabricating a command. Dash-prefixed operands use the argument terminator (`--`).

## JSON result shapes

There is no versioned envelope. Page output is an object. Symbol and technology catalogs are top-level arrays.

### Pages

`types view --json` exposes these top-level fields:

| Fields                               | Meaning                                                          |
| ------------------------------------ | ---------------------------------------------------------------- |
| `title`, `kind`                      | Display title and page/symbol kind                               |
| `technology`, `path`, `url`          | Technology slug, full documentation path, and canonical URL      |
| `modules`                            | Module names                                                     |
| `abstract`                           | Semantic summary as inline records                               |
| `deprecation`                        | Deprecation content as blocks                                    |
| `declarations`                       | Objects with `text` and a `languages` array                      |
| `availability`                       | Platform metadata, including version and availability qualifiers |
| `content`                            | Ordered body blocks                                              |
| `relationships`, `topics`, `seeAlso` | Ordered reference groups                                         |

Groups contain `id`, `title`, and `references`. References contain `id`, `title`, `kind`, `abstract`, and a validated `target`. Agent JSON adds `navigation` to representable page, discovery-result, or grouped-reference destinations.

Availability entries contain `name`, `isBeta`, and `isUnavailable`. Version strings `introducedAt`, `deprecatedAt`, and `obsoletedAt` are included when supplied. The boolean fields are present even when false.

Array-valued fields remain arrays when empty. Inapplicable optional fields are omitted. JSON is pretty-printed with sorted keys and unescaped forward slashes. Consumers should parse keys and values rather than rely on field ordering or whitespace.

### Semantic content and links

Inline records contain `type` and `text`. Types are `text`, `code`, and `link`. A link also contains `target`.

| Block `type`    | Content fields                          |
| --------------- | --------------------------------------- |
| `paragraph`     | `inlineContent` array of inline records |
| `heading`       | `text`                                  |
| `codeListing`   | `code` line array and optional `syntax` |
| `orderedList`   | `items` and `startIndex`                |
| `unorderedList` | `items`                                 |
| `aside`         | `content`, `style`, and optional `name` |

Each list item is an array of blocks. An aside's `content` is also an array of blocks, so nested content retains its structure.

Targets use a `type` of `documentation`, `external`, or `unavailable`. Documentation targets contain `technology`, full `path`, `url`, and an optional `fragment`. External targets contain `url`. Unavailable targets retain `label` rather than an executable destination.

### Discovery results

- `types list` and `types search`: arrays of objects with `name`, `kind`, technology-relative `path`, and `url`.
- `technologies list`: a case-insensitively sorted array of objects with `name` and `identifier`.
- Agent variants additionally include `navigation` where supported. Navigation contains `technology`, a technology-relative `path` for document destinations, and `command`. Technology-root navigation omits `path`.

No search matches is a successful empty array, not an error. Partial results remain usable but emit an incomplete-coverage warning to stderr. Human text reports no matches explicitly. Cancellation stops the search rather than returning partial results.

## Compatibility with older output

Documentation commands now open the browser when both stdin and stdout are terminals. Use `--non-interactive` to retain one-shot human output. Agent and JSON output remain one-shot.

The current output contracts also differ from the earlier raw-DocC interface:

- `--agent` emits Markdown rather than acting as an alias for `--json`.
- Use both `--agent --json` for structured agent output.
- `types view --json` emits normalized semantic content, not unchanged upstream DocC bytes.
- There is no replacement raw-DocC export flag.

For example, title extraction uses `.title`, not `.metadata.title`:

```bash
apple-docs types view String --technology Swift --json | jq -r '.title'
```

See [Browsing](BROWSING.md) for interactive use, [Testing](TESTING.md) for output-contract verification, and [Telemetry](TELEMETRY.md) for the separate diagnostic-upload policy.
