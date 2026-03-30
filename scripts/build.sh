#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly VERSION_FILE="${PROJECT_ROOT}/.opencode-version"
readonly CONTAINERFILE="${PROJECT_ROOT}/Containerfile"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log() {
    echo -e "${BLUE}[BUILD]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] [-- RUNTIME_ARGS...]

Build the OpenCode Harness container image.

Options:
    -t, --tag TAG         Image tag (default: opencode-harness)
    -v, --version VER     OpenCode version (default: reads from .opencode-version)
    -r, --runtime RT      Container runtime: podman or docker (default: auto-detect)
        --no-cache        Build without cache
        --load            Load image into local registry after build (for multi-stage)
    -h, --help            Show this help message

Any arguments after -- are passed to the container runtime build command.

Examples:
    $(basename "${BASH_SOURCE[0]}")
    $(basename "${BASH_SOURCE[0]}") --tag my-harness:v1
    $(basename "${BASH_SOURCE[0]}") --runtime docker --no-cache
    $(basename "${BASH_SOURCE[0]}") --version 1.3.3
EOF
}

detect_runtime() {
    if command -v podman &>/dev/null; then
        echo "podman"
    elif command -v docker &>/dev/null; then
        echo "docker"
    else
        log_error "No container runtime found (install podman or docker)"
        exit 1
    fi
}

parse_args() {
    TAG="opencode-harness"
    OPENCODE_VERSION=""
    RUNTIME=""
    NO_CACHE=false
    PASSTHROUGH_ARGS=()
    RUNTIME_ARGS=()
    local parse_passthrough=false

    while [[ $# -gt 0 ]]; do
        if [[ "$parse_passthrough" == true ]]; then
            RUNTIME_ARGS+=("$1")
            shift
            continue
        fi

        case "$1" in
            -t|--tag)
                TAG="${2:-}"
                if [[ -z "$TAG" ]]; then
                    log_error "--tag requires a value"
                    exit 1
                fi
                shift 2
                ;;
            -v|--version)
                OPENCODE_VERSION="${2:-}"
                if [[ -z "$OPENCODE_VERSION" ]]; then
                    log_error "--version requires a value"
                    exit 1
                fi
                shift 2
                ;;
            -r|--runtime)
                RUNTIME="${2:-}"
                if [[ -z "$RUNTIME" ]]; then
                    log_error "--runtime requires a value"
                    exit 1
                fi
                shift 2
                ;;
            --no-cache)
                NO_CACHE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                parse_passthrough=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    RUNTIME="${RUNTIME:-$(detect_runtime)}"
}

resolve_version() {
    if [[ -n "$OPENCODE_VERSION" ]]; then
        return
    fi

    if [[ -f "$VERSION_FILE" ]]; then
        OPENCODE_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
        log "Using version from .opencode-version: ${OPENCODE_VERSION}"
    else
        log_warn "No .opencode-version file found, version will be resolved at build time"
    fi
}

validate_inputs() {
    if [[ ! -f "$CONTAINERFILE" ]]; then
        log_error "Containerfile not found at ${CONTAINERFILE}"
        exit 1
    fi

    if [[ "$RUNTIME" != "podman" ]] && [[ "$RUNTIME" != "docker" ]]; then
        log_error "Unsupported runtime: ${RUNTIME} (use podman or docker)"
        exit 1
    fi
}

run_build() {
    local build_cmd=("${RUNTIME}" "build")

    build_cmd+=("-f" "${CONTAINERFILE}")

    if [[ -n "$OPENCODE_VERSION" ]]; then
        build_cmd+=("--build-arg" "OPENCODE_VERSION=${OPENCODE_VERSION}")
    fi

    if [[ "$NO_CACHE" == true ]]; then
        build_cmd+=("--no-cache")
    fi

    build_cmd+=("-t" "${TAG}")
    build_cmd+=("${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}")

    build_cmd+=("${PROJECT_ROOT}")

    if [[ ${#RUNTIME_ARGS[@]} -gt 0 ]]; then
        build_cmd+=("${RUNTIME_ARGS[@]}")
    fi

    log "Building image: ${TAG}"
    log "Runtime: ${RUNTIME}"
    log "Context: ${PROJECT_ROOT}"
    if [[ -n "$OPENCODE_VERSION" ]]; then
        log "OpenCode version: ${OPENCODE_VERSION}"
    fi
    log "Command: ${build_cmd[*]}"
    echo ""

    if "${build_cmd[@]}"; then
        echo ""
        log_success "Image built: ${TAG}"

        local image_size
        image_size=$("${RUNTIME}" images "${TAG}" --format "{{.Size}}" 2>/dev/null | head -1 || echo "unknown")
        log_success "Size: ${image_size}"
    else
        log_error "Build failed"
        exit 1
    fi
}

main() {
    parse_args "$@"
    resolve_version
    validate_inputs
    run_build
}

main "$@"
