#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly FIX_MODE="${1:-}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

# Logging functions
log() {
    echo -e "${BLUE}[CHECK]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((CHECKS_PASSED++)) || true
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((CHECKS_FAILED++)) || true
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    ((CHECKS_WARNED++)) || true
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check if required tools are installed
check_tools() {
    log_section "Checking Required Tools"

    local tools=("jq" "git")
    local missing=()

    for tool in "${tools[@]}"; do
        if command -v "${tool}" &>/dev/null; then
            log_pass "${tool} is installed"
        else
            log_fail "${tool} is not installed"
            missing+=("${tool}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_fail "Missing required tools: ${missing[*]}"
        return 1
    fi
}

# Validate JSON configuration files
validate_json() {
    log_section "Validating JSON Configuration"

    local json_files=(
        "${PROJECT_ROOT}/build/.opencode/opencode.json"
    )

    for file in "${json_files[@]}"; do
        if [[ -f "${file}" ]]; then
            if jq empty "${file}" 2>/dev/null; then
                log_pass "Valid JSON: ${file##*/}"

                # Check for $schema field
                if jq -e '."$schema"' "${file}" &>/dev/null; then
                    log_pass "Has \$schema: ${file##*/}"
                else
                    log_warn "Missing \$schema field: ${file##*/}"
                fi

                # Check for plugin field
                if jq -e '.plugin' "${file}" &>/dev/null; then
                    local plugin_count
                    plugin_count=$(jq '.plugin | length' "${file}")
                    log_pass "Has ${plugin_count} plugins configured: ${file##*/}"
                else
                    log_fail "Missing 'plugin' field: ${file##*/}"
                fi
            else
                log_fail "Invalid JSON: ${file##*/}"
            fi
        else
            log_fail "File not found: ${file}"
        fi
    done
}

# Validate file permissions
validate_permissions() {
    log_section "Validating File Permissions"

    local executable_scripts=(
        "${PROJECT_ROOT}/scripts/local-setup.sh"
        "${PROJECT_ROOT}/build/entrypoint.sh"
    )

    for script in "${executable_scripts[@]}"; do
        if [[ -f "${script}" ]]; then
            if [[ -x "${script}" ]]; then
                log_pass "Executable: ${script##*/}"
            else
                if [[ "${FIX_MODE}" == "--fix" ]]; then
                    chmod +x "${script}"
                    log_pass "Fixed permissions: ${script##*/}"
                else
                    log_fail "Not executable: ${script##*/}"
                    log "Run with --fix to auto-fix permissions"
                fi
            fi
        fi
    done
}

# Validate git submodules
validate_submodules() {
    log_section "Validating Git Submodules"

    cd "${PROJECT_ROOT}"

    # Check if .gitmodules exists
    if [[ ! -f ".gitmodules" ]]; then
        log_warn "No .gitmodules file found"
        return 0
    fi

    log_pass ".gitmodules file found"

    # Check if submodules are initialized
    local submodule_status
    submodule_status=$(git submodule status 2>/dev/null || echo "")

    if [[ -z "${submodule_status}" ]]; then
        log_warn "No submodules configured"
        return 0
    fi

    # Check each submodule
    while IFS= read -r line; do
        local status="${line:0:1}"
        local path="${line:1}"
        path="${path#* }"
        path="${path%% *}"

        case "${status}" in
            " ")
                log_pass "Submodule initialized: ${path}"
                ;;
            "-")
                log_fail "Submodule not initialized: ${path}"
                ;;
            "+")
                log_warn "Submodule has changes: ${path}"
                ;;
            "U")
                log_fail "Submodule has merge conflicts: ${path}"
                ;;
        esac
    done <<< "${submodule_status}"
}

# Validate Containerfile
validate_containerfile() {
    log_section "Validating Containerfile"

    local containerfile="${PROJECT_ROOT}/build/Containerfile"

    if [[ ! -f "${containerfile}" ]]; then
        log_fail "Containerfile not found"
        return 1
    fi

    log_pass "Containerfile exists"

    # Check for best practices
    local checks=(
        "FROM.*ubuntu:25.10:Base image uses pinned version"
        "FROM.*@sha256:.*AS tools:Builder image uses SHA digest"
        "USER opencode:Runs as non-root user"
        "rm -rf /var/lib/apt/lists/\*:Cleans apt cache"
        "set -euo pipefail:Error handling in scripts"
    )

    for check in "${checks[@]}"; do
        local pattern="${check%%:*}"
        local description="${check##*:}"

        if grep -qE "${pattern}" "${containerfile}" 2>/dev/null; then
            log_pass "${description}"
        else
            log_warn "Missing: ${description}"
        fi
    done

    # Check for anti-patterns - only flag :latest on final runtime images (not builder stages)
    # Builder stages with :latest are acceptable (e.g., FROM image:latest AS builder)
    local final_from_line
    final_from_line=$(grep -E "^FROM" "${containerfile}" | tail -1)

    if echo "${final_from_line}" | grep -qE "ubuntu:latest|debian:latest|alpine:latest"; then
        log_fail "Final runtime image uses :latest tag (should use pinned version)"
    else
        log_pass "Final runtime image uses pinned version"
    fi
}

# Validate project structure
validate_structure() {
    log_section "Validating Project Structure"

    local required_files=(
        "build/Containerfile"
        "build/.opencode/opencode.json"
        "build/etc/opencode/opencode.jsonc"
        "scripts/local-setup.sh"
        "build/entrypoint.sh"
        "README.md"
        "AGENTS.md"
    )

    local required_dirs=(
        "build/etc"
        "build/modules"
        "scripts"
    )

    for file in "${required_files[@]}"; do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            log_pass "File exists: ${file}"
        else
            log_fail "File missing: ${file}"
        fi
    done

    for dir in "${required_dirs[@]}"; do
        if [[ -d "${PROJECT_ROOT}/${dir}" ]]; then
            log_pass "Directory exists: ${dir}"
        else
            log_warn "Directory missing: ${dir}"
        fi
    done
}

# Print summary
print_summary() {
    log_section "Validation Summary"

    local total=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNED))

    echo ""
    echo "  Total checks: ${total}"
    echo -e "  ${GREEN}Passed:        ${CHECKS_PASSED}${NC}"
    echo -e "  ${RED}Failed:        ${CHECKS_FAILED}${NC}"
    echo -e "  ${YELLOW}Warnings:      ${CHECKS_WARNED}${NC}"
    echo ""

    if [[ "${CHECKS_FAILED}" -eq 0 ]]; then
        echo -e "${GREEN}✅ All critical validations passed!${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ Some validations failed. Please fix the issues above.${NC}"
        echo ""
        return 1
    fi
}

# Print usage
print_usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS]

OpenCode Harness - Pre-build Validation Script

Options:
    --fix       Attempt to fix fixable issues (e.g., file permissions)
    -h, --help  Show this help message

Exit Codes:
    0   All critical validations passed
    1   One or more critical validations failed
EOF
}

# Main function
main() {
    # Parse arguments
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        print_usage
        exit 0
    fi

    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        OpenCode Harness - Validation Suite                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Project Root: ${PROJECT_ROOT}"
    echo "Fix Mode:     ${FIX_MODE:-disabled}"
    echo ""

    # Run validations
    check_tools || true
    validate_json
    validate_permissions
    validate_submodules
    validate_containerfile
    validate_structure

    # Print summary
    print_summary
}

main "$@"
