# opencoder - Usage Guide

This guide covers how to effectively use opencoder in different environments and workflows.

## Basic Usage

### Host Environment

After running `./scripts/local-setup.sh`, OpenCode is available globally with the opencoder configuration installed:

```bash
# Basic OpenCode commands
opencode --version
opencode --help
opencode  # Start interactive TUI

# Start OpenCode with opencoder configuration
opencode
```

The opencoder configuration includes these OpenCode plugins:

- `@tarquinen/opencode-dcp@3.1.13`
- `cc-safety-net@1.0.6`
- `oh-my-openagent@4.12.0`

### Container Environment

The container comes with OpenCode pre-configured and ready to use:

```bash
# Check installation
podman run -it --rm opencoder opencode --version

# Interactive session
podman run -it --rm opencoder

# Run specific commands
podman run --rm opencoder opencode --help
```

### Docker Compose / Podman Compose

The project ships a `compose.yml` and `.env.example` at the root for repeatable container runs without memorizing flags. Compose manages two volumes behind the scenes:

- `/workspace` binds your project directory (read-write)
- `/home/opencode` is a named volume for container state (Bun cache, sessions, auth.json, opencode-mem data), persisted across runs

**Quick start:**

```bash
# 1. Create your .env from the template
cp .env.example .env

# 2. Edit .env to set your API key
#    ZHIPU_API_KEY=your-key-here

# 3. Run interactively (Docker)
docker compose run --rm opencode

# 3b. Or with Podman Compose
podman-compose run --rm opencode
```

**Local builds instead of pulling from GHCR:**

```bash
# Build the image first
docker compose build

# Then run
docker compose run --rm opencode
```

Every environment variable documented in the [Configuration Guide](configuration.md) (provider keys, skill toggles, subscription flags, telemetry) can be set in `.env` and compose will pass it through automatically. The `.env` file is gitignored; `.env.example` is safe to commit.

**opencode-mem web UI:** `compose run` publishes service ports only with `--service-ports` — plain `docker compose run --rm opencode` will not expose the web UI even when enabled. To reach it:

```bash
# 1. In .env: OPENCODE_MEM_WEB_EXPOSED=1 and OPENCODE_MEM_WEB_TOKEN=<token>
# 2. Run with service ports
docker compose run --rm --service-ports opencode
# 3. Browse http://127.0.0.1:4747
```

See the [Configuration Guide](configuration.md) for the full exposure flow (token requirements, podman equivalent).

## Development Workflows

### Project Development

Mount your project directory to work on existing codebases:

```bash
# Mount current directory as workspace
podman run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  opencoder bash

# Direct command execution
podman run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  opencoder opencode --version
```

### Multi-Agent Orchestration

The opencoder includes oh-my-openagent for sophisticated multi-agent workflows:

```bash
# Start orchestration session
opencode

# Available agents (examples):
# - Sisyphus: Main orchestrator
# - Hephaestus: Deep autonomous worker
# - Prometheus: Strategic planner
# - Oracle: Architecture consultant
# - Librarian: Documentation and research
```

### Skills and Commands

Access production-ready skills and commands:

```bash
# Skills are loaded automatically from plugins

# Use specific skills in your workflow
# - TDD workflows
# - Git operations
# - Browser automation (Playwright)
# - Debugging methodologies
```

## Container Usage Patterns

### Development Environment

**Interactive development:**

```bash
# Start development container
podman run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  --name opencode-dev \
  opencoder bash

# Inside container
opencode --version
ls -la /workspace
```

**Persistent containers:**

```bash
# Create persistent container for long-running work
podman run -dit \
  -v $(pwd):/workspace \
  -w /workspace \
  --name my-opencode-env \
  opencoder

# Attach to existing container
podman exec -it my-opencode-env bash

# Stop when done
podman stop my-opencode-env
podman rm my-opencode-env
```

### CI/CD Integration

**GitHub Actions example:**

```yaml
name: OpenCode Check
on: [push, pull_request]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check OpenCode version
        run: |
          podman pull ghcr.io/tankdonut/opencoder:latest
          podman run --rm \
            -v ${{ github.workspace }}:/workspace \
            -w /workspace \
            ghcr.io/tankdonut/opencoder:latest \
            opencode --version
```

**GitLab CI example:**

```yaml
check-opencode:
  stage: test
  image: ghcr.io/tankdonut/opencoder:latest
  script:
    - opencode --version
  only:
    - merge_requests
    - main
```

### Team Collaboration

**Consistent environments:**

```bash
# Team members use same container version
podman pull ghcr.io/tankdonut/opencoder:v1.0.0

# Shared configuration via mounted configs
podman run -it --rm \
  -v $(pwd):/workspace \
  -v ~/team-opencode-config:/config \
  -w /workspace \
  opencoder
```

**Workspace mount:**

```bash
# Mount a project workspace with the opencoder configuration
podman run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  opencoder
```

## Plugin Management

### Updating Plugins

The opencoder uses the skills.sh CLI for skill distribution. Plugins (npm packages) are pinned in `opencode.json`:

```bash
# Update plugin versions in opencode.json, then rebuild
./scripts/build.sh

# Refresh the skills lockfile (baseline skills)
npx skills@1.5.13 experimental_install
git add build/skills-lock.json
git commit -m "update: refresh skills lockfile"

# Container rebuild needed after plugin updates
./scripts/build.sh
```

### Plugin Configuration

**Main configuration file:** `build/.opencode/opencode.json`

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

**Container-specific configuration:** `build/etc/opencode/opencode.jsonc`

- Used for container-specific optimizations
- Supports comments and trailing commas

### Adding Custom Plugins

```bash
# Add the plugin to opencode.json with a pinned version
jq '.plugin += ["my-plugin@1.0.0"]' build/.opencode/opencode.json > tmp.json && mv tmp.json build/.opencode/opencode.json

# Add a new skill source at runtime (opt-in)
npx skills@1.5.13 add owner/repo --agent opencode --skill '*' --copy -y

# Rebuild container if using container deployment
./scripts/build.sh
```

## Advanced Usage

### Custom Skills Development

Custom skills can be developed following the patterns in the upstream skill repositories linked in the README.

### Environment Variables

Environment variables for OpenCode are configured by the tool itself. Refer to the OpenCode documentation for available options.

### Debugging and Logging

**Access container logs:**

```bash
# View container logs
podman logs my-opencode-container

# Follow logs in real-time
podman logs -f my-opencode-container
```

## Performance Optimization

### Container Performance

**Resource limits:**

```bash
# Limit container resources
podman run -it --rm \
  --memory=4g \
  --cpus=2 \
  -v $(pwd):/workspace \
  opencoder
```

**Volume optimization:**

```bash
# Use bind mounts for better performance
podman run -it --rm \
  --mount type=bind,source=$(pwd),target=/workspace \
  -w /workspace \
  opencoder
```

### Caching Strategies

**Container layer caching:**

```bash
# Build with tag
./scripts/build.sh --tag opencoder
```

**Plugin caching:**

```bash
# Skills are baked into the image at build time (oh-my-openagent baseline)
# Optional runtime skills (ECC, superpowers) are fetched on demand
# No additional caching needed for most use cases
```

## Best Practices

### Security

1. **Container security:**
   - Containers run as non-root user (UID 1000)
   - No secrets baked into images
   - Minimal attack surface

2. **Host security:**
   - Keep OpenCode and plugins updated
   - Review plugin permissions
   - Use project-specific configurations

### Maintenance

1. **Regular updates:**

   ```bash
   # Update opencoder
   git pull origin main

    # Rebuild container
    ./scripts/build.sh
   ```

2. **Cleanup:**

   ```bash
   # Clean up old containers
   podman system prune -a

   # Clean up unused images
   podman image prune -a
   ```

### Troubleshooting

**Common issues and solutions:**

1. **Plugin loading failures:**

   ```bash
   # Verify plugin config is valid
   jq . build/.opencode/opencode.json

   # Verify skills lockfile
   jq . build/skills-lock.json

   # Rebuild from scratch
   ./scripts/build.sh --no-cache
   ```

2. **Container permission issues:**

   ```bash
   # Fix workspace permissions
   chown -R 1000:1000 /path/to/workspace
   ```

3. **Memory/resource issues:**

   ```bash
   # Monitor container resource usage
   podman stats my-container

   # Increase limits if needed
   podman run --memory=8g --cpus=4 ...
   ```

## Getting Help

- **Documentation**: Check [DEVELOPMENT.md](../../DEVELOPMENT.md) for development-specific usage
- **Issues**: Report problems on [GitHub Issues](https://github.com/tankdonut/opencoder/issues)
- **Community**: Join discussions for user support and tips
