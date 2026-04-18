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

- **Bootstrap automation** - Setup scripts and containerized environments
- **Plugin ecosystem** - Pre-wired access to 3 major OpenCode plugin collections
- **Agent-ready documentation** - Comprehensive guides designed for AI assistants
- **Git submodule management** - Easy plugin updates and version control

## Quick Start

### For AI Assistants / Agents

Copy and paste this prompt to your LLM agent (Claude Code, Cursor, etc.):

```text
Install and configure OpenCode Harness by following the instructions here:
https://raw.githubusercontent.com/tankdonut/opencode-harness/main/docs/guides/installation.md
```

Or read the [Agent Installation Guide](docs/guides/installation.md) - specifically designed for AI assistants with context, role definitions, and technical instructions.

## Documentation

### Getting Started

- **[Agent Installation Guide](docs/guides/installation.md)** - For AI assistants/agents (includes role definitions and context)
- **[Detailed Installation Guide](docs/guides/installation-detailed.md)** - Comprehensive installation for all platforms and use cases
- **[Usage Guide](docs/guides/usage.md)** - How to use OpenCode Harness in different environments
- **[Configuration Guide](docs/guides/configuration.md)** - Complete configuration reference

### Development & Contributing

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

- **everything-claude-code**: See [LICENSE](build/modules/everything-claude-code/LICENSE)
- **oh-my-openagent**: See [LICENSE](build/modules/oh-my-openagent/LICENSE)
- **superpowers**: See [LICENSE](build/modules/superpowers/LICENSE)

## Support

For issues related to:

- **This harness**: Open an issue in this repository
- **Specific plugins**: Open issues in their respective repositories
- **OpenCode itself**: Check [OpenCode documentation](https://opencode.ai/docs)

---

**Remember**: This harness is about reproducibility and ease of setup. Every change should make it easier for teams to get a working OpenCode environment.
