extends SceneTree
## Focused Godot 4.7.2 test with local-theme fixtures supplied by CI.
## Production does not ship any Pixel Fantasy art in this GitHub repository.
const Terrain = preload("res://scripts/world_terrain_atlas_registry.gd")
const TilePool = preload("res://scripts/world_tileset_pool.gd")
const Art = preload("res://scripts/c_art_overrides.gd")
const Root: String = "res://assets/art/local_themes/pixel_fantasy_v1/"
const Regions: Array[String] = [
    "region_coast", "region_oaths", "region_forge", "region_isles",
    "region_mirror", "region_oldland", "region_sanctum", "region_city"
]
var problems: Array[String] = []

func ensure(value: bool, reason: String) -> void:
    if not value:
        problems.append(reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    ensure(FileAccess.file_exists(Root + "active.json"),
        "Fixture switch missing")
    for region_id in Regions:
        var paths: Array[String] = Terrain.pixel_theme_paths(region_id)
        ensure(paths.size() == 2, region_id + " did not resolve explicit local theme")
        if paths.size() != 2:
            continue
        for path in paths:
            ensure(path.begins_with(Root + "regions/"), region_id + " wrong source")
        var actual: Array[String] = Terrain.atlas_sources(region_id, "", "", true)
        ensure(actual == paths, region_id + " live atlas source did not select local theme")
        var ts: TileSet = TilePool.shared(paths)
        ensure(ts != null, region_id + " no usable TileSet")
        if ts == null:
            continue
        ensure(ts.get_source_count() == 2, region_id + " source count")
        for index in [0, 1]:
            var source: TileSetAtlasSource = ts.get_source(index) as TileSetAtlasSource
            ensure(source != null, region_id + " source missing " + str(index))
            if source == null:
                continue
            ensure(source.texture.get_size() == Vector2(256,256), "bad physical atlas size")
            ensure(source.get_tiles_count() == 64, "not all 64 cell tiles registered")
    ensure(Terrain.pixel_theme_paths("region_coast", false).is_empty(),
        "Outdoor terrain must not replace authored indoor TileSet")
    var found: Texture2D = Art.pixel_fantasy_texture(
        "res://assets/art/runtime/act01_global_v14/props/prop_cottage.png")
    ensure(found != null and found.get_width() > 0,
        "Official cottage source not resolved to local Pixel Fantasy image")
    ensure(Art.pixel_fantasy_texture(
        "res://assets/art/runtime/act01_global_v14/props/prop_sign.png") == null,
        "Unreviewed sign must never be remapped")
    # Removing one atlas must roll back *every* region and prop, not just
    # the damaged map. Restore the disposable CI fixture before exiting.
    var atlas: String = Root + "regions/region_city_water.png"
    var absent: String = atlas + ".qa_missing"
    var moved: Error = DirAccess.rename_absolute(
        ProjectSettings.globalize_path(atlas), ProjectSettings.globalize_path(absent))
    ensure(moved == OK, "Could not simulate missing local theme atlas")
    if moved == OK:
        for region_id in Regions:
            ensure(Terrain.pixel_theme_paths(region_id).is_empty(),
                region_id + " mixed local and baseline atlases after pack damage")
        ensure(Art.pixel_fantasy_texture(
            "res://assets/art/runtime/act01_global_v14/props/prop_cottage.png") == null,
            "Local prop remained active with an incomplete regional theme")
        var restored: Error = DirAccess.rename_absolute(
            ProjectSettings.globalize_path(absent), ProjectSettings.globalize_path(atlas))
        ensure(restored == OK, "Failed to restore local theme fixture")
        if restored == OK:
            ensure(Terrain.pixel_theme_ready(), "Complete local theme did not recover")
    if problems.is_empty():
        print("PASS: 8 regions select 16 Pixel Fantasy fixture atlases, 2x64 tiles per region, allowed props resolve, interiors stay untouched.")
        quit(0)
        return
    for p in problems:
        push_error(p)
    quit(1)
