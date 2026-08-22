# build/ — Container Build Context

## Purpose

The **sole container build context** for `podman/docker build`. Everything needed to produce the reproducible OCI image lives here: Containerfile, runtime entrypoint, OpenCode version pinning, system config, and the skills.sh lockfile.

**This directory IS the build context.** `podman build -f build/Containerfile build/` — all `COPY` paths are relative to `build/`.

## File Inventory

| Path | Role |
| ------ | ------ |
| `Containerfile` (132L) | Multi-stage image definition: `tools` stage → `ubuntu:26.04` runtime |
| `entrypoint.py` | Container ENTRYPOINT (Python, stdlib-only) — the real bootstrap logic (runs at `podman run`, NOT build time) |
| `.opencode-version` | Single source of truth for OpenCode release (currently `1.17.6`) |
| `.opencode-checksums` | SHA256 for `opencode-linux-{x64,arm64}.tar.gz` — integrity gate |
| `.containerignore` | Excludes `.opencode/{node_modules,bun.lock,package.json}` from build context |
| `.opencode/package.json` + `bun.lock` | JS-tooling artifacts for theme/plugin deps (gitignored from build context, NOT shipped) |
| `.opencode/opencode.json` | **Plugins** (project-level, strict JSON) |
| `.opencode/dcp.json` | Dynamic Context Pruning config (compress at 50%, floor 40%) |
| `.opencode/opencode-mem.jsonc` | opencode-mem plugin default — entrypoint seeds it to `~/.config/opencode/` so auto-capture works out of the box |
| `.opencode/opencode-mem.web.jsonc` | web-exposed variant (0.0.0.0 + `env://OPENCODE_MEM_WEB_TOKEN`) — seeded instead when `OPENCODE_MEM_WEB_EXPOSED=1` + token are set |
| `.opencode/tui.json` + `themes/` | TUI theming (ayu-dark default) |
| `etc/opencode/opencode.jsonc` | **Runtime behavior** (container-level, JSONC with comments) |
| `etc/npmrc` | Supply-chain: `min-release-age=7`, `ignore-scripts=true` |
| `etc/uv/uv.toml` | Supply-chain: `exclude-newer = "7 days"` |
| `skills-lock.json` | skills.sh lockfile (18 baseline skills: 12 OMO + agents-md + create-agentsmd + find-skills + 3 superpowers skills) |

## Two-Tier Config (CRITICAL)

| File | Scope | Format | Purpose | Image path |
|------|-------|--------|---------|------------|
| `.opencode/opencode.json` | Project | Strict JSON | **Plugins** (npm-pinned) | `/opencode/default/opencode.json` |
| `etc/opencode/opencode.jsonc` | Container | JSONC | **Runtime** (autoupdate, perms, watcher) | `/etc/opencode/opencode.jsonc` |

**Editing the wrong file is the #1 mistake.** Plugins go in `opencode.json`. Runtime behavior goes in `opencode.jsonc`. The jsonc file has a comment pointing to opencode.json for plugins.

⚠️ **`tui.json` plugin alignment**: `tui.json` has its own `plugin` array — it need NOT match `opencode.json` 1:1, but any plugin present in BOTH files must use the SAME version. `opencode.json` is the canonical full list; `tui.json` may subset it.

## The `COPY etc/ /etc/` Convention

Containerfile L107 copies the **entire** `etc/` tree to `/etc/` wholesale:

- `etc/opencode/opencode.jsonc` → `/etc/opencode/opencode.jsonc`
- `etc/npmrc` → `/etc/npmrc`
- `etc/uv/uv.toml` → `/etc/uv/uv.toml`

**To add new system config**: drop a file at `build/etc/<path>` mirroring the target `/etc/<path>`. No Containerfile edit needed.

## Containerfile Structure

```dockerfile
# Stage 1: pre-built tools (pinned by SHA digest)
FROM ghcr.io/tankdonut/tools:latest@sha256:... AS tools

# Stage 2: runtime
FROM docker.io/library/ubuntu:26.04
# apt deps, bun@1.3.11 global install
# COPY .opencode-version + .opencode-checksums → /etc/
# RUN: curl opencode tarball, sha256sum -c verify, extract → /vendor/bin
# Create non-root user opencode (uid 1001, HOME=/home/opencode)
# COPY config, entrypoint; install skills via skills.sh CLI
USER opencode
ENTRYPOINT ["/usr/local/bin/entrypoint.py"]
CMD ["/bin/bash"]
```

**Key**: entrypoint.py is COPIED (`--chmod=755`) but **NOT executed** at build time. It runs at every `podman run`.

## entrypoint.py — Importable + Executable Bootstrap

### `if __name__ == "__main__"` guard (bottom of file)

- **Executed** as container ENTRYPOINT → runs `main()`
- **Imported** by `tests/test_bootstrap.py` (via `importlib.util.spec_from_file_location`) → helper functions only, no bootstrap side effects

Stdlib only — the image ships python3 with no pip packages. Fatal steps raise `BootstrapError` (caught in `main`, exit 1); soft steps (skills sync, OMO install, optional skills) return `False` and only warn. All logging goes to stderr; stdout stays clean. Trailing argv is `os.execv`'d as the container command.

### Bootstrap Flow (main)

```
validate_environment  → check git/node/npm/curl/jq/python3/pip3/yq, PATH
verify_opencode       → opencode --version vs /etc/opencode-version
bootstrap_config      → copy_config + copy_theme_config (defaults from /opencode/default/ → writable $HOME/.opencode/)
copy_mem_config       → seed opencode-mem.jsonc → $HOME/.config/opencode/ (plugin's global discovery path; soft-fail)
sync_skills           → symlink $HOME/.agents/skills → /opencode/default/.agents/skills/
validate_config       → jq empty + plugin count > 0
install_oh_my_openagent → bunx oh-my-openagent install (7 flags: OMO_CLAUDE/OMO_GEMINI/OMO_COPILOT/OMO_OPENAI/OMO_OPENCODE_GO/OMO_OPENCODE_ZEN/OMO_ZAI_CODING_PLAN; OMO_FORCE=yes forces) (warns on failure, non-fatal)
install_optional_skills → ECC/superpowers runtime install when ECC_ENABLED/SUPERPOWERS_ENABLED set (network required)
verify_installation   → final checks
print_summary
exec "$@"             → hand off to CMD (/bin/bash) or user args
```

### Helper Functions

- `derive_config_dir` — resolves config destination based on workspace state
- `create_config_dir` — mkdir -p with ownership
- `copy_config` — `cp -n` (no-clobber) unless `OPENCODE_BOOTSTRAP_FORCE=1`
- `copy_theme_config` — TUI theme setup
- `copy_mem_config` — seeds `opencode-mem.jsonc` into `~/.config/opencode/` before first start (plugin would otherwise write a template with auto-capture unconfigured); picks the web-exposed variant when `OPENCODE_MEM_WEB_EXPOSED=1` + `OPENCODE_MEM_WEB_TOKEN` are set, swapping an untouched seed so the toggle works on existing volumes
- `sync_skills` — creates symlink from `$HOME/.agents/skills` to `/opencode/default/.agents/skills/` (keeps skills available in HOME without polluting the bind-mounted workspace)
- `install_optional_skills` — runtime installer for ECC/superpowers via skills.sh CLI (gated by `ECC_ENABLED` / `SUPERPOWERS_ENABLED`)

### Force Flag

`OPENCODE_BOOTSTRAP_FORCE=1` overwrites existing config. Absent or `0` preserves (uses `cp -n`).

### Known Tricky Logic

1. **Line 328**: `${install_cmd} 2>&2 >&2` — unusual redirect, sends all output to stderr (keeps stdout clean)
2. **Line 149/187**: `cp -n` / `cp -rn` — GNU cp extensions; won't work on macOS bash 3.2
3. **Line 79/77**: `${flag_value,,}` (lowercase) and `${!flag_name:-1}` (indirect expansion) — bash 4+ required
4. **Line 336-346**: `sync_skills` replaces an existing symlink only if it points to the wrong target; a real directory at `$HOME/.agents/skills` is left alone (logs a warning)
5. **Line 100-106 (Containerfile)**: `useradd -m -d /home/opencode` sets HOME to `/home/opencode`, NOT `/workspace`. This is intentional: bind-mounting a host dir to `/workspace` must not shadow the container HOME (Bun JIT, config writes depend on writable HOME).

## Skills Distribution

Skills ship through two distinct mechanisms, layered on top of the npm plugin loader.

**Do not conflate these:**

| Mechanism | What it does | Source |
| ----------- | ------------- | -------- |
| **OpenCode plugin loader** | Fetches npm packages at runtime | `.opencode/opencode.json` plugin[] |
| **Build-time skills (baseline)** | `oh-my-openagent` skills baked into the image via `npx skills experimental_install` | `skills-lock.json` → `/opencode/default/.agents/skills/` |
| **Runtime skills (opt-in)** | ECC / superpowers skills fetched at container start | entrypoint `install_optional_skills` via `npx skills add` |
| **`bunx oh-my-openagent install`** | Installs multi-agent orchestrator | npm package `oh-my-openagent` (`oh-my-opencode` is a legacy alias of the same package) |

### Plugin ↔ Skill Source Mapping (LOOSE)

| npm package | Skill source | Relationship |
| ------------- | ------------- | -------------- |
| `@tarquinen/opencode-dcp@3.1.13` | — | npm-only |
| `cc-safety-net@1.0.6` | — | npm-only |
| `oh-my-openagent@4.12.0` | `code-yeongyu/oh-my-openagent` | Name overlaps; skills ship at build time, npm is the plugin |
| — | `affaan-m/everything-claude-code` | Skills only (opt-in at runtime via `ECC_ENABLED=1`) |
| — | `obra/superpowers` | Skills only (opt-in at runtime via `SUPERPOWERS_ENABLED=1`) |

**Build-time skills are pinned by `skills-lock.json`. Runtime skills fetch whatever the source repo has at start time (no lock).** They can drift independently.

### Adding a Baseline Skill (lockfile)

Run from this `build/` directory:

```bash
npx skills@1.5.13 add <owner/repo> --skill <name>|'*' --agent opencode --copy -y
jq '.skills | keys | length' skills-lock.json   # verify count increased
```

Then rebuild (`./scripts/build.sh --tag test --no-cache`) and commit `skills-lock.json`. See root `AGENTS.md` → Workflow Patterns → Adding a New Baseline Skill for the full step-by-step. Never hand-edit the lockfile.

### Adding a Runtime-Only Skill (opt-in)

Don't touch the lockfile. Add an env-var gate in `entrypoint.py` `install_optional_skills()` (copy the `ECC_ENABLED`/`SUPERPOWERS_ENABLED` block), document the flag in root `AGENTS.md` Module Toggle table + `docs/guides/configuration.md`. Requires network at container start.

## Anti-Patterns (build-specific)

- **Don't** edit `skills-lock.json` by hand — regenerate it via the skills.sh CLI
- **Don't** put plugins in `opencode.jsonc` — use `opencode.json`
- **Don't** run entrypoint.py at build time (RUN) — it's the ENTRYPOINT, runs at container start
- **Don't** use `:latest` on final FROM — validate.sh hard-fails this (builder stage `:latest` OK)
- **Don't** change base image without updating validate.sh:197 pattern AND AGENTS.md
- **Don't** bump `.opencode-version` without updating `.opencode-checksums` — use `scripts/bump-version.sh`
- **Don't** expect runtime skill installs (ECC, superpowers) to work offline — they need network at container start

## Version Pinning Flow

```
.opencode-version (1.17.6) ─┐
.opencode-checksums (2x)   ─┤
                            ├─→ Containerfile COPY → /etc/opencode-{version,checksums}
                            │   → RUN: curl github.com/anomalyco/opencode v1.17.6
                            │         → sha256sum -c → extract → /vendor/bin
scripts/bump-version.sh ────┘   atomic updater (GitHub Releases API)
```

## Quick Reference

```bash
# Verify entrypoint is importable (for tests)
python3 -c "import importlib.util as i; s=i.spec_from_file_location('e','build/entrypoint.py'); m=i.module_from_spec(s); s.loader.exec_module(m); print(m.derive_config_dir('/a/b/c.json'))"

# Enable runtime opt-in skills (ECC + superpowers)
ECC_ENABLED=1 SUPERPOWERS_ENABLED=1 \
  podman run --rm opencoder -c 'echo optional skills installed in summary'

# Force re-bootstrap (overwrite existing config)
podman run -e OPENCODE_BOOTSTRAP_FORCE=1 --rm opencoder
```
