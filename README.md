# OpenCode Harness

[![CI](https://github.com/tankdonut/opencode-harness/actions/workflows/ci.yml/badge.svg)](https://github.com/tankdonut/opencode-harness/actions/workflows/ci.yml)
[![Container](https://img.shields.io/badge/container-ghcr.io-blue)](https://github.com/tankdonut/opencode-harness/pkgs/container/opencode-harness)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A comprehensive harness for bootstrapping OpenCode environments with production-ready agents, skills, and commands. Includes containerized deployment for consistent, reproducible setups.

## Overview

OpenCode Harness bundles three powerful OpenCode plugin ecosystems as git submodules:

- **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** - 16 agents, 65 skills, 40 commands for production workflows
- **[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)** - Multi-agent orchestration system with 26 tools and 46 lifecycle hooks
- **[superpowers](https://github.com/obra/superpowers)** - Advanced workflow skills (TDD, debugging, git workflows)

This harness provides:

- ✅ Automated setup scripts for host and container environments
- ✅ Pre-configured OpenCode plugin wiring
- ✅ Containerized deployments (Podman/Docker)
- ✅ Comprehensive agent instructions via AGENTS.md
- ✅ Git submodule management for easy updates
- ✅ **CI/CD automation with container build, test, and validation**

## Quick Start

### Host Installation

```bash
git clone https://github.com/tankdonut/opencode-harness.git
cd opencode-harness
git submodule update --init --recursive
./setup.sh
```

### Container Usage

```bash
podman build -t opencode-harness -f Containerfile .
podman run -it --rm opencode-harness
```

### For AI Assistants / Agents

Copy and paste this prompt to your LLM agent (Claude Code, Cursor, etc.):

```
Install and configure OpenCode Harness by following the instructions here:
https://raw.githubusercontent.com/tankdonut/opencode-harness/main/docs/guide/installation.md
```

Or read the [Agent Installation Guide](docs/guide/installation.md) - specifically designed for AI assistants with context, role definitions, and technical instructions.

## Features

- **Reproducible Environments**: Container-based deployments ensure consistent setups across teams
- **Plugin Management**: Git submodules make updating and versioning plugins straightforward
- **Production Ready**: Battle-tested agents and skills from established OpenCode ecosystems
- **Security Focused**: Non-root containers, no secrets in images, minimal attack surface
- **Well Documented**: Comprehensive AGENTS.md files following GitHub best practices

## Installation

### Prerequisites

- **Git**: 2.34+
- **Node.js**: 12.22+ (includes npm)
- **Podman** or **Docker**: For container deployments (optional)
- **jq**: For JSON validation (optional but recommended)

### Host Setup

1. **Clone repository with submodules**:

   ```bash
   git clone --recurse-submodules https://github.com/tankdonut/opencode-harness.git
   cd opencode-harness
   ```

   Or if already cloned:

   ```bash
   git submodule update --init --recursive
   ```

2. **Run setup script**:

   ```bash
   ./setup.sh
   ```

   The script will:
   - Check prerequisites
   - Initialize git submodules
   - Validate `opencode.json`
   - Install OpenCode
   - Set up configuration

3. **Verify installation**:

   ```bash
   opencode --version
   ```

### Container Setup

Build the container image:

```bash
podman build -t opencode-harness -f Containerfile .
```

Or with Docker:

```bash
docker build -t opencode-harness -f Containerfile .
```

Run interactively:

```bash
podman run -it --rm opencode-harness
```

Mount a workspace:

```bash
podman run -it --rm -v $(pwd):/workspace opencode-harness
```

## Usage

### Host Environment

After running `setup.sh`, OpenCode is available globally:

```bash
opencode
```

### Container Environment

The container comes with OpenCode pre-configured:

```bash
podman run -it --rm opencode-harness opencode --version
```

For development work, mount your project directory:

```bash
podman run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  opencode-harness bash
```

## Configuration

### opencode.json

The main configuration file defines which plugins to load:

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

For plugin management and advanced configuration, see [DEVELOPMENT.md](DEVELOPMENT.md).

## Security

- **No secrets in containers**: API keys and credentials never committed or baked into images
- **Non-root user**: Containers run as `opencode` user (UID 1000)
- **Pinned versions**: All base images and packages use explicit versions
- **Minimal images**: Only essential dependencies installed
- **Vulnerability scanning**: Run `podman image scan` before releases

## Documentation

- **[CONTRIBUTING.md](CONTRIBUTING.md)** - How to contribute to this project
- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Development workflows, testing, and troubleshooting
- **[AGENTS.md](AGENTS.md)** - Agent instructions and project structure

## Resources

- [OpenCode Documentation](https://opencode.ai/docs)
- [Everything Claude Code](https://github.com/affaan-m/everything-claude-code)
- [Oh My OpenAgent](https://github.com/code-yeongyu/oh-my-openagent)
- [Superpowers](https://github.com/obra/superpowers)
- [Podman Documentation](https://docs.podman.io/)
- [Git Submodules Guide](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [GitHub AGENTS.md Best Practices](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/)

## License

This harness is provided as-is for bootstrapping OpenCode environments. Individual plugin modules are licensed under their respective licenses:

- **everything-claude-code**: See [LICENSE](modules/everything-claude-code/LICENSE)
- **oh-my-openagent**: See [LICENSE](modules/oh-my-openagent/LICENSE)
- **superpowers**: See [LICENSE](modules/superpowers/LICENSE)

## Support

For issues related to:

- **This harness**: Open an issue in this repository
- **Specific plugins**: Open issues in their respective repositories
- **OpenCode itself**: Check [OpenCode documentation](https://opencode.ai/docs)

---

**Remember**: This harness is about reproducibility and ease of setup. Every change should make it easier for teams to get a working OpenCode environment.
