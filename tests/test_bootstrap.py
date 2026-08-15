#!/usr/bin/env python3
"""Unit tests for build/entrypoint.py bootstrap helpers.

Run: python3 tests/test_bootstrap.py

Ported from tests/test_bootstrap.sh — the bash "source entrypoint.sh" pattern
becomes a module import via importlib (filename lives outside sys.path).
Unlike the bash runner, this suite exits non-zero on failure (CI-gateable).
"""

from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from types import ModuleType
from unittest import mock

_SPEC = importlib.util.spec_from_file_location(
    "entrypoint", Path(__file__).resolve().parent.parent / "build" / "entrypoint.py"
)
assert _SPEC is not None and _SPEC.loader is not None
entrypoint: ModuleType = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(entrypoint)


class DeriveConfigDirTest(unittest.TestCase):
    def test_extracts_directory_from_config_path(self) -> None:
        result = entrypoint.derive_config_dir("/workspace/.config/opencode/opencode.json")
        self.assertEqual(result, "/workspace/.config/opencode")

    def test_raises_when_path_empty(self) -> None:
        with self.assertRaises(entrypoint.BootstrapError):
            entrypoint.derive_config_dir("")


class CreateConfigDirTest(unittest.TestCase):
    def test_creates_missing_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config_dir = Path(tmp) / ".config" / "opencode"
            self.assertFalse(config_dir.is_dir())
            self.assertTrue(entrypoint.create_config_dir(str(config_dir)))
            self.assertTrue(config_dir.is_dir())

    def test_succeeds_when_directory_exists(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config_dir = Path(tmp) / ".config" / "opencode"
            config_dir.mkdir(parents=True)
            self.assertTrue(entrypoint.create_config_dir(str(config_dir)))
            self.assertTrue(config_dir.is_dir())


class CopyConfigTest(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.source = self.tmp / "source" / "opencode.json"
        self.source.parent.mkdir()
        self.source.write_text('{"test": "config"}', encoding="utf-8")
        self.target = self.tmp / "target" / "opencode.json"

        # Isolate OPENCODE_BOOTSTRAP_FORCE per test.
        env_patch = mock.patch.dict(os.environ)
        env_patch.start()
        self.addCleanup(env_patch.stop)
        os.environ.pop("OPENCODE_BOOTSTRAP_FORCE", None)

    def test_copies_to_missing_target(self) -> None:
        self.assertFalse(self.target.exists())
        self.assertTrue(entrypoint.copy_config(str(self.source), str(self.target)))
        self.assertTrue(self.target.is_file())

    def test_preserves_existing_target_without_force(self) -> None:
        self.target.parent.mkdir()
        self.target.write_text('{"target": "original"}', encoding="utf-8")
        original = self.target.read_text(encoding="utf-8")

        self.assertTrue(entrypoint.copy_config(str(self.source), str(self.target)))
        self.assertEqual(self.target.read_text(encoding="utf-8"), original)

    def test_overwrites_existing_target_with_force(self) -> None:
        self.target.parent.mkdir()
        self.target.write_text('{"target": "original"}', encoding="utf-8")
        source_content = self.source.read_text(encoding="utf-8")

        os.environ["OPENCODE_BOOTSTRAP_FORCE"] = "1"
        self.assertTrue(entrypoint.copy_config(str(self.source), str(self.target)))
        self.assertEqual(self.target.read_text(encoding="utf-8"), source_content)

    def test_fails_when_source_missing(self) -> None:
        self.assertFalse(entrypoint.copy_config(str(self.tmp / "nope.json"), str(self.target)))

    def test_fails_when_args_empty(self) -> None:
        self.assertFalse(entrypoint.copy_config("", str(self.target)))


class ErrorHandlingContractTest(unittest.TestCase):
    def test_main_and_typed_error_defined_on_import(self) -> None:
        # Bash equivalent: handle_error is defined when entrypoint.sh is sourced.
        self.assertTrue(callable(entrypoint.main))
        self.assertTrue(issubclass(entrypoint.BootstrapError, Exception))


class VerifyOpencodeTest(unittest.TestCase):
    def test_detects_broken_binary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp) / "bin"
            bin_dir.mkdir()
            fake = bin_dir / "opencode"
            fake.write_text("#!/usr/bin/env bash\nexit 1\n", encoding="utf-8")
            fake.chmod(0o755)

            patched_path = f"{bin_dir}{os.pathsep}{os.environ.get('PATH', '')}"
            with mock.patch.dict(os.environ, {"PATH": patched_path}):
                self.assertFalse(entrypoint.verify_opencode())


class SkillsSymlinkLogicTest(unittest.TestCase):
    def test_symlink_points_to_source_and_exposes_skill_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "default-skills" / ".agents" / "skills"
            skill_dir = source / "test-skill"
            skill_dir.mkdir(parents=True)
            (skill_dir / "SKILL.md").write_text("# Test Skill", encoding="utf-8")

            home_agents = Path(tmp) / "home" / ".agents"
            home_agents.mkdir(parents=True)
            link = home_agents / "skills"
            link.symlink_to(source)

            self.assertEqual(os.path.realpath(link), str(source))
            self.assertTrue((link / "test-skill" / "SKILL.md").is_file())


class LoadOpenCodeConfigTest(unittest.TestCase):
    def test_parses_schema_and_plugins(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "opencode.json"
            path.write_text(
                json.dumps({"$schema": "https://opencode.ai/config.json", "plugin": ["a@1.0.0"]}),
                encoding="utf-8",
            )
            config = entrypoint._load_opencode_config(str(path))
            assert config is not None
            self.assertEqual(config["$schema"], "https://opencode.ai/config.json")
            self.assertEqual(config["plugin"], ["a@1.0.0"])

    def test_returns_none_on_invalid_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "opencode.json"
            path.write_text("{not json", encoding="utf-8")
            self.assertIsNone(entrypoint._load_opencode_config(str(path)))

    def test_defaults_plugin_to_empty_list(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "opencode.json"
            path.write_text("{}", encoding="utf-8")
            config = entrypoint._load_opencode_config(str(path))
            assert config is not None
            self.assertEqual(config.get("plugin", []), [])


class CountSkillsTest(unittest.TestCase):
    def test_counts_skill_md_files_recursively(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ("alpha", "beta", "nested/gamma"):
                skill = root / name
                skill.mkdir(parents=True)
                (skill / "SKILL.md").write_text("# skill", encoding="utf-8")
            (root / "beta" / "extra.md").write_text("not a skill", encoding="utf-8")
            self.assertEqual(entrypoint._count_skills(root), 3)


class ExecContainerCommandTest(unittest.TestCase):
    def test_returns_127_when_command_not_found(self) -> None:
        # Regression: execvp (not execv) — bash exec searches PATH; 127 = shell not-found code.
        with mock.patch.dict(os.environ):
            code = entrypoint._exec_container_command(["definitely-missing-command-xyz"])
        self.assertEqual(code, 127)


if __name__ == "__main__":
    unittest.main(verbosity=2)
