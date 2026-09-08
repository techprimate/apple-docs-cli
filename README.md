# apple-docs

`apple-docs` is a stateless macOS CLI for retrieving Apple Developer documentation for known API types. It fetches Apple’s DocC JSON and renders a concise terminal view or returns the raw document for further processing.

## Type documentation

Pass the exact type and technology names:

```bash
apple-docs type MXHangDiagnostic --technology MetricKit
```

The terminal output includes available information such as:

- Summary and declaration
- Platform availability and deprecation
- Inheritance and protocol conformances
- Documented members and related APIs
- Canonical Apple Developer URL

Every invocation requires `--technology`. The CLI does not persist a selected framework or other session state.

## Raw DocC JSON

Use `--json` to print Apple’s upstream DocC document unchanged:

```bash
apple-docs type MXHangDiagnostic --technology MetricKit --json
```

For example, extract the documented title with `jq`:

```bash
apple-docs type MXHangDiagnostic --technology MetricKit --json \
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

Install SwiftLint and resolve SwiftPM dependencies:

```bash
make init
```

Run tests and quality checks:

```bash
make test
make analyze
```

Format project-owned Swift files with `swift format`:

```bash
make format
```

Build the standalone release binary at `dist/apple-docs`:

```bash
make build
```

During development, invoke the executable through SwiftPM:

```bash
make run ARGS="type MXHangDiagnostic --technology MetricKit"
```

Run `make help` to see all available development commands.
