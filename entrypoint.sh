#!/usr/bin/env bash
#
# OpenCode Harness - Container Bootstrap Script
#
# This script runs inside the container to set up OpenCode with all plugins.
# It validates configurations, installs dependencies, and verifies the installation.

set -euo pipefail

# Configuration
readonly OPENCODE_VERSION="${OPENCODE_VERSION:-1.2.27}"
readonly CONFIG_PATH="${OPENCODE_CONFIG:-/app/opencode.json}"
readonly MODULES_PATH="/app/modules"
readonly VENDOR_BIN="/vendor/bin"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $*${NC}" >&2
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ $*${NC}" >&2
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ $*${NC}" >&2
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Validate environment
validate_environment() {
    log "Validating environment..."
    
    # Check required commands
    local required_cmds=("git" "node" "npm")
    for cmd in "${required_cmds[@]}"; do
        if ! command_exists "$cmd"; then
            log_error "Required command not found: $cmd"
            return 1
        fi
    done
    
    # Check PATH includes vendor bin
    if [[ ":$PATH:" != *":$VENDOR_BIN:"* ]]; then
        log_warn "Vendor bin not in PATH, adding..."
        export PATH="$VENDOR_BIN:$PATH"
    fi
    
    log_success "Environment validation passed"
}

# Verify OpenCode installation (pre-installed in container image)
verify_opencode() {
    log "Verifying OpenCode installation..."
    
    if ! command_exists opencode; then
        log_error "OpenCode not found - this should be pre-installed in the container image"
        return 1
    fi
    
    local installed_version
    installed_version=$(opencode --version 2>/dev/null | head -n1 || echo "unknown")
    
    log_success "OpenCode ${installed_version} found"
    
    # Verify version matches expected (if OPENCODE_VERSION is set)
    if [[ -n "${OPENCODE_VERSION:-}" ]]; then
        if [[ "$installed_version" != *"${OPENCODE_VERSION}"* ]]; then
            log_warn "Installed version (${installed_version}) differs from expected (${OPENCODE_VERSION})"
        fi
    fi
}

# Validate OpenCode configuration
validate_config() {
    log "Validating OpenCode configuration..."
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        log_error "Config file not found at $CONFIG_PATH"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$CONFIG_PATH" 2>/dev/null; then
        log_error "Invalid JSON syntax in $CONFIG_PATH"
        return 1
    fi
    
    # Check for required fields
    local schema_url
    schema_url=$(jq -r '."$schema" // empty' "$CONFIG_PATH")
    if [[ -z "$schema_url" ]]; then
        log_warn "No \$schema field in config (recommended: https://opencode.ai/config.json)"
    fi
    
    local plugin_count
    plugin_count=$(jq '.plugin | length' "$CONFIG_PATH")
    log "Found ${plugin_count} plugins configured"
    
    log_success "Configuration validation passed"
}

# Initialize git submodules (if present)
init_submodules() {
    log "Checking for git submodules..."
    
    if [[ ! -d "$MODULES_PATH" ]]; then
        log_warn "Modules directory not found at $MODULES_PATH, skipping"
        return 0
    fi
    
    cd "$(dirname "$MODULES_PATH")"
    
    if [[ ! -f ".gitmodules" ]]; then
        log_warn "No .gitmodules file found, skipping submodule init"
        return 0
    fi
    
    # Initialize and update submodules
    git submodule update --init --recursive
    
    local submodule_count
    submodule_count=$(git submodule status | wc -l)
    log_success "Initialized ${submodule_count} git submodules"
}

# Verify installation
verify_installation() {
    log "Verifying OpenCode installation..."
    
    # Check OpenCode command
    if ! opencode --version &>/dev/null; then
        log_error "OpenCode command not working"
        return 1
    fi
    
    # Check config is readable
    if [[ ! -r "$CONFIG_PATH" ]]; then
        log_error "Config file not readable at $CONFIG_PATH"
        return 1
    fi
    
    # List configured plugins
    log "Configured plugins:"
    jq -r '.plugin[]' "$CONFIG_PATH" | while read -r plugin; do
        log "  - ${plugin}"
    done
    
    log_success "Installation verification passed"
}

# Print summary
print_summary() {
    log ""
    log "========================================="
    log "  OpenCode Harness Bootstrap Complete"
    log "========================================="
    log ""
    log "OpenCode Version: $(opencode --version 2>/dev/null | head -n1 || echo 'unknown')"
    log "Config Path: ${CONFIG_PATH}"
    log "Plugin Count: $(jq '.plugin | length' "$CONFIG_PATH")"
    log ""
    log "To start using OpenCode:"
    log "  opencode"
    log ""
    log "========================================="
}

# Main execution
main() {
    log "Starting OpenCode Harness bootstrap..."
    log ""
    
    validate_environment || exit 1
    verify_opencode || exit 1
    validate_config || exit 1
    init_submodules || true  # Don't fail if submodules aren't available
    verify_installation || exit 1
    
    print_summary
    
    log_success "Bootstrap completed successfully!"
    
    # If arguments provided, execute them (for custom entry points)
    if [[ $# -gt 0 ]]; then
        log "Executing: $*"
        exec "$@"
    fi
}

# Run main function
main "$@"
