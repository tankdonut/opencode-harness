# OpenCode Harness - Detailed Installation Guide

This comprehensive installation guide covers all setup methods for OpenCode Harness across different environments and use cases.

## Prerequisites

Before installing OpenCode Harness, ensure you have:

- **Git**: 2.34+ (required for submodule support)
- **Node.js**: 12.22+ (includes npm, required for OpenCode)
- **Podman** or **Docker**: For container deployments (optional but recommended)
- **jq**: For JSON validation and manipulation (optional but recommended)

### Operating System Support

- **Linux**: Ubuntu 20.04+, CentOS 8+, RHEL 8+, Fedora 34+
- **macOS**: 10.15+ (Catalina or newer)
- **Windows**: Windows 10/11 with WSL2

### Verification Commands

```bash
# Check prerequisites
git --version          # Should be 2.34+
node --version         # Should be 12.22+
npm --version          # Should be included with Node.js
podman --version       # Or docker --version
jq --version           # Optional but recommended
```

## Installation Methods

### Method 1: Host Installation (Recommended for Development)

Host installation provides the most flexibility and is recommended for active development work.

#### Step 1: Clone Repository with Submodules

```bash
# Option A: Clone with submodules in one command
git clone --recurse-submodules https://github.com/tankdonut/opencode-harness.git
cd opencode-harness

# Option B: If already cloned without submodules
git clone https://github.com/tankdonut/opencode-harness.git
cd opencode-harness
git submodule update --init --recursive
```

#### Step 2: Run Setup Script

```bash
./setup.sh
```

The setup script will:

- Check all prerequisites and report any missing dependencies
- Initialize git submodules (everything-claude-code, oh-my-openagent, superpowers)
- Validate `opencode.json` syntax and plugin references
- Install or update OpenCode to the latest compatible version
- Set up configuration files and permissions
- Verify the installation works correctly

#### Step 3: Verify Installation

```bash
# Check OpenCode is installed and plugins are loaded
opencode --version

# Verify plugin configuration
cat opencode.json

# Test basic functionality
opencode --help
```

#### Troubleshooting Host Installation

**Submodule initialization fails:**

```bash
# Manually sync and update submodules
git submodule sync
git submodule update --init --recursive --force
```

**OpenCode installation fails:**

```bash
# Check Node.js and npm versions
node --version && npm --version

# Clear npm cache and retry
npm cache clean --force
npm install -g @opencode/cli@latest
```

**Permission errors:**

```bash
# Fix permissions on setup script
chmod +x setup.sh

# If npm global installation fails, use npx
npx @opencode/cli --version
```

### Method 2: Container Usage (Recommended for Production)

Container deployment ensures consistent environments and is ideal for production use, CI/CD pipelines, and team consistency.

#### Option A: Pre-built Container (Fastest)

```bash
# Pull latest pre-built image
podman pull ghcr.io/tankdonut/opencode-harness:latest

# Run interactively
podman run -it --rm ghcr.io/tankdonut/opencode-harness:latest

# Mount workspace for development
podman run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/tankdonut/opencode-harness:latest

# Using Docker instead of Podman
docker pull ghcr.io/tankdonut/opencode-harness:latest
docker run -it --rm -v $(pwd):/workspace -w /workspace ghcr.io/tankdonut/opencode-harness:latest
```

#### Option B: Build from Source

```bash
# Clone repository
git clone --recurse-submodules https://github.com/tankdonut/opencode-harness.git
cd opencode-harness

# Build container image
./scripts/build.sh

# Or explicitly with Docker
./scripts/build.sh --runtime docker

# Test the build
podman run -it --rm opencode-harness bash -c "opencode --version && echo 'Success!'"
```

#### Container Usage Patterns

**Development workflow:**

```bash
# Mount current directory as workspace
podman run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  opencode-harness bash

# Run specific OpenCode commands
podman run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  opencode-harness opencode --help
```

**CI/CD integration:**

```bash
# In your CI pipeline
podman run --rm \
  -v $GITHUB_WORKSPACE:/workspace \
  -w /workspace \
  ghcr.io/tankdonut/opencode-harness:latest \
  opencode validate
```

### Method 3: Development Setup

For contributors or advanced users who need to modify the harness itself.

#### Development Prerequisites

Additional tools needed for development:

- **Make**: Build automation
- **ShellCheck**: Shell script linting
- **hadolint**: Dockerfile linting

```bash
# Install development tools (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y make shellcheck

# Install hadolint
wget -O /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64
chmod +x /tmp/hadolint
sudo mv /tmp/hadolint /usr/local/bin/
```

#### Development Workflow

```bash
# Clone for development
git clone --recurse-submodules https://github.com/tankdonut/opencode-harness.git
cd opencode-harness

# Set up development environment
./setup.sh

# Run validation suite
./scripts/validate.sh

# Build and test container
./scripts/build.sh --no-cache --tag opencode-harness-dev
./scripts/container-test.sh opencode-harness-dev

# Run security scan
podman image scan opencode-harness-dev
```

## Platform-Specific Instructions

### Ubuntu/Debian

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y git nodejs npm curl jq

# Install Podman (optional)
sudo apt-get install -y podman

# Follow main installation steps
git clone --recurse-submodules https://github.com/tankdonut/opencode-harness.git
cd opencode-harness
./setup.sh
```

### CentOS/RHEL/Fedora

```bash
# Install prerequisites (Fedora/CentOS 8+)
sudo dnf install -y git nodejs npm curl jq podman

# Or for older CentOS/RHEL
sudo yum install -y git nodejs npm curl
# Note: jq and podman may need EPEL repository

# Follow main installation steps
git clone --recurse-submodules https://github.com/tankdonut/opencode-harness.git
cd opencode-harness
./setup.sh
```

### macOS

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install prerequisites
brew install git node jq podman

# Follow main installation steps
git clone --recurse-submodules https://github.com/tankdonut/opencode-harness.git
cd opencode-harness
./setup.sh
```

### Windows (WSL2)

```bash
# In WSL2 Ubuntu environment
sudo apt-get update
sudo apt-get install -y git nodejs npm curl jq

# Install Podman or Docker Desktop
# Follow Ubuntu instructions above

# Clone and setup
git clone --recurse-submodules https://github.com/tankdonut/opencode-harness.git
cd opencode-harness
./setup.sh
```

## Post-Installation Verification

### Basic Verification

```bash
# Check OpenCode installation
opencode --version
opencode --help

# Verify plugin loading
grep -E '"plugin":\s*\[' opencode.json

# Test submodule status
git submodule status
```

### Advanced Verification

```bash
# Run full validation suite
./scripts/validate.sh

# Test container functionality
./scripts/build.sh --tag test-harness
./scripts/container-test.sh test-harness

# Verify plugin functionality
opencode list-plugins  # If supported by your OpenCode version
```

### Troubleshooting Common Issues

**Git submodule authentication:**

```bash
# If submodules fail to clone due to authentication
git config --global url."https://github.com/".insteadOf git@github.com:
git submodule sync
git submodule update --init --recursive
```

**Container build failures:**

```bash
# Check available disk space
df -h

# Clean up container images
podman system prune -a

# Rebuild with no cache
./scripts/build.sh --no-cache
```

**OpenCode version conflicts:**

```bash
# Check for multiple OpenCode installations
which opencode
npm list -g @opencode/cli

# Uninstall and reinstall cleanly
npm uninstall -g @opencode/cli
npm install -g @opencode/cli@latest
```

## Next Steps

After successful installation:

1. **Read the [Usage Guide](usage.md)** to understand how to work with OpenCode Harness
2. **Review [Configuration Guide](configuration.md)** to customize your setup
3. **Check [DEVELOPMENT.md](../../DEVELOPMENT.md)** for development workflows
4. **Explore plugin documentation** in the `modules/` directory

## Getting Help

If you encounter issues:

1. **Check the [Troubleshooting section](../../DEVELOPMENT.md#troubleshooting)** in DEVELOPMENT.md
2. **Search existing [GitHub Issues](https://github.com/tankdonut/opencode-harness/issues)**
3. **Create a new issue** with detailed error messages and system information
4. **Join our community discussions** for help from other users
