# Terminal browser

The documentation browser opens automatically when both stdin and stdout are terminals and no one-shot output flag is supplied. It lets you follow technologies, collections, types, and members without leaving the terminal.

For scripting and agent use, see [Output modes and JSON](OUTPUT.md). For implementation boundaries, see [Architecture](ARCHITECTURE.md).

## Start a session

```bash
apple-docs types view MXHangDiagnostic --technology MetricKit
apple-docs types list --technology MetricKit
apple-docs technologies list
apple-docs types search Button --technology SwiftUI
```

| Entry command       | Initial view                                                            |
| ------------------- | ----------------------------------------------------------------------- |
| `types view`        | Requested document, with its technology navigator loading independently |
| `types list`        | Selectable symbols linked from the requested technology root            |
| `technologies list` | Selectable technologies, without an implied current technology          |
| `types search`      | Technology-scoped search panel initialized with the supplied query      |

Required command arguments remain required. Every `types` command takes `--technology`. Cache commands, agent-skill commands, help, and version output never open the browser.

## Navigator and document

The normal layout places a navigator on the left and documentation on the right. Ctrl+B hides or restores the navigator without discarding its loaded branches, selection, or scroll position. Hiding a focused navigator transfers focus to the document.

The navigator preserves Apple's topic groups. A technology can contain collections or types, and a type can contain groups of members. Group-only rows expand without inventing a document destination. Expanding a document loads its topic children only when needed. Previously loaded pages are reused within the session.

The navigator represents a graph, not a unique or exhaustive hierarchy. The same page can occur under more than one group. Related links remain navigable without all becoming tree children. Apple's curated root pages are not complete API indexes.

A requested document does not wait for its technology tree. A **Current page** entry keeps it accessible while its position in the loaded tree is unknown. The browser does not crawl a technology to discover its parent. Once a real occurrence becomes known, the shortcut relocates to it.

Below 69 columns, the navigator is temporarily suppressed. Widening the terminal restores it if the user's visibility preference is still enabled. Hidden panes do not receive keyboard focus.

## Links and history

Supported Apple documentation links open inside the browser. Collections and members are ordinary destinations. Cross-technology links switch the technology context and navigator.

Alt+Left and Alt+Right move through history, restoring the document viewport, selected link, navigator snapshot, and main-pane focus. A new successful navigation after Back replaces the forward branch. Failed or cancelled navigation preserves the current page and forward history. Expanding a tree branch alone does not create a history entry.

History is not ancestry. The previously visited page need not be the current page's parent.

Select document links with `]` and `[`, then press Enter to activate. Link selection reveals the selected occurrence. Ordinary scrolling does not force the viewport back to that link.

External HTTP(S) links open in the system browser only when explicitly activated. The `o` shortcut opens the current page's canonical URL. Unsafe schemes are rejected, and launcher errors remain local to the session.

## Keyboard reference

| Context    | Key                  | Action                                        |
| ---------- | -------------------- | --------------------------------------------- |
| Navigator  | Up / Down            | Select a visible row                          |
| Navigator  | Right / Left         | Expand or collapse a branch                   |
| Navigator  | Enter                | Open a destination or expand a group-only row |
| Main panes | Tab                  | Switch between visible panes                  |
| Main panes | Ctrl+B               | Hide or restore the navigator                 |
| Document   | Up / Down            | Scroll one row                                |
| Document   | Page Up / Page Down  | Scroll approximately one viewport             |
| Document   | `]` / `[`            | Select and reveal the next or previous link   |
| Document   | Enter                | Activate the selected link                    |
| Browser    | Alt+Left / Alt+Right | Back / Forward                                |
| Browser    | `/`                  | Open search for the current technology        |
| Browser    | `o`                  | Open the current page in the system browser   |
| Browser    | `r`                  | Retry the relevant failed operation           |
| Browser    | Backtick             | Show or hide session logs                     |
| Browser    | `q` or Ctrl+C        | Exit the session                              |

Printable shortcuts, including `q`, `/`, backtick, `o`, `[` and `]`, are ordinary characters while editing the search input. Ctrl+C still exits. The footer shows shortcuts appropriate to the current focus.

Escape follows this priority:

1. Dismiss the active search panel and cancel its pending request.
2. Close focused logs and restore the preceding focus.
3. Cancel pending page navigation, keeping the displayed page.
4. Move document focus to the navigator if it is visible.
5. Otherwise do nothing.

Escape is not Back or Quit.

## Submitted search

Press `/` to search the current technology. Enter submits when the query field is focused. Tab switches between the query and results. Up/Down select a result, and Enter opens it when results have focus.

Typing does not issue requests. Dismissing a pending search cancels it. Cancelled or superseded responses cannot reopen the panel or replace newer results.

Opening a result closes the panel but preserves its query, results, selection, and coverage information. Reopening search restores these values without repeating the search. This state is retained separately for each technology during the session. The global technology catalog has no active search technology until one is selected.

Search matches symbol names or paths across the technology root and recursively linked collections. It is not full-text search and does not crawl every symbol page. No matches is a normal empty result. If collections could not be fetched, the panel reports incomplete coverage rather than claiming a complete search.

A `types search` session has an underlying technology location, so dismissing its initial search panel leaves a useful browser view. Opening a result participates in document history. Panel visibility itself does not.

## Loading, errors, and logs

Page loading, branch expansion, and search have independent loading and error states. A page failure retains the previous document. A branch failure affects that branch only. Search errors preserve the query. An initial-page failure still allows retry and exit. Cancellation is not displayed as an ordinary request error.

Backtick opens a bottom log panel and gives it focus. Closing it restores the preceding focus. Logs scroll independently of documentation and retain their reading position across updates unless already following the end.

The buffer retains at most 500 entries, dropping the oldest first. It captures warnings and errors normally, or debug-and-higher entries with `--verbose`, even while hidden. It has no disk persistence. Interactive diagnostics do not write over the display. See [Telemetry](TELEMETRY.md) for the separate upload policy and opt-out.

## Session lifetime and limitations

History, expanded branches, search results, focus, and selected technology exist only in the current session. The CLI does not persist browsing history, bookmarks, or a technology default. HTTP response caching is separate and may survive between commands.

Exiting cancels owned work and returns control to the host. Normal exit, handled interruption, and handled errors restore terminal state. Cleanup cannot be guaranteed after uncatchable process termination.

Documentation is treated as untrusted text. Terminal control sequences are filtered, and link destinations are validated before navigation or external opening.

For what has been tested and the remaining acceptance work, see [Testing](TESTING.md).
