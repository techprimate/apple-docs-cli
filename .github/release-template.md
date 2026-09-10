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

#### Linux (DNF/YUM)

```bash
sudo dnf config-manager --add-repo https://packages.techprimate.app/techprimate.repo
sudo dnf install apple-docs
```

#### Linux (APT)

```bash
sudo curl -fsSL https://packages.techprimate.app/RPM-GPG-KEY-techprimate \
  | sudo gpg --dearmor -o /usr/share/keyrings/techprimate-archive-keyring.gpg
sudo curl -fsSL https://packages.techprimate.app/techprimate.sources \
  -o /etc/apt/sources.list.d/techprimate.sources
sudo apt update
sudo apt install apple-docs
```

#### Linux (Manual)

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
