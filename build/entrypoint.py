#!/usr/bin/env python3
# opencoder - Container Bootstrap Script (Python).
#
# Runs inside the container at every `podman run` (ENTRYPOINT, never at build
# time). Validates the environment, bootstraps OpenCode config into a writable
# HOME, links baseline skills, optionally installs opt-in skill sets and
# oh-my-opencode, then execs the container CMD.
#
# Ported 1:1 from the former bash entrypoint.sh. Behavioral contract:
#   - All logs go to stderr; stdout stays clean.
#   - Fatal step failures abort bootstrap with exit code 1.
#   - Soft failures (skills sync, OMO install, optional skills) only warn.
#   - Any trailing argv is exec'd as the container command (os.execv).
#
# Stdlib only: the image ships python3 with no pip packages at runtime.

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from collections.abc import Sequence
from datetime import datetime
from pathlib import Path
from typing import Final, TypedDict

# allow: SIZE_OK — single-file container ENTRYPOINT; splitting into a package
# would add a second COPY + import path to the image for no behavioral gain.


class BootstrapError(Exception):
    """Fatal bootstrap failure. `reason` names the failed step (user-facing)."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


# Parsed shape of an opencode.json ("$schema" is not a valid identifier key,
# so the TypedDict is built via functional syntax). Boundary type for
# _load_opencode_config — parse once, trust everywhere.
_OpenCodeConfig = TypedDict(
    "_OpenCodeConfig", {"$schema": str, "plugin": list[str]}, total=False
)


def _read_expected_version() -> str:
    """Expected OpenCode version from /etc/opencode-version ('' when absent)."""
    try:
        return Path("/etc/opencode-version").read_text(encoding="utf-8").strip()
    except OSError:
        return ""


# --- Configuration -----------------------------------------------------------

HOME: Final = os.environ.get("HOME", "")
OPENCODE_VERSION: Final = _read_expected_version()
OPENCODE_THEME: Final = os.environ.get("OPENCODE_THEME", "ayu-dark")
# Writable config destination (in HOME — survives bind-mount shadowing)
HOME_CONFIG_DIR: Final = f"{HOME}/.opencode"
HOME_CONFIG_PATH: Final = f"{HOME_CONFIG_DIR}/opencode.json"
MEM_CONFIG_PATH: Final = f"{HOME}/.config/opencode/opencode-mem.jsonc"
VENDOR_BIN: Final = "/vendor/bin"
# Read-only image defaults (source for bootstrap_config copy)
DEFAULT_CONFIG_SOURCE: Final = "/opencode/default/opencode.json"
DEFAULT_TUI_SOURCE: Final = "/opencode/default/tui.json"
DEFAULT_THEMES_SOURCE: Final = "/opencode/default/themes"
DEFAULT_SKILLS_SOURCE: Final = "/opencode/default/.agents/skills"
DEFAULT_MEM_CONFIG_SOURCE: Final = "/opencode/default/opencode-mem.jsonc"
DEFAULT_MEM_WEB_CONFIG_SOURCE: Final = "/opencode/default/opencode-mem.web.jsonc"
MEM_WEB_TOKEN_ENV: Final = "OPENCODE_MEM_WEB_TOKEN"
SKILLS_CLI_VERSION: Final = "1.5.13"
SKILLS_INSTALL_CWD: Final = "/opencode/default"
REQUIRED_COMMANDS: Final = ("git", "node", "npm", "curl", "jq", "python3", "pip3", "yq")
_TRUTHY: Final = frozenset({"1", "true", "yes"})

# Optional skill sets (installed at runtime, require network):
#   ECC_ENABLED=1          → install everything-claude-code skills
#   SUPERPOWERS_ENABLED=1  → install superpowers skills
# Both default to disabled; oh-my-openagent skills are always baked in.
# Oh-My-OpenCode (OMO) options: OMO_FORCE forces reinstall; OMO_CLAUDE /
# OMO_GEMINI / OMO_COPILOT / OMO_OPENAI / OMO_OPENCODE_GO / OMO_OPENCODE_ZEN /
# OMO_ZAI_CODING_PLAN (yes|no, OMO_CLAUDE also max20) pick subscriptions.

RED: Final = "\033[0;31m"
GREEN: Final = "\033[0;32m"
YELLOW: Final = "\033[1;33m"
NC: Final = "\033[0m"


# --- Logging (stderr only — stdout stays clean) -------------------------------


def _timestamp() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def log(message: str = "") -> None:
    print(f"[{_timestamp()}] {message}", file=sys.stderr, flush=True)


def log_success(message: str) -> None:
    print(f"{GREEN}[{_timestamp()}] ✓ {message}{NC}", file=sys.stderr, flush=True)


def log_error(message: str) -> None:
    print(f"{RED}[{_timestamp()}] ✗ {message}{NC}", file=sys.stderr, flush=True)


def log_warn(message: str) -> None:
    print(f"{YELLOW}[{_timestamp()}] ⚠ {message}{NC}", file=sys.stderr, flush=True)


def _run_to_stderr(cmd: Sequence[str], cwd: str | None = None) -> bool:
    """Run cmd with all output routed to stderr; True on exit code 0."""
    completed = subprocess.run(
        list(cmd), cwd=cwd, stdout=sys.stderr, stderr=sys.stderr, check=False
    )
    return completed.returncode == 0


def _load_opencode_config(path: str) -> _OpenCodeConfig | None:
    """Parse an opencode.json into its typed shape; None when invalid/unreadable."""
    try:
        with open(path, encoding="utf-8") as handle:
            raw = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(raw, dict):
        return None
    plugins_raw = raw.get("plugin", [])
    return {
        "$schema": raw.get("$schema", "") if isinstance(raw.get("$schema", ""), str) else "",
        "plugin": [str(entry) for entry in plugins_raw] if isinstance(plugins_raw, list) else [],
    }


# --- Bootstrap helper functions -----------------------------------------------


def derive_config_dir(config_path: str | None = None) -> str:
    """Directory holding a config file (default: HOME_CONFIG_PATH)."""
    resolved = HOME_CONFIG_PATH if config_path is None else config_path
    if not resolved:
        raise BootstrapError("derive_config_dir: config_path is required")
    return str(Path(resolved).parent)


def create_config_dir(config_dir: str) -> bool:
    """mkdir -p the config directory; True on success."""
    if not config_dir:
        log_error("create_config_dir: config_dir is required")
        return False
    try:
        Path(config_dir).mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        log_error(f"create_config_dir: cannot create {config_dir} ({exc})")
        return False
    return True


def copy_config(source: str, target: str) -> bool:
    """Copy a config file; skips an existing target unless OPENCODE_BOOTSTRAP_FORCE=1."""
    if not source or not target:
        log_error("copy_config: source and target are required")
        return False
    if not Path(source).is_file():
        log_error(f"copy_config: source file not found: {source}")
        return False

    target_path = Path(target)
    try:
        target_path.parent.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        log_error(f"copy_config: cannot create target directory: {target_path.parent} ({exc})")
        return False

    force = os.environ.get("OPENCODE_BOOTSTRAP_FORCE", "0") == "1"
    if force:
        shutil.copy2(source, target_path)
    elif target_path.exists():
        log_warn(f"Config exists at {target}, skipping (set OPENCODE_BOOTSTRAP_FORCE=1 to overwrite)")
    else:
        shutil.copy2(source, target_path)
    return True


def _copy_tree_no_clobber(source: Path, target: Path) -> None:
    """cp -rn: copy a directory tree without overwriting existing files."""
    for item in source.rglob("*"):
        destination = target / item.relative_to(source)
        if item.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
        elif not destination.exists():
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, destination)


def copy_theme_config(config_dir: str) -> bool:
    """Copy tui.json + themes/ from image defaults into the config directory."""
    if not config_dir:
        log_error("copy_theme_config: config_dir is required")
        return False

    if Path(DEFAULT_TUI_SOURCE).is_file():
        if not copy_config(DEFAULT_TUI_SOURCE, f"{config_dir}/tui.json"):
            return False

    if Path(DEFAULT_THEMES_SOURCE).is_dir():
        _copy_tree_no_clobber(Path(DEFAULT_THEMES_SOURCE), Path(config_dir) / "themes")
        log_success(f"Theme files copied ({DEFAULT_THEMES_SOURCE})")
    return True


def bootstrap_config() -> bool:
    """Orchestrate the config bootstrap: dirs, config copy, theme copy."""
    log("Bootstrapping OpenCode configuration...")

    if not create_config_dir(HOME_CONFIG_DIR):
        return False
    if not copy_config(DEFAULT_CONFIG_SOURCE, HOME_CONFIG_PATH):
        return False
    if not copy_theme_config(HOME_CONFIG_DIR):
        return False

    log_success("Configuration bootstrap complete")
    return True


def _read_text_or_empty(path: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8")
    except OSError:
        return ""


def _select_mem_config_source() -> str:
    """Baked opencode-mem config variant to seed: web-exposed when safely enabled."""
    if not _enabled("OPENCODE_MEM_WEB_EXPOSED"):
        return DEFAULT_MEM_CONFIG_SOURCE
    if Path(DEFAULT_MEM_WEB_CONFIG_SOURCE).is_file() and os.environ.get(MEM_WEB_TOKEN_ENV, ""):
        return DEFAULT_MEM_WEB_CONFIG_SOURCE
    log_warn(
        "OPENCODE_MEM_WEB_EXPOSED=1 needs OPENCODE_MEM_WEB_TOKEN set; "
        "web UI stays loopback-only this run"
    )
    return DEFAULT_MEM_CONFIG_SOURCE


def copy_mem_config() -> bool:
    """Seed opencode-mem's config at ~/.config/opencode/opencode-mem.jsonc.

    The plugin reads its config from the global opencode config dir and, when
    the file is absent, writes a template with auto-capture left unconfigured.
    Seeding before first start wires auto-capture to the container's
    zai-coding-plan auth; without a provider key the plugin degrades
    gracefully (capture skipped, storage/search keep working).

    An existing config is preserved unless OPENCODE_BOOTSTRAP_FORCE=1 — except
    one still byte-identical to a baked variant (never user-edited), which is
    swapped to the wanted variant so toggling OPENCODE_MEM_WEB_EXPOSED takes
    effect on existing HOME volumes.
    """
    source = _select_mem_config_source()
    if not Path(source).is_file():
        log_warn(f"opencode-mem config not found at {source}, skipping")
        return True

    existing = _read_text_or_empty(MEM_CONFIG_PATH)
    force = os.environ.get("OPENCODE_BOOTSTRAP_FORCE", "0") == "1"
    if existing and not force:
        if existing == _read_text_or_empty(source):
            return True
        other = (
            DEFAULT_MEM_CONFIG_SOURCE
            if source == DEFAULT_MEM_WEB_CONFIG_SOURCE
            else DEFAULT_MEM_WEB_CONFIG_SOURCE
        )
        if existing != _read_text_or_empty(other):
            log_warn(f"Config exists at {MEM_CONFIG_PATH}, skipping (set OPENCODE_BOOTSTRAP_FORCE=1 to overwrite)")
            return True
        # untouched seed of the other variant — swap to the wanted one

    target_path = Path(MEM_CONFIG_PATH)
    try:
        target_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target_path)
    except OSError as exc:
        log_error(f"copy_mem_config: cannot seed {target_path} from {source} ({exc})")
        return False
    return True


# --- Oh-My-OpenCode installation ---------------------------------------------

_OMO_SUBSCRIPTION_FLAGS: Final = (
    ("claude", "OMO_CLAUDE"),
    ("gemini", "OMO_GEMINI"),
    ("copilot", "OMO_COPILOT"),
    ("openai", "OMO_OPENAI"),
    ("opencode-go", "OMO_OPENCODE_GO"),
    ("opencode-zen", "OMO_OPENCODE_ZEN"),
    ("zai-coding-plan", "OMO_ZAI_CODING_PLAN"),
)


def install_oh_my_opencode() -> bool:
    """Run `bunx oh-my-opencode install` unless ~/.omo/omo.jsonc already exists."""
    log("Oh-My-OpenCode installation enabled")

    omo_config = Path(HOME) / ".omo" / "omo.jsonc"

    if omo_config.is_file():
        if os.environ.get("OMO_FORCE", ""):
            log("OMO_FORCE set, will reinstall")
        else:
            log("OMO config exists, skipping (set OMO_FORCE to reinstall)")
            return True
    else:
        log("OMO config not found, will install")

    cmd = ["bunx", "oh-my-opencode", "install", "--no-tui"]
    cmd += [f"--{flag}={os.environ.get(var, 'no')}" for flag, var in _OMO_SUBSCRIPTION_FLAGS]

    log(f"Running: {' '.join(cmd)}")
    if not _run_to_stderr(cmd):
        log_error("Oh-My-OpenCode installation failed")
        return False

    log_success("Oh-My-OpenCode installed successfully")
    if omo_config.is_file():
        log(f"Config created at: {omo_config}")
    else:
        log_warn(f"Config file not found at {omo_config}")
    return True


# --- Validation ----------------------------------------------------------------


def validate_environment() -> bool:
    """Check required commands and ensure VENDOR_BIN is on PATH."""
    log("Validating environment...")

    for cmd in REQUIRED_COMMANDS:
        if shutil.which(cmd) is None:
            log_error(f"Required command not found: {cmd}")
            return False

    path_entries = os.environ.get("PATH", "").split(os.pathsep)
    if VENDOR_BIN not in path_entries:
        log_warn("Vendor bin not in PATH, adding...")
        os.environ["PATH"] = os.pathsep.join([VENDOR_BIN, *path_entries])

    log_success("Environment validation passed")
    return True


def _opencode_version_line() -> str:
    """First line of `opencode --version` output ('' when it prints nothing)."""
    completed = subprocess.run(
        ["opencode", "--version"], capture_output=True, text=True, check=False
    )
    output = f"{completed.stdout}{completed.stderr}".strip()
    return output.splitlines()[0] if output else ""


def verify_opencode() -> bool:
    """Verify the pre-installed OpenCode binary executes and reports a version."""
    log("Verifying OpenCode installation...")

    if shutil.which("opencode") is None:
        log_error("OpenCode not found - this should be pre-installed in the container image")
        return False

    installed_version = _opencode_version_line()
    if not installed_version:
        log_error("OpenCode binary exists but fails to execute")
        return False

    log_success(f"OpenCode {installed_version} found")

    if OPENCODE_VERSION and OPENCODE_VERSION not in installed_version:
        log_warn(f"Installed version ({installed_version}) differs from expected ({OPENCODE_VERSION})")
    return True


def validate_config() -> bool:
    """Validate HOME_CONFIG_PATH: exists, valid JSON, has $schema and plugins."""
    log("Validating OpenCode configuration...")

    if not Path(HOME_CONFIG_PATH).is_file():
        log_error(f"Config file not found at {HOME_CONFIG_PATH}")
        return False

    config = _load_opencode_config(HOME_CONFIG_PATH)
    if config is None:
        log_error(f"Invalid JSON syntax in {HOME_CONFIG_PATH}")
        return False

    if not config.get("$schema"):
        log_warn("No $schema field in config (recommended: https://opencode.ai/config.json)")

    log(f"Found {len(config.get('plugin', []))} plugins configured")
    log_success("Configuration validation passed")
    return True


# --- Skills --------------------------------------------------------------------


def _count_skills(source: Path) -> int:
    """Number of SKILL.md files under source (bash: find | wc -l)."""
    return sum(
        1
        for _root, _dirs, files in os.walk(source)
        for name in files
        if name == "SKILL.md"
    )


def sync_skills() -> bool:
    """Symlink $HOME/.agents/skills → /opencode/default/.agents/skills."""
    source = Path(DEFAULT_SKILLS_SOURCE)
    if not source.is_dir():
        log_warn(f"Baseline skills not found at {DEFAULT_SKILLS_SOURCE}, skipping sync")
        return True

    home_skills = Path(HOME) / ".agents" / "skills"
    try:
        home_skills.parent.mkdir(parents=True, exist_ok=True)
    except OSError:
        log_error(f"Cannot create {home_skills.parent} (HOME should be writable)")
        return False

    if home_skills.is_symlink():
        if os.path.realpath(home_skills) == DEFAULT_SKILLS_SOURCE:
            log_success(f"Skills symlink already configured ({_count_skills(source)} skills)")
            return True
        home_skills.unlink()  # pointed at the wrong target — recreate below

    if home_skills.is_dir() and not home_skills.is_symlink():
        log_warn(f"{home_skills} exists as a directory (not symlinking to avoid overwriting)")
        return True

    try:
        home_skills.symlink_to(source)
    except OSError:
        log_error(f"Failed to create skills symlink at {home_skills}")
        return False

    log_success(f"Symlinked {_count_skills(source)} skills to {home_skills}")
    return True


def _skills_cli_cmd(repo: str) -> list[str]:
    return [
        "npx", "--yes", f"skills@{SKILLS_CLI_VERSION}", "add", repo,
        "--agent", "opencode", "--skill", "*", "--copy", "-y",
    ]


def _enabled(var: str) -> bool:
    return os.environ.get(var, "0").lower() in _TRUTHY


def install_optional_skills() -> None:
    """Install ECC / superpowers skills when their env gates are set (best-effort)."""
    installed = False

    if _enabled("ECC_ENABLED"):
        log("Installing everything-claude-code skills...")
        if _run_to_stderr(_skills_cli_cmd("affaan-m/everything-claude-code"), cwd=SKILLS_INSTALL_CWD):
            log_success("everything-claude-code skills installed")
            installed = True
        else:
            log_warn("Failed to install everything-claude-code skills (continuing)")

    if _enabled("SUPERPOWERS_ENABLED"):
        log("Installing superpowers skills...")
        if _run_to_stderr(_skills_cli_cmd("obra/superpowers"), cwd=SKILLS_INSTALL_CWD):
            log_success("superpowers skills installed")
            installed = True
        else:
            log_warn("Failed to install superpowers skills (continuing)")

    if installed:
        sync_skills()


# --- Final verification + summary ----------------------------------------------


def verify_installation() -> bool:
    """Final checks: opencode runs, config readable, plugins listed."""
    log("Verifying OpenCode installation...")

    completed = subprocess.run(
        ["opencode", "--version"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if completed.returncode != 0:
        log_error("OpenCode command not working")
        return False

    if not os.access(HOME_CONFIG_PATH, os.R_OK):
        log_error(f"Config file not readable at {HOME_CONFIG_PATH}")
        return False

    config = _load_opencode_config(HOME_CONFIG_PATH)
    if config is not None:
        log("Configured plugins:")
        for plugin in config.get("plugin", []):
            log(f"  - {plugin}")

    log_success("Installation verification passed")
    return True


def print_summary() -> None:
    """Print the end-of-bootstrap summary block."""
    config = _load_opencode_config(HOME_CONFIG_PATH)
    plugin_count = len(config.get("plugin", [])) if config is not None else 0

    log("")
    log("=========================================")
    log("  opencoder Bootstrap Complete")
    log("=========================================")
    log("")
    log(f"OpenCode Version: {_opencode_version_line() or 'unable to determine'}")
    log(f"Config Path: {HOME_CONFIG_PATH}")
    log(f"Theme: {OPENCODE_THEME}")
    log(f"Plugin Count: {plugin_count}")
    log("")
    log("To start using OpenCode:")
    log("  opencode")
    log("")
    log("=========================================")


# --- Main -----------------------------------------------------------------------


def _require(ok: bool, step: str) -> None:
    """Abort bootstrap when a fatal step fails (bash: set -e + ERR trap)."""
    if not ok:
        raise BootstrapError(step)


def _exec_container_command(argv: Sequence[str]) -> int:
    """Replace this process with argv (the container CMD).

    Mirrors bash `exec "$@"`: PATH lookup via execvp; 127 when the command
    is not found, 126 on other execution failures (shell conventions).
    Never returns on success — the process image is replaced.
    """
    log(f"Executing: {' '.join(argv)}")
    os.environ["OPENCODE_CONFIG"] = HOME_CONFIG_PATH
    try:
        os.execvp(argv[0], list(argv))
    except FileNotFoundError:
        log_error(f"Cannot execute command: {argv[0]} not found")
        return 127
    except OSError as exc:
        log_error(f"Cannot execute {argv[0]}: {exc}")
        return 126


def main(argv: Sequence[str]) -> int:
    """Bootstrap the container, then exec argv (the container CMD) if given."""
    log("Starting opencoder bootstrap...")
    log("")

    try:
        _require(validate_environment(), "environment validation")
        _require(verify_opencode(), "opencode verification")
        _require(bootstrap_config(), "config bootstrap")

        if not copy_mem_config():
            log_warn("opencode-mem config bootstrap failed")

        if not sync_skills():
            log_warn("Skills sync failed")

        _require(validate_config(), "config validation")

        if not install_oh_my_opencode():
            log_warn(
                "Oh-My-OpenCode installation failed "
                "(orchestrator features unavailable; container continues)"
            )

        install_optional_skills()

        _require(verify_installation(), "installation verification")
    except BootstrapError as exc:
        log_error(f"Bootstrap failed during {exc.reason} (exit code 1)")
        return 1

    print_summary()
    log_success("Bootstrap completed successfully!")

    if argv:
        return _exec_container_command(argv)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
