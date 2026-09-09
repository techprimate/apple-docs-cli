# apple-docs-cli

`apple-docs-cli` is a stateless macOS CLI for retrieving Apple Developer documentation for known API types. It fetches Apple’s DocC JSON and renders a concise terminal view or returns the raw document for further processing.

## Type documentation

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

Every invocation requires `--technology`. The CLI does not persist a selected framework or other session state.
Nested symbols accept either dotted Swift spelling or slash-separated DocC paths:

```bash
apple-docs types view URLSession.AsyncBytes --technology Foundation
apple-docs types view URLSession/AsyncBytes --technology Foundation
```

## Type discovery

List the API symbols referenced directly by a technology's root DocC page:

```bash
apple-docs types list --technology MetricKit
apple-docs types list --technology MetricKit --json
```

Each result includes the symbol name, kind, command-ready DocC path, and canonical Apple Developer URL. Apple's root pages are curated, so large frameworks may link to collection pages instead of listing every API directly.

Search a technology's root page and recursively linked collection groups by symbol name or path:

```bash
apple-docs types search Button --technology SwiftUI
apple-docs types search Button --technology SwiftUI --json
```

Search deliberately does not crawl individual symbol pages, which keeps requests bounded. Collection pages can directly reference some nested members, so those may appear, but search is not an exhaustive nested-member index.

## Technologies

List the technologies in Apple’s documentation catalog:

```bash
apple-docs technologies list
```

The default output is a two-column table containing each technology’s display name and full documentation identifier. Use `--json` to return the same sorted catalog as an array of `name` and `identifier` objects:

```bash
apple-docs technologies list --json
```

## Raw DocC JSON

Use `--json` to print Apple’s upstream DocC document unchanged:

```bash
apple-docs types view MXHangDiagnostic --technology MetricKit --json
```

For example, extract the documented title with `jq`:

```bash
apple-docs types view MXHangDiagnostic --technology MetricKit --json \
  | jq -r '.metadata.title'
```

## Agent Skills

The executable includes task-specific guidance for coding agents. The root help points agents to the bundled catalog:

```bash
apple-docs agent skills list
```

Print the bundled skill without installing files:

```bash
apple-docs agent skills get apple-docs
```

## Development

Install dprint, the pre-commit hooks, and SwiftLint, then resolve SwiftPM dependencies:

```bash
make init
```

Run tests and quality checks:

```bash
make test
make analyze
```

Format Swift with `swift format` and JSON, YAML, Markdown, and TOML with dprint:

```bash
make format
```

Build the standalone release binary at `dist/apple-docs`:

```bash
make build
```

During development, invoke the executable through SwiftPM:

```bash
make run ARGS="types view MXHangDiagnostic --technology MetricKit"
```

Run `make help` to see all available development commands.
