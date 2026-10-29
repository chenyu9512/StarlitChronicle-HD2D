extends RefCounted
## Verified source file, matching monster species, frontview PNG only.
## Visual/canon sign-off and real combat animation are separately pending.
const Art = preload("res://scripts/c_art_overrides.gd")
const MONSTERS: Dictionary = {
    "mon_oaths_01": "res://assets/art/runtime/region_monsters_v15/mon_oaths_01.png",
    "mon_oaths_02": "res://assets/art/runtime/region_monsters_v15/mon_oaths_02.png",
    "mon_forge_01": "res://assets/art/runtime/region_monsters_v15/mon_forge_01.png",
    "mon_forge_02": "res://assets/art/runtime/region_monsters_v15/mon_forge_02.png",
    "mon_isles_02": "res://assets/art/runtime/region_monsters_v15/mon_isles_02.png",
    "mon_mirror_04": "res://assets/art/runtime/region_monsters_v15/mon_mirror_04.png",
    "mon_oldland_01": "res://assets/art/runtime/region_monsters_v15/mon_oldland_01.png",
}
static func battle_path(monster_id: String) -> String:
    var path: String = str(MONSTERS.get(monster_id, ""))
    return path if not path.is_empty() and Art.exists(path) else ""
