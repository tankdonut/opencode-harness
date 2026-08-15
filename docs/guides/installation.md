# opencoder - Agent Installation Guide

This guide is specifically for AI assistants and agents who need to understand and install opencoder.

## What is opencoder?

opencoder is a comprehensive bootstrap environment that bundles OpenCode plugin ecosystems via the skills.sh CLI:

- **oh-my-openagent** (Multi-agent orchestration with 26 tools, 46 hooks) - installed at build time
- **everything-claude-code** (16 agents, 65 skills, 40 commands) - opt-in at runtime
- **superpowers** (Advanced workflow skills: TDD, debugging, git workflows) - opt-in at runtime

## Quick Agent Context

```text
Project: opencoder
Purpose: Containerized bootstrap for OpenCode with production-ready plugins
Tech Stack: Bash, Docker/Podman, skills.sh CLI, OpenCode JSON config
Agent Role: opencoder Engineer
```

## Installation Options

### Option 1: Container Usage (Recommended)

**For immediate testing or isolated environments:**

```bash
# Pull pre-built container
podman pull ghcr.io/tankdonut/opencoder:latest
podman run -it --rm ghcr.io/tankdonut/opencoder:latest

# Or with Docker
docker pull ghcr.io/tankdonut/opencoder:latest
docker run -it --rm ghcr.io/tankdonut/opencoder:latest

# Mount workspace for development
podman run -it --rm -v $(pwd):/workspace -w /workspace ghcr.io/tankdonut/opencoder:latest
```

### Option 2: Host Installation

**For permanent setup or development:**

```bash
# Clone the repository
git clone https://github.com/tankdonut/opencoder.git
cd opencoder

# Run setup script
./scripts/local-setup.sh

# Verify installation
opencode --version
```

### Option 3: Build from Source

**For customization or development:**

```bash
# Clone the repository
git clone https://github.com/tankdonut/opencoder.git
cd opencoder

# Build container
./scripts/build.sh

# Test container
podman run -it --rm opencoder bash -c "opencode --version && echo 'Success!'"
```

## Key Files and Structure

```text
opencoder/
├── build/                     # Container build files
│   ├── Containerfile          # Container build definition
│   ├── entrypoint.py          # Container entrypoint
│   ├── .opencode-version      # OpenCode version pin
│   ├── .opencode-checksums    # SHA256 checksums
│   ├── .opencode/             # OpenCode configuration
│   ├── etc/                   # System config files
│   └── skills-lock.json       # skills.sh lockfile (oh-my-openagent baseline)
├── .pre-commit-config.yaml   # Pre-commit hooks
├── scripts/
│   ├── local-setup.sh         # Host installation script
│   ├── validate.sh            # Pre-build validation
│   ├── container-test.sh      # Container verification
│   └── bump-version.sh        # Version bumper
├── AGENTS.md                  # Detailed agent instructions
├── DEVELOPMENT.md             # Development workflows
└── CONTRIBUTING.md            # Contribution guidelines
```

## Configuration

**Main config file:** `build/.opencode/opencode.json`

```json
{
    "$schema": "https://opencode.ai/config.json",
    "plugin": [
        "@tarquinen/opencode-dcp@3.1.13",
        "cc-safety-net@1.0.6",
        "oh-my-openagent@4.12.0"
    ]
}
```

**Container-specific config:** `build/etc/opencode/opencode.jsonc`

## Agent Instructions Context

When working with this project, you should understand:

### Your Role

- **opencoder Engineer** specializing in:
  - Configuration management
  - Container engineering
  - Skills distribution via skills.sh CLI
  - Bootstrap automation

### Key Responsibilities

- Setting up reproducible OpenCode environments
- Managing plugins (npm) and skills (skills.sh CLI)
- Building and testing containerized deployments
- Writing reliable setup scripts for multi-platform environments

### Code Style & Conventions

**Shell Scripts:**

```bash
#!/usr/bin/env bash
set -euo pipefail  # Always use strict error handling

function install_plugin() {
    local plugin_name="$1"
    # Implementation
}
```

**Container Builds:**

```dockerfile
# Always pin versions, never use 'latest'
FROM docker.io/library/ubuntu:26.04

# Multi-stage builds for efficiency
COPY --from=builder /dist/ /vendor/bin/

# Run as non-root user
USER opencode
```

## Validation Commands

**Before making changes:**

```bash
# Validate configuration
./scripts/validate.sh

# Test container build
./scripts/build.sh --no-cache --tag test

# Run test suite
./scripts/container-test.sh test
```

## Troubleshooting Common Issues

### Container Build Fails

```bash
# Check base images are accessible
podman pull ghcr.io/tankdonut/tools
```

### JSON Validation Errors

```bash
jq . build/.opencode/opencode.json  # Validate syntax
```

### Permission Errors

```bash
# Container runs as UID 1000 (opencode user)
chown -R 1000:1000 /path/to/workspace
```

## Testing Your Changes

```bash
# Full validation workflow
./scripts/validate.sh
./scripts/build.sh --no-cache --tag opencoder-test
./scripts/container-test.sh opencoder-test
podman image scan opencoder-test
```

## Next Steps

After installation:

1. **Read AGENTS.md** - Detailed technical instructions
2. **Review DEVELOPMENT.md** - Development workflows and troubleshooting
3. **Check CONTRIBUTING.md** - If you plan to contribute

## Agent-Specific Notes

- **Always use error handling** in shell scripts (`set -euo pipefail`)
- **Pin all versions** - no `latest` tags in production
- **Test before committing** - build and validate changes
- **Follow existing patterns** - this codebase is disciplined and consistent
- **Security first** - no secrets in containers, run as non-root

---

**Remember:** opencoder is about reproducibility and ease of setup. Every change should make it easier for teams to get a working OpenCode environment.
