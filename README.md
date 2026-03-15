# OpenCode Harness

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

## Features

- **Reproducible Environments**: Container-based deployments ensure consistent setups across teams
- **Plugin Management**: Git submodules make updating and versioning plugins straightforward
- **Production Ready**: Battle-tested agents and skills from established OpenCode ecosystems
- **Security Focused**: Non-root containers, no secrets in images, minimal attack surface
- **Well Documented**: Comprehensive AGENTS.md files following GitHub best practices

## Project Structure

```
opencode-harness/
├── modules/                    # Git submodules (OpenCode plugins)
│   ├── everything-claude-code/ # Production agents, skills, commands
│   ├── oh-my-openagent/       # Multi-agent orchestration
│   └── superpowers/           # Workflow skills
├── docker/                    # Container configuration
│   ├── Containerfile          # Image definition
│   ├── AGENTS.md             # Container-specific instructions
│   └── entrypoint.sh         # Container entrypoint
├── setup.sh                   # Host bootstrap script
├── opencode.json             # Plugin configuration
├── AGENTS.md                 # Agent instructions
├── .gitignore                # Git exclusions
└── README.md                 # This file
```

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

### Adding Plugins

1. Add plugin as git submodule:
   ```bash
   git submodule add <plugin-url> modules/<plugin-name>
   ```

2. Update `opencode.json`:
   ```json
   {
       "plugin": [
           "existing-plugin",
           "new-plugin"
       ]
   }
   ```

3. Test in container:
   ```bash
   podman build --no-cache -t opencode-harness -f Containerfile .
   ```

### Updating Plugins

Update all submodules to latest:

```bash
git submodule update --remote --recursive
git add modules/
git commit -m "chore: update plugin submodules"
```

Update specific submodule:

```bash
cd modules/<plugin-name>
git pull origin main
cd ../..
git add modules/<plugin-name>
git commit -m "chore: update <plugin-name>"
```

## Setup Script Options

```bash
./setup.sh [OPTIONS]

OPTIONS:
    --skip-submodules    Skip git submodule initialization
    --skip-install       Skip OpenCode installation
    --skip-config        Skip OpenCode config setup
    --version VERSION    Install specific OpenCode version
    -h, --help           Show help message

EXAMPLES:
    ./setup.sh                       # Full setup
    ./setup.sh --skip-install        # Setup without installing OpenCode
    ./setup.sh --version 2.0.0       # Install specific version
```

## Troubleshooting

### Submodules Not Initialized

**Symptom**: `modules/` directories are empty

**Solution**:
```bash
git submodule update --init --recursive
```

### Container Build Fails

**Symptom**: `COPY --from=tools` fails

**Solution**: Verify base image is accessible:
```bash
podman pull ghcr.io/tankdonut/tools:latest
```

### OpenCode Config Not Found

**Symptom**: Container can't find `opencode.json`

**Solution**: Ensure file exists in repository root:
```bash
ls -la opencode.json
```

### Permission Errors in Container

**Symptom**: Can't write to `/app` or `/workspace`

**Solution**: Container runs as non-root user `opencode` (UID 1000). Match host permissions:
```bash
chown -R 1000:1000 /path/to/workspace
```

### JSON Validation Fails

**Symptom**: `Invalid JSON syntax` error

**Solution**: Validate with jq:
```bash
jq . opencode.json
```

## Development

### Testing Container Changes

1. **Build without cache**:
   ```bash
   podman build --no-cache -t opencode-harness-test -f Containerfile .
   ```

2. **Run validation tests**:
   ```bash
   podman run -it --rm opencode-harness-test bash -c "
       opencode --version &&
       cat /app/opencode.json &&
       ls -la /vendor/bin &&
       echo 'All checks passed'
   "
   ```

3. **Scan for vulnerabilities**:
   ```bash
   podman image scan opencode-harness-test
   ```

### Validating Configuration

```bash
jq . opencode.json
shellcheck setup.sh docker/entrypoint.sh
```

### Git Workflow

1. Make changes
2. Test in container
3. Validate configs
4. Commit with conventional commits:
   ```bash
   git commit -m "feat: add new plugin"
   git commit -m "fix: resolve submodule issue"
   git commit -m "chore: update dependencies"
   ```

## AGENTS.md Files

This project follows [GitHub's AGENTS.md best practices](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/):

- **AGENTS.md** - Root-level agent instructions for harness engineering
- **docker/AGENTS.md** - Container-specific agent instructions

These files provide AI agents with:
- Executable commands with flags
- Code examples and style guides
- Clear boundaries (always/ask/never)
- Project structure and tech stack
- Troubleshooting guidance

## Security

- **No secrets in containers**: API keys and credentials never committed or baked into images
- **Non-root user**: Containers run as `opencode` user (UID 1000)
- **Pinned versions**: All base images and packages use explicit versions
- **Minimal images**: Only essential dependencies installed
- **Vulnerability scanning**: Run `podman image scan` before releases

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test in container (`podman build --no-cache -f Containerfile .`)
5. Commit your changes (`git commit -m "feat: add amazing feature"`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New features
- `fix:` - Bug fixes
- `chore:` - Maintenance tasks
- `docs:` - Documentation updates
- `refactor:` - Code refactoring

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
