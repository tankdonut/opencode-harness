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
    -r, --runtime RT      Container runtime: podman or docker (default: auto-detect)
        --no-cache        Build without cache
        --load            Load image into local registry after build (for multi-stage)
    -h, --help            Show this help message

Any arguments after -- are passed to the container runtime build command.

Examples:
    $(basename "${BASH_SOURCE[0]}")
    $(basename "${BASH_SOURCE[0]}") --tag my-harness:v1
    $(basename "${BASH_SOURCE[0]}") --runtime docker --no-cache
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
    log "Command: ${build_cmd[*]}"
    echo ""

    if "${build_cmd[@]}"; then
        echo ""
        log_success "Image built: ${TAG}"

        apply_labels

        local image_size
        image_size=$("${RUNTIME}" images "${TAG}" --format "{{.Size}}" 2>/dev/null | head -1 || echo "unknown")
        log_success "Size: ${image_size}"
    else
        log_error "Build failed"
        exit 1
    fi
}

apply_labels() {
    if [[ ! -f "$VERSION_FILE" ]]; then
        log_warn "No .opencode-version file found, skipping label application"
        return
    fi

    local opencode_version
    opencode_version=$(cat "$VERSION_FILE" | tr -d '[:space:]')

    log "Applying image labels..."

    "${RUNTIME}" inspect --type image "${TAG}" &>/dev/null || return

    local label_cmd=("${RUNTIME}" "image" "label")
    label_cmd+=("org.opencontainers.image.title=OpenCode Harness" "${TAG}")
    "${label_cmd[@]}" 2>/dev/null || true

    "${RUNTIME}" image label "org.opencontainers.image.description=Containerized OpenCode environment with production-ready agents and skills" "${TAG}" 2>/dev/null || true
    "${RUNTIME}" image label "org.opencontainers.image.version=${opencode_version}" "${TAG}" 2>/dev/null || true
    "${RUNTIME}" image label "org.opencontainers.image.source=https://github.com/tankdonut/opencode-harness" "${TAG}" 2>/dev/null || true
    "${RUNTIME}" image label "opencode.version=${opencode_version}" "${TAG}" 2>/dev/null || true

    log_success "Labels applied (version: ${opencode_version})"
}

main() {
    parse_args "$@"
    validate_inputs
    run_build
}

main "$@"
