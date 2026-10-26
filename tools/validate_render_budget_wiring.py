#!/usr/bin/env python3
"""Static HD-2D render pool and quality wiring gate.

Use with Godot smoke tests: source-level checks are NOT GPU/fps validation.
"""
from __future__ import annotations
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def source(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")

def main() -> int:
    errors: list[str]=[]
    pool=source("scripts/world_tileset_pool.gd")
    def check(ok: bool,message: str) -> None:
        if not ok:
            errors.append(message)
    check("MAX_ENTRIES: int = 12" in pool and "while _recent.size() > MAX_ENTRIES:" in pool,
          "Bounded atlas cache missing")
    check("Art.revision()" in pool and "_sets.clear()" in pool,
          "Override-aware atlas cache invalidation missing")
    clients=[
        "scripts/first_act_world.gd",
        "scripts/world_coastal_scene.gd",
        "scripts/world_interior_art.gd",
        "scripts/c_coastal_painter.gd",
    ]
    for name in clients:
        text=source(name)
        check('res://scripts/world_tileset_pool.gd' in text and "TilePool.shared(" in text,
              "Missing shared atlas pool binding: "+name)
        check("TileSet.new()" not in text and "TileSetAtlasSource.new()" not in text,
              "One-off 32px atlas still created by "+name)
    world=source("scripts/first_act_world.gd")
    ambience=source("scripts/world_ambience.gd")
    interior=source("scripts/world_interior_art.gd")
    coast=source("scripts/world_coastal_scene.gd")
    game=source("scripts/first_act.gd")
    menu=source("scripts/rpg_menu.gd")
    for name,text in (
        ("first_act_world",world),("world_ambience",ambience),
        ("world_interior_art",interior),("world_coastal_scene",coast)
    ):
        check("func set_visual_quality(" in text,name+" has no budget hook")
    check("particle_budget" in ambience and "visual_quality" in ambience,
          "Weather animation does not respect quality budget")
    check("lamp_cap" in interior and "lamp.shadow_enabled" in interior,
          "Interior lighting is not budgeted")
    check("cavern_lights[index].visible=" in coast,
          "Cave lights not budgeted")
    check("visual_quality_changed" in menu and "visual_quality_changed.connect" in game,
          "Settings cannot update live game")
    check("world.set_visual_quality(int(progress.rpg.get(" in game,
          "Saved graphics setting not loaded")
    check("fog.reveal(" not in world and "func _draw_atlas" not in source("scripts/map_view.gd"),
          "Retired exploration fog or global map leaked back into game")
    print("PASS source wiring: shared 32px TileSets + cache cap + quality budgets"
          if not errors else "\n".join("FAIL "+e for e in errors))
    return 1 if errors else 0

if __name__=="__main__":
    raise SystemExit(main())
