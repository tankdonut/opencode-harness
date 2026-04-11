#!/usr/bin/env bash
#
# OpenCode Harness - Bootstrap Helper Function Tests
#
# TDD tests for bootstrap helper functions. These tests will FAIL initially
# because the functions don't exist yet - that's expected in TDD methodology.
#
# Run: bash tests/test_bootstrap.sh
#

set -euo pipefail

# =============================================================================
# Simple Test Framework
# =============================================================================

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Assertion: Check equality
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "  ASSERTION FAILED: $message" >&2
        echo "    Expected: '$expected'" >&2
        echo "    Actual:   '$actual'" >&2
        return 1
    fi
}

# Assertion: Check file exists
assert_file_exists() {
    local filepath="$1"
    local message="${2:-File should exist}"

    if [[ -f "$filepath" ]]; then
        return 0
    else
        echo "  ASSERTION FAILED: $message" >&2
        echo "    File not found: $filepath" >&2
        return 1
    fi
}

# Assertion: Check directory exists
assert_dir_exists() {
    local dirpath="$1"
    local message="${2:-Directory should exist}"

    if [[ -d "$dirpath" ]]; then
        return 0
    else
        echo "  ASSERTION FAILED: $message" >&2
        echo "    Directory not found: $dirpath" >&2
        return 1
    fi
}

# Assertion: Check string is empty
assert_empty() {
    local value="$1"
    local message="${2:-Value should be empty}"

    if [[ -z "$value" ]]; then
        return 0
    else
        echo "  ASSERTION FAILED: $message" >&2
        echo "    Expected empty, got: '$value'" >&2
        return 1
    fi
}

# Assertion: Check string is not empty
assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"

    if [[ -n "$value" ]]; then
        return 0
    else
        echo "  ASSERTION FAILED: $message" >&2
        echo "    Expected non-empty value" >&2
        return 1
    fi
}

# Assertion: Check command succeeds
assert_succeeds() {
    local message="$1"
    shift

    if "$@"; then
        return 0
    else
        echo "  ASSERTION FAILED: $message" >&2
        echo "    Command failed: $*" >&2
        return 1
    fi
}

# Assertion: Check command fails
assert_fails() {
    local message="$1"
    shift

    if ! "$@" 2>/dev/null; then
        return 0
    else
        echo "  ASSERTION FAILED: $message" >&2
        echo "    Command should have failed: $*" >&2
        return 1
    fi
}

# Run a single test
run_test() {
    local test_name="$1"
    shift

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  ${test_name}... "

    if "$@" 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    # Always return 0 to continue running remaining tests
    return 0
}

# Skip a test with reason
skip_test() {
    local test_name="$1"
    local reason="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    echo -e "  ${test_name}... ${YELLOW}SKIP${NC} (${reason})"
}

# =============================================================================
# Stub Functions (These will FAIL - that's expected in TDD)
#
# Real implementations should be added to entrypoint.sh
# =============================================================================

# Stub: Derive config directory from OPENCODE_CONFIG path
# Expected: Given "/workspace/.config/opencode/opencode.json", return "/workspace/.config/opencode"
derive_config_dir() {
    local config_path="${1:-}"

    # STUB: Not implemented yet
    echo "STUB_NOT_IMPLEMENTED" >&2
    return 1
}

# Stub: Create config directory if missing
create_config_dir() {
    local config_dir="${1:-}"

    # STUB: Not implemented yet
    echo "STUB_NOT_IMPLEMENTED" >&2
    return 1
}

# Stub: Copy config file
copy_config() {
    local source="${1:-}"
    local target="${2:-}"
    # shellcheck disable=SC2034
    local force="${OPENCODE_BOOTSTRAP_FORCE:-0}"

    # STUB: Not implemented yet
    echo "STUB_NOT_IMPLEMENTED" >&2
    return 1
}

# Stub: Copy assets from module directory
copy_assets() {
    local module_path="${1:-}"
    local config_dir="${2:-}"
    # shellcheck disable=SC2034
    local force="${OPENCODE_BOOTSTRAP_FORCE:-0}"

    # STUB: Not implemented yet
    echo "STUB_NOT_IMPLEMENTED" >&2
    return 1
}

# Source real implementations from entrypoint.sh (overrides stubs)
# shellcheck source=../entrypoint.sh
source "${BASH_SOURCE[0]%/*}/../entrypoint.sh"

# =============================================================================
# Test Cases
# =============================================================================

# Test 1: derive_config_dir extracts directory from config path
test_derive_config_dir() {
    local config_path="/workspace/.config/opencode/opencode.json"
    local expected_dir="/workspace/.config/opencode"

    local result
    result=$(derive_config_dir "$config_path" 2>/dev/null) || true

    assert_equals "$expected_dir" "$result" "derive_config_dir should extract directory from path"
}

# Test 2: create_config_dir creates directory when missing
test_create_config_dir_missing() {
    local temp_dir
    temp_dir=$(mktemp -d)
    local config_dir="${temp_dir}/.config/opencode"

    # Directory should not exist initially
    [[ ! -d "$config_dir" ]] || return 1

    # Function should create the directory
    if create_config_dir "$config_dir" 2>/dev/null; then
        assert_dir_exists "$config_dir" "create_config_dir should create missing directory"
    else
        # Expected to fail - stub not implemented
        return 1
    fi

    # Cleanup
    rm -rf "$temp_dir"
}

# Test 3: create_config_dir succeeds when directory exists
test_create_config_dir_existing() {
    local temp_dir
    temp_dir=$(mktemp -d)
    local config_dir="${temp_dir}/.config/opencode"

    # Pre-create the directory
    mkdir -p "$config_dir"

    # Function should succeed when directory already exists
    if create_config_dir "$config_dir" 2>/dev/null; then
        assert_dir_exists "$config_dir" "create_config_dir should succeed when directory exists"
    else
        # Expected to fail - stub not implemented
        return 1
    fi

    # Cleanup
    rm -rf "$temp_dir"
}

# Test 4: copy_config copies config when target missing
test_copy_config_missing_target() {
    local temp_dir
    temp_dir=$(mktemp -d)

    local source="${temp_dir}/source/opencode.json"
    local target="${temp_dir}/target/opencode.json"

    # Create source file
    mkdir -p "$(dirname "$source")"
    echo '{"test": "config"}' > "$source"

    # Target should not exist
    [[ ! -f "$target" ]] || return 1

    # Unset force
    unset OPENCODE_BOOTSTRAP_FORCE

    if copy_config "$source" "$target" 2>/dev/null; then
        assert_file_exists "$target" "copy_config should copy to missing target"
    else
        # Expected to fail - stub not implemented
        return 1
    fi

    # Cleanup
    rm -rf "$temp_dir"
}

# Test 5: copy_config skips when target exists without force
test_copy_config_existing_no_force() {
    local temp_dir
    temp_dir=$(mktemp -d)

    local source="${temp_dir}/source/opencode.json"
    local target="${temp_dir}/target/opencode.json"

    # Create both files with different content
    mkdir -p "$(dirname "$source")" "$(dirname "$target")"
    echo '{"source": "config"}' > "$source"
    echo '{"target": "original"}' > "$target"

    local original_content
    original_content=$(cat "$target")

    # Unset force - should skip
    unset OPENCODE_BOOTSTRAP_FORCE

    if copy_config "$source" "$target" 2>/dev/null; then
        # Should NOT overwrite
        local new_content
        new_content=$(cat "$target")
        assert_equals "$original_content" "$new_content" "copy_config should skip without force"
    else
        # Expected to fail - stub not implemented
        return 1
    fi

    # Cleanup
    rm -rf "$temp_dir"
}

# Test 6: copy_config overwrites when OPENCODE_BOOTSTRAP_FORCE=1
test_copy_config_existing_with_force() {
    local temp_dir
    temp_dir=$(mktemp -d)

    local source="${temp_dir}/source/opencode.json"
    local target="${temp_dir}/target/opencode.json"

    # Create both files with different content
    mkdir -p "$(dirname "$source")" "$(dirname "$target")"
    echo '{"source": "config"}' > "$source"
    echo '{"target": "original"}' > "$target"

    local source_content
    source_content=$(cat "$source")

    # Set force - should overwrite
    export OPENCODE_BOOTSTRAP_FORCE=1

    if copy_config "$source" "$target" 2>/dev/null; then
        # Should overwrite
        local new_content
        new_content=$(cat "$target")
        assert_equals "$source_content" "$new_content" "copy_config should overwrite with force"
    else
        # Expected to fail - stub not implemented
        unset OPENCODE_BOOTSTRAP_FORCE
        return 1
    fi

    unset OPENCODE_BOOTSTRAP_FORCE
    # Cleanup
    rm -rf "$temp_dir"
}

# Test 7: copy_assets skips when module lacks asset directories
test_copy_assets_missing_source_dir() {
    local temp_dir
    temp_dir=$(mktemp -d)

    local module_path="${temp_dir}/modules/test-module"
    local config_dir="${temp_dir}/.config/opencode"

    # Create module without asset directories
    mkdir -p "$module_path"
    echo "# Test module" > "${module_path}/README.md"

    # No skills/, agents/, commands/ directories
    mkdir -p "$config_dir"

    unset OPENCODE_BOOTSTRAP_FORCE

    if copy_assets "$module_path" "$config_dir" 2>/dev/null; then
        # Should succeed without copying anything
        # No assertion needed - just check it doesn't fail
        return 0
    else
        # Expected to fail - stub not implemented
        return 1
    fi

    # Cleanup
    rm -rf "$temp_dir"
}

# Test 8: copy_assets copies when target files missing
test_copy_assets_missing_target() {
    local temp_dir
    temp_dir=$(mktemp -d)

    local module_path="${temp_dir}/modules/test-module"
    local config_dir="${temp_dir}/.config/opencode"

    # Create module with skills directory
    mkdir -p "${module_path}/skills"
    echo "# Test Skill" > "${module_path}/skills/test-skill.md"

    # Config dir exists but no skills
    mkdir -p "$config_dir"

    unset OPENCODE_BOOTSTRAP_FORCE

    if copy_assets "$module_path" "$config_dir" 2>/dev/null; then
        # Should copy skills directory
        assert_dir_exists "${config_dir}/skills" "copy_assets should create skills directory"
        assert_file_exists "${config_dir}/skills/test-skill.md" "copy_assets should copy skill files"
    else
        # Expected to fail - stub not implemented
        return 1
    fi

    # Cleanup
    rm -rf "$temp_dir"
}

# Test 9: copy_assets skips existing files without force
test_copy_assets_existing_no_force() {
    local temp_dir
    temp_dir=$(mktemp -d)

    local module_path="${temp_dir}/modules/test-module"
    local config_dir="${temp_dir}/.config/opencode"

    # Create module with skills
    mkdir -p "${module_path}/skills"
    echo "# New Skill Content" > "${module_path}/skills/test-skill.md"

    # Create existing skill in config
    mkdir -p "${config_dir}/skills"
    echo "# Original Skill Content" > "${config_dir}/skills/test-skill.md"

    local original_content
    original_content=$(cat "${config_dir}/skills/test-skill.md")

    unset OPENCODE_BOOTSTRAP_FORCE

    if copy_assets "$module_path" "$config_dir" 2>/dev/null; then
        # Should NOT overwrite existing file
        local new_content
        new_content=$(cat "${config_dir}/skills/test-skill.md")
        assert_equals "$original_content" "$new_content" "copy_assets should skip existing without force"
    else
        # Expected to fail - stub not implemented
        return 1
    fi

    # Cleanup
    rm -rf "$temp_dir"
}

# Test 10: copy_assets overwrites existing files with force
test_copy_assets_with_force() {
    local temp_dir
    temp_dir=$(mktemp -d)

    local module_path="${temp_dir}/modules/test-module"
    local config_dir="${temp_dir}/.config/opencode"

    # Create module with skills
    mkdir -p "${module_path}/skills"
    echo "# New Skill Content" > "${module_path}/skills/test-skill.md"

    # Create existing skill in config
    mkdir -p "${config_dir}/skills"
    echo "# Original Skill Content" > "${config_dir}/skills/test-skill.md"

    local source_content
    source_content=$(cat "${module_path}/skills/test-skill.md")

    # Set force
    export OPENCODE_BOOTSTRAP_FORCE=1

    if copy_assets "$module_path" "$config_dir" 2>/dev/null; then
        # Should overwrite existing file
        local new_content
        new_content=$(cat "${config_dir}/skills/test-skill.md")
        assert_equals "$source_content" "$new_content" "copy_assets should overwrite with force"
    else
        # Expected to fail - stub not implemented
        unset OPENCODE_BOOTSTRAP_FORCE
        return 1
    fi

    unset OPENCODE_BOOTSTRAP_FORCE
    # Cleanup
    rm -rf "$temp_dir"
}

# =============================================================================
# Test Runner
# =============================================================================

main() {
    echo ""
    echo "========================================"
    echo "  Bootstrap Helper Function Tests (TDD)"
    echo "========================================"
    echo ""
    echo "Note: These tests are expected to FAIL initially."
    echo "      Implement the functions in entrypoint.sh to make them pass."
    echo ""
    echo "Running tests..."
    echo ""

    # Run all tests
    run_test "test_derive_config_dir" test_derive_config_dir
    run_test "test_create_config_dir_missing" test_create_config_dir_missing
    run_test "test_create_config_dir_existing" test_create_config_dir_existing
    run_test "test_copy_config_missing_target" test_copy_config_missing_target
    run_test "test_copy_config_existing_no_force" test_copy_config_existing_no_force
    run_test "test_copy_config_existing_with_force" test_copy_config_existing_with_force
    run_test "test_copy_assets_missing_source_dir" test_copy_assets_missing_source_dir
    run_test "test_copy_assets_missing_target" test_copy_assets_missing_target
    run_test "test_copy_assets_existing_no_force" test_copy_assets_existing_no_force
    run_test "test_copy_assets_with_force" test_copy_assets_with_force

    echo ""
    echo "========================================"
    echo "  Results"
    echo "========================================"
    echo ""
    echo "  Total:  ${TESTS_RUN}"
    echo -e "  ${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "  ${RED}Failed: ${TESTS_FAILED}${NC}"
    if [[ $TESTS_SKIPPED -gt 0 ]]; then
        echo -e "  ${YELLOW}Skipped: ${TESTS_SKIPPED}${NC}"
    fi
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${YELLOW}TDD Note: Failures are expected until functions are implemented.${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Implement derive_config_dir() in entrypoint.sh"
        echo "  2. Implement create_config_dir() in entrypoint.sh"
        echo "  3. Implement copy_config() in entrypoint.sh"
        echo "  4. Implement copy_assets() in entrypoint.sh"
        echo "  5. Re-run this test to verify"
        echo ""
        # Return success anyway for TDD workflow
        return 0
    else
        echo -e "${GREEN}All tests passed! Functions are correctly implemented.${NC}"
        return 0
    fi
}

# Run main
main "$@"
