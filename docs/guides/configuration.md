# opencoder - Configuration Guide

opencoder uses two configuration files to control plugin loading and container behavior. This guide documents their structure and how to modify them.

## Configuration Files Overview

| File | Format | Purpose |
|------|--------|---------|
| `build/.opencode/opencode.json` | JSON | Project plugin list with pinned versions |
| `build/etc/opencode/opencode.jsonc` | JSONC | Container runtime config (compaction, permissions, watcher) |

## Plugin Configuration

**Location:** `build/.opencode/opencode.json`
**Format:** JSON (strict syntax)

```json
{
    "$schema": "https://opencode.ai/config.json",
    "plugin": [
        "@tarquinen/opencode-dcp@3.1.13",
        "cc-safety-net@1.0.6",
        "oh-my-openagent@4.12.0"
    ]
}
```

### Plugins

- `@tarquinen/opencode-dcp@3.1.13` — Distributed context protocol plugin. Pinned to 3.1.13 for reproducibility.
- `cc-safety-net@1.0.6` — Safety guardrails for agent operations. Pinned to 1.0.6.
- `oh-my-openagent@4.12.0` — Multi-agent orchestration with Sisyphus orchestrator. Pinned to 4.12.0.

All plugin versions are pinned. Do not use `@latest` in this file; update versions deliberately.

### Validation

```bash
jq . build/.opencode/opencode.json
```

## Container Configuration

**Location:** `build/etc/opencode/opencode.jsonc`
**Format:** JSONC (supports comments)

This file is copied to `/etc/opencode/opencode.jsonc` inside the container and controls runtime behavior.

```jsonc
{
    "$schema": "https://opencode.ai/config.json",
    // Disable automatic self-updates inside the container
    "autoupdate": false,
    // Conversation compaction settings to manage context size
    "compaction": {
        // Automatically compact long conversations
        "auto": true,
        // Remove low-value messages during compaction
        "prune": true,
        // Tokens reserved to avoid exceeding model context limits
        "reserved": 10000
    },
    // Default agent profile to use when none is specified
    "default_agent": "build",
    // Additional instruction files loaded into the agent context
    "instructions": [
        "AGENTS.md"
    ],
    // Default permission policy for tool usage
    // "ask" prompts before executing the action
    "permission": {
        "edit": "ask",
        "write": "ask",
        "bash": {
            "*": "ask",
            "basename": "allow",
            "dirname": "allow",
            "file": "allow",
            "git branch *": "allow",
            "git diff *": "allow",
            "git log *": "allow",
            "git rev-parse *": "allow",
            "git show *": "allow",
            "git status *": "allow",
            "head *": "allow",
            "ls *": "allow",
            "pwd": "allow",
            "realpath": "allow",
            "stat": "allow",
            "tail *": "allow",
            "wc *": "allow",
            "which": "allow"
        }
    },
    // Sharing behavior for sessions (manual = explicit user action required)
    "share": "manual",
    // File watcher configuration for workspace awareness
    "watcher": {
        "ignore": [
            // Ignore VCS metadata
            ".git/**",
            // Ignore dependency directories
            "node_modules/**",
            // Ignore build outputs
            "dist/**",
            "build/**"
        ]
    }
}
```

### Key Settings

- **`autoupdate: false`** — Prevents OpenCode from updating itself inside the container. Version is pinned via `build/.opencode-version`.
- **`compaction`** — Manages context window usage. `reserved: 10000` keeps 10k tokens free to avoid truncation.
- **`default_agent: "build"`** — Uses the `build` agent profile by default in the container.
- **`instructions: ["AGENTS.md"]`** — Loads project instructions into every agent session.
- **`permission`** — All file edits and writes require confirmation (`"ask"`). Read-only bash commands (`ls`, `cat`, `git log`, etc.) are auto-allowed. Everything else prompts.
- **`share: "manual"`** — Sessions are never shared without explicit user action.
- **`watcher.ignore`** — Excludes `.git`, `node_modules`, `dist`, and `build` directories from file watching.

### Validation

```bash
jq . build/etc/opencode/opencode.jsonc
```

## Container Architecture: HOME vs Workspace

The container splits its filesystem into two distinct directories with separate roles. Understanding this split prevents the most common container deployment mistakes.

| Path | Mount Type | Contents |
| ------ | ----------- | ---------- |
| `/home/opencode` | Named volume (container HOME) | Bun JIT cache, sessions, auth.json, `.opencode/` config+themes, `.agents/skills` symlink, Oh My OpenAgent config |
| `/workspace` | Bind mount (host project) | Your source code, checked-out repos, working files |

**Why the split exists:** Bun standalone binaries need a writable HOME directory for JIT compilation and cache writes. When `/workspace` was the container HOME, bind-mounting a host directory there would shadow the HOME and break those writes (host-owned UIDs differ from the container's `opencode` user). The split ensures container state never depends on host mount permissions.

The entrypoint copies config defaults (opencode.json, tui.json, themes/) from the read-only image source (`/opencode/default/`) into the writable `$HOME/.opencode/` at container start, then exports `OPENCODE_CONFIG` to point there. This means `oh-my-openagent install` can write its config alongside, and user customizations persist in the named volume across container restarts. Skills are exposed through a symlink: `$HOME/.agents/skills` points to `/opencode/default/.agents/skills/`. Nothing is written to the bind-mounted `/workspace`.

## Memory Plugin (opencode-mem)

The `opencode-mem` plugin ships enabled and works out of the box. The entrypoint seeds its config to `~/.config/opencode/opencode-mem.jsonc` from the image default (`build/.opencode/opencode-mem.jsonc`) on first start; edit the HOME copy to customize (it persists in the named volume).

What works with zero configuration:

- **Memory storage, search, and profile injection** — local embeddings, no API needed. The first memory operation downloads the embedding model (network required).

What needs `ZHIPU_API_KEY` (the container's default provider auth):

- **Auto-capture** (background session summaries) and **user-profile learning** run through the `zai-coding-plan` provider via the seeded config. Without the key they are skipped with warnings; everything else keeps working.

Customizing the capture model or using another authenticated provider:

```jsonc
// ~/.config/opencode/opencode-mem.jsonc (inside the container)
"opencodeProvider": "anthropic",   // any provider from `opencode providers list`
"opencodeModel": "claude-haiku-4-5-20251001"
```

The memory database persists at `~/.opencode-mem/data` (HOME named volume). The web UI (memory explorer) listens on container-internal loopback `127.0.0.1:4747` by default — unreachable through port publishing. To expose it:

```bash
# compose: set in .env, then run with published ports
OPENCODE_MEM_WEB_EXPOSED=1
OPENCODE_MEM_WEB_TOKEN=$(openssl rand -hex 32)   # required — protects the web API
docker compose run --rm --service-ports opencode   # compose run needs --service-ports

# plain podman/docker
podman run -it --rm \
  -e OPENCODE_MEM_WEB_EXPOSED=1 \
  -e OPENCODE_MEM_WEB_TOKEN=<token> \
  -p 127.0.0.1:4747:4747 \
  opencoder
```

The entrypoint then seeds a config variant binding `0.0.0.0` with the API token resolved from the environment (never written to a file). The plugin refuses non-loopback binds without a token, so exposure without `OPENCODE_MEM_WEB_TOKEN` falls back to loopback-only with a warning. `OPENCODE_BOOTSTRAP_FORCE=1` re-seeds the config from the image default, overwriting edits; without it, an existing config you edited is preserved (a still-untouched seeded config is swapped when you toggle exposure).

## Container Module Control

The entrypoint script (`build/entrypoint.py`) supports environment variables to install optional skill collections at container startup. `oh-my-openagent` is always installed at build time; the others default to **disabled** and require network access at runtime.

| Variable | Default | Controls |
|----------|---------|----------|
| `ECC_ENABLED` | `false` | Runtime install of `everything-claude-code` skills via skills.sh CLI |
| `SUPERPOWERS_ENABLED` | `false` | Runtime install of `superpowers` skills via skills.sh CLI |

Set a variable to `1`, `true`, or `yes` to enable the corresponding skill set.

### Examples

```bash
# Enable everything-claude-code skills
podman run -it --rm -e ECC_ENABLED=1 opencoder

# Enable both optional skill sets
podman run -it --rm \
  -e ECC_ENABLED=1 \
  -e SUPERPOWERS_ENABLED=1 \
  opencoder

# Run with baseline only (default)
podman run -it --rm opencoder
```

### OMO Subscription Flags

The entrypoint passes subscription flags to `bunx oh-my-openagent install` at container start. Set these to configure which LLM subscriptions to declare:

- `OMO_CLAUDE` — Claude subscription (`yes|no|max20`)
- `OMO_GEMINI` — Gemini subscription (`yes|no`)
- `OMO_COPILOT` — GitHub Copilot subscription (`yes|no`)
- `OMO_OPENAI` — OpenAI subscription (`yes|no`)
- `OMO_OPENCODE_GO` — OpenCode Go subscription (`yes|no`)
- `OMO_OPENCODE_ZEN` — OpenCode Zen subscription (`yes|no`)
- `OMO_ZAI_CODING_PLAN` — ZAI Coding Plan subscription (`yes|no`)

Set `OMO_FORCE=yes` to force reinstall of Oh My OpenAgent regardless of existing state.

> **Note:** `OMO_*` flags are **subscription toggles**, not credentials. They tell Oh My OpenAgent which models to add to agent fallback chains. Authentication is handled separately via environment variables (see below).

## Provider Authentication

OpenCode resolves provider credentials in priority order:

1. **Environment variables** (highest priority) — recommended for containers
2. **Project `.env` file**
3. **`auth.json`** (`~/.local/share/opencode/auth.json`, written by interactive `opencode auth login`)

For containers, pass the API key as an environment variable — no interactive TTY required, and it takes precedence over `auth.json`. The entrypoint does **not** call `opencode auth login`.

### ZAI Coding Plan

| Variable | Required | Purpose |
|----------|----------|---------|
| `ZHIPU_API_KEY` | Yes (to use GLM models) | API key for the `zai-coding-plan` provider (GLM-4.5, GLM-5.x). The base URL is pinned to `https://api.z.ai/api/coding/paas/v4` in `opencode.jsonc` as a workaround for [opencode#11106](https://github.com/anomalyco/opencode/issues/11106). |

```bash
# Run with ZAI Coding Plan authentication
podman run -it --rm \
  -e ZHIPU_API_KEY=your-key-here \
  -e OMO_ZAI_CODING_PLAN=yes \
  opencoder
```

`OMO_ZAI_CODING_PLAN=yes` enables the ZAI models in the fallback chain; `ZHIPU_API_KEY` provides the credential. Both are needed for the models to actually work.

## Adding Plugins

1. Add the plugin to `build/.opencode/opencode.json` with a pinned version:

```json
{
    "$schema": "https://opencode.ai/config.json",
    "plugin": [
        "@tarquinen/opencode-dcp@3.1.13",
        "cc-safety-net@1.0.6",
        "oh-my-openagent@4.12.0",
        "<new-plugin>@<version>"
    ]
}
```

1. Rebuild and test:

```bash
./scripts/build.sh --tag test --no-cache
./scripts/container-test.sh test
```

## Validating Configuration

```bash
# Validate JSON syntax for plugin config
jq . build/.opencode/opencode.json

# Validate JSONC syntax for container config
jq . build/etc/opencode/opencode.jsonc

# Run full pre-build validation
./scripts/validate.sh
```
