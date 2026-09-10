## apple-docs v{{VERSION}}

### Installation

#### macOS (Homebrew)

```bash
brew install techprimate/tap/apple-docs
```

#### macOS (Apple Silicon)

```bash
curl -L -o apple-docs https://github.com/{{REPOSITORY}}/releases/download/v{{VERSION}}/apple-docs-darwin-arm64
chmod +x apple-docs
sudo mv apple-docs /usr/local/bin/
```

#### macOS (Intel)

```bash
curl -L -o apple-docs https://github.com/{{REPOSITORY}}/releases/download/v{{VERSION}}/apple-docs-darwin-amd64
chmod +x apple-docs
sudo mv apple-docs /usr/local/bin/
```

#### Linux

```bash
# AMD64
curl -L -o apple-docs https://github.com/{{REPOSITORY}}/releases/download/v{{VERSION}}/apple-docs-linux-amd64
chmod +x apple-docs
sudo mv apple-docs /usr/local/bin/

# ARM64
curl -L -o apple-docs https://github.com/{{REPOSITORY}}/releases/download/v{{VERSION}}/apple-docs-linux-arm64
chmod +x apple-docs
sudo mv apple-docs /usr/local/bin/
```

See the [README](https://github.com/{{REPOSITORY}}/blob/main/README.md) for more details.

### Checksums

See `checksums.txt` for SHA256 checksums of all binaries.
