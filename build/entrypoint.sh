#!/usr/bin/env bash
#
# opencoder - Container Bootstrap Script
#
# This script runs inside the container to set up OpenCode with all plugins.
# It validates configurations, installs dependencies, and verifies the installation.

set -euo pipefail

# Configuration
OPENCODE_VERSION="$(cat /etc/opencode-version 2>/dev/null | tr -d '[:space:]')" || true
readonly OPENCODE_VERSION
readonly OPENCODE_THEME="${OPENCODE_THEME:-ayu-dark}"
# Writable config destination (in HOME — survives bind-mount shadowing)
readonly HOME_CONFIG_DIR="${HOME}/.opencode"
readonly HOME_CONFIG_PATH="${HOME_CONFIG_DIR}/opencode.json"
readonly VENDOR_BIN="/vendor/bin"
# Read-only image defaults (source for bootstrap_config copy)
readonly DEFAULT_CONFIG_SOURCE="/opencode/default/opencode.json"
readonly DEFAULT_TUI_SOURCE="/opencode/default/tui.json"
readonly DEFAULT_THEMES_SOURCE="/opencode/default/themes"
readonly DEFAULT_SKILLS_SOURCE="/opencode/default/.agents/skills"
readonly SKILLS_CLI_VERSION="1.5.13"

# Optional skill sets (installed at runtime, require network)
# ECC_ENABLED=1:           install everything-claude-code skills
# SUPERPOWERS_ENABLED=1:   install superpowers skills
# Both default to disabled. oh-my-openagent skills are always baked in.

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

# =============================================================================
# Bootstrap Helper Functions
# =============================================================================

# Derive config directory from a config file path
# Given "/opencode/default/opencode.json", returns "/opencode/default"
derive_config_dir() {
    local config_path="${1:-$HOME_CONFIG_PATH}"

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
        if ! mkdir -p "$target_dir"; then
            log_error "copy_config: cannot create target directory: $target_dir"
            return 1
        fi
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

    create_config_dir "$HOME_CONFIG_DIR"

    copy_config "$DEFAULT_CONFIG_SOURCE" "$HOME_CONFIG_PATH"
    copy_theme_config "$HOME_CONFIG_DIR"

    log_success "Configuration bootstrap complete"
}

# =============================================================================
# Oh-My-OpenCode Installation
# =============================================================================

install_oh_my_opencode() {
    log "Oh-My-OpenCode installation enabled"

    # Path to oh-my-opencode marker (installer writes to ~/.omo/omo.jsonc)
    local omo_config="${HOME}/.omo/omo.jsonc"

    # Check if we need to install
    local should_install=false

    if [[ -f "$omo_config" ]]; then
        if [[ -n "${OMO_FORCE:-}" ]]; then
            log "OMO_FORCE set, will reinstall"
            should_install=true
        else
            log "OMO config exists, skipping (set OMO_FORCE to reinstall)"
            return 0
        fi
    else
        log "OMO config not found, will install"
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

    local -a install_cmd=(
        bunx oh-my-opencode install --no-tui
        --claude="${claude_flag}"
        --gemini="${gemini_flag}"
        --copilot="${copilot_flag}"
        --openai="${openai_flag}"
        --opencode-go="${opencode_go_flag}"
        --opencode-zen="${opencode_zen_flag}"
        --zai-coding-plan="${zai_coding_plan_flag}"
    )

    log "Running: ${install_cmd[*]}"

    if ! "${install_cmd[@]}" >&2 2>&1; then
        log_error "Oh-My-OpenCode installation failed"
        return 1
    fi

    log_success "Oh-My-OpenCode installed successfully"

    if [[ -f "$omo_config" ]]; then
        log "Config created at: ${omo_config}"
    else
        log_warn "Config file not found at ${omo_config}"
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
    if ! installed_version=$(opencode --version 2>&1 | head -n1); then
        log_error "OpenCode binary exists but fails to execute"
        return 1
    fi

    log_success "OpenCode ${installed_version} found"

    if [[ -n "${OPENCODE_VERSION:-}" ]]; then
        if [[ "$installed_version" != *"${OPENCODE_VERSION}"* ]]; then
            log_warn "Installed version (${installed_version}) differs from expected (${OPENCODE_VERSION})"
        fi
    fi
}

# Validate OpenCode configuration
validate_config() {
    log "Validating OpenCode configuration..."

    if [[ ! -f "$HOME_CONFIG_PATH" ]]; then
        log_error "Config file not found at $HOME_CONFIG_PATH"
        return 1
    fi

    # Validate JSON syntax
    if ! jq empty "$HOME_CONFIG_PATH" 2>/dev/null; then
        log_error "Invalid JSON syntax in $HOME_CONFIG_PATH"
        return 1
    fi

    # Check for required fields
    local schema_url
    schema_url=$(jq -r '."$schema" // empty' "$HOME_CONFIG_PATH")
    if [[ -z "$schema_url" ]]; then
        log_warn "No \$schema field in config (recommended: https://opencode.ai/config.json)"
    fi

    local plugin_count
    plugin_count=$(jq '.plugin | length' "$HOME_CONFIG_PATH")
    log "Found ${plugin_count} plugins configured"

    log_success "Configuration validation passed"
}

sync_skills() {
    if [[ ! -d "$DEFAULT_SKILLS_SOURCE" ]]; then
        log_warn "Baseline skills not found at $DEFAULT_SKILLS_SOURCE, skipping sync"
        return 0
    fi

    local home_skills="${HOME}/.agents/skills"
    local home_agents_dir
    home_agents_dir="$(dirname "$home_skills")"

    if ! mkdir -p "$home_agents_dir" 2>/dev/null; then
        log_error "Cannot create $home_agents_dir (HOME should be writable)"
        return 1
    fi

    if [[ -L "$home_skills" ]]; then
        local current_target
        current_target=$(readlink -f "$home_skills" 2>/dev/null || echo "")
        if [[ "$current_target" == "$DEFAULT_SKILLS_SOURCE" ]]; then
            local skill_count
            skill_count=$(find "$DEFAULT_SKILLS_SOURCE" -name 'SKILL.md' | wc -l)
            log_success "Skills symlink already configured (${skill_count} skills)"
            return 0
        fi
        rm -f "$home_skills"
    fi

    if [[ -d "$home_skills" ]] && [[ ! -L "$home_skills" ]]; then
        log_warn "$home_skills exists as a directory (not symlinking to avoid overwriting)"
        return 0
    fi

    if ! ln -s "$DEFAULT_SKILLS_SOURCE" "$home_skills"; then
        log_error "Failed to create skills symlink at $home_skills"
        return 1
    fi

    local skill_count
    skill_count=$(find "$DEFAULT_SKILLS_SOURCE" -name 'SKILL.md' | wc -l)
    log_success "Symlinked ${skill_count} skills to ${home_skills}"
}

install_optional_skills() {
    local skills_cli="npx --yes skills@${SKILLS_CLI_VERSION}"
    local installed=0

    local ecc_enabled="${ECC_ENABLED:-0}"
    case "${ecc_enabled,,}" in
        1|true|yes)
            log "Installing everything-claude-code skills..."
            if (cd /opencode/default && $skills_cli add affaan-m/everything-claude-code --agent opencode --skill '*' --copy -y) >&2; then
                log_success "everything-claude-code skills installed"
                installed=1
            else
                log_warn "Failed to install everything-claude-code skills (continuing)"
            fi
            ;;
    esac

    local sp_enabled="${SUPERPOWERS_ENABLED:-0}"
    case "${sp_enabled,,}" in
        1|true|yes)
            log "Installing superpowers skills..."
            if (cd /opencode/default && $skills_cli add obra/superpowers --agent opencode --skill '*' --copy -y) >&2; then
                log_success "superpowers skills installed"
                installed=1
            else
                log_warn "Failed to install superpowers skills (continuing)"
            fi
            ;;
    esac

    if [[ "$installed" -eq 1 ]]; then
        sync_skills
    fi
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
    if [[ ! -r "$HOME_CONFIG_PATH" ]]; then
        log_error "Config file not readable at $HOME_CONFIG_PATH"
        return 1
    fi

    # List configured plugins
    log "Configured plugins:"
    jq -r '.plugin[]' "$HOME_CONFIG_PATH" | while read -r plugin; do
        log "  - ${plugin}"
    done

    log_success "Installation verification passed"
}

# Print summary
print_summary() {
    log ""
    log "========================================="
    log "  opencoder Bootstrap Complete"
    log "========================================="
    log ""
    log "OpenCode Version: $(opencode --version 2>&1 | head -n1 || echo 'unable to determine')"
    log "Config Path: ${HOME_CONFIG_PATH}"
    log "Theme: ${OPENCODE_THEME}"
    log "Plugin Count: $(jq '.plugin | length' "$HOME_CONFIG_PATH")"
    log ""
    log "To start using OpenCode:"
    log "  opencode"
    log ""
    log "========================================="
}

handle_error() {
    local exit_code=$?
    log_error "Bootstrap failed (exit code ${exit_code})"
    exit "$exit_code"
}

main() {
    trap 'handle_error' ERR
    log "Starting opencoder bootstrap..."
    log ""

    validate_environment
    verify_opencode
    bootstrap_config

    if ! sync_skills; then
        log_warn "Skills sync failed"
    fi

    validate_config

    if ! install_oh_my_opencode; then
        log_warn "Oh-My-OpenCode installation failed (orchestrator features unavailable; container continues)"
    fi

    if ! install_optional_skills; then
        log_warn "Optional skills installation incomplete"
    fi

    verify_installation

    print_summary

    log_success "Bootstrap completed successfully!"

    if [[ $# -gt 0 ]]; then
        log "Executing: $*"
        export OPENCODE_CONFIG="$HOME_CONFIG_PATH"
        exec "$@"
    fi
}

# Run main function (only if executed directly, not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
