#!/usr/bin/env python3
"""Static acceptance for the user-requested map UI policy.

The local TileMap and minimap are fully visible. Global/regional atlas and
per-cell exploration fog are removed. This is a source gate, not a Godot test.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def main() -> int:
    world = read("scripts/first_act_world.gd")
    ui = read("scripts/map_hud.gd")
    view = read("scripts/map_view.gd")
    game = read("scripts/first_act.gd")
    menu = read("scripts/rpg_menu.gd")
    errors: list[str] = []

    def require(ok: bool, message: str) -> None:
        if not ok:
            errors.append(message)

    require(not (ROOT / "scripts/world_fog_v3.gd").exists(),
            "Obsolete fog implementation reintroduced")
    require(not (ROOT / "tools/smoke_world_fog_v3.gd").exists(),
            "Obsolete fog-only smoke test reintroduced")
    for name, source in (
        ("first_act.gd", game),
        ("first_act_world.gd", world),
        ("map_view.gd", view),
        ("map_hud.gd", ui),
    ):
        for token in ("world_fog_v3.gd", "fog.reveal(", "fog.revealed(",
                      "fog.configure(", "fog.percent("):
            require(token not in source, f"{name} still references fog: {token}")
    require("func show_world_map()" not in ui and "world_button" not in ui,
            "World map mode is still accessible from map HUD")
    require("region_button" not in ui and "travel_requested" not in ui,
            "Regional map or map-based travel remains in HUD")
    require("func _draw_atlas(" not in view and "WORLD_ART" not in view,
            "Global/regional atlas renderer remains in map view")
    require('mode = "local"' in view and 'mode = "local"' in ui,
            "Local-only map mode not established")
    require("world.fog_key" not in ui and "world.fog" not in view,
            "Map UI still depends on fog discovery")
    require('"世界地图"' not in menu,
            "Adventure book still exposes global map page")
    require("adventure_menu.map_requested.connect(_open_local_map_from_book)" in game,
            "Adventure book current-area map handler is disconnected")
    require("func _open_local_map_from_book()" in game,
            "Current-area map handler is missing")
    require('atlas.show_world_map()' not in game,
            "Game still invokes removed world atlas method")
    require("func local_frame()" in view and "func _draw_local()" in view,
            "Local map renderer and dynamic viewport must be retained")
    require("small_view = View.new()" in ui and "full_view = View.new()" in ui,
            "Compact and expanded local views must remain")
    print("PASS: no fog implementation, no global atlas, local chart/minimap wired"
          if not errors else "\n".join("FAIL: " + e for e in errors))
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
