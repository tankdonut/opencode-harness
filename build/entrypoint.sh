#!/usr/bin/env bash
#
# OpenCode Harness - Container Bootstrap Script
#
# This script runs inside the container to set up OpenCode with all plugins.
# It validates configurations, installs dependencies, and verifies the installation.

set -euo pipefail

# Configuration
OPENCODE_VERSION="$(cat /etc/opencode-version 2>/dev/null | tr -d '[:space:]')" || true
readonly OPENCODE_VERSION
readonly OPENCODE_THEME="${OPENCODE_THEME:-ayu-dark}"
readonly CONFIG_PATH="${OPENCODE_CONFIG:-/opencode/default/opencode.json}"
readonly MODULES_PATH="/vendor/modules"
readonly VENDOR_BIN="/vendor/bin"
readonly DEFAULT_CONFIG_SOURCE="/opencode/default/opencode.json"
readonly DEFAULT_TUI_SOURCE="/opencode/default/tui.json"
readonly DEFAULT_THEMES_SOURCE="/opencode/default/themes"

# Module Enable/Disable (default: all enabled, set to 0/false/no to disable)
# ECC_ENABLED:           everything-claude-code module assets
# OMO_ENABLED:           oh-my-openagent module assets + oh-my-opencode installation
# SUPERPOWERS_ENABLED:   superpowers module assets

# Oh-My-OpenCode (OMO) Installation Options
# OMO_FORCE: Force reinstallation even if config exists
# Subscription flags (passed to bunx oh-my-opencode install):
# OMO_CLAUDE: Claude subscription (yes|no|max20)
# OMO_GEMINI: Gemini subscription (yes|no)
# OMO_COPILOT: GitHub Copilot subscription (yes|no)
# OMO_OPENAI: OpenAI subscription (yes|no)
# OMO_OPENCODE_GO: OpenCode Go subscription (yes|no)
# OMO_OPENCODE_ZEN: OpenCode Zen subscription (yes|no)
# OMO_ZAI_CODING_PLAN: Z.ai Coding Plan subscription (yes|no)

# Colors for output
if [[ -z "${RED:-}" ]]; then readonly RED='\033[0;31m'; fi
if [[ -z "${GREEN:-}" ]]; then readonly GREEN='\033[0;32m'; fi
if [[ -z "${YELLOW:-}" ]]; then readonly YELLOW='\033[1;33m'; fi
if [[ -z "${NC:-}" ]]; then readonly NC='\033[0m'; fi

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

is_module_enabled() {
    local module_name="${1:-}"
    local flag_name=""
    local flag_value=""

    case "$module_name" in
        everything-claude-code) flag_name="ECC_ENABLED" ;;
        oh-my-openagent)        flag_name="OMO_ENABLED" ;;
        superpowers)            flag_name="SUPERPOWERS_ENABLED" ;;
        *)                      return 0 ;;
    esac

    flag_value="${!flag_name:-1}"

    case "${flag_value,,}" in
        0|false|no) return 1 ;;
        *)          return 0 ;;
    esac
}

# =============================================================================
# Bootstrap Helper Functions
# =============================================================================

# Derive config directory from CONFIG_PATH
# Given "/opencode/default/opencode.json", returns "/opencode/default"
derive_config_dir() {
    local config_path="${1:-$CONFIG_PATH}"

    if [[ -z "$config_path" ]]; then
        log_error "derive_config_dir: config_path is required"
        return 1
    fi

    dirname "$config_path"
}

# Create config directory if missing
create_config_dir() {
    local config_dir="${1:-}"

    if [[ -z "$config_dir" ]]; then
        log_error "create_config_dir: config_dir is required"
        return 1
    fi

    if [[ -d "$config_dir" ]]; then
        return 0
    fi

    mkdir -p "$config_dir"
}

# Copy config file from source to target
# Uses cp -n (no overwrite) unless OPENCODE_BOOTSTRAP_FORCE=1
copy_config() {
    local source="${1:-}"
    local target="${2:-}"
    local force="${OPENCODE_BOOTSTRAP_FORCE:-0}"

    if [[ -z "$source" ]] || [[ -z "$target" ]]; then
        log_error "copy_config: source and target are required"
        return 1
    fi

    if [[ ! -f "$source" ]]; then
        log_error "copy_config: source file not found: $source"
        return 1
    fi

    # Ensure target directory exists
    local target_dir
    target_dir=$(dirname "$target")
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
    fi

    if [[ "$force" == "1" ]]; then
        cp "$source" "$target"
    elif [[ -f "$target" ]]; then
        # Target exists, skip without force
        log_warn "Config exists at $target, skipping (set OPENCODE_BOOTSTRAP_FORCE=1 to overwrite)"
    else
        # Target missing, use cp -n (no overwrite)
        cp -n "$source" "$target"
    fi
}

# Copy assets from module directory to config directory
# Copies skills/, agents/, commands/ directories if they exist
copy_assets() {
    local module_path="${1:-}"
    local config_dir="${2:-}"
    local force="${OPENCODE_BOOTSTRAP_FORCE:-0}"

    if [[ -z "$module_path" ]] || [[ -z "$config_dir" ]]; then
        log_error "copy_assets: module_path and config_dir are required"
        return 1
    fi

    # Asset directories to copy
    local asset_dirs=("skills")

    for asset_dir in "${asset_dirs[@]}"; do
        local source_dir="${module_path}/${asset_dir}"

        # Skip if source doesn't exist
        if [[ ! -d "$source_dir" ]]; then
            continue
        fi

        local dest_dir="${config_dir}/${asset_dir}"

        # Create destination directory if needed
        if [[ ! -d "$dest_dir" ]]; then
            mkdir -p "$dest_dir"
        fi

        # Copy files
        if [[ "$force" == "1" ]]; then
            cp -r "${source_dir}/." "${dest_dir}/"
        else
            cp -rn "${source_dir}/." "${dest_dir}/"
        fi
    done
}

copy_theme_config() {
    local config_dir="${1:-}"

    if [[ -z "$config_dir" ]]; then
        log_error "copy_theme_config: config_dir is required"
        return 1
    fi

    if [[ -f "$DEFAULT_TUI_SOURCE" ]]; then
        copy_config "$DEFAULT_TUI_SOURCE" "${config_dir}/tui.json"
    fi

    if [[ -d "$DEFAULT_THEMES_SOURCE" ]]; then
        local themes_dest="${config_dir}/themes"
        if [[ ! -d "$themes_dest" ]]; then
            mkdir -p "$themes_dest"
        fi
        cp -rn "${DEFAULT_THEMES_SOURCE}/." "${themes_dest}/"
        log_success "Theme files copied (${DEFAULT_THEMES_SOURCE})"
    fi
}

# Main bootstrap orchestration - calls all helpers
bootstrap_config() {
    log "Bootstrapping OpenCode configuration..."

    local config_dir
    config_dir=$(derive_config_dir "$CONFIG_PATH")

    create_config_dir "$config_dir"

    copy_config "$DEFAULT_CONFIG_SOURCE" "$CONFIG_PATH"
    copy_theme_config "$config_dir"

    # Copy assets from all modules
    if [[ -d "$MODULES_PATH" ]]; then
        local module module_name
        for module in "$MODULES_PATH"/*; do
            if [[ -d "$module" ]]; then
                module_name=$(basename "$module")
                if is_module_enabled "$module_name"; then
                    copy_assets "$module" "$config_dir"
                else
                    log "Module ${module_name} disabled, skipping"
                fi
            fi
        done
    fi

    # Sync config to workspace directory for runtime use
    # Ensures /workspace/.config/opencode/opencode.json is managed by
    # the bootstrap process, respecting OPENCODE_BOOTSTRAP_FORCE
    local workspace_config_dir="/workspace/.config/opencode"
    if [[ -d "/workspace" ]]; then
        create_config_dir "$workspace_config_dir"
        copy_config "$DEFAULT_CONFIG_SOURCE" "${workspace_config_dir}/opencode.json"
        copy_theme_config "$workspace_config_dir"

        if [[ -d "$MODULES_PATH" ]]; then
            local module module_name
            for module in "$MODULES_PATH"/*; do
                if [[ -d "$module" ]]; then
                    module_name=$(basename "$module")
                    if is_module_enabled "$module_name"; then
                        copy_assets "$module" "$workspace_config_dir"
                    fi
                fi
            done
        fi
    fi

    log_success "Configuration bootstrap complete"
}

# =============================================================================
# Oh-My-OpenCode Installation
# =============================================================================

install_oh_my_opencode() {
    if ! is_module_enabled "oh-my-openagent"; then
        log "OMO module disabled"
        return 0
    fi

    log "Oh-My-OpenCode installation enabled"

    # Derive config directory from CONFIG_PATH
    local config_dir
    config_dir=$(derive_config_dir "$CONFIG_PATH")

    # Path to oh-my-opencode config
    local omo_config="${config_dir}/oh-my-opencode.json"

    # Check if we need to install
    local should_install=false

    if [[ -f "$omo_config" ]]; then
        if [[ -n "${OMO_FORCE:-}" ]]; then
            log "OMO_FORCE set, will reinstall"
            should_install=true
        else
            log "oh-my-opencode.json exists, skipping (set OMO_FORCE to reinstall)"
            return 0
        fi
    else
        log "oh-my-opencode.json not found, will install"
        should_install=true
    fi

    if [[ "$should_install" != "true" ]]; then
        return 0
    fi

    # Build subscription flags
    local claude_flag="${OMO_CLAUDE:-no}"
    local gemini_flag="${OMO_GEMINI:-no}"
    local copilot_flag="${OMO_COPILOT:-no}"
    local openai_flag="${OMO_OPENAI:-no}"
    local opencode_go_flag="${OMO_OPENCODE_GO:-no}"
    local opencode_zen_flag="${OMO_OPENCODE_ZEN:-no}"
    local zai_coding_plan_flag="${OMO_ZAI_CODING_PLAN:-no}"

    # Build the install command
    local install_cmd="bunx oh-my-opencode install --no-tui"
    install_cmd+=" --claude=${claude_flag}"
    install_cmd+=" --gemini=${gemini_flag}"
    install_cmd+=" --copilot=${copilot_flag}"
    install_cmd+=" --openai=${openai_flag}"
    install_cmd+=" --opencode-go=${opencode_go_flag}"
    install_cmd+=" --opencode-zen=${opencode_zen_flag}"
    install_cmd+=" --zai-coding-plan=${zai_coding_plan_flag}"

    log "Running: ${install_cmd}"

    # Execute installation (redirect output to stderr so it doesn't
    # contaminate stdout when container is used programmatically)
    if ${install_cmd} 2>&2 >&2; then
        log_success "Oh-My-OpenCode installed successfully"

        # Verify config was created
        if [[ -f "$omo_config" ]]; then
            log "Config created at: ${omo_config}"
        else
            log_warn "Config file not found at ${omo_config}"
        fi
    else
        log_error "Oh-My-OpenCode installation failed"
        return 1
    fi
}

# Validate environment
validate_environment() {
    log "Validating environment..."

    # Check required commands
    local required_cmds=("git" "node" "npm" "curl" "jq" "python3" "pip3" "yq")
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
    log "Theme: ${OPENCODE_THEME}"
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
    init_submodules || true
    verify_opencode || exit 1
    bootstrap_config || exit 1
    validate_config || exit 1
    install_oh_my_opencode || true
    verify_installation || exit 1

    print_summary

    log_success "Bootstrap completed successfully!"

    if [[ $# -gt 0 ]]; then
        log "Executing: $*"
        exec "$@"
    fi
}

# Run main function (only if executed directly, not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
