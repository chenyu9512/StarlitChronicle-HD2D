extends SceneTree
## Real Godot smoke: selected Act-I PNGs reach the actual Sprite2D renderer.
const Art = preload("res://scripts/c_art_overrides.gd")
const Semantic = preload("res://scripts/c_act01_semantic_art_v17.gd")
const Coastal = preload("res://scripts/world_coastal_scene.gd")
const World = preload("res://scripts/first_act_world.gd")
var failures: Array[String] = []

func require(ok: bool, what: String) -> void:
    if not ok:
        failures.append(what)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for id in Semantic.PROPS.keys():
        var path: String = Semantic.prop_path(str(id))
        var image: Texture2D = Art.texture(path)
        require(image != null and image.get_width() > 0 and image.get_height() > 0,
            "Real prop image missing: " + str(id))
    for id in Semantic.SCENERY.keys():
        var candidate: String = str(Semantic.SCENERY[id])
        var image: Texture2D = Art.texture(candidate)
        require(image != null and image.get_width() > 0 and image.get_height() > 0,
            "Real scenery PNG missing: " + str(id))
    require(Semantic.scenery_path("cave_crystal", "map_coast_04") ==
        Semantic.prop_path("sea_crystal"), "Cave and shore crystals must share one file")
    require(Semantic.scenery_path("harbor_crane", "map_coast_01").is_empty(),
        "A harbour crane must not appear in the morning village")
    var scene := Coastal.new()
    scene.map_id = "map_coast_02"
    root.add_child(scene)
    for id in ["harbor_crane","sea_wind_pine","saltwind_oak","tide_pool"]:
        var sprite: Sprite2D = scene.call("_sprite",id,Vector2i(10,10)) as Sprite2D
        require(sprite != null, "Scenery did not produce Sprite2D: " + id)
        if sprite != null:
            require(sprite.texture != null and str(sprite.get_meta("semantic_art_v17","")) == id,
                "Wrong scene art / legacy fallback: " + id)
            sprite.free()
    scene.map_id = "map_coast_04"
    var cave_crystal: Sprite2D = scene.call("_sprite","cave_crystal",Vector2i(10,10)) as Sprite2D
    require(cave_crystal != null and str(cave_crystal.get_meta("semantic_art_v17","")) == "cave_crystal",
        "Actual cave crystal did not load its selected image")
    if cave_crystal != null:
        cave_crystal.free()
    # Do not falsely render old unrelated SVG redirects as stalactites.
    require(scene.call("_sprite","cave_stalactite",Vector2i(9,10)) == null,
        "Unmatched cave geometry was wrongly rendered from an unrelated image")
    var marker: Sprite2D = scene.call("_sprite","quest_glow",Vector2i(11,10)) as Sprite2D
    require(marker != null and marker.texture != null,"Quest glow has no valid visual")
    if marker != null:
        marker.free()
    require(scene.call("_wave_glimmer_texture") != null,
        "Procedural water glimmer is missing")
    var world := World.new()
    root.add_child(world)
    world.chapter = 2
    world.map_profile = {"id":"map_coast_02"}
    world.scenery = Node2D.new()
    world.add_child(world.scenery)
    for kind in ["flowerpot","sea_crystal","palm_tree","crab"]:
        var prop: Sprite2D = world._add_sprite(kind,Vector2i(12,13),false,true)
        require(prop != null and prop.texture != null,"Real world prop texture missing: "+kind)
        if prop != null:
            require(str(prop.get_meta("act01_semantic_source_v17","")) == kind,
                "World re-used old visually invalid art: "+kind)
            if prop.texture != null:
                var size: Vector2 = prop.texture.get_size()*prop.scale
                require(size.x <= (46.0 if kind == "crab" else 113.0) and size.y <= (47.0 if kind == "crab" else 161.0),
                    "World footpoint sprite is oversized: "+kind)
    var boat: Sprite2D = world._add_sprite("dock_boat",Vector2i(14,13),false,true)
    require(boat != null and str(boat.get_meta("act01_matched_source_v16","")) == "dock_boat",
        "Existing real dock boat was regressed")
    if failures.is_empty():
        print("PASS: selected coast assets genuinely load as Sprite2D; no mismatched crane, cave geometry or sea rocks")
        quit(0)
    else:
        for fault in failures:
            push_error(fault)
        quit(1)
