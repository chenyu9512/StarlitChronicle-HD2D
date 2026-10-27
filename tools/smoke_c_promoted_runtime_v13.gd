extends SceneTree
## End-to-end scenes, not a resource listing: real world actors, live props,
## genuine 3-frame water effects, and unchanged collision/save.
const World = preload("res://scripts/first_act_world.gd")
const State = preload("res://scripts/first_act_state.gd")
const Registry = preload("res://scripts/world_registry.gd")
const NPC = preload("res://scripts/c_art_regional_npc.gd")
const Manifest = "res://data/assets/c_art_allocated_decor_runtime_v1.json"
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    if not value:
        errors.append(message)

func _run() -> void:
    var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(Manifest))
    check(source is Dictionary, "No promoted prop manifest")
    if not source is Dictionary:
        quit(1)
        return
    var expected: Dictionary = {}
    for item in source.get("placements", []):
        if item is Dictionary:
            var key: String = str(item.get("map_id", ""))
            expected[key] = int(expected.get(key, 0)) + 1
    check(int(source.get("count", 0)) == 25, "25 explicitly approved 32px props not registered")
    var lookup: Dictionary = {
        "map_oaths_01":["npc_oaths_01", "npc_oaths_04"],
        "map_mirror_01":["npc_mirror_03", "npc_mirror_05"]
    }
    for id in ["npc_oaths_01", "npc_oaths_04", "npc_mirror_03", "npc_mirror_05"]:
        check(NPC.costume(id).size() == 4, "Directional costume incomplete for " + id)
    var maps: Array[String] = ["map_coast_01", "map_coast_02", "map_coast_03",
        "map_coast_04", "map_oaths_01", "map_oaths_03",
        "map_city_01", "map_sanctum_01", "map_mirror_01"]
    var result_count: int = 0
    for map_id in maps:
        var state := State.new()
        state.new_game()
        state.chapter = 60
        var router := Registry.new()
        router.bind(state)
        var world := World.new()
        world.map_profile = router.profile(map_id)
        root.add_child(world)
        world.build(60, 2)
        var previous: Dictionary = state._pack().duplicate(true)
        check(world.layer != null and world.layer.tile_set != null,
            map_id + ": no playable TileMap layer")
        check(world.allocated_decor != null, map_id + ": no actual runtime prop layer")
        if world.allocated_decor != null:
            var placed: int = world.allocated_decor.placed.size()
            var wanted: int = int(expected.get(map_id, 0))
            check(placed == wanted, map_id + ": missing live props: %s" % str(world.allocated_decor.skipped))
            result_count += placed
            for item in world.allocated_decor.placed.values():
                var node: Sprite2D = item
                check(node.texture != null and node.texture.get_size() == Vector2(32,32),
                    map_id + ": promoted texture did not display at 32px")
                check(bool(node.get_meta("visual_only", false)),
                    map_id + ": prop changed collision or route contract")
        for id in lookup.get(map_id, []):
            var key: String = "citizen:" + id
            check(world.nodes.has(key), map_id + ": named NPC lost its real world interaction " + id)
            if not world.nodes.has(key):
                continue
            var citizen = world.nodes[key]
            check(citizen.artwork != null and citizen.costume_atlas != null,
                id + ": four-facing character not shown in world")
            if citizen.costume_atlas != null:
                var initial: Texture2D = citizen.costume_atlas.atlas
                citizen.face_player(citizen.global_position + Vector2.LEFT * 25)
                citizen._update_costume()
                check(citizen.costume_atlas.atlas != initial, id + ": visual did not face player")
                check(citizen.costume_atlas.region.size == Vector2(48,48),
                    id + ": incorrectly sliced character strip")
        if map_id == "map_coast_03":
            check(world.coast_waves != null, "Whale shoal wave layer missing")
            if world.coast_waves != null:
                check(world.coast_waves.art_errors.is_empty(),
                    "Raw wave sheets have invalid frame sizes: " + str(world.coast_waves.art_errors))
                check(world.coast_waves.animated.size() >= 1,
                    "No real three-frame shoreline wave visible to player")
                for clip in world.coast_waves.animated:
                    var wave: Sprite2D = clip["sprite"]
                    check(wave.texture != null and wave.texture is AtlasTexture,
                        "Whale shoal motion renders no sprite")
                var waves_before: int = world.coast_waves.animated.size()
                world.coast_waves._process(0.35)
                check(world.coast_waves.animated.size() == waves_before,
                    "Shore FX changed map geometry")
        check(previous == state._pack(), "Art rendering mutated save: " + map_id)
        world.queue_free()
        await process_frame
    check(result_count == 25, "Promoted world sprites do not all appear on their assigned maps")
    if errors.is_empty():
        print("PASS C V13 live: 25 regional 32px props, four uniquely assigned directional NPCs, actual animated whale-shoal waves, no state mutation")
        quit(0)
        return
    for err in errors:
        push_error(err)
    quit(1)
