# Testing and acceptance

Tests distinguish semantic application behavior, embedded terminal behavior, and actual release-process behavior. Passing one layer does not establish all others or prove support on an untested platform.

## Local verification

Use Swift 6.4 or later. Start with the narrowest relevant test suite, then run the repository checks:

```bash
make test
make analyze
make build
```

After Swift edits, run `make format` and rerun analysis. Behavior tests use explicit Arrange, Act, and Assert sections. Add focused failing tests before behavior changes. Tests should assert contracts and observable state rather than duplicate implementation details.

Unit tests are under `Tests/CLITests/`, mirroring the source domains. Important coverage includes:

- Output flags, flag order, independently redirected descriptors, and avoiding browser construction in one-shot dispatch.
- Normalized page/link/content fields, grouped references, human/agent parity, JSON shapes, and safe follow-up commands.
- Exact versus named paths, canonical roots, HTTP boundary validation, byte counts, cancellation, empty search results, and partial coverage.
- Lazy graph occurrences, duplicate references, ancestor cycles, branch retry, and no eager crawl to locate the current page.
- Successful-load-only history, forward-history replacement, scroll/link/focus restoration, and technology-specific retained state.
- Submitted search, retained query/results, independent focus scopes, cancellation, and stale-response rejection.
- Bounded hidden logs, verbosity, coalesced notifications, telemetry opt-out, and runtime-issue routing.

Renderer tests exercise public SwiftTUI frame and semantic geometry APIs, including duplicate labels, wrapped links, wide/combining characters, long declarations, code punctuation, control filtering, and narrow layouts. Exact colors are not acceptance criteria.

## Embedded terminal tests

`TerminalSessionTests` uses injected public `PresentationSurface`, `TerminalInputReading`, and `SignalReading` collaborators with the real runtime. Tests cover q/Ctrl+C, EOF, host-task cancellation, rendering failure, focus transitions, resize signals, background completion, and log redraws.

These tests prove runtime integration and balanced protocol cleanup, not actual OS terminal restoration. `TerminalSignalsTests` separately verifies signal delivery, restoration of previous handlers, and leaving fatal-signal handlers untouched. External opener tests assert validated URLs and exact process arguments without launching a browser.

## Release integration tests

Build and run the real executable against Apple's documentation service:

```bash
TELEMETRY_DISABLED=true make test-integration
```

This requires internet access. `APPLE_DOCS_EXECUTABLE` selects the built binary. Without it, integration suites are gated off during ordinary unit-test runs. One-shot subprocesses explicitly use noninteractive stdin and concurrently drain stdout/stderr to avoid pipe deadlocks.

The release suite verifies normalized page JSON, existing discovery-array keys, agent Markdown, combined agent JSON, dotted names, and verbose diagnostics staying off JSON stdout.

`TerminalBrowserIntegrationTests` uses a serialized PTY harness with bounded waits, a retained terminal descriptor, and before/after terminal snapshots. Current release PTY coverage verifies q/Ctrl+C, SIGINT/SIGTERM, normal/enhanced keyboard negotiation, resize/panel interactions, and restored termios and relevant POSIX file-status flags. Darwin's extra write-history bit is not a restorable file-status mode and is excluded from that comparison.

## Manual and broader terminal acceptance

Some behavior already has unit or embedded-runtime coverage but still needs broader native release acceptance. Exercise:

1. `MXHangDiagnostic → MetricKit → collection or type → member → Back`, without leaving the terminal.
2. Alt+Left/Right restoration of document position, selected link, tree selection/expansion, and main-pane focus, including cross-technology links.
3. `/` submission, result opening, and reopening the retained result set. Verify ordinary typing does not trigger printable global shortcuts.
4. Long-page scrolling and semantic link selection, including links that wrap across rows.
5. Navigator/log toggles and narrowing/widening the terminal without losing visibility preferences or focus.
6. Cancellation during navigation, error retry, and independent page/branch/search errors.
7. Asynchronous content and log updates without a keypress or console logs overwriting the display.
8. Each supported exit route and return to a usable terminal.

External browser activation is a deliberate manual action, not an automated test side effect. Do not upload test logs or screenshots as part of local verification.

## Output smoke checks

These are checks of the shipping binary, separate from renderer unit tests:

```bash
TELEMETRY_DISABLED=true dist/apple-docs types view MXHangDiagnostic --technology MetricKit --non-interactive
TELEMETRY_DISABLED=true dist/apple-docs types view MXHangDiagnostic --technology MetricKit --json
TELEMETRY_DISABLED=true dist/apple-docs types view MXHangDiagnostic --technology MetricKit --agent
TELEMETRY_DISABLED=true dist/apple-docs types view MXHangDiagnostic --technology MetricKit --agent --json
TELEMETRY_DISABLED=true dist/apple-docs types search Button --technology SwiftUI --agent --json
TELEMETRY_DISABLED=true dist/apple-docs technologies list --non-interactive
```

Run each command separately. Also verify descriptor selection independently from a terminal:

```bash
TELEMETRY_DISABLED=true dist/apple-docs types view String --technology Swift | cat
TELEMETRY_DISABLED=true dist/apple-docs types view String --technology Swift < /dev/null
```

The first retains terminal stdin but pipes stdout. The second redirects stdin while retaining terminal stdout. Both should print one-shot human text and return without entering the browser. Passing `--json` is not a substitute for these checks because that flag forces one-shot mode regardless of descriptors.

## Platform verification status

macOS unit tests, release builds, and the current live CLI/PTY suite have passed. That does not establish broader native navigation acceptance, runtime behavior on macOS 15 hardware, or Linux support.

The official `swift:6.4` image is now published for Linux amd64 and arm64. Container startup and `swift --version` have been verified on arm64 Linux. Application tests inside that image, native Linux PTY behavior, and both static Linux release artifacts remain unverified.

The Makefile and CI still select Swift 6.3.3 in their deferred paths. Updating those settings and verifying the official static SDK URL/checksum remain required before distribution acceptance. The release workflow's old `.metadata.title` JSON smoke assertion also needs migration to `.title`.

Before calling platform acceptance complete, run native Linux tests and terminal checks and build both `x86_64-swift-linux-musl` and `aarch64-swift-linux-musl` artifacts with the matching verified Swift 6.4 SDK. Preserve both architectures. Review dependency changes, working-tree diffs, and the documented contracts. Report unavailable checks explicitly rather than treating local macOS success as cross-platform proof.
