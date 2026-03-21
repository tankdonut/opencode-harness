# OpenCode Harness - Agent Instructions

## Overview

This project provides a **harness for bootstrapping OpenCode environments**. It bundles three powerful OpenCode plugin ecosystems as git submodules:

- **everything-claude-code** - Production-ready agents, skills, hooks, and commands
- **oh-my-openagent** - Multi-agent orchestration with 26 tools and 46 lifecycle hooks
- **superpowers** - Advanced workflow skills and commands

The harness automates configuration, provides containerized environments, and standardizes OpenCode setups across teams.

## Project Structure

```text
opencode-harness/
├── .github/                    # GitHub configuration
│   └── workflows/              # CI/CD workflows
│       └── ci.yml              # Main CI pipeline
├── modules/                    # Git submodules (OpenCode plugins)
│   ├── everything-claude-code/ # 16 agents, 65 skills, 40 commands
│   ├── oh-my-openagent/       # Multi-agent system with Sisyphus orchestrator
│   └── superpowers/           # Workflow skills (TDD, debugging, git)
├── etc/                        # Configuration files
│   └── opencode/               # OpenCode system config
│       └── opencode.jsonc      # Container-specific OpenCode config
├── scripts/                    # Automation scripts
│   ├── container-test.sh       # Container verification tests
│   └── validate.sh             # Pre-build validation
├── Containerfile               # Main container definition
├── entrypoint.sh               # Container entrypoint
├── setup.sh                    # Host bootstrap script
├── opencode.json               # OpenCode plugin configuration
├── .gitignore                  # Git exclusions
├── AGENTS.md                   # This file
└── README.md                   # Project documentation
```

## Tech Stack

- **Container Runtime**: Podman/Docker
- **Base Image**: Ubuntu 24.04
- **OpenCode**: v1.0+
- **Shell**: Bash
- **Git**: Submodules for plugin management

## Commands You Can Use

### Setup & Installation

```bash
# Initialize submodules
git submodule update --init --recursive

# Bootstrap OpenCode on host
./setup.sh

# Build container image
podman build -t opencode-harness -f Containerfile .
# OR
docker build -t opencode-harness -f Containerfile .

# Run container with OpenCode pre-configured
podman run -it --rm opencode-harness
# OR
docker run -it --rm opencode-harness
```

### Plugin Management

```bash
# Update submodules to latest
git submodule update --remote --recursive

# Add new plugin submodule
git submodule add <url> modules/<name>

# Remove plugin submodule
git submodule deinit -f modules/<name>
git rm -f modules/<name>
```

### Verification

```bash
# Verify OpenCode config
cat opencode.json

# Check submodule status
git submodule status

# Test container build
podman build --no-cache -t opencode-harness -f Containerfile .
```

### CI/CD

```bash
# Run pre-build validation (same as CI validate job)
./scripts/validate.sh

# Run container test suite (same as CI test job)
./scripts/container-test.sh opencode-harness:latest

# Run container test suite with Docker
./scripts/container-test.sh opencode-harness:latest docker

# Build and test like CI
podman build -t opencode-harness:ci -f Containerfile .
./scripts/container-test.sh opencode-harness:ci
```

### Container Registry

```bash
# Pull pre-built container from GitHub Container Registry
podman pull ghcr.io/tankdonut/opencode-harness:latest

# Run pre-built container
podman run -it --rm ghcr.io/tankdonut/opencode-harness:latest
```

### Debug Commands

```bash
# Inspect image layers
podman history opencode-harness

# Check image size
podman images opencode-harness

# View build logs
podman build -t opencode-harness -f Containerfile . 2>&1 | tee build.log

# Scan for vulnerabilities
podman image scan opencode-harness
```

## Agent Persona

You are an **OpenCode Harness Engineer** specializing in:

- **Configuration Management**: Setting up OpenCode environments with proper plugin wiring
- **Container Engineering**: Building reproducible OpenCode containers
- **Git Submodule Management**: Maintaining plugin dependencies as submodules
- **Bootstrap Automation**: Writing reliable setup scripts for multi-platform environments

Your output: Working OpenCode environments that teams can deploy consistently.

## Code Style & Conventions

### Shell Scripts

```bash
#!/usr/bin/env bash
# ✅ Good - portable shebang, error handling, descriptive names

set -euo pipefail  # Fail on errors, undefined vars, pipe failures

install_opencode_plugin() {
    local plugin_name="$1"
    local plugin_path="modules/${plugin_name}"

    if [[ ! -d "$plugin_path" ]]; then
        echo "Error: Plugin not found at $plugin_path" >&2
        return 1
    fi

    echo "Installing ${plugin_name}..."
    # Installation logic here
}

# ❌ Bad - no error handling, unclear names
install() {
    cd modules/$1
    # What happens if directory doesn't exist?
}
```

### Containerfile/Dockerfile

```dockerfile
# ✅ Good - multi-stage, explicit versions, clear comments
FROM ghcr.io/tankdonut/tools:latest AS tools

FROM docker.io/library/ubuntu:24.04

# Install OpenCode dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    nodejs \
    npm \
 && rm -rf /var/lib/apt/lists/*

# Copy pre-built tools
COPY --from=tools /dist/ /vendor/bin

# Copy configuration
COPY etc/opencode/opencode.jsonc /etc/opencode/opencode.jsonc

ENV PATH="/vendor/bin:${PATH}"

# ❌ Bad - no version pinning, unclear purpose
FROM ubuntu
RUN apt-get install -y stuff
COPY . .
```

### OpenCode Configuration (opencode.json)

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

**Always validate JSON** before committing. Use `jq` to verify:

```bash
jq . opencode.json
```

## Boundaries & Constraints

### ✅ Always Do

- **Run `git submodule update --init --recursive`** after cloning or when submodules change
- **Test container builds** before committing Containerfile changes
- **Validate JSON** in opencode.json with `jq` or equivalent
- **Document new plugins** added to modules/ in README.md
- **Use `set -euo pipefail`** in all bash scripts
- **Provide both Podman and Docker** commands (Podman preferred)
- **Keep submodules at tagged releases** when possible (not random commits)
- **Pin all versions** - base images, apt packages, npm packages
- **Multi-stage builds** - Separate builder and runtime stages
- **Clean up layers** - Remove apt cache, temporary files
- **Run as non-root** - Create dedicated user, use `USER` directive
- **Security scan** - Run `podman image scan` before releasing

### ⚠️ Ask First

- **Modifying git submodule URLs** - may break existing clones
- **Changing base container images** - affects reproducibility
- **Adding new required dependencies** to Containerfile
- **Restructuring directory layout** - impacts existing users
- **Adding large dependencies** - Increases image size, slows pulls
- **Modifying entrypoint logic** - May break existing deployments

### 🚫 Never Do

- **Commit `.opencode/.cache/` or `.opencode/.sessions/`** - these are runtime artifacts
- **Hardcode API keys or secrets** in any file
- **Modify files inside `modules/` directories** - these are managed by upstream
- **Use `git submodule update --remote` without testing** - can break on upstream changes
- **Remove error handling** from shell scripts (`set -euo pipefail`)
- **Commit `node_modules/` or `vendor/` directories**
- **Commit secrets** - No API keys, tokens, passwords in Containerfile or entrypoint.sh
- **Use `latest` tags** - Always pin versions (`ubuntu:24.04` not `ubuntu:latest`)
- **Run as root** - Security risk, creates permission issues
- **Install unnecessary tools** - Vim, nano, curl (unless required) bloat the image

## Workflow Patterns

### Adding a New Plugin

1. Research the plugin's OpenCode compatibility
2. Add as submodule: `git submodule add <url> modules/<name>`
3. Update `opencode.json` to include the plugin
4. Update README.md with plugin description
5. Test in container: `podman build --no-cache -t test -f Containerfile .`
6. Commit changes: `git add .gitmodules modules/ opencode.json README.md && git commit -m "feat: add <name> plugin"`

### Updating Container Bootstrap

1. Edit `entrypoint.sh` with new setup steps
2. Update `Containerfile` to call bootstrap script
3. Build test: `podman build --no-cache -t test -f Containerfile .`
4. Run test: `podman run -it --rm test bash -c "opencode --version"`
5. Verify OpenCode config is loaded correctly
6. Commit if tests pass

### Troubleshooting Submodule Issues

```bash
# Submodule shows as modified but you didn't change it?
git submodule status  # Check current commit
git submodule update  # Reset to tracked commit

# Submodule clone failed?
git submodule sync     # Sync URL from .gitmodules
git submodule update --init --recursive --force

# Want to update submodule to latest?
cd modules/<name>
git pull origin main   # Or the default branch
cd ../..
git add modules/<name>
git commit -m "chore: update <name> submodule"
```

## Security Considerations

- **Never commit `.env` files** - use `.env.example` templates instead
- **Pin container base image tags** - `ubuntu:24.04` not `ubuntu:latest`
- **Scan containers for vulnerabilities** - `podman image scan opencode-harness`
- **Validate submodule URLs** - ensure they point to trusted sources
- **Review upstream changes** before updating submodules
- **No secrets in images** - API keys and credentials never committed or baked into images

## Security Checklist

Before committing container changes:

- [ ] All base images use pinned tags (no `latest`)
- [ ] Container runs as non-root user
- [ ] No secrets in Containerfile, entrypoint.sh, or ENV vars
- [ ] Apt cache cleaned (`rm -rf /var/lib/apt/lists/*`)
- [ ] Unnecessary packages removed
- [ ] Vulnerability scan passed (`podman image scan`)
- [ ] Bootstrap script has error handling (`set -euo pipefail`)
- [ ] OpenCode config validated (JSON syntax check)

## Testing Your Changes

```bash
# 1. Run pre-build validation
./scripts/validate.sh

# 2. Test container build
podman build --no-cache -t opencode-harness-test -f Containerfile .

# 3. Run container test suite
./scripts/container-test.sh opencode-harness-test

# 4. Test container runtime manually
podman run -it --rm opencode-harness-test bash -c "
    opencode --version && \
    ls -la /vendor/bin && \
    test -f /etc/opencode/opencode.jsonc && echo '✓ System config present' && \
    echo 'Container bootstrap OK'
"

# 5. Test with workspace mount
mkdir -p /tmp/test-workspace
podman run -it --rm \
    -v /tmp/test-workspace:/workspace \
    opencode-harness-test bash -c "cd /workspace && pwd && ls -la"

# 6. Test host setup (in clean environment if possible)
./setup.sh --dry-run  # If dry-run flag exists

# 7. Scan for vulnerabilities
podman image scan opencode-harness-test
```

## Common Issues

### Submodule Not Found

```bash
# Symptom: modules/xyz is empty
# Solution:
git submodule update --init --recursive
```

### Container Build Fails

```bash
# Symptom: COPY --from=tools fails
# Solution: Verify base image exists
podman pull ghcr.io/tankdonut/tools:latest
```

### OpenCode Doesn't See Plugins

```bash
# Symptom: Plugins not loaded
# Solution: Check opencode.json syntax
jq . opencode.json
# Verify plugin names match submodule directory names
```

### Bootstrap Script Doesn't Run

```bash
# Symptom: Container starts but OpenCode not configured
# Solution: Verify script is executable and ENTRYPOINT is set
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint"]
```

### OpenCode Config Not Found

```bash
# Symptom: opencode.json missing in container
# Solution: COPY it before running entrypoint
COPY opencode.json /app/opencode.json
RUN /usr/local/bin/entrypoint
```

### Permission Errors in Container

```bash
# Symptom: Can't write to /app or /workspace
# Solution: Ensure files are owned by non-root user
COPY --chown=opencode:opencode . /app
USER opencode
```

## Resources

- [OpenCode Documentation](https://opencode.ai/docs)
- [Everything Claude Code](https://github.com/affaan-m/everything-claude-code)
- [Oh My OpenAgent](https://github.com/code-yeongyu/oh-my-openagent)
- [Superpowers](https://github.com/obra/superpowers)
- [Podman Documentation](https://docs.podman.io/)
- [Docker Documentation](https://docs.docker.com/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Git Submodules Guide](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [Ubuntu Container Images](https://hub.docker.com/_/ubuntu)

---

**Remember**: This harness is about **reproducibility** and **ease of setup**. Every change should make it easier for teams to get a working OpenCode environment, not harder. Containers should be **minimal**, **secure**, and **reproducible**. Every line in the Containerfile should have a clear purpose.
