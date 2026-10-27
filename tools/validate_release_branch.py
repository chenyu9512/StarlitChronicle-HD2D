#!/usr/bin/env python3
"""Check that this branch contains only Godot runtime files and active art aliases."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
assert (root / "project.godot").is_file()
assert (root / "scenes/first_act.tscn").is_file()
assert not (root / "assets/art/source_packs").exists(), "Source packs leaked into slim branch"
assert not (root / "assets/art/candidates").exists(), "Candidate archive leaked"
assert not (root / "docs").exists(), "Development notes leaked"
manifest = json.loads((root / "data/assets/c_act01_global_distribution_v14.json").read_text("utf-8"))
assert manifest["packaging"] == "runtime_only"
active = {value for cat in ("props", "scenery", "monsters") for value in manifest["runtime"][cat].values()}
assert len(active) == 25
physical = list((root / "assets/art/runtime/act01_global_v14").rglob("*.png"))
assert len(physical) == 25
assert len({str(p) for p in physical}) == 25
for path in active:
    assert (root / path.removeprefix("res://")).is_file(), path
assert (root / "assets/art/runtime/imported/librarium/dynamo_3frame.png").is_file()
assert (root / "assets/art/runtime/imported/librarium/skoll_3frame.png").is_file()
assert len(list((root / "assets/art/external").rglob("*.png"))) >= 600
print("PASS: trim boundary, 25 active aliases, imported Boss frames, and playable project paths")
