# Repository Instructions

## Scope

- This is a Swift 6.3 command-line package targeting macOS 13 or later.
- Use SwiftPM for dependencies and the Makefile for standard development workflows.
- Keep the CLI stateless. Commands must receive the technology they operate on.
- Do not add or update dependencies unless the requested change requires it.

## Structure

- Keep the executable entry point and composition root in `Sources/CLI/main/`.
- Put commands under `Sources/CLI/cmd/` and reusable implementation code in its matching domain directory.
- Mirror source hierarchy for behavior tests under `Tests/CLITests/`.
- Keep bundled Agent Skills compiled into `Sources/CLI/skills/BundledAgentSkills.swift`. Do not introduce SwiftPM resource bundles for them.

## Architecture

- Follow the compilation-optimized abstraction pattern used by Sentry Cocoa.
- In debug builds, expose protocols for injecting test doubles.
- In release builds, alias those abstractions to concrete default implementations.
- Use a gated `Dependencies` constraint when a default implementation needs injectable collaborators.
- Keep `TypesViewCommandRunner` focused on orchestration. HTTP access and output rendering belong behind their respective abstractions.
- Validate HTTP status and response types at the external boundary.
- Preserve Apple’s response bytes unchanged for `--json` output.

## Workflow

- For behavior changes and bug fixes, add a focused failing test before changing production code.
- Structure tests with explicit `// -- Arrange --`, `// -- Act --`, and `// -- Assert --` sections.
- Keep changes scoped and avoid unrelated refactoring.
- Do not commit or push unless explicitly requested.

## Verification

Run the narrowest relevant tests first, then before completion run:

```bash
make test
make analyze
make build
```

Run `make format` after Swift edits, then rerun `make analyze`. For command-facing changes, also exercise the affected release command directly.
