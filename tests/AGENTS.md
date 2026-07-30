# tests/ — Custom Bash Test Framework

## Purpose

TDD-style **unit tests** for `build/entrypoint.sh` bootstrap helper functions. Uses a hand-rolled assertion framework — no bats, no shunit2, no external test dependencies.

## ⚠️ CRITICAL: Not Wired Into CI

`tests/test_bootstrap.sh` is **NOT invoked by `.github/workflows/build-and-publish-image.yaml`**. CI runs only `scripts/container-test.sh` (the integration suite). This file is **dev-only** — run it manually:

```bash
bash tests/test_bootstrap.sh
```

**Implication**: drift between these tests and the real entrypoint.sh goes undetected in CI. If you change bootstrap helpers, run this manually.

## File Inventory

| File | LOC | Runs in CI? | Tests |
|------|-----|-------------|-------|
| `test_bootstrap.sh` | 457 | ❌ No | 9 unit tests for entrypoint.sh helpers |
| (`scripts/container-test.sh`) | 598 | ✅ Yes | 15 integration tests (black-box, spins containers) |

## Test Architecture

### How It Works (stub-override pattern)
"TDD" in the original sense is historical — these are plain unit tests. The mechanism:
1. Defines **stub functions** for the 3 helpers (all return `1` with `STUB_NOT_IMPLEMENTED`)
2. **Sources** `../build/entrypoint.sh` (line 196) which **overrides** the stubs with real implementations
3. entrypoint.sh's `BASH_SOURCE[0] == ${0}` guard (line 483) prevents `main()` from executing during source
4. Tests call the real implementations against temp dirs

### Custom Assertion API (lines 29-126)
```bash
assert_equals "<expected>" "<actual>" "<message>"
assert_file_exists "<path>" "<message>"
assert_dir_exists  "<path>" "<message>"
assert_empty       "<value>" "<message>"
assert_not_empty   "<value>" "<message>"
assert_succeeds    "<command>" "<message>"   # runs in subshell
assert_fails       "<command>" "<message>"   # runs in subshell
```

### Test Runner
```bash
run_test "<name>" <test_function>   # always returns 0 (non-bail); tallies PASS/FAIL/SKIP
skip_test "<name>" "<reason>"        # marks as skipped
```
**Warning**: `main()` returns 0 even when tests fail (line 449, TDD-friendly). CI cannot gate on exit code — must parse output.

## What's Tested

9 test cases covering bootstrap helpers and integration patterns:

| Function / Pattern | Test Cases |
|----------|-----------|
| `derive_config_dir` | basic resolution |
| `create_config_dir` | missing dir (creates), existing dir (idempotent) |
| `copy_config` | missing target (creates), existing no-force (preserves), existing with force (overwrites) |
| `handle_error` | function is defined when entrypoint.sh is sourced |
| `verify_opencode` | returns 1 when the opencode binary exits non-zero (broken binary detection) |
| Skills symlink pattern | `ln -s` + `readlink` creates a working symlink, SKILL.md accessible through it |

**Force flag under test**: `OPENCODE_BOOTSTRAP_FORCE` env var (unset/0 = preserve, 1 = overwrite).

## Conventions

- **Naming**: `test_<function>_<scenario>` (e.g., `test_copy_config_existing_with_force`)
- **Dispatch**: explicit manual calls in `main()` (no auto-discovery)
- **Output**: ANSI color (GREEN pass, RED fail, YELLOW skip) + counters + summary
- **Temp dirs**: `mktemp -d` per test, cleaned with `rm -rf "$temp_dir"` at end
- **Isolation**: `unset OPENCODE_BOOTSTRAP_FORCE` between tests to reset state

## Known Issues

1. **Temp dir leaks**: several early-return paths (`return 1` at lines 232, 240, 280, etc.) skip cleanup. No `trap` cleanup like container-test.sh has. Failed tests leak `/tmp/tmp.XXXXX`.
2. **Exit code always 0**: CI cannot gate on exit code. If wiring into CI, change `main` to `return $TESTS_FAILED`.
3. **Global env mutation**: `OPENCODE_BOOTSTRAP_FORCE` toggled globally — fragile if tests ever run in parallel (they don't, but still).
4. **No coverage for**: `copy_theme_config`, `bootstrap_config` (the full orchestration), `install_oh_my_opencode`, `validate_*`. (`verify_opencode` is partially covered: the broken-binary path is tested; the success path is exercised indirectly by other tests.)

## Adding New Tests

```bash
# 1. Add test function following naming convention
test_my_function_scenario() {
    local temp_dir
    temp_dir="$(mktemp -d)"

    # Setup
    # ...

    # Assert
    assert_equals "expected" "actual" "message"

    # Cleanup (ALWAYS, even on failure paths)
    rm -rf "$temp_dir"
    return 0
}

# 2. Register in main()
main() {
    # ...existing tests...
    run_test "my_function_scenario" test_my_function_scenario
    # ...
}
```

### Defensive Cleanup Pattern (recommended for new tests)
```bash
test_my_function() {
    local temp_dir
    temp_dir="$(mktemp -d)" || return 1

    # Use trap for guaranteed cleanup
    trap 'rm -rf "$temp_dir"' RETURN

    # Test logic...
    assert_equals "x" "y" "z"

    return 0  # trap cleans up
}
```

## Integration Test (separate file)

`scripts/container-test.sh` is the **integration** counterpart — it spins real containers and asserts runtime state. See `scripts/AGENTS.md` for its function map. Key differences:

| Aspect | tests/test_bootstrap.sh | scripts/container-test.sh |
|--------|------------------------|---------------------------|
| Level | Unit (function-level) | Integration (container-level) |
| Runs in CI | ❌ No | ✅ Yes |
| Spawns containers | ❌ No | ✅ ~30 per run |
| Tests entrypoint helpers directly | ✅ Yes (sources) | ❌ No (black-box) |
| Assert framework | `assert_*` helpers | Inline `if/else log_pass/log_fail` |
| Exit code | Always 0 | 0=pass, 1=fail, 2=setup error |

## Quick Reference

```bash
# Run unit tests manually
bash tests/test_bootstrap.sh

# Run with verbose output (if ever added)
# bash tests/test_bootstrap.sh --verbose

# Run integration tests (CI-equivalent)
./scripts/container-test.sh opencoder:latest
```
