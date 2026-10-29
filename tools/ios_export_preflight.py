#!/usr/bin/env python3
"""Diagnose Godot iOS export preconditions before the expensive editor import.

The unsigned Codemagic path creates an Xcode project first; no Apple account,
code-signing key, or private identifier is embedded by this preflight.
"""
from __future__ import annotations

import argparse
import configparser
import json
from pathlib import Path
import re
import sys
import zipfile


def load_config(path: Path) -> configparser.ConfigParser:
    if not path.is_file():
        raise ValueError("Missing Godot configuration: " + str(path))
    # Godot's project.godot is not a pure INI file: its mandatory
    # config_version=5 lives before the first [section]. Python's standard
    # configparser raises MissingSectionHeaderError on that valid Godot line.
    # Add a parser-only synthetic section; never rewrite project.godot.
    content = path.read_text(encoding="utf-8-sig")
    first_non_comment = next(
        (line.strip() for line in content.splitlines()
         if line.strip() and not line.lstrip().startswith(("#", ";"))),
        "",
    )
    if not first_non_comment.startswith("["):
        if path.name != "project.godot":
            raise ValueError("Missing INI section header: " + str(path))
        content = "[__godot_project_root__]\\n".replace("\\\\n", "\\n") + content
    cfg = configparser.ConfigParser(interpolation=None, delimiters=("=",))
    cfg.read_string(content, source=str(path))
    return cfg


def value(cfg: configparser.ConfigParser, section: str, key: str) -> str:
    return cfg.get(section, key, fallback="").strip().strip('"')


def verify(root: Path, template_dir: Path | None = None) -> list[str]:
    issues: list[str] = []
    project = load_config(root / "project.godot")
    presets = load_config(root / "export_presets.cfg")
    if value(project, "rendering", "textures/vram_compression/import_etc2_astc").lower() != "true":
        issues.append(
            "P0: rendering/textures/vram_compression/import_etc2_astc must "
            "be true for iOS ETC2/ASTC imports (otherwise Godot may print "
            "a blank configuration error)."
        )
    if value(presets, "preset.0", "name") != "iOS" or value(presets, "preset.0", "platform") != "iOS":
        issues.append("P0: preset.0 must be named 'iOS' and target the iOS exporter.")
    team = value(presets, "preset.0.options", "application/app_store_team_id")
    bundle = value(presets, "preset.0.options", "application/bundle_identifier")
    if not re.fullmatch(r"[A-Za-z0-9]{10}", team):
        issues.append("P0: iOS Team ID must be exactly 10 alphanumeric characters.")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle):
        issues.append("P0: iOS Bundle ID must be a reverse-DNS identifier.")
    if value(presets, "preset.0.options", "application/export_project_only").lower() != "true":
        issues.append("P0: Codemagic unsigned build needs application/export_project_only=true.")
    icon = value(project, "application", "config/icon")
    if not icon.startswith("res://") or ".." in Path(icon[6:]).parts:
        issues.append("P0: project.godot application/config/icon has no safe res:// path.")
    else:
        image = root / icon[6:]
        if not image.is_file():
            issues.append("P0: iOS fallback application icon does not exist: " + icon)
        elif image.suffix.lower() == ".png":
            with image.open("rb") as fh:
                if fh.read(8) != b"\x89PNG\r\n\x1a\n":
                    issues.append("P0: application icon is not a valid PNG header: " + icon)
    if template_dir is not None:
        ios_template = template_dir / "ios.zip"
        if not ios_template.is_file() or not zipfile.is_zipfile(ios_template):
            issues.append("P0: iOS export template ios.zip missing/invalid: " + str(ios_template))
    return issues


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--template-dir", type=Path)
    args = parser.parse_args()
    try:
        issues = verify(args.project.resolve(), args.template_dir)
    except (ValueError, OSError, configparser.Error) as exc:
        issues = [str(exc)]
    print(json.dumps({
        "stage": "ios_export_preflight",
        "status": "成功" if not issues else "失败",
        "ios_export_template": "checked" if args.template_dir else "未测试",
        "unsigned_build": True,
        "checks": ["ios preset", "ETC2/ASTC", "icon", "Team ID format", "Bundle ID", "Xcode-only export"],
        "issues": issues,
    }, ensure_ascii=False, indent=2))
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
