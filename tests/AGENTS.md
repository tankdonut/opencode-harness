# tests/ — Unit Test Suite (Python)

## Purpose

**Unit tests** for `build/entrypoint.py` bootstrap helper functions. stdlib `unittest` — no pytest, no external test dependencies (matches the container image, which ships python3 with no pip packages).

## ⚠️ CRITICAL: Not Wired Into CI

`tests/test_bootstrap.py` is **NOT invoked by `.github/workflows/build-and-publish-image.yaml`**. CI runs only `scripts/container-test.sh` (the integration suite). This file is **dev-only** — run it manually:

```bash
python3 tests/test_bootstrap.py
```

**Implication**: drift between these tests and the real entrypoint.py goes undetected in CI. If you change bootstrap helpers, run this manually.

## File Inventory

| File | Runs in CI? | Tests |
|------|-------------|-------|
| `test_bootstrap.py` | ❌ No | 16 unit tests for entrypoint.py helpers |
| (`scripts/container-test.sh`) | ✅ Yes | 15 integration tests (black-box, spins containers) |

## Test Architecture

### How It Works (import pattern)
The module under test lives at `build/entrypoint.py`, outside any package, so the suite loads it by path:

```python
_SPEC = importlib.util.spec_from_file_location(
    "entrypoint", Path(__file__).resolve().parent.parent / "build" / "entrypoint.py"
)
entrypoint = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(entrypoint)
```

entrypoint.py's `if __name__ == "__main__"` guard prevents `main()` from executing during import — only helper functions run under test.

### Test style
- stdlib `unittest` (`unittest.TestCase` classes grouped per helper)
- Temp dirs via `tempfile.TemporaryDirectory()` context managers — guaranteed cleanup, no leaks
- Env isolation via `unittest.mock.patch.dict(os.environ)` — `OPENCODE_BOOTSTRAP_FORCE` etc. never leak between tests
- Exit code: nonzero on any failure (CI-gateable, unlike the old bash runner)

## What's Tested

16 test cases covering bootstrap helpers and integration patterns:

| Function / Pattern | Test Cases |
|----------|-----------|
| `derive_config_dir` | basic resolution; raises `BootstrapError` on empty path |
| `create_config_dir` | missing dir (creates), existing dir (idempotent) |
| `copy_config` | missing target (creates), existing no-force (preserves), existing with force (overwrites), missing source (fails), empty args (fails) |
| error-handling contract | `main` callable + `BootstrapError` defined on import |
| `verify_opencode` | returns `False` when the opencode binary exits non-zero (broken binary detection) |
| Skills symlink pattern | symlink + `realpath` resolution, SKILL.md accessible through it |
| `_load_opencode_config` | parses `$schema`+`plugin`, `None` on invalid JSON, `plugin` defaults to `[]` |
| `_count_skills` | recursive SKILL.md counting, non-SKILL.md files ignored |

**Force flag under test**: `OPENCODE_BOOTSTRAP_FORCE` env var (unset/0 = preserve, 1 = overwrite).

## Known Issues

1. **No coverage for**: `copy_theme_config`, `bootstrap_config` (the full orchestration), `install_oh_my_opencode`, `validate_environment`, `validate_config`, `sync_skills` (the symlink *pattern* is tested; the function itself uses absolute container paths like `/opencode/default/` and needs a real container — that's container-test.sh territory).

## Adding New Tests

```python
class MyFunctionTest(unittest.TestCase):
    def test_scenario(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "opencode.json"
            path.write_text("{}", encoding="utf-8")

            result = entrypoint.my_function(str(path))

            self.assertTrue(result)
```

Register by class — `unittest` auto-discovers `TestCase` subclasses; no manual dispatch.

## Integration Test (separate file)

`scripts/container-test.sh` is the **integration** counterpart — it spins real containers and asserts runtime state. See `scripts/AGENTS.md` for its function map. Key differences:

| Aspect | tests/test_bootstrap.py | scripts/container-test.sh |
|--------|------------------------|---------------------------|
| Level | Unit (function-level) | Integration (container-level) |
| Runs in CI | ❌ No | ✅ Yes |
| Spawns containers | ❌ No | ✅ ~30 per run |
| Tests entrypoint helpers directly | ✅ Yes (imports module) | ❌ No (black-box) |
| Assert framework | `unittest` | Inline `if/else log_pass/log_fail` |
| Exit code | 0=pass, 1=fail | 0=pass, 1=fail, 2=setup error |

## Quick Reference

```bash
# Run unit tests manually
python3 tests/test_bootstrap.py

# Run with verbose per-test output
python3 tests/test_bootstrap.py -v

# Run integration tests (CI-equivalent)
./scripts/container-test.sh opencoder:latest
```
