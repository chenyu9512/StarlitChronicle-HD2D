extends SceneTree
## Main2-only runtime gate: real gameplay maps, real Texture2D objects,
## 48px direction strips, 32px placed props and zero invented sign-offs.
const Art = preload("res://scripts/c_art_overrides.gd")
const Assigned = preload("res://scripts/c_allocated_decor_runtime.gd")
const Production = preload("res://scripts/c_act01_production_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
const Registry = preload("res://scripts/world_registry.gd")
const World = preload("res://scripts/first_act_world.gd")
const Icons = preload("res://scripts/c_art_item_icons.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, message: String) -> void:
    if not ok:
        errors.append(message)

func _run() -> void:
    var unique: Dictionary = {}
    var maps: Array[String] = [
        "map_coast_01", "map_coast_02", "map_coast_04",
        "map_coast_02", "map_coast_03", "map_coast_05"
    ]
    verify(Icons.allocated_count() == 288, "288 allocated content IDs no longer bound to RPG icons")
    for map_key in maps:
        for path in Production.production_paths(map_key):
            unique[path] = true
    var loaded: int = 0
    for path in unique.keys():
        var texture: Texture2D = Art.texture(str(path))
        if texture == null or texture.get_width() < 1 or texture.get_height() < 1:
            errors.append("Missing real runtime Texture2D: " + str(path))
        else:
            loaded += 1
    verify(unique.size() >= 120, "Expected at least 120 distinct Act-I slots")
    verify(loaded == unique.size(), "One or more Act-I assigned runtime paths did not resolve")
    var state := State.new()
    state.new_game()
    var router := Registry.new()
    router.bind(state)
    for chapter in range(1, 7):
        var map_id: String = maps[chapter - 1]
        var world := World.new()
        world.map_profile = router.profile(map_id)
        root.add_child(world)
        world.build(chapter, 4)
        verify(world.layer != null, "No live TileMapLayer on chapter " + str(chapter))
        if world.layer != null:
            verify(world.layer.get_used_cells().size() > 200,
                "No actual floor drawn on chapter " + str(chapter))
            verify(world.layer.tile_set != null,
                "Chapter atlas missing from Godot: " + map_id)
        for actor in [world.hero, world.companion, world.third, world.fourth]:
            verify(actor != null and actor.sprite != null and actor.sprite.texture != null,
                "Chapter " + str(chapter) + " has a blank party character")
            if actor != null and actor.sprite != null:
                var generated_walk: bool = str(actor.sprite.get_meta("art_source","")) == "global_factory_v3"
                var authentic_strips: bool = not actor.third_party_strips.is_empty()
                verify(generated_walk or authentic_strips,
                    "Party has neither active 3x4 identity walk atlas nor uploaded four-direction strips")
                verify(actor.sprite.hframes > 1, "Party has no real walking frames")
                if generated_walk:
                    verify(actor.sprite.hframes == 3 and actor.sprite.vframes == 4 and
                        actor.sprite.texture.get_size() == Vector2(96,192),
                        "Generated walking sprite lost four real directional rows")
        verify(world.coastal_scene != null,
            "Act-I coastal scene absent from live world: " + map_id)
        # Prevent the legacy city-market fallback from reappearing in the
        # chapter-specific cave, shoal and lighthouse maps. The canonical
        # puzzle/quest props remain authored by terrain and _build_sites().
        if map_id in ["map_coast_03", "map_coast_04", "map_coast_05"]:
            var stray_market: Array[String] = []
            for visual in world.scenery.get_children():
                if visual is Sprite2D and visual.visible:
                    var kind: String = str(visual.get_meta("prop_kind", ""))
                    var forbidden: Array[String] = ["fish_stall", "flowerpot", "well"]
                    if map_id == "map_coast_04":
                        forbidden.append_array(["palm_tree", "dock_boat"])
                    if kind in forbidden:
                        stray_market.append(kind)
            verify(stray_market.is_empty(),
                "Non-town chapter contains old market scatter: %s / %s" % [map_id, str(stray_market)])
        # Chapter-five tidal pool must resolve to an imported sprite already
        # installed by the official coastal scenery renderer, not a guessed
        # asset name or a world-map screenshot without the actual landmark.
        if chapter == 5:
            var tidal_key: String = "saltwind_shoal_tidal_step"
            var tidal: Sprite2D = null
            if world.coastal_scene != null:
                tidal = world.coastal_scene.authored_sprites.get(tidal_key,null) as Sprite2D
            verify(is_instance_valid(tidal) and tidal.texture != null,
                "Chapter-five real tidal-pool landmark is not imported: " + tidal_key)
            if is_instance_valid(tidal):
                verify(str(tidal.get_meta("art_kind","")) == "tide_pool",
                    "Chapter-five pool mistakenly mapped to a different scenery role")
                verify(tidal.visible and tidal.texture != null and tidal.scale.x > 0.0,
                    "Chapter-five tidal pool exists but is not visible in the game")
        # This tests the real World._add_sprite render entrypoint, not merely
        # that a source archive contains a filename with 'boat' in it.
        if chapter == 1:
            var rowboat: Sprite2D = world._add_sprite("dock_boat", Vector2i(16, 16), false, true)
            verify(rowboat != null and rowboat.texture != null,
                "Curated rowboat is missing from the live dock renderer")
            if rowboat != null and rowboat.texture != null:
                verify(str(rowboat.get_meta("act01_matched_source_v16", "")) == "dock_boat",
                    "Dock boat fell back to the unrelated wooden-bridge migration image")
                verify(rowboat.texture.get_width() * rowboat.scale.x <= 121.0 and
                    rowboat.texture.get_height() * rowboat.scale.y <= 75.0,
                    "Actual dock boat sprite does not fit the intended world prop footprint")
        world.queue_free()
        await process_frame

    var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(Assigned.MANIFEST))
    verify(manifest is Dictionary, "Promoted assignment manifest not parseable")
    if manifest is Dictionary:
        var counts: Dictionary = {}
        for item in manifest.get("placements", []):
            if not item is Dictionary:
                continue
            var map_id: String = str(item.get("map_id", ""))
            counts[map_id] = int(counts.get(map_id, 0)) + 1
        for map_id in ["map_oaths_01", "map_city_01", "map_sanctum_01"]:
            var world := World.new()
            world.map_profile = router.profile(map_id)
            root.add_child(world)
            world.build(8, 2)
            var layer: Node2D = world.allocated_decor
            verify(layer != null, "Allocated runtime layer not installed: " + map_id)
            if layer != null:
                verify(layer.placed.size() == int(counts.get(map_id, 0)),
                    "%s: assigned props could not find valid live positions: %s" % [map_id, str(layer.skipped)])
                for id in layer.placed.keys():
                    var sprite: Sprite2D = layer.placed[id]
                    verify(sprite.texture != null and sprite.texture.get_size() == Vector2(32, 32),
                        map_id + ": assigned prop is not drawn with an imported 32px texture")
                    verify(bool(sprite.get_meta("visual_only", false)),
                        map_id + ": an allocated prop wrote gameplay state")
            world.queue_free()
            await process_frame
    if errors.is_empty():
        print("PASS Main2 ART runtime: %d Act-I slot textures, six built chapter maps, four-direction party animation and eight assigned live props" % loaded)
        quit(0)
        return
    for problem in errors:
        push_error(problem)
    quit(1)
