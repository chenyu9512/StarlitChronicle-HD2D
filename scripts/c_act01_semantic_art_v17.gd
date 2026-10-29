extends RefCounted
## Act-I semantic art selected from uploaded Golden Horizon 2D PNGs.
## Every value points to a real, Godot-importable runtime alias, never a
## .gdignore production source. Unmatched kinds intentionally return null.
const Art = preload("res://scripts/c_art_overrides.gd")
const ThemeV2 = preload("res://scripts/c_art_theme_v2.gd")
const ROOT: String = "res://assets/art/runtime/act01_semantic_v17/"
const PROPS: Dictionary = {
    "flowerpot": ROOT + "flowerpot.png",
    "sea_crystal": ROOT + "sea_crystal.png",
    # Semantically exact marine species, scaled down for world ambience.
    "crab": ROOT + "crab.png",
    # Old gameplay kind is named palm_tree; coastal regions use a real mangrove
    # rather than the unrelated cherry-blossom PNG from the legacy migration.
    "palm_tree": ROOT + "mangrove.png",
}
const SCENERY: Dictionary = {
    "harbor_crane": ROOT + "harbor_crane.png",
    "sea_wind_pine": ROOT + "sea_wind_pine.png",
    "saltwind_oak": ROOT + "saltwind_oak.png",
    "tide_pool": ROOT + "tide_pool.png",
    # The same crystal cluster also depicts a cave crystal; no duplicate PNG.
    "cave_crystal": ROOT + "sea_crystal.png",
}
const MAPS: Dictionary = {
    "harbor_crane": ["map_coast_02"],
    "sea_wind_pine": ["map_coast_01", "map_coast_02", "map_coast_03", "map_coast_05"],
    "saltwind_oak": ["map_coast_01", "map_coast_02", "map_coast_03", "map_coast_05"],
    "tide_pool": ["map_coast_01", "map_coast_02", "map_coast_03", "map_coast_05"],
    "cave_crystal": ["map_coast_04"],
}

static func prop_path(kind: String) -> String:
    return str(PROPS.get(kind, ""))

static func scenery_path(kind: String, map_id: String) -> String:
    if not MAPS.has(kind) or map_id not in (MAPS[kind] as Array):
        return ""
    return str(SCENERY.get(kind, ""))

static func texture_for_prop(kind: String) -> Texture2D:
    var path: String = prop_path(kind)
    var themed: Texture2D = ThemeV2.texture("prop.coast."+kind)
    return themed if themed != null else (Art.texture(path) if not path.is_empty() else null)

static func texture_for_scenery(kind: String, map_id: String) -> Texture2D:
    var path: String = scenery_path(kind, map_id)
    var themed: Texture2D = ThemeV2.texture("scenery.coast."+kind)
    return themed if themed != null else (Art.texture(path) if not path.is_empty() else null)
