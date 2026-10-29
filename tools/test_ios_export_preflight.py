#!/usr/bin/env python3
"""Regression for Codemagic ios_export_preflight MissingSectionHeaderError."""
from __future__ import annotations
import base64
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ios_export_preflight import load_config, verify

PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAF"
    "gAI/ScLytAAAAABJRU5ErkJggg=="
)

PROJECT = """; Starlit Chronicle Godot 4.7.2
; A valid Godot file has config_version before the first section.
config_version=5

[application]
config/name="星灯纪行"
config/icon="res://icons/test.png"

[rendering]
textures/vram_compression/import_etc2_astc=true
"""
PRESETS = """; Unsigned export is only the Xcode project.
[preset.0]
name="iOS"
platform="iOS"

[preset.0.options]
application/app_store_team_id="ABCDE12345"
application/bundle_identifier="com.example.starlitdemo"
application/export_project_only=true
"""


class IosPreflightRegression(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "project.godot").write_text(PROJECT, encoding="utf-8")
        (self.root / "export_presets.cfg").write_text(PRESETS, encoding="utf-8")
        (self.root / "icons").mkdir()
        (self.root / "icons/test.png").write_bytes(PNG)

    def test_godot_root_config_version_not_a_missing_header(self):
        parsed = load_config(self.root / "project.godot")
        self.assertEqual(parsed.get("__godot_project_root__", "config_version"), "5")
        self.assertEqual(parsed.get("application", "config/name"), '"星灯纪行"')
        self.assertEqual(parsed.get("rendering", "textures/vram_compression/import_etc2_astc"), "true")
        self.assertEqual(verify(self.root), [])

    def test_godot_uses_utf8_bom_without_losing_header(self):
        (self.root / "project.godot").write_text(PROJECT, encoding="utf-8-sig")
        self.assertEqual(verify(self.root), [])

    def test_template_integrity_still_enforced(self):
        t = self.root / "templates"
        t.mkdir()
        self.assertTrue(any("ios.zip missing/invalid" in s for s in verify(self.root, t)))
        with zipfile.ZipFile(t / "ios.zip", "w") as archive:
            archive.writestr("ios/.keep", "ok")
        self.assertEqual(verify(self.root, t), [])

    def test_bad_etc2_setting_fails(self):
        (self.root / "project.godot").write_text(
            PROJECT.replace("import_etc2_astc=true", "import_etc2_astc=false"), encoding="utf-8"
        )
        self.assertTrue(any("ETC2/ASTC" in s for s in verify(self.root)))

    def test_bad_ios_team_id_fails(self):
        (self.root / "export_presets.cfg").write_text(
            PRESETS.replace("ABCDE12345", "invalid"), encoding="utf-8"
        )
        self.assertTrue(any("Team ID" in s for s in verify(self.root)))

    def test_non_godot_headerless_ini_still_fails(self):
        (self.root / "export_presets.cfg").write_text('name="iOS"\n', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Missing INI section header"):
            verify(self.root)


if __name__ == "__main__":
    unittest.main()
