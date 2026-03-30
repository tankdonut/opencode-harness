# Development Guide

This guide covers development workflows, testing, troubleshooting, and CI/CD for OpenCode Harness contributors.

## Local Testing

Run validation and container tests locally before pushing:

```bash
# Validate configuration and scripts
./scripts/validate.sh

# Build container
podman build -t opencode-harness:test -f Containerfile .

# Run container test suite
./scripts/container-test.sh opencode-harness:test
```

## Testing Container Changes

1. **Build without cache**:

   ```bash
   podman build --no-cache -t opencode-harness-test -f Containerfile .
   ```

2. **Run validation tests**:

   ```bash
   podman run -it --rm opencode-harness-test bash -c "
       opencode --version &&
       cat /workspace/.config/opencode/opencode.json &&
       test -f /etc/opencode/opencode.jsonc &&
       ls -la /vendor/bin &&
       echo 'All checks passed'
   "
   ```

3. **Run comprehensive test suite**:

   ```bash
   ./scripts/container-test.sh opencode-harness-test
   ```

4. **Scan for vulnerabilities**:

   ```bash
   podman image scan opencode-harness-test
   ```

## Validating Configuration

```bash
# Run all validations
./scripts/validate.sh

# Or manually
jq . opencode.json
shellcheck setup.sh entrypoint.sh scripts/*.sh
```

## Git Workflow

1. Make changes
2. Run validation: `./scripts/validate.sh`
3. Build and test: `podman build -t test -f Containerfile . && ./scripts/container-test.sh test`
4. Commit with conventional commits:

   ```bash
   git commit -m "feat: add new plugin"
   git commit -m "fix: resolve submodule issue"
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
podman build -t opencode-harness:ci -f Containerfile .
./scripts/container-test.sh opencode-harness:ci podman
```

### Using Pre-built Container

Pull the latest container from GitHub Container Registry:

```bash
podman pull ghcr.io/tankdonut/opencode-harness:latest
podman run -it --rm ghcr.io/tankdonut/opencode-harness:latest
```

### CI Configuration

- Workflow: `.github/workflows/ci.yml`
- Test script: `scripts/container-test.sh`
- Validation: `scripts/validate.sh`

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

## Plugin Management

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

## Container Build Options

### Build with OpenCode Version

The OpenCode version is managed in `.opencode-version` (single source of truth). Build reads the version from this file:

```bash
# Build using version from .opencode-version
podman build --build-arg OPENCODE_VERSION=$(cat .opencode-version) -t opencode-harness -f Containerfile .

# Or with Docker
docker build --build-arg OPENCODE_VERSION=$(cat .opencode-version) -t opencode-harness -f Containerfile .
```

To change the OpenCode version, update `.opencode-version` and rebuild:

```bash
echo "1.4.0" > .opencode-version
podman build --build-arg OPENCODE_VERSION=$(cat .opencode-version) -t opencode-harness -f Containerfile .
```

## Security Considerations

- **No secrets in containers**: API keys and credentials never committed or baked into images
- **Non-root user**: Containers run as `opencode` user (UID 1000)
- **Pinned versions**: All base images and packages use explicit versions
- **Minimal images**: Only essential dependencies installed
- **Vulnerability scanning**: Run `podman image scan` before releases
