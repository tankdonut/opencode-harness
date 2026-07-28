---
name: bumping-opencoder-versions
description: Use when working in the tankdonut/opencoder repository and the user asks to bump, update, or upgrade versions that Renovate does NOT auto-manage. Four surfaces only: OpenCode core (.opencode-version + .opencode-checksums), npm plugins in opencode.json and tui.json (oh-my-openagent, cc-safety-net, @tarquinen/opencode-dcp), skills.sh CLI pin in markdown docs, and skills-lock.json content hashes. Triggers include "bump opencode version", "upgrade oh-my-openagent", "refresh skills lockfile", "update plugins", and Renovate-bypassed version bumps.
---

# Bumping opencoder Versions (Renovate-Blind Surfaces Only)

## Overview

Renovate (`config:recommended` + 7-day `minimumReleaseAge`) auto-manages most versioned surfaces in this repo: bun, ubuntu base, builder digest, GitHub Actions, the `skills@X.Y.Z` pin in Containerfile L123, and the dep in `build/.opencode/package.json`. **This skill covers the four surfaces Renovate cannot see** — custom files, non-standard plugin arrays, markdown prose, and content hashes. Each has its own mechanic and one cross-surface invariant.

**Core principle:** Bump one surface at a time, verify the plugin-alignment invariant, then run `./scripts/validate.sh` before committing. Never bundle multiple surfaces in one commit — bisecting becomes impossible.

## When to Use

- User asks to bump OpenCode core, an opencode plugin, the skills.sh CLI pin, or skills-lock hashes
- New OpenCode release is published (or an older release becomes eligible as the embargo clears — see Supply-Chain Policy)
- New plugin release on npm
- `skills-lock.json` is stale vs upstream SKILL.md changes
- Renovate PR triage where the surface turns out to be Renovate-blind

**When NOT to use:**
- Bun, ubuntu base, builder digest, GitHub Actions, or `package.json` deps → **Renovate owns these**. Wait for the PR.
- The `skills@X.Y.Z` pin in Containerfile L123 → **Renovate's npm manager detects `npx pkg@version`**. Wait for the PR.
- Any repo other than `tankdonut/opencoder`.

## The Four Renovate-Blind Surfaces

| # | Surface | File(s) | Tool |
|---|---------|---------|------|
| 1 | **OpenCode core** | `build/.opencode-version` + `build/.opencode-checksums` | `scripts/bump-version.sh` |
| 2 | **npm plugins** | `build/.opencode/opencode.json` (+ `build/.opencode/tui.json` for plugins in both) | `jq` edit |
| 3 | **skills.sh CLI pin in markdown** | `AGENTS.md`, `build/AGENTS.md`, `DEVELOPMENT.md`, `docs/guides/usage.md` | search-and-replace ALL four files |
| 4 | **`skills-lock.json` hashes** | `build/skills-lock.json` | regenerate via skills CLI |

## Per-Surface Procedures

### Surface 1 — OpenCode core (HAS DEDICATED SCRIPT)

```bash
# Auto-detect latest from GitHub Releases API + update both files atomically
./scripts/bump-version.sh --latest

# Bump to explicit version
./scripts/bump-version.sh 1.18.0

# Preview without writing
./scripts/bump-version.sh --dry-run --latest
```

The script fetches SHA256 digests from `api.github.com/repos/anomalyco/opencode/releases` and writes both `build/.opencode-version` and `build/.opencode-checksums`. **Never edit these files by hand** — the checksum file must match the version file exactly, and `sha256sum -c` runs at build time as a security gate.

### Surface 2 — npm plugins (MANUAL jq EDIT)

Renovate's npm manager doesn't recognize the OpenCode `plugin[]` JSON shape, so these are manual. Plugin names currently in use:

```bash
# Check what's latest on npm
npm view oh-my-openagent version
npm view cc-safety-net version
npm view @tarquinen/opencode-dcp version

# Check publish date to enforce 7-day embargo
npm view oh-my-openagent time --json | jq -r '."4.19.3"'
```

⚠️ **Indent rule**: these JSON files use **4-space indent** (repo convention). Plain `jq` defaults to 2-space output and will create a noisy reformat diff. Always pass `--indent 4`.

```bash
# Bump in opencode.json (the canonical full plugin list)
jq --indent 4 '.plugin |= map(
  if startswith("@tarquinen/opencode-dcp@") then "@tarquinen/opencode-dcp@3.1.14"
  elif startswith("cc-safety-net@") then "cc-safety-net@1.0.7"
  elif startswith("oh-my-openagent@") then "oh-my-openagent@4.19.3"
  else . end)' build/.opencode/opencode.json > /tmp/opencode.json && mv /tmp/opencode.json build/.opencode/opencode.json

# CRITICAL: mirror into tui.json for any plugin present in BOTH files
# (currently @tarquinen/opencode-dcp and oh-my-openagent are in both)
jq --indent 4 '.plugin |= map(
  if startswith("@tarquinen/opencode-dcp@") then "@tarquinen/opencode-dcp@3.1.14"
  elif startswith("oh-my-openagent@") then "oh-my-openagent@4.19.3"
  else . end)' build/.opencode/tui.json > /tmp/tui.json && mv /tmp/tui.json build/.opencode/tui.json

# Verify no collateral reformatting (diff should be only the plugin-version lines)
git diff --stat build/.opencode/opencode.json build/.opencode/tui.json
git diff build/.opencode/opencode.json build/.opencode/tui.json
```

### Surface 3 — skills.sh CLI pin in markdown (MULTI-FILE)

The Containerfile L123 pin is Renovate-managed (npm manager). The same version sprinkled across **four markdown files** is NOT — Renovate doesn't touch prose. All four must change together:

```bash
# Verify current pin distribution before bumping
grep -rn "skills@1" --include="*.md" .

# Bump everywhere (example: 1.5.13 → 1.5.20)
sed -i 's/skills@1\.5\.13/skills@1.5.20/g' \
  AGENTS.md build/AGENTS.md DEVELOPMENT.md docs/guides/usage.md

# Verify zero stragglers in markdown (Containerfile is Renovate's job)
grep -rn "skills@1\.5\.13" --include="*.md" . && echo "STRAGGLERS REMAIN" || echo "ALL CLEAN"

# Cross-check: markdown pin should match Containerfile pin after Renovate merges its PR
grep "skills@" build/Containerfile
```

### Surface 4 — skills-lock.json hashes

The `computedHash` fields are SHA256 of upstream `SKILL.md` content. They drift as upstream changes and **must never be hand-edited**.

```bash
# Refresh all hashes (use the SAME skills CLI pin as Containerfile L123)
cd build
npx skills@1.5.13 experimental_install --agent opencode --copy -y
cd ..

# Verify hashes changed (git diff should show new computedHash values only)
git diff build/skills-lock.json

# Count check
jq '.skills | keys | length' build/skills-lock.json
```

To **add** a baseline skill: `cd build && npx skills@<PIN> add <owner/repo> --skill '<name>|*' --agent opencode --copy -y`. To **remove** one: jq-delete the entry (the only sanctioned hand-edit).

## Cross-Surface Invariant: Plugin Alignment

Enforced indirectly by runtime behavior. Violating it doesn't fail `validate.sh` but breaks the TUI at container start.

> Any plugin name present in BOTH `opencode.json` AND `tui.json` MUST use the same version.

Currently `@tarquinen/opencode-dcp` and `oh-my-openagent` appear in both files. `cc-safety-net` appears only in `opencode.json` (no tui.json mirror needed).

```bash
# Quick alignment check (run before committing any plugin bump)
jq -r '.plugin[]' build/.opencode/opencode.json | sort > /tmp/a.txt
jq -r '.plugin[]' build/.opencode/tui.json       | sort > /tmp/b.txt
# Plugins in both files must have identical versions:
comm -12 /tmp/a.txt /tmp/b.txt
```

## Verification Protocol (ASK BEFORE THE SLOW STEPS)

Verification splits into two tiers with different policies:

### Tier 1 — Always run (seconds, no approval needed)

These are fast and enforce the invariants the bump relies on. Run after every commit.

```bash
./scripts/validate.sh                    # Pre-build invariants (plugin alignment, checksum format, etc.)
jq . build/.opencode/opencode.json && jq . build/.opencode/tui.json && jq . build/skills-lock.json
```

### Tier 2 — ASK FIRST (slow: container build + ~30 container starts)

`build.sh` and `container-test.sh` together take 5–20+ minutes because each test spawns a fresh container with no layer reuse. **Do not run them without explicit user approval.** Ask the user a single question covering both before invoking either.

```bash
# Only after explicit "yes" from the user:
./scripts/build.sh --tag opencoder-bump-test --no-cache
./scripts/container-test.sh opencoder-bump-test
```

**Ask pattern:**
> "Bumps are committed and `validate.sh` passes. Do you want me to run the container build + integration tests (5–20+ min) before opening the PR, or skip and open the PR now?"

If the user says skip: note in the PR body that build/test were deferred and CI will run them on the PR.
If the user says run: include the results in the PR body.

### Red Flag

- You're about to invoke `./scripts/build.sh` or `./scripts/container-test.sh` without asking → **stop and ask first**
- `validate.sh` fails after your bump → **fix before committing; never commit a red validate** (Tier 1, no exception)

## Supply-Chain Policy (7-DAY EMBARGO WITH FALLBACK)

This repo enforces a coordinated 7-day minimum release age:

- `build/etc/npmrc`: `min-release-age=7`
- `build/etc/uv/uv.toml`: `exclude-newer = "7 days"`
- `renovate.json`: `minimumReleaseAge: 7 days`

**Default behavior: fall back, don't skip.** If the latest version of a surface is embargoed (published <7 days ago), do NOT skip the bump entirely. Instead, walk the version history backward and bump to the **latest version that is ≥7 days old**. This matches Renovate's own behavior (its `minimumReleaseAge` filter picks the newest eligible release, not nothing).

### Procedure

1. Compute the cutoff: `CUTOFF=$(date -d '7 days ago' -Iseconds)`
2. Fetch version-to-publish-time map for the target package.
3. Filter to versions with `publish_time <= CUTOFF`.
4. Pick the highest semver among those (NOT the most-recently-published — semver ordering and publish-time ordering usually agree, but when they don't, semver wins).
5. If that version is newer than what's currently pinned → bump to it.
6. If the latest-eligible version equals the current pin → no bump needed; note in PR body.
7. If the latest-eligible version is OLDER than the current pin (rare — indicates a yank or rollback) → flag and ask the user; do not downgrade silently.

### Recipes

```bash
# npm package: find latest version ≥7 days old
CUTOFF=$(date -d '7 days ago' -Iseconds)
npm view oh-my-openagent time --json \
  | jq -r --arg c "$CUTOFF" '
      to_entries
      | map(select(.key != "modified" and .key != "created"))
      | map(select(.value <= $c))
      | sort_by(.key | rtrimstr("-") | gsub("\\."; " ") | [splits(" ")] | map(tonumber))
      | .[-1].key'

# OpenCode core: GitHub releases, filtered by published_at >= 7 days old
CUTOFF=$(date -d '7 days ago' -Iseconds)
curl -fsSL https://api.github.com/repos/anomalyco/opencode/releases \
  | jq -r --arg c "$CUTOFF" '
      map(select(.published_at <= $c and (.tag_name | startswith("v"))))
      | sort_by(.tag_name | ltrimstr("v") | [splits("[.]")] | map(tonumber))
      | .[-1].tag_name'
```

### Reporting

When falling back, the PR body MUST state both versions explicitly:

> `oh-my-openagent`: latest is `4.19.3` (published 2026-07-28, embargoed). Fell back to `4.19.0` (published 2026-07-17, eligible).

This makes it easy for a reviewer to either accept the fallback or wait for the embargo to clear.

### Override

If the user explicitly says "ignore embargo" or "bump to latest regardless", do it — but record the override in the commit message and PR body so it's auditable.

## Commit Message Conventions

One commit per surface, conventional-commits style:

```
chore: update opencode to v1.18.0
chore(deps): bump oh-my-openagent to 4.19.3
chore(deps): bump @tarquinen/opencode-dcp to 3.1.14
chore(deps): bump cc-safety-net to 1.0.7
chore(deps): bump skills.sh CLI pin to 1.5.20 in markdown docs
chore(deps): refresh skills-lock.json hashes
```

## Common Mistakes

| Mistake | Consequence | Fix |
|---------|-------------|-----|
| Editing `.opencode-version` or `.opencode-checksums` by hand | `sha256sum -c` fails in Containerfile RUN | Always use `scripts/bump-version.sh` |
| Bumping plugin in `opencode.json` only | TUI breaks at container start | Mirror to `tui.json` if plugin is in both |
| Plain `jq` (2-space output) on opencode.json/tui.json | Noisy full-file reformat diff hides the real change | Always pass `--indent 4` (repo convention) |
| Hand-editing a `computedHash` in `skills-lock.json` | Hash mismatch on next `experimental_install` | Regenerate via skills CLI only |
| Bumping skills CLI pin in markdown only | Containerfile pin drifts from docs | Out of scope here — Renovate handles Containerfile; markdown sync happens when Renovate's PR lands |
| Bumping to a version <7 days old | npm/uv build rejects; wasted cycle | Walk back to the latest ≥7-day-old version (see Supply-Chain Policy). Skip ONLY if no newer-than-pin eligible version exists. |
| Skipping a bump entirely because the latest is embargoed | Falls behind Renovate's own behavior (Renovate picks the newest eligible, not nothing) | Always fall back to the latest ≥7-day-old version; report both versions in the PR body |
| Bundling multiple surface bumps in one commit | Impossible to bisect regressions | One commit per surface |
| Touching bun/ubuntu/builder/GitHub Actions/skills-in-Containerfile/package.json | Duplicates Renovate's job, causes conflicts | **Leave to Renovate.** Wait for its PR. |
| Running `build.sh` / `container-test.sh` without asking | Wastes 5–20+ minutes of user time | **Always ask first** — see Verification Protocol Tier 2 |

## Red Flags — Stop and Re-verify

- You're about to edit `build/.opencode-version` or `build/.opencode-checksums` directly → **use `scripts/bump-version.sh`**
- You bumped a plugin in only one JSON file → **mirror to the other if it's in both**
- You're hand-editing a `computedHash` → **stop, regenerate via CLI**
- `validate.sh` fails after your bump → **fix before committing; never commit a red validate**
- You're about to invoke `./scripts/build.sh` or `./scripts/container-test.sh` → **stop and ask the user first** (Tier 2 verification)
- You're about to touch bun, ubuntu, builder digest, GitHub Actions, or `package.json` → **Renovate owns these — stop**
- The target version is less than 7 days old → **fall back to the latest ≥7-day-old version**; only flag-and-ask if the user explicitly demands the embargoed version, or if the latest-eligible is older than the current pin (indicates a yank)

## Quick Reference: Where Each Renovate-Blind Pin Lives

```
build/.opencode-version                                  # Surface 1 (script-managed)
build/.opencode-checksums                                # Surface 1 (script-managed)
build/.opencode/opencode.json        plugin[]            # Surface 2 (canonical)
build/.opencode/tui.json             plugin[]            # Surface 2 (must align with opencode.json)
build/skills-lock.json               computedHash        # Surface 4
AGENTS.md, build/AGENTS.md, DEVELOPMENT.md, docs/guides/usage.md  # Surface 3 (skills CLI pin in prose)
```
