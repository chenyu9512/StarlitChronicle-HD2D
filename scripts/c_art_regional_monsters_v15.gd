extends RefCounted
const RuntimeArt = preload("res://scripts/c_art_runtime.gd")
## Verified source file, matching monster species, frontview PNG only.
## Visual/canon sign-off and real combat animation are separately pending.
const Art = preload("res://scripts/c_art_overrides.gd")
## Species-to-render-source mapping is stored in the official runtime index.
static func battle_path(monster_id: String) -> String:
    return RuntimeArt.monster_source(monster_id)
