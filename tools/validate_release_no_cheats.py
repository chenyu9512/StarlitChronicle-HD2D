#!/usr/bin/env python3
"""Shipping contract: editor commands never run in exported games."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
panel = (root / "scripts/cheat_panel.gd").read_text(encoding="utf-8")
game = (root / "scripts/first_act.gd").read_text(encoding="utf-8")
runner = (root / "tools/d_control/run_main2_ci.py").read_text(encoding="utf-8")

for name in ("_unhandled_input", "_star_pressed", "_show_panel", "_unlock"):
    start = panel.index("func " + name + "(")
    scope = panel[start:].split(" -> void:\n", 1)[1]
    assert scope.startswith('    if not OS.has_feature("editor"):\n        return\n'), name
for name in ("_on_cheat_opened", "_run_cheat"):
    start = game.index("func " + name + "(")
    scope = game[start:].split(" -> void:\n", 1)[1]
    assert scope.startswith('    if not OS.has_feature("editor"):\n        return\n'), name
assert 'if not OS.has_feature("editor"):\n        star.hide()\n        star.disabled = true\n        set_process_unhandled_input(false)\n        return' in panel
assert 'tools/smoke_act01_six_chapters_normal.gd' in runner
assert 'tools/smoke_b_act01_physical_reachability.gd' in runner
print("PASS: exported cheat commands disabled; release normal-play and reachability gates enrolled")
