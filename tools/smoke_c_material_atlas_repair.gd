extends SceneTree
## Regression for the exact map defect: checkerboard transparency, wrong
## terrain/water UV and tiny prop stretched to a house. No gameplay mutations.
const AtlasAdapter = preload("res://scripts/third_party_terrain_adapter.gd")
const TilePool = preload("res://scripts/world_tileset_pool.gd")
const Registry = preload("res://scripts/world_terrain_atlas_registry.gd")
const Structure = preload("res://scripts/world_structure.gd")
const Art = preload("res://scripts/c_art_overrides.gd")

var issues: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, message: String) -> void:
    if not ok:
        issues.append(message)

func _run() -> void:
    TilePool.reset()
    var checked: int = 0
    for map_id in ["map_coast_01", "map_coast_02", "map_coast_03", "map_coast_04", "map_coast_05"]:
        var sources: Array[String] = Registry.atlas_sources("region_coast", map_id)
        var tile_set: TileSet = TilePool.shared(sources)
        verify(tile_set != null, map_id + " terrain atlas did not import")
        if tile_set == null:
            continue
        for source_id in range(2):
            var atlas: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
            verify(atlas != null, map_id + " atlas source %d missing" % source_id)
            if atlas == null:
                continue
            var texture: Texture2D = atlas.texture
            verify(texture != null and texture.get_size() == Vector2(256, 256),
                map_id + " atlas lost 8x8 32px layout")
            if texture == null:
                continue
            var pixels: Image = texture.get_image()
            var failures: int = 0
            for row in range(8):
                for col in range(8):
                    for offset in [Vector2i(0, 0), Vector2i(15, 15), Vector2i(31, 31)]:
                        var c: Color = pixels.get_pixel(col * 32 + offset.x, row * 32 + offset.y)
                        if c.a < 0.99 or c.r + c.g + c.b < 0.13:
                            failures += 1
            verify(failures == 0,
                "%s source %d has %d transparent/black atlas samples" % [map_id, source_id, failures])
            if source_id == 0:
                var sand: Color = pixels.get_pixel(10, 12)
                var pavement: Color = pixels.get_pixel(10, 3 * 32 + 12)
                var cliffs: Color = pixels.get_pixel(10, 6 * 32 + 12)
                verify(sand.distance_to(pavement) > 0.05 and cliffs.distance_to(pavement) > 0.05,
                    map_id + " sand/path/cliff are still the same wrongly repeated source cell")
            checked += 1
    var overlays: Array[String] = [
        "res://assets/art/tilesets/story_v1/region_coast_decals.svg",
        "res://assets/art/exteriors/coast_final_pass/coastal_detail_atlas.svg",
        "res://assets/art/exteriors/coast_final_pass/dew_ground_glaze.svg"
    ]
    for path in overlays:
        verify(AtlasAdapter.supports(path), "Missing overlay adapter: " + path)
        if not Art.exists(path):
            continue
        var set: TileSet = TilePool.shared([path])
        verify(set != null, "Overlay does not have a valid 32px atlas: " + path)
        if set != null:
            var source: TileSetAtlasSource = set.get_source(0) as TileSetAtlasSource
            var sample: Image = source.texture.get_image()
            verify(sample.get_pixel(0, 0).a < 0.9,
                "Overlay paints an opaque 32px blocking square: " + path)
    var facade := Structure.new()
    var slot: String = "res://assets/art/exteriors/coast_final_pass/map_coast_01_house.svg"
    facade.setup("house", "朝露屋", Vector2i(8, 6), "coastal",
        "map_coast_01", 720, Vector2i(0, 3))
    verify(facade.facade == null,
        "Whole house still stretches legacy redirected prop instead of native facade")
    verify(facade.entrance_local == Vector2(0, 96),
        "Building doorway no longer follows authoritative entrance tile")
    facade.free()
    verify(checked == 10, "Not all five coastal map atlas source pairs were exercised")
    if issues.is_empty():
        print("PASS C material repair: five real coast atlases, fully opaque 32px ground/water, separated materials, translucent overlays, safe house facade")
        quit(0)
        return
    for message in issues:
        push_error(message)
    quit(1)
