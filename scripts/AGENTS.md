# scripts/ — Host-Side Automation

## Purpose

Host-side bash scripts that **build, validate, test, and bump** the OpenCode container image. Invoked by CI (`.github/workflows/build-and-publish-image.yaml`) and by developers locally. No script sources another — coupling is data-level (version/checksum files) and CI-level (job sequencing).

## File Inventory

| Script | LOC | CI-run? | Role |
|--------|-----|---------|------|
| `validate.sh` | 395 | ✅ build-and-publish-image | Pre-build validation (7 checks + `--fix` mode) |
| `build.sh` | 204 | ✅ build-and-publish-image | Container build driver (podman/docker auto-detect) |
| `container-test.sh` | 598 | ✅ build-and-publish-image | Post-build integration suite (15 test groups) |
| `bump-version.sh` | 284 | ❌ manual | Atomic OpenCode version + checksum updater |
| `local-setup.sh` | 303 | ❌ manual | Host bootstrap (non-container path) |
| `opencode-sandbox.sh` | 392 | ❌ manual | Linux sandbox wrapper (bwrap / gVisor / nspawn modes) |

## Conventions

### Shared Patterns
- **Shebang**: `#!/usr/bin/env bash` (portable)
- **Strict mode**: `set -euo pipefail` in every script (validated by validate.sh)
- **Logging**: each script defines its own `log`/`log_success`/`log_error`/`log_warn` helpers writing to **stderr** (`>&2`)
- **Colors**: ANSI vars `RED`/`GREEN`/`YELLOW`/`BLUE`/`NC` declared `readonly` at top
- **Exit codes**: 0=success, 1=failure, 2=bad args/setup (container-test.sh convention)
- **Usage**: every script has `print_usage()` / `usage()` function + `--help` flag
- **Counters**: validate.sh uses `CHECKS_PASSED`/`CHECKS_FAILED`/`CHECKS_WARNED`; container-test.sh uses `TESTS_PASSED`/`TESTS_FAILED`/`TESTS_SKIPPED`

### Argument Parsing
- `parse_args()` function pattern with `while`/`case` loop
- Flags: `--tag`, `--runtime`, `--no-cache`, `--fix`, `--latest`, `--dry-run`, `--help`
- Positional args kept minimal (image name, container runtime)

### Runtime Detection (build.sh, container-test.sh)
```
podman preferred → docker fallback
CI forces docker (CONTAINER_CMD=docker, pre-installed on runners)
```
**Known gap**: build.sh `apply_labels()` uses `${RUNTIME} image label` (podman-specific). On docker, silently fails (`|| true`) — labels only applied when podman used locally. To fix: add `LABEL` directives in Containerfile instead.

## Function Map

### validate.sh (395L)
```
check_tools          # jq, git present
validate_json        # opencode.json valid + $schema + plugin[]
validate_permissions # local-setup.sh + entrypoint.sh executable (--fix auto-chmods)
validate_skills_lock # skills-lock.json exists, valid JSON, has skills
validate_containerfile  # regex greps: ubuntu:26.04, @sha256:, sha256sum -c, USER opencode, etc.
validate_checksums   # format ^[0-9a-f]{64}\ \ filename, both arches present
validate_structure   # required files/dirs exist
print_summary / print_usage / main
```
**Anti-pattern check** (L217-226): `:latest` on final FROM → hard `log_fail`. Builder-stage `:latest` tolerated.

### build.sh (204L)
```
detect_runtime   # podman > docker
parse_args       # --tag, --runtime, --no-cache, passthrough
validate_inputs  # context dir, Containerfile exist
run_build        # invokes ${RUNTIME} build -f build/Containerfile build/
apply_labels     # OCI labels via ${RUNTIME} image label (podman-only — see gap above)
main
```

### container-test.sh (598L)
Black-box: spawns fresh `${CONTAINER_RUNTIME} run --rm` per assertion (~30+ container starts). Args: `<image> [runtime]`.
```
# Logging
log / log_pass / log_fail / log_skip / log_section

# 15 test functions
test_container_startup        test_bootstrap_creates_config
test_required_binaries        test_bootstrap_copies_assets
test_opencode_installation    test_bootstrap_preserves_existing
test_configuration            test_bootstrap_force_overwrites
test_directory_structure      test_user_permissions
test_skills                   test_environment
test_entrypoint               test_workspace_mounting

check_prerequisites / cleanup / print_summary / main
```
- `trap cleanup EXIT` removes `/tmp/opencode-test-$$` workspace
- `OPENCODE_BOOTSTRAP_FORCE=0|1` env var tested for idempotency

### bump-version.sh (284L)
```
strip_v_prefix / validate_semver    # semver parsing
resolve_version                     # --latest fetches GitHub Releases API
fetch_checksums                     # curl + jq extracts SHA256 digests
write_version_file / write_checksums_file  # atomic writes
check_dependencies / parse_args / main
```
Globals: `BUMP_VERSION`, `BUMP_USE_LATEST`, `BUMP_DRY_RUN`. Source: `github.com/anomalyco/opencode` releases.

### local-setup.sh (303L)
Standalone host path — no script-to-script deps. Installs OpenCode via `npm install -g opencode@VERSION`, copies config to `~/.opencode/config.json`.
```
command_exists / check_prerequisites
validate_config
install_opencode / setup_opencode_config
verify_installation / print_summary / main
```

## CI Integration

CI consumes centralized actions from [`tankdonut/github-actions@v1`](https://github.com/tankdonut/github-actions):

```
.github/workflows/
 ├─ lint-and-test.yaml:            pre-commit@v1 (all-files)
 ├─ build-and-publish-image.yaml:  validate.sh → build.sh → tag (sha, version, latest)
 │                                 → container-test.sh → trivy (advisory)
 │                                 → ghcr-login@v1 → push ghcr.io (non-PR only)
 ├─ prune-ghcr-images.yaml:        reusable prune-ghcr.yaml@v1 (daily cron)
 └─ renovate-auto-approve.yaml:    renovate-auto-approve@v1 (on Renovate PRs)
```
- Build triggers: `schedule (Mon 03:00 UTC)`, `workflow_dispatch`, PR + push to `main` (path-filtered on `build/**`, `scripts/**`, the workflow file itself); PR runs build+test+scan but never publish
- Pre-commit runs on every PR + push to `main` (no path filter, `fetch-depth: 0`)
- No `ci-status` aggregator job — set branch-protection required checks on `Lint & Test / pre-commit` + `Build & Publish Image / release`
- Vulnerability scan: `aquasecurity/trivy-action@v0.36.0`, image-ref scan, severity CRITICAL/HIGH, `continue-on-error: true` (non-blocking advisory). Docker-compatible — runs in CI and locally.

## Anti-Patterns (script-specific)

- **Don't** omit `set -euo pipefail` — validate.sh enforces this via Containerfile check
- **Don't** use `:latest` on final FROM image — validate.sh hard-fails this
- **Don't** skip checksum verification — `sha256sum -c` is a security gate
- **Don't** call scripts via `cd <dir> && ./script.sh` — use absolute paths or `workdir`
- **Don't** add new Containerfile checks without updating both validate.sh AND Containerfile (they must stay in sync)
- **Do** use `local` for function-local variables
- **Do** quote all variable expansions
- **Do** use `[[ ]]` for tests (bash), not `[ ]`

## Known Issues

1. **Runtime mismatch**: local prefers podman, CI uses docker — `apply_labels` silently fails in CI
2. **container-test.sh is slow**: ~30 fresh container starts per run (no layer reuse)
3. **No tests for validate.sh/build.sh/bump-version.sh/local-setup.sh themselves** — only container-test.sh and test_bootstrap.sh exist

## Quick Reference

```bash
# Full CI-like local run
./scripts/validate.sh && \
./scripts/build.sh --tag opencoder:ci --no-cache && \
./scripts/container-test.sh opencoder:ci

# Bump OpenCode version (fetches latest + checksums)
./scripts/bump-version.sh --latest

# Bump to specific version
./scripts/bump-version.sh 1.18.0

# Validate with auto-fix for permissions
./scripts/validate.sh --fix
```
