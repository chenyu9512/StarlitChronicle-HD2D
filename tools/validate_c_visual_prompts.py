#!/usr/bin/env python3
"""C visual prompt and style integration audit; static only, not rendered acceptance."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def run():
    manifest = json.loads((ROOT / "data/assets/c_art_catalog.json").read_text(encoding="utf-8"))
    profiles = json.loads((ROOT / "data/assets/c_visual_prompt_profiles.json").read_text(encoding="utf-8"))
    issues = []
    assets = {x["path"]: x for x in manifest["assets"]}
    categories = set(manifest["categories"])
    instructions = set(profiles.get("categories", {}).keys())
    for category in sorted(categories - instructions):
        issues.append("Uncovered category: " + category)
    for path, prompt in profiles.get("targets", {}).items():
        if path not in assets:
            issues.append("Target does not exist in canonical gallery: " + path)
        if not isinstance(prompt, str) or len(prompt.strip()) < 8:
            issues.append("Target prompt too short: " + path)
    required = {
        "scripts/c_art_manager_ui.gd": ("VisualPrompts.for_asset", "func _open_prompt()", "func _copy_prompt()", "Visual.style_button"),
        "scripts/first_act_ui.gd": ("CVisual.frame", "CVisual.style_button"),
        "scripts/d_title_screen.gd": ("CVisual.frame", "CVisual.style_button"),
        "scripts/map_hud.gd": ("CVisual.frame", "CVisual.style_button"),
        "scripts/battle_hud.gd": ("CVisual.INK", "CVisual.RIM"),
        "scripts/world_ambience.gd": ("CVisual.INK",),
    }
    for filename, markers in required.items():
        path = ROOT / filename
        if not path.exists():
            issues.append("Missing code: " + filename)
            continue
        text = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in text:
                issues.append("Missing integration marker: " + filename + " -> " + marker)
    for path in ("scripts/c_visual_prompts.gd", "scripts/c_visual_design.gd"):
        if not (ROOT / path).exists():
            issues.append("Missing visual module: " + path)
    if "自动" in profiles.get("mode", ""):
        issues.append("Prompt workflow must remain manual and reviewed")
    for item in issues[:60]:
        print("FAIL:", item)
    print("C Visual: %d image catalog entries, %d category profiles, %d specific prompts, %d static issues; Godot QA NOT RUN" %
          (manifest["count"], len(instructions), len(profiles["targets"]), len(issues)))
    return int(bool(issues))
if __name__ == "__main__":
    raise SystemExit(run())
