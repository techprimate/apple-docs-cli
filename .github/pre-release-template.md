## Latest Development Build

**This is a pre-release build from the latest `main` branch.**

- **Commit**: {{COMMIT_SHA}}
- **Built**: {{BUILD_DATE}}
- **Version**: {{VERSION}}

**Warning**: This is an unstable development build. For production use, download a stable release instead.

### Installation

#### macOS (Apple Silicon)

```bash
curl -L -o apple-docs https://github.com/{{REPOSITORY}}/releases/download/latest/apple-docs-darwin-arm64
chmod +x apple-docs
sudo mv apple-docs /usr/local/bin/
```

#### macOS (Intel)

```bash
curl -L -o apple-docs https://github.com/{{REPOSITORY}}/releases/download/latest/apple-docs-darwin-amd64
chmod +x apple-docs
sudo mv apple-docs /usr/local/bin/
```

### What's New?

See the [commit history](https://github.com/{{REPOSITORY}}/commits/main) for recent changes.

### Checksums

See `checksums.txt` for SHA256 checksums of both binaries.
