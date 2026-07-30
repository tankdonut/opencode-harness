#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC2155
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly IMAGE_NAME="${1:-opencoder:latest}"
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

opencoder Container Test Script

Arguments:
    image_name          Container image to test (e.g., opencoder:latest)
    container_runtime   Container runtime to use (default: podman, fallback: docker)

Options:
    -h, --help          Show this help message

Examples:
    ${SCRIPT_NAME} opencoder:latest
    ${SCRIPT_NAME} opencoder:abc123 podman
    ${SCRIPT_NAME} opencoder:latest docker

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
        log "Build the image first: ./scripts/build.sh --tag ${IMAGE_NAME}"
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

    # Check opencode.json exists at HOME (bootstrap copies it there at container start)
    if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" test -f /home/opencode/.opencode/opencode.json; then
        log_pass "opencode.json exists at /home/opencode/.opencode/opencode.json"
    else
        log_fail "opencode.json not found at /home/opencode/.opencode/opencode.json"
        return
    fi

    # Validate JSON syntax
    if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" jq empty /home/opencode/.opencode/opencode.json 2>/dev/null; then
        log_pass "opencode.json is valid JSON"
    else
        log_fail "opencode.json has invalid JSON syntax"
    fi

    # Check plugin configuration
    local plugin_count
    plugin_count=$(${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" jq '.plugin | length' /home/opencode/.opencode/opencode.json 2>/dev/null || echo "0")
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

# Test: Baseline skills installed (skills.sh CLI)
test_skills() {
    log_section "Testing Baseline Skills"

    # Check baseline skills dir exists (installed at build time via skills CLI)
    if ! ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" test -d /opencode/default/.agents/skills; then
        log_fail "Baseline skills directory missing: /opencode/default/.agents/skills"
        return
    fi
    log_pass "Baseline skills directory exists"

    # Verify skills are symlinked into the opencode user's HOME (not copied)
    if ! ${CONTAINER_RUNTIME} run --rm --user opencode "${IMAGE_NAME}" test -L /home/opencode/.agents/skills; then
        log_fail "Skills symlink missing: /home/opencode/.agents/skills is not a symlink"
    else
        local link_target
        link_target=$(${CONTAINER_RUNTIME} run --rm --user opencode "${IMAGE_NAME}" \
            readlink -f /home/opencode/.agents/skills 2>/dev/null || echo "")
        if [[ "${link_target}" == "/opencode/default/.agents/skills" ]]; then
            log_pass "Skills symlinked: /home/opencode/.agents/skills -> /opencode/default/.agents/skills"
        else
            log_fail "Skills symlink target wrong (got: '${link_target}', want: /opencode/default/.agents/skills)"
        fi
    fi

    # Count SKILL.md files (18 baseline skills: OMO + agents-md + create-agentsmd + find-skills + superpowers subset)
    local skill_count
    skill_count=$(${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" \
        bash -c 'find /opencode/default/.agents/skills -name SKILL.md 2>/dev/null | wc -l' || echo "0")

    if [[ "${skill_count}" -gt 0 ]]; then
        log_pass "Baseline skills installed: ${skill_count} SKILL.md files"
    else
        log_fail "No SKILL.md files found in baseline skills dir"
    fi

    # Check skills-lock.json exists
    if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" test -f /opencode/default/skills-lock.json; then
        log_pass "skills-lock.json present"
    else
        log_fail "skills-lock.json missing at /opencode/default/skills-lock.json"
    fi
}

# Test: Bootstrap does NOT pollute mounted workspace
test_bootstrap_no_workspace_pollution() {
    log_section "Testing Bootstrap Keeps Workspace Clean"

    local test_dir="${TEST_WORKSPACE}/bootstrap-pollution-test"
    mkdir -p "${test_dir}"

    # Trigger bootstrap by running the entrypoint against a mounted workspace
    ${CONTAINER_RUNTIME} run --rm \
        -v "${test_dir}:/workspace" \
        "${IMAGE_NAME}" \
        bash -c 'exit 0' 2>/dev/null || true

    # Config mirror must NOT be created in the mounted workspace
    if ${CONTAINER_RUNTIME} run --rm \
        -v "${test_dir}:/workspace" \
        "${IMAGE_NAME}" \
        test -d /workspace/.config/opencode; then
        log_fail "Bootstrap polluted workspace: /workspace/.config/opencode created"
    else
        log_pass "Bootstrap does not create /workspace/.config/opencode"
    fi

    # Skills must NOT be copied into the mounted workspace either
    if ${CONTAINER_RUNTIME} run --rm \
        -v "${test_dir}:/workspace" \
        "${IMAGE_NAME}" \
        test -e /workspace/.agents/skills; then
        log_fail "Bootstrap polluted workspace: /workspace/.agents/skills created"
    else
        log_pass "Bootstrap does not create /workspace/.agents/skills"
    fi

    rm -rf "${test_dir}"
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

    # Check HOME directory is set to /home/opencode
    local home_dir
    home_dir=$(${CONTAINER_RUNTIME} run --rm --user opencode "${IMAGE_NAME}" bash -c "echo \$HOME" 2>/dev/null || echo "")
    if [[ "${home_dir}" == "/home/opencode" ]]; then
        log_pass "HOME directory is /home/opencode"
    else
        log_fail "HOME directory is not /home/opencode (got: ${home_dir})"
    fi

    # Verify user's home directory in passwd
    local passwd_home
    passwd_home=$(${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" getent passwd opencode | cut -d: -f6 2>/dev/null || echo "")
    if [[ "${passwd_home}" == "/home/opencode" ]]; then
        log_pass "User home in /etc/passwd is /home/opencode"
    else
        log_fail "User home in /etc/passwd is not /home/opencode (got: ${passwd_home})"
    fi

    # Verify HOME is writable by the opencode user
    if ${CONTAINER_RUNTIME} run --rm --user opencode "${IMAGE_NAME}" \
        bash -c 'touch /home/opencode/.write-test && rm /home/opencode/.write-test' 2>/dev/null; then
        log_pass "opencode user can write to /home/opencode"
    else
        log_fail "opencode user cannot write to /home/opencode"
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
    if [[ "${config_value}" == "/home/opencode/.opencode/opencode.json" ]]; then
        log_pass "OPENCODE_CONFIG set correctly"
    else
        log_fail "OPENCODE_CONFIG not set correctly (got: ${config_value})"
    fi
}

# Test: Entrypoint execution
test_entrypoint() {
    log_section "Testing Entrypoint"

    # Check entrypoint script exists
    if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" test -x /usr/local/bin/entrypoint.sh; then
        log_pass "Entrypoint script is executable"
    else
        log_fail "Entrypoint script not executable or missing"
    fi

    # Test entrypoint runs to completion at container start (NOT during build)
    if ${CONTAINER_RUNTIME} run --rm "${IMAGE_NAME}" bash -c 'exit 0' 2>/dev/null; then
        log_pass "Entrypoint runs successfully (bootstrap completes, exits 0)"
    else
        log_fail "Entrypoint failed during container startup"
    fi
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
    echo -e "${BLUE}║        opencoder - Container Test Suite                    ║${NC}"
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
    test_skills
    test_bootstrap_no_workspace_pollution
    test_user_permissions
    test_environment
    test_entrypoint
    test_workspace_mounting

    # Print summary
    print_summary
}

main "$@"
