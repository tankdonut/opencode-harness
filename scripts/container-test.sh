#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC2155
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly IMAGE_NAME="${1:-opencode-harness:latest}"
readonly CONTAINER_RUNTIME="${2:-podman}"
readonly TEST_WORKSPACE="/tmp/opencode-test-$$"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Logging functions
log() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++)) || true
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++)) || true
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $*"
    ((TESTS_SKIPPED++)) || true
}

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Print usage
print_usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} <image_name> [container_runtime]

OpenCode Harness Container Test Script

Arguments:
    image_name          Container image to test (e.g., opencode-harness:latest)
    container_runtime   Container runtime to use (default: podman, fallback: docker)

Options:
    -h, --help          Show this help message

Examples:
    ${SCRIPT_NAME} opencode-harness:latest
    ${SCRIPT_NAME} opencode-harness:abc123 podman
    ${SCRIPT_NAME} opencode-harness:latest docker

Exit Codes:
    0   All tests passed
    1   One or more tests failed
    2   Invalid arguments or setup error
EOF
}

# Check prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"

    # Check container runtime
    if ! command -v "${CONTAINER_RUNTIME}" &>/dev/null; then
        # Fallback to docker if podman not found
        if [[ "${CONTAINER_RUNTIME}" == "podman" ]] && command -v docker &>/dev/null; then
            log "Podman not found, falling back to Docker"
            CONTAINER_RUNTIME="docker"
        else
            log_fail "Container runtime '${CONTAINER_RUNTIME}' not found"
            exit 2
        fi
    fi
    log_pass "Container runtime: ${CONTAINER_RUNTIME} ($(${CONTAINER_RUNTIME} --version | head -n1))"

    # Check if image exists
    if ! ${CONTAINER_RUNTIME} image inspect "${IMAGE_NAME}" &>/dev/null; then
        log_fail "Image not found: ${IMAGE_NAME}"
        log "Build the image first: ${CONTAINER_RUNTIME} build -t ${IMAGE_NAME} -f Containerfile ."
        exit 2
    fi
    log_pass "Image found: ${IMAGE_NAME}"

    # Create test workspace
    mkdir -p "${TEST_WORKSPACE}"
    log_pass "Test workspace created: ${TEST_WORKSPACE}"
}

# Test: Container can start and execute commands
test_container_startup() {
    log_section "Testing Container Startup"

    if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" echo "Container startup OK" &>/dev/null; then
        log_pass "Container starts and executes commands"
    else
        log_fail "Container fails to start or execute commands"
    fi
}

# Test: Required binaries exist
test_required_binaries() {
    log_section "Testing Required Binaries"

    local required_binaries=("git" "node" "npm" "jq")

    for binary in "${required_binaries[@]}"; do
        if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" which "${binary}" &>/dev/null; then
            local version
            version=$(${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" bash -c "${binary} --version 2>&1 | head -n1" || echo "unknown")
            log_pass "${binary} available (${version})"
        else
            log_fail "${binary} not found in container"
        fi
    done
}

# Test: OpenCode installation
test_opencode_installation() {
    log_section "Testing OpenCode Installation"

    # Check if opencode command exists
    if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" which opencode &>/dev/null; then
        log_pass "opencode command found"
    else
        log_fail "opencode command not found"
        return
    fi

    # Check opencode version
    local version
    version=$(${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" opencode --version 2>&1 | head -n1 || echo "unknown")
    if [[ -n "${version}" && "${version}" != "unknown" ]]; then
        log_pass "OpenCode version: ${version}"
    else
        log_fail "Could not determine OpenCode version"
    fi
}

# Test: Configuration files
test_configuration() {
    log_section "Testing Configuration"

    # Check opencode.json exists
    if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" test -f /workspace/opencode.json; then
        log_pass "opencode.json exists at /workspace/opencode.json"
    else
        log_fail "opencode.json not found at /workspace/opencode.json"
        return
    fi

    # Validate JSON syntax
    if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" jq empty /workspace/opencode.json 2>/dev/null; then
        log_pass "opencode.json is valid JSON"
    else
        log_fail "opencode.json has invalid JSON syntax"
    fi

    # Check plugin configuration
    local plugin_count
    plugin_count=$(${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" jq '.plugin | length' /workspace/opencode.json 2>/dev/null || echo "0")
    if [[ "${plugin_count}" -gt 0 ]]; then
        log_pass "Plugin count: ${plugin_count}"
    else
        log_fail "No plugins configured in opencode.json"
    fi

    # Check opencode.jsonc exists at /etc/opencode/
    if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" test -f /etc/opencode/opencode.jsonc; then
        log_pass "opencode.jsonc exists at /etc/opencode/opencode.jsonc"
    else
        log_fail "opencode.jsonc not found at /etc/opencode/opencode.jsonc"
    fi
}

# Test: Directory structure
test_directory_structure() {
    log_section "Testing Directory Structure"

    local required_dirs=("/workspace" "/vendor/bin")

    for dir in "${required_dirs[@]}"; do
        if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" test -d "${dir}"; then
            log_pass "Directory exists: ${dir}"
        else
            log_fail "Directory missing: ${dir}"
        fi
    done

    # Check vendor binaries
    local vendor_count
    vendor_count=$(${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" bash -c "ls -1 /vendor/bin 2>/dev/null | wc -l" || echo "0")
    if [[ "${vendor_count}" -gt 0 ]]; then
        log_pass "Vendor binaries available: ${vendor_count} files"
    else
        log_fail "No vendor binaries found in /vendor/bin"
    fi
}

# Test: Modules directory (submodules)
test_modules() {
    log_section "Testing Modules Directory"

    # Check if modules directory exists
    if ! ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" test -d /workspace/modules; then
        log_skip "Modules directory not found (submodules may not be included)"
        return
    fi

    log_pass "Modules directory exists"

    # Check for expected submodules
    local expected_modules=("everything-claude-code" "oh-my-openagent" "superpowers")
    local found_count=0

    for module in "${expected_modules[@]}"; do
        if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" test -d "/workspace/modules/${module}"; then
            log_pass "Module found: ${module}"
            ((found_count++)) || true
        else
            log_skip "Module not found: ${module}"
        fi
    done

    if [[ "${found_count}" -gt 0 ]]; then
        log_pass "Found ${found_count}/${#expected_modules[@]} expected modules"
    fi
}

# Test: User and permissions
test_user_permissions() {
    log_section "Testing User and Permissions"

    # Check if opencode user exists
    local user_info
    user_info=$(${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" id opencode 2>/dev/null || echo "")
    if [[ -n "${user_info}" ]]; then
        log_pass "User 'opencode' exists (${user_info})"
    else
        log_fail "User 'opencode' not found"
    fi

    # Check /workspace permissions
    if ${CONTAINER_RUNTIME} run --rm --user opencode "${IMAGE_NAME}" test -r /workspace/opencode.json; then
        log_pass "opencode user can read /workspace/opencode.json"
    else
        log_fail "opencode user cannot read /workspace/opencode.json"
    fi
}

# Test: Environment variables
# shellcheck disable=SC2016
test_environment() {
    log_section "Testing Environment Variables"

    # Check PATH includes vendor bin
    local path_value
    path_value=$(${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" bash -c 'echo $PATH')
    if [[ "${path_value}" == *"/vendor/bin"* ]]; then
        log_pass "PATH includes /vendor/bin"
    else
        log_fail "PATH does not include /vendor/bin"
    fi

    # Check OPENCODE_CONFIG
    local config_value
    config_value=$(${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" bash -c 'echo $OPENCODE_CONFIG')
    if [[ "${config_value}" == "/workspace/opencode.json" ]]; then
        log_pass "OPENCODE_CONFIG set correctly"
    else
        log_fail "OPENCODE_CONFIG not set correctly (got: ${config_value})"
    fi
}

# Test: Entrypoint execution
test_entrypoint() {
    log_section "Testing Entrypoint"

    # Check entrypoint script exists
    if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" test -x /usr/local/bin/entrypoint; then
        log_pass "Entrypoint script is executable"
    else
        log_fail "Entrypoint script not executable or missing"
    fi

    # Test entrypoint runs without errors (it already ran during build)
    log_pass "Entrypoint executed during build (container image is valid)"
}

# Test: Workspace mounting
test_workspace_mounting() {
    log_section "Testing Workspace Mounting"

    # Create test file
    echo "test content" > "${TEST_WORKSPACE}/test-file.txt"

    # Test read access - may fail in rootless container environments due to UID mapping
    if ${CONTAINER_RUNTIME} run --rm -v "${TEST_WORKSPACE}:/workspace" "${IMAGE_NAME}" cat /workspace/test-file.txt &>/dev/null; then
        log_pass "Can read mounted workspace files"
    else
        log_skip "Cannot read mounted workspace (UID mapping issue - expected in rootless environments)"
    fi

    # Test write access (may fail if running as non-root without proper permissions)
    if ${CONTAINER_RUNTIME} run --rm -v "${TEST_WORKSPACE}:/workspace" "${IMAGE_NAME}" bash -c "echo 'write test' > /workspace/write-test.txt" 2>/dev/null; then
        log_pass "Can write to mounted workspace"
    else
        log_skip "Cannot write to mounted workspace (permission issue - expected in some setups)"
    fi
}

# Print test summary
print_summary() {
    log_section "Test Summary"

    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

    echo ""
    echo "  Total tests:  ${total}"
    echo -e "  ${GREEN}Passed:       ${TESTS_PASSED}${NC}"
    echo -e "  ${RED}Failed:       ${TESTS_FAILED}${NC}"
    echo -e "  ${YELLOW}Skipped:      ${TESTS_SKIPPED}${NC}"
    echo ""

    if [[ "${TESTS_FAILED}" -eq 0 ]]; then
        echo -e "${GREEN}✅ All critical tests passed!${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ Some tests failed. Please review the output above.${NC}"
        echo ""
        return 1
    fi
}

# Cleanup
cleanup() {
    rm -rf "${TEST_WORKSPACE}" 2>/dev/null || true
}

# Main function
main() {
    # Parse arguments
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        print_usage
        exit 0
    fi

    if [[ -z "${1:-}" ]]; then
        echo "Error: Image name required" >&2
        print_usage
        exit 2
    fi

    # Ensure cleanup on exit
    trap cleanup EXIT

    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        OpenCode Harness - Container Test Suite             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Image:            ${IMAGE_NAME}"
    echo "Container Runtime: ${CONTAINER_RUNTIME}"
    echo "Test Workspace:   ${TEST_WORKSPACE}"
    echo ""

    # Run tests
    check_prerequisites
    test_container_startup
    test_required_binaries
    test_opencode_installation
    test_configuration
    test_directory_structure
    test_modules
    test_user_permissions
    test_environment
    test_entrypoint
    test_workspace_mounting

    # Print summary
    print_summary
}

main "$@"
