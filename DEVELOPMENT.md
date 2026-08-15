# Development Guide

This guide covers development workflows, testing, troubleshooting, and CI/CD for opencoder contributors.

## Local Testing

Run validation and container tests locally before pushing:

```bash
# Validate configuration and scripts
./scripts/validate.sh

# Build container
./scripts/build.sh --tag opencoder:test

# Run container test suite
./scripts/container-test.sh opencoder:test
```

## Testing Container Changes

1. **Build without cache**:

   ```bash
   ./scripts/build.sh --tag opencoder-test --no-cache
   ```

2. **Run validation tests**:

   ```bash
   podman run -it --rm opencoder-test bash -c "
      opencode --version &&
      cat /etc/opencode/opencode.jsonc &&
      test -f /etc/opencode/opencode.jsonc &&
      ls -la /vendor/bin &&
      echo 'All checks passed'
   "
   ```

3. **Run comprehensive test suite**:

   ```bash
   ./scripts/container-test.sh opencoder-test
   ```

4. **Scan for vulnerabilities**:

   ```bash
   podman image scan opencoder-test
   ```

## Validating Configuration

```bash
# Run all validations
./scripts/validate.sh

# Or manually
jq . build/.opencode/opencode.json
shellcheck scripts/*.sh
```

## Git Workflow

1. Make changes
2. Run validation: `./scripts/validate.sh`
3. Build and test: `./scripts/build.sh --tag test && ./scripts/container-test.sh test`
4. Commit with conventional commits:

   ```bash
   git commit -m "feat: add new plugin"
   git commit -m "fix: resolve config issue"
   git commit -m "chore: update dependencies"
   ```

## CI/CD

This project includes automated CI/CD via GitHub Actions:

### Pipeline Stages

1. **Validate** - Lints shell scripts, validates JSON configuration
2. **Build** - Builds the container image with Podman/Docker
3. **Test** - Runs the container test suite
4. **Push** - Pushes image to GitHub Container Registry (main branch only)

### Running CI Locally

```bash
# Run the same validations as CI
./scripts/validate.sh

# Build and test like CI does
./scripts/build.sh --tag opencoder:ci
./scripts/container-test.sh opencoder:ci podman
```

### Using Pre-built Container

Pull the latest container from GitHub Container Registry:

```bash
podman pull ghcr.io/tankdonut/opencoder:latest
podman run -it --rm ghcr.io/tankdonut/opencoder:latest
```

### CI Configuration

- Workflows: `.github/workflows/` (4 files — `lint-and-test.yaml`, `build-and-publish-image.yaml`, `prune-ghcr-images.yaml`, `renovate-auto-approve.yaml`); consume centralized actions from `tankdonut/github-actions@v1`
- Test script: `scripts/container-test.sh`
- Validation: `scripts/validate.sh`

## Troubleshooting

### Container Build Fails

**Symptom**: `COPY --from=tools` fails

**Solution**: Verify base image is accessible:

```bash
podman pull ghcr.io/tankdonut/tools
```

### OpenCode Config Not Found

**Symptom**: Container can't find `opencode.json`

**Solution**: Ensure config exists at the correct path:

```bash
ls -la build/.opencode/opencode.json
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
jq . build/.opencode/opencode.json
```

## Setup Script Options

```bash
./scripts/local-setup.sh [OPTIONS]

OPTIONS:
    --skip-install       Skip OpenCode installation
    --skip-config        Skip OpenCode config setup
    --version VERSION    Install specific OpenCode version
    -h, --help           Show help message

EXAMPLES:
    ./scripts/local-setup.sh                       # Full setup
    ./scripts/local-setup.sh --skip-install        # Setup without installing OpenCode
    ./scripts/local-setup.sh --version 2.0.0       # Install specific version
```

## Plugin Management

### Adding Plugins

1. Add the plugin to `opencode.json` with a pinned version:

   ```json
   {
       "plugin": [
           "existing-plugin",
           "new-plugin"
       ]
   }
   ```

2. Test in container:

   ```bash
   ./scripts/build.sh --tag opencoder --no-cache
   ```

### Adding Skills

Add a new skill source using the skills.sh CLI:

   ```bash
   npx skills@1.5.13 add <owner/repo> --agent opencode --skill '*' --copy -y
   ```

Then commit the updated `build/skills-lock.json`.

### Updating Skills

Regenerate the lockfile and rebuild:

```bash
npx skills@1.5.13 experimental_install
git add build/skills-lock.json
git commit -m "chore: refresh skills lockfile"
```

## Container Build Options

### Build with OpenCode Version

The OpenCode version is managed in `build/.opencode-version` (single source of truth). The build script reads the version from this file automatically:

```bash
./scripts/build.sh
```

To use Docker instead of Podman:

```bash
./scripts/build.sh --runtime docker
```

To change the OpenCode version, use the version bumper script:

```bash
./scripts/bump-version.sh 1.14.18
./scripts/build.sh
```

## Security Considerations

- **No secrets in containers**: API keys and credentials never committed or baked into images
- **Non-root user**: Containers run as `opencode` user (UID 1000)
- **Pinned versions**: All base images and packages use explicit versions
- **Minimal images**: Only essential dependencies installed
- **Vulnerability scanning**: Run `podman image scan` before releases
