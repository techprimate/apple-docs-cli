# Telemetry

`apple-docs` uses telemetry to understand failures, improve reliability, and learn which parts of Apple documentation are useful. Telemetry is enabled by default and can be disabled by setting `TELEMETRY_DISABLED=true`.

## Principles

Telemetry follows an explicit allowlist model and is enabled by default. Set `TELEMETRY_DISABLED=true` to opt out:

- Capture only fields that have been reviewed and approved.
- Treat new commands, arguments, and metadata as private by default.
- Collect the minimum context needed to reproduce failures.
- Prefer stable, structured fields over raw text and payloads.
- Keep expected user mistakes out of error monitoring.
- Apply privacy controls before data leaves the process and again at ingestion.

Adding a CLI argument does not automatically add it to telemetry.

## What We Capture

### Errors

Unexpected transport, decoding, and rendering failures are reported. Error values are replaced with a generic message while retaining the error type, stack trace, release, environment, and approved command context.

Invalid commands, missing required arguments, invalid flags, and command-level validation errors are user errors. They are not reported as application errors.

### Command Context

Each leaf command starts a `console.command` transaction and opts in to a fixed set of fields.

| Command             | Captured fields                                                    |
| ------------------- | ------------------------------------------------------------------ |
| `types view`        | Command name, documentation type, technology, and JSON output mode |
| `types list`        | Command name, technology, and JSON output mode                     |
| `types search`      | Command name, technology, and JSON output mode                     |
| `technologies list` | Command name and JSON output mode                                  |
| `agent skills list` | Command name                                                       |
| `agent skills get`  | Command name                                                       |

Documentation type and technology values are captured because they identify public Apple documentation and are required to reproduce page-specific failures. Other positional values are excluded unless explicitly approved.

### Logs

Application logs use `apple/swift-log` with the Sentry Swift Log handler. Messages are selected from a fixed allowlist and contain only approved command metadata.

Source file paths, function names, arbitrary metadata, interpolated values, and unapproved log messages are removed before transmission.

### Local browser diagnostics

Local session capture and telemetry transmission are separate. The entry point owns the single SwiftLog bootstrap and selects its handlers before starting the terminal runtime.

While the browser owns the terminal, console logging is disabled so diagnostics cannot overwrite the screen. Instead, a thread-safe in-memory buffer captures warning-and-higher entries by default or debug-and-higher entries with `--verbose`, including while the log panel is hidden. Backtick opens the panel. It retains at most 500 entries, evicts the oldest first, and writes no session-log file.

The existing telemetry handler remains active at its existing info-and-higher threshold when enabled. Its allowlist and privacy filtering still apply. Disabling telemetry does not disable local session capture. Local panel contents should not be mistaken for the exact data uploaded to Sentry.

SwiftTUI runtime issues go through the host logger rather than a second bootstrap or a direct telemetry integration. Log redraw notifications are coalesced, and rendering the panel does not generate more logs. New browser logging does not add raw documentation bodies, credentials, or search-query text.

One-shot results remain on stdout. With `--verbose`, console diagnostics go to stderr instead of a session panel. Errors and incomplete-search warnings likewise stay off JSON stdout.

The host installs handlers only for resize and nonfatal shutdown signals. It does not replace Sentry's fatal-signal handlers. A browser command's telemetry lifetime ends after the session returns or fails.

See [Browsing](BROWSING.md) for panel interaction and [Architecture](ARCHITECTURE.md) for ownership boundaries.

### Breadcrumbs

A command invocation adds one breadcrumb to subsequent errors. Its message and category are fixed, and its data is restricted to the approved command context.

Automatic system and network breadcrumbs are disabled.

### Metrics

The CLI records:

- `apple_docs.technology.requested` to measure technology popularity.
- `apple_docs.type.requested` to measure type popularity within a technology.
- `apple_docs.response.size` to monitor Apple documentation response sizes.
- `apple_docs.technology.catalog.count` to monitor the size of the technology catalog.
- `apple_docs.type.catalog.count` to monitor direct type counts in technology root documents.
- `apple_docs.type.search.result.count` to monitor the number of search matches.

Metric names and attributes are allowlisted. Type and technology are the only variable popularity dimensions.

## What We Do Not Capture

The CLI does not intentionally send:

- Raw process arguments or type search queries.
- Environment variables.
- User identity or account information.
- IP addresses or geographic location.
- Hostnames or persistent device identifiers.
- Request or response headers.
- Cookies or authentication values.
- Query strings.
- Request or response bodies.
- Apple documentation page contents.
- Local file paths.
- Agent Skill names requested by the user.

Automatic network, file I/O, failed-request, and performance instrumentation is disabled. Command transactions are created manually so their data remains within the allowlist.

## Privacy Controls

Before transmission, the SDK:

- Disables default PII collection.
- Removes user, request, server, extra, and arbitrary tag data from error events.
- Restricts event contexts, breadcrumbs, logs, metrics, and spans.
- Reduces native frame and debug-image paths to filenames.
- Replaces error values with a generic message.

Sentry ingestion also prevents IP storage, applies default data scrubbing, and removes geographic information. These server-side controls are a backstop rather than a substitute for SDK-side filtering.

## Debug Symbols

Release builds upload matching dSYMs to Sentry so native stack traces can be symbolicated. Uploads run only for release builds, use an organization token stored in GitHub Actions secrets, and fail the release workflow if authentication or processing fails.

Source context is included because this repository is public. Auth tokens and other upload credentials must never be committed or printed.

## Disabling Telemetry

Set the environment variable before invoking the CLI:

```sh
TELEMETRY_DISABLED=true apple-docs types view String --technology Swift
```

The value `true` is matched case-insensitively. When disabled, Sentry is not initialized and SDK calls are skipped so command output remains unchanged.

## Adding Telemetry

Before adding a field or signal:

1. State the production question it answers.
2. Confirm that an existing error, trace, log, or metric does not already answer it.
3. Decide whether the value can contain personal, local, credential, or user-authored data.
4. Add only the minimum approved fields to the command context and relevant allowlists.
5. Verify enabled and disabled command output.
6. Trigger the signal and inspect the stored event for unexpected fields.

When uncertain whether a value is sensitive, do not capture it.
