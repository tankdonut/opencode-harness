#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly OPENCODE_VERSION="${OPENCODE_VERSION:-$(cat "${PROJECT_ROOT}/.opencode-version" 2>/dev/null | tr -d '[:space:]')}"
readonly CONFIG_PATH="${PROJECT_ROOT}/.opencode/opencode.json"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $*${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ $*${NC}" >&2
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ $*${NC}"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ $*${NC}"
}

command_exists() {
    command -v "$1" &>/dev/null
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    local required_cmds=("git" "node" "npm" "curl" "jq")
    local missing_cmds=()
    
    for cmd in "${required_cmds[@]}"; do
        if ! command_exists "$cmd"; then
            missing_cmds+=("$cmd")
        fi
    done
    
    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_cmds[*]}"
        log_info "Please install the following:"
        for cmd in "${missing_cmds[@]}"; do
            case "$cmd" in
                git)
                    log_info "  - Git: https://git-scm.com/downloads"
                    ;;
                node|npm)
                    log_info "  - Node.js (includes npm): https://nodejs.org/"
                    ;;
                curl)
                    log_info "  - curl: usually pre-installed, or via package manager"
                    ;;
                jq)
                    log_info "  - jq: https://jqlang.github.io/jq/download/"
                    ;;
            esac
        done
        return 1
    fi
    
    log_success "All required prerequisites found"
    
    log_info "Detected versions:"
    log_info "  - Git: $(git --version | head -n1)"
    log_info "  - Node: $(node --version)"
    log_info "  - npm: $(npm --version)"
    log_info "  - curl: $(curl --version | head -n1)"
    log_info "  - jq: $(jq --version)"
}

init_submodules() {
    log "Initializing git submodules..."
    
    cd "$PROJECT_ROOT"
    
    if [[ ! -f ".gitmodules" ]]; then
        log_warn "No .gitmodules file found, skipping submodule initialization"
        return 0
    fi
    
    git submodule update --init --recursive
    
    local submodule_count
    submodule_count=$(git submodule status | wc -l)
    log_success "Initialized ${submodule_count} git submodules"
    
    if [[ -d "modules" ]]; then
        log_info "Available plugins:"
        for module in modules/*/; do
            if [[ -d "$module" ]]; then
                local module_name
                module_name=$(basename "$module")
                log_info "  - ${module_name}"
            fi
        done
    fi
}

validate_config() {
    log "Validating OpenCode configuration..."
    
    if [[ ! -f "$CONFIG_PATH" ]]; then
        log_error "Config file not found at $CONFIG_PATH"
        return 1
    fi
    
    if ! jq empty "$CONFIG_PATH" 2>/dev/null; then
        log_error "Invalid JSON syntax in $CONFIG_PATH"
        return 1
    fi
    
    local plugin_count
    plugin_count=$(jq '.plugin | length' "$CONFIG_PATH" 2>/dev/null || echo "0")
    log_success "Configuration valid - ${plugin_count} plugins configured"
    
    log_info "Configured plugins:"
    jq -r '.plugin[]' "$CONFIG_PATH" 2>/dev/null | while read -r plugin; do
        log_info "  - ${plugin}"
    done
}

install_opencode() {
    log "Installing OpenCode..."
    
    if command_exists opencode; then
        local installed_version
        installed_version=$(opencode --version 2>/dev/null | head -n1 || echo "unknown")
        log_warn "OpenCode already installed (${installed_version})"
        
        read -p "Reinstall OpenCode ${OPENCODE_VERSION}? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping OpenCode installation"
            return 0
        fi
    fi
    
    npm install -g "opencode@${OPENCODE_VERSION}"
    
    if ! command_exists opencode; then
        log_error "OpenCode installation failed"
        return 1
    fi
    
    log_success "OpenCode ${OPENCODE_VERSION} installed successfully"
}

setup_opencode_config() {
    log "Setting up OpenCode configuration..."
    
    local opencode_dir="${HOME}/.opencode"
    mkdir -p "$opencode_dir"
    
    if [[ -f "${opencode_dir}/config.json" ]]; then
        log_warn "OpenCode config already exists at ${opencode_dir}/config.json"
        log_info "Current harness config: ${CONFIG_PATH}"
        log_info "You may want to merge these configs manually"
    else
        log_info "Copying config to ${opencode_dir}/config.json"
        cp "$CONFIG_PATH" "${opencode_dir}/config.json"
        log_success "OpenCode configuration copied"
    fi
}

verify_installation() {
    log "Verifying installation..."
    
    if ! opencode --version &>/dev/null; then
        log_error "OpenCode command not working"
        return 1
    fi
    
    log_success "Installation verified"
    log_info "OpenCode version: $(opencode --version | head -n1)"
}

print_summary() {
    echo ""
    echo "========================================="
    echo "  OpenCode Harness Setup Complete"
    echo "========================================="
    echo ""
    echo "✓ Prerequisites checked"
    echo "✓ Git submodules initialized"
    echo "✓ Configuration validated"
    echo "✓ OpenCode installed"
    echo ""
    echo "Next steps:"
    echo "  1. Review configuration: ${CONFIG_PATH}"
    echo "  2. Start OpenCode: opencode"
    echo "  3. Build container: ./scripts/build.sh"
    echo ""
    echo "Documentation:"
    echo "  - README.md - Project overview"
    echo "  - AGENTS.md - Agent and container instructions"
    echo ""
    echo "========================================="
}

print_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

OpenCode Harness Setup Script

OPTIONS:
    --skip-submodules    Skip git submodule initialization
    --skip-install       Skip OpenCode installation
    --skip-config        Skip OpenCode config setup
    --version VERSION    Install specific OpenCode version (default: ${OPENCODE_VERSION})
    -h, --help           Show this help message

EXAMPLES:
    $0                           # Full setup
    $0 --skip-install            # Setup without installing OpenCode
    $0 --version 2.0.0           # Install OpenCode 2.0.0

EOF
}

main() {
    local skip_submodules=false
    local skip_install=false
    local skip_config=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-submodules)
                skip_submodules=true
                shift
                ;;
            --skip-install)
                skip_install=true
                shift
                ;;
            --skip-config)
                skip_config=true
                shift
                ;;
            --version)
                OPENCODE_VERSION="$2"
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    log "Starting OpenCode Harness setup..."
    echo ""
    
    check_prerequisites || exit 1
    
    if [[ "$skip_submodules" == false ]]; then
        init_submodules || exit 1
    else
        log_info "Skipping submodule initialization (--skip-submodules)"
    fi
    
    validate_config || exit 1
    
    if [[ "$skip_install" == false ]]; then
        install_opencode || exit 1
    else
        log_info "Skipping OpenCode installation (--skip-install)"
    fi
    
    if [[ "$skip_config" == false ]]; then
        setup_opencode_config || true
    else
        log_info "Skipping OpenCode config setup (--skip-config)"
    fi
    
    verify_installation || exit 1
    
    print_summary
    
    log_success "Setup completed successfully!"
}

main "$@"
