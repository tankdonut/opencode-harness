# OpenCode Harness - Agent Installation Guide

This guide is specifically for AI assistants and agents who need to understand and install OpenCode Harness.

## What is OpenCode Harness?

OpenCode Harness is a comprehensive bootstrap environment that bundles three powerful OpenCode plugin ecosystems:

- **everything-claude-code** (16 agents, 65 skills, 40 commands)
- **oh-my-openagent** (Multi-agent orchestration with 26 tools, 46 hooks)
- **superpowers** (Advanced workflow skills: TDD, debugging, git workflows)

## Quick Agent Context

```text
Project: OpenCode Harness
Purpose: Containerized bootstrap for OpenCode with production-ready plugins
Tech Stack: Bash, Docker/Podman, Git submodules, OpenCode JSON config
Agent Role: OpenCode Harness Engineer
```

## Installation Options

### Option 1: Container Usage (Recommended)

**For immediate testing or isolated environments:**

```bash
# Pull pre-built container
podman pull ghcr.io/tankdonut/opencode-harness:latest
podman run -it --rm ghcr.io/tankdonut/opencode-harness:latest

# Or with Docker
docker pull ghcr.io/tankdonut/opencode-harness:latest
docker run -it --rm ghcr.io/tankdonut/opencode-harness:latest

# Mount workspace for development
podman run -it --rm -v $(pwd):/workspace -w /workspace ghcr.io/tankdonut/opencode-harness:latest
```

### Option 2: Host Installation

**For permanent setup or development:**

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/tankdonut/opencode-harness.git
cd opencode-harness

# Run setup script
./setup.sh

# Verify installation
opencode --version
```

### Option 3: Build from Source

**For customization or development:**

```bash
# Clone and initialize
git clone https://github.com/tankdonut/opencode-harness.git
cd opencode-harness
git submodule update --init --recursive

# Build container
./scripts/build.sh

# Test container
podman run -it --rm opencode-harness bash -c "opencode --version && echo 'Success!'"
```

## Key Files and Structure

```text
opencode-harness/
├── setup.sh                   # Host installation script
├── Containerfile              # Container build definition
├── opencode.json              # Plugin configuration
├── modules/                   # Git submodules
│   ├── everything-claude-code/
│   ├── oh-my-openagent/
│   └── superpowers/
├── scripts/
│   ├── validate.sh            # Pre-build validation
│   └── container-test.sh      # Container verification
├── AGENTS.md                  # Detailed agent instructions
├── DEVELOPMENT.md             # Development workflows
└── CONTRIBUTING.md            # Contribution guidelines
```

## Configuration

**Main config file:** `opencode.json`

```json
{
    "$schema": "https://opencode.ai/config.json",
    "plugin": [
        "@tarquinen/opencode-dcp@latest",
        "cc-safety-net",
        "ecc-universal",
        "oh-my-opencode"
    ]
}
```

**Container-specific config:** `etc/opencode/opencode.jsonc`

## Agent Instructions Context

When working with this project, you should understand:

### Your Role

- **OpenCode Harness Engineer** specializing in:
  - Configuration management
  - Container engineering
  - Git submodule management
  - Bootstrap automation

### Key Responsibilities

- Setting up reproducible OpenCode environments
- Managing plugin dependencies as submodules
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
FROM docker.io/library/ubuntu:24.04

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

### Submodules Not Initialized

```bash
git submodule update --init --recursive
```

### Container Build Fails

```bash
# Check base images are accessible
podman pull ghcr.io/tankdonut/tools:latest
```

### JSON Validation Errors

```bash
jq . opencode.json  # Validate syntax
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
./scripts/build.sh --no-cache --tag opencode-harness-test
./scripts/container-test.sh opencode-harness-test
podman image scan opencode-harness-test
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

**Remember:** This harness is about reproducibility and ease of setup. Every change should make it easier for teams to get a working OpenCode environment.
