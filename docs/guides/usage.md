# OpenCode Harness - Usage Guide

This guide covers how to effectively use OpenCode Harness in different environments and workflows.

## Basic Usage

### Host Environment

After running `setup.sh`, OpenCode is available globally with all harness plugins loaded:

```bash
# Basic OpenCode commands
opencode --version
opencode --help
opencode list-plugins  # If supported

# Start OpenCode with harness configuration
opencode
```

The harness automatically loads plugins from:

- **everything-claude-code**: Production agents, skills, and commands
- **oh-my-openagent**: Multi-agent orchestration system
- **superpowers**: Advanced workflow skills

### Container Environment

The container comes with OpenCode pre-configured and ready to use:

```bash
# Check installation
podman run -it --rm opencode-harness opencode --version

# Interactive session
podman run -it --rm opencode-harness

# Run specific commands
podman run --rm opencode-harness opencode --help
```

## Development Workflows

### Project Development

Mount your project directory to work on existing codebases:

```bash
# Mount current directory as workspace
podman run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  opencode-harness bash

# Direct command execution
podman run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  opencode-harness opencode validate
```

### Multi-Agent Orchestration

The harness includes oh-my-openagent for sophisticated multi-agent workflows:

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
# List available skills (if supported)
opencode list-skills

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
  opencode-harness bash

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
  opencode-harness

# Attach to existing container
podman exec -it my-opencode-env bash

# Stop when done
podman stop my-opencode-env
podman rm my-opencode-env
```

### CI/CD Integration

**GitHub Actions example:**

```yaml
name: OpenCode Validation
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Run OpenCode validation
        run: |
          podman pull ghcr.io/tankdonut/opencode-harness:latest
          podman run --rm \
            -v ${{ github.workspace }}:/workspace \
            -w /workspace \
            ghcr.io/tankdonut/opencode-harness:latest \
            opencode validate
```

**GitLab CI example:**

```yaml
validate-opencode:
  stage: test
  image: ghcr.io/tankdonut/opencode-harness:latest
  script:
    - opencode validate
    - opencode lint
  only:
    - merge_requests
    - main
```

### Team Collaboration

**Consistent environments:**

```bash
# Team members use same container version
podman pull ghcr.io/tankdonut/opencode-harness:v1.0.0

# Shared configuration via mounted configs
podman run -it --rm \
  -v $(pwd):/workspace \
  -v ~/team-opencode-config:/config \
  -w /workspace \
  opencode-harness
```

**Project-specific configurations:**

```bash
# Each project can have its own opencode.json
# Container automatically picks up project configuration
podman run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  opencode-harness
```

## Plugin Management

### Updating Plugins

The harness uses git submodules for plugin management:

```bash
# Update all plugins to latest
git submodule update --remote --recursive

# Update specific plugin
cd modules/everything-claude-code
git pull origin main
cd ../..
git add modules/everything-claude-code
git commit -m "update: everything-claude-code plugin"

# Container rebuild needed after plugin updates
podman build -t opencode-harness -f Containerfile .
```

### Plugin Configuration

**Main configuration file:** `opencode.json`

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

**Container-specific configuration:** `etc/opencode/opencode.jsonc`

- Used for container-specific optimizations
- Supports comments and trailing commas
- Inherits from main opencode.json

### Adding Custom Plugins

```bash
# Add new plugin as submodule
git submodule add https://github.com/example/opencode-plugin.git modules/my-plugin

# Update opencode.json
jq '.plugin += ["my-plugin"]' opencode.json > tmp.json && mv tmp.json opencode.json

# Rebuild container if using container deployment
podman build -t opencode-harness -f Containerfile .
```

## Advanced Usage

### Custom Skills Development

Create project-specific skills:

```bash
# Create skills directory
mkdir -p .opencode/skills/my-skill

# Create skill definition
cat > .opencode/skills/my-skill/SKILL.md << 'EOF'
# My Custom Skill

Description of what this skill does.

## Usage
...

## Implementation
...
EOF
```

### Environment Variables

**Host environment:**

```bash
# Set OpenCode environment variables
export OPENCODE_CONFIG_PATH=/path/to/config
export OPENCODE_PLUGINS_PATH=/path/to/plugins

# Run with custom environment
opencode
```

**Container environment:**

```bash
# Pass environment variables to container
podman run -it --rm \
  -e OPENCODE_CONFIG_PATH=/config \
  -e OPENCODE_LOG_LEVEL=debug \
  -v $(pwd):/workspace \
  opencode-harness
```

### Debugging and Logging

**Enable verbose logging:**

```bash
# Host
OPENCODE_LOG_LEVEL=debug opencode

# Container
podman run -it --rm \
  -e OPENCODE_LOG_LEVEL=debug \
  opencode-harness opencode
```

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
  opencode-harness
```

**Volume optimization:**

```bash
# Use bind mounts for better performance
podman run -it --rm \
  --mount type=bind,source=$(pwd),target=/workspace \
  -w /workspace \
  opencode-harness
```

### Caching Strategies

**Container layer caching:**

```bash
# Build with cache optimization
podman build \
  --cache-from ghcr.io/tankdonut/opencode-harness:latest \
  -t opencode-harness \
  -f Containerfile .
```

**Plugin caching:**

```bash
# Cache plugin installations
# Plugins are cached as git submodules
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
   # Update harness
   git pull origin main
   git submodule update --remote --recursive

   # Rebuild container
   podman build -t opencode-harness -f Containerfile .
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
   # Verify submodules are initialized
   git submodule status

   # Reinitialize if needed
   git submodule update --init --recursive
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
- **Issues**: Report problems on [GitHub Issues](https://github.com/tankdonut/opencode-harness/issues)
- **Community**: Join discussions for user support and tips
