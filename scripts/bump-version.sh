#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly VERSION_FILE="${PROJECT_ROOT}/build/.opencode-version"
readonly CHECKSUM_FILE="${PROJECT_ROOT}/build/.opencode-checksums"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[BUMP]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

print_usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] [VERSION]

OpenCode Harness - Version Bump Script

Bumps the OpenCode version in build/.opencode-version and updates
SHA256 checksums in build/.opencode-checksums by fetching release
metadata from the GitHub Releases API.

Options:
    --latest    Auto-detect latest release version from GitHub
    --dry-run   Show changes without modifying files
    -h, --help  Show this help message

Arguments:
    VERSION     Explicit version number (e.g. 1.14.18 or v1.14.18)

Examples:
    $(basename "${BASH_SOURCE[0]}") 1.14.18
    $(basename "${BASH_SOURCE[0]}") v1.14.18
    $(basename "${BASH_SOURCE[0]}") --latest
    $(basename "${BASH_SOURCE[0]}") --dry-run 1.14.18
    $(basename "${BASH_SOURCE[0]}") --dry-run --latest

Exit Codes:
    0   Version bumped successfully
    1   Error occurred (missing args, invalid version, API failure)
EOF
}

# Script state
BUMP_VERSION=""
BUMP_USE_LATEST=false
BUMP_DRY_RUN=false
API_RESPONSE=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --latest)
                BUMP_USE_LATEST=true
                shift
                ;;
            --dry-run)
                BUMP_DRY_RUN=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            -*)
                log_fail "Unknown option: $1"
                print_usage >&2
                exit 1
                ;;
            *)
                if [[ -n "${BUMP_VERSION}" ]]; then
                    log_fail "Multiple version arguments provided"
                    print_usage >&2
                    exit 1
                fi
                BUMP_VERSION="$1"
                shift
                ;;
        esac
    done

    if [[ "${BUMP_USE_LATEST}" == false && -z "${BUMP_VERSION}" ]]; then
        log_fail "No version specified. Provide VERSION or use --latest."
        print_usage >&2
        exit 1
    fi
}

check_dependencies() {
    local tools=("curl" "jq")
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
        exit 1
    fi
}

strip_v_prefix() {
    local version="$1"
    echo "${version#v}"
}

validate_semver() {
    local version="$1"
    if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_fail "Invalid semver: '${version}' (expected X.Y.Z format)"
        exit 1
    fi
}

resolve_version() {
    if [[ "${BUMP_USE_LATEST}" == true ]]; then
        log "Fetching latest release from GitHub..."
        API_RESPONSE=$(curl -fsSL "https://api.github.com/repos/anomalyco/opencode/releases/latest")
        local tag_name
        tag_name=$(echo "${API_RESPONSE}" | jq -r '.tag_name')
        if [[ -z "${tag_name}" || "${tag_name}" == "null" ]]; then
            log_fail "Failed to extract tag_name from GitHub API response"
            exit 1
        fi
        BUMP_VERSION=$(strip_v_prefix "${tag_name}")
        log "Latest release: ${BUMP_VERSION}"
    else
        BUMP_VERSION=$(strip_v_prefix "${BUMP_VERSION}")
    fi

    validate_semver "${BUMP_VERSION}"
}

fetch_checksums() {
    local version="$1"
    local response

    if [[ -n "${API_RESPONSE}" ]]; then
        response="${API_RESPONSE}"
    else
        log "Fetching release metadata for v${version}..." >&2
        response=$(curl -fsSL "https://api.github.com/repos/anomalyco/opencode/releases/tags/v${version}")
    fi

    local entries
    entries=$(echo "${response}" | jq -r '
        .assets[]
        | select(.name | test("opencode-linux-(x64|arm64)\\.tar\\.gz$"))
        | "\(.digest | split(":")[1])  \(.name)"
    ')

    if [[ -z "${entries}" ]]; then
        log_fail "No linux checksums found for v${version}"
        exit 1
    fi

    echo "${entries}"
}

write_version_file() {
    local version="$1"
    local content="${version}"

    if [[ "${BUMP_DRY_RUN}" == true ]]; then
        echo "--- Would write to ${VERSION_FILE} ---"
        echo "${content}"
        echo "---"
        return 0
    fi

    local tmp
    tmp=$(mktemp "$(dirname "${VERSION_FILE}")/.opencode-version.XXXXXX")
    echo "${content}" > "${tmp}"
    mv "${tmp}" "${VERSION_FILE}"
    log_pass "Updated ${VERSION_FILE##*/} to ${version}"
}

write_checksums_file() {
    local version="$1"
    local checksums="$2"
    local content
    content="$(cat <<EOF
# SHA256 checksums for OpenCode release tarballs
# Format: <sha256>  <filename>
# Update this file when changing .opencode-version
# Checksums source: GitHub Releases API asset digests
${checksums}
EOF
)"

    if [[ "${BUMP_DRY_RUN}" == true ]]; then
        echo "--- Would write to ${CHECKSUM_FILE} ---"
        echo "${content}"
        echo "---"
        return 0
    fi

    local tmp
    tmp=$(mktemp "$(dirname "${CHECKSUM_FILE}")/.opencode-checksums.XXXXXX")
    echo "${content}" > "${tmp}"
    mv "${tmp}" "${CHECKSUM_FILE}"
    log_pass "Updated ${CHECKSUM_FILE##*/} for v${version}"
}

main() {
    parse_args "$@"
    check_dependencies
    resolve_version

    local current_version=""
    if [[ -f "${VERSION_FILE}" ]]; then
        current_version=$(cat "${VERSION_FILE}")
    fi

    if [[ "${BUMP_VERSION}" == "${current_version}" ]]; then
        log_warn "Version unchanged (${BUMP_VERSION})"
    else
        log "Bumping version: ${current_version} -> ${BUMP_VERSION}"
    fi

    local checksums
    checksums=$(fetch_checksums "${BUMP_VERSION}")

    # Verify both architectures present
    local x64_count arm64_count
    x64_count=$(echo "${checksums}" | grep -c "opencode-linux-x64.tar.gz" || true)
    arm64_count=$(echo "${checksums}" | grep -c "opencode-linux-arm64.tar.gz" || true)

    if [[ "${x64_count}" -eq 0 ]]; then
        log_fail "Missing checksum for linux-x64"
        exit 1
    fi
    if [[ "${arm64_count}" -eq 0 ]]; then
        log_fail "Missing checksum for linux-arm64"
        exit 1
    fi

    log_pass "Found checksums for x64 and arm64"

    write_version_file "${BUMP_VERSION}"
    write_checksums_file "${BUMP_VERSION}" "${checksums}"

    if [[ "${BUMP_DRY_RUN}" == true ]]; then
        log "Dry run complete. No files were modified."
    else
        log_pass "Version bump to ${BUMP_VERSION} complete"
        echo ""
        echo "Suggested commands:"
        echo "  git add build/.opencode-version build/.opencode-checksums"
        echo "  git commit -m \"chore: update opencode to v${BUMP_VERSION}\""
    fi
}

main "$@"
