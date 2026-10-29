extends SceneTree
## Regression: a missing historical res:// tileset must not erase town ground.
const Pool = preload("res://scripts/world_tileset_pool.gd")
const Geography = preload("res://scripts/world_geography.gd")
const World = preload("res://scripts/first_act_world.gd")

var problems: Array[String] = []

func _check(valid: bool, msg: String) -> void:
    if not valid:
        problems.append(msg)

func _initialize() -> void:
    call_deferred("_run")

func _check_nonempty_tiles(label: String, atlas: TileSet) -> void:
    _check(atlas != null, label + " has no TileSet")
    if atlas == null:
        return
    _check(atlas.get_source_count() == 2, label + " ground/water source count wrong")
    for source_id in [0, 1]:
        var source: TileSetAtlasSource = atlas.get_source(source_id) as TileSetAtlasSource
        _check(source != null, label + " missing source " + str(source_id))
        if source == null:
            continue
        var texture: Texture2D = source.texture
        _check(texture != null and texture.get_size() == Vector2(256, 256),
            label + " source is not a physical 256x256 8x8 atlas")
        if texture == null:
            continue
        var img: Image = texture.get_image()
        var opaque: int = 0
        for y in range(8):
            for x in range(8):
                if img.get_pixel(x * 32 + 16, y * 32 + 16).a > 0.95:
                    opaque += 1
        _check(opaque == 64,
            label + " contains missing or transparent tile centers " + str(opaque) + "/64")

func _run() -> void:
    # Invented *logical* tile IDs emulate the disappeared pre-migration files.
    var missing_sources: Array[String] = [
        "res://assets/art/tilesets/regions/__ground_recovery_probe_ground.png",
        "res://assets/art/tilesets/regions/__ground_recovery_probe_water.png",
    ]
    for path in missing_sources:
        _check(not ResourceLoader.exists(path), "probe should be a deliberately absent historical atlas")
        _check(Pool._verified_material_for(path) != null, "no reviewed fallback for " + path)
    var repaired: TileSet = Pool.shared(missing_sources)
    _check_nonempty_tiles("recovered_missing_pair", repaired)
    # Check live geometry and rendered atlas source for two distinct towns.
    var geo := Geography.new()
    var world := World.new()
    root.add_child(world)
    for map_id in ["map_coast_01", "map_coast_02", "map_oaths_01", "map_city_01"]:
        world.map_profile = {"id": map_id, "region_id": (
            "region_coast" if map_id.begins_with("map_coast") else ("region_oaths" if map_id.begins_with("map_oaths") else "region_city"))}
        world.build(1, 2)
        _check(is_instance_valid(world.layer), map_id + " live ground TileMapLayer absent")
        if not is_instance_valid(world.layer):
            continue
        var expected: int = int(world.WIDTH * world.HEIGHT)
        _check(world.layer.get_used_cells().size() == expected,
            map_id + " world has visible nodes but not all painted ground cells")
        _check(world.layer.tile_set != null,
            map_id + " ground TileMapLayer missing TileSet")
        var mid: Vector2i = Vector2i(world.WIDTH / 2, world.HEIGHT / 2)
        _check(world.layer.get_cell_source_id(mid) >= 0,
            map_id + " center ground has no atlas source")
    world.queue_free()
    if problems.is_empty():
        print("PASS: 4 live towns render complete ground layers; missing pre-migration ground/water URLs are rebuilt as opaque semantic atlases")
        quit(0)
        return
    for issue in problems:
        push_error(issue)
    quit(1)
