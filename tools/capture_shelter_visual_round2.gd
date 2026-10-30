extends SceneTree
## Reproducible real Godot framebuffer evidence for shelter visual round 2.
## No editor mock, no fake screenshot and no main-story flags changed.
const State = preload("res://scripts/first_act_state.gd")
const Registry = preload("res://scripts/world_registry.gd")
const World = preload("res://scripts/first_act_world.gd")
const OUTPUT_ENV: String = "SHELTER_CAPTURE_OUT"

func _initialize() -> void:
    call_deferred("_run")

func _error(reason: String) -> void:
    push_error(reason)
    quit(1)

func _save_frame(directory: String, name: String) -> bool:
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        return false
    var path: String = directory.path_join(name+".png")
    if image.save_png(path) != OK:
        return false
    print("REAL_SHELTER_CAPTURE ",path," size=",image.get_size())
    return true

func _frame(world, camera: Camera2D, directory: String,
        name: String, clock: int, center: Vector2, zoom: float) -> bool:
    world.sync_world_clock(1,clock)
    camera.position_smoothing_enabled = false
    camera.position = Vector2.ZERO
    camera.zoom = Vector2(zoom,zoom)
    # Keep player/mission geometry untouched; inspect by camera only.
    camera.offset = center-world.hero.global_position
    for i in range(8):
        await process_frame
    return _save_frame(directory,name)

func _run() -> void:
    var output: String = OS.get_environment(OUTPUT_ENV)
    if output.is_empty():
        output = ProjectSettings.globalize_path("res://build/shelter-round2")
    DirAccess.make_dir_recursive_absolute(output)
    var state = State.new()
    state.new_game()
    var router = Registry.new()
    router.bind(state)
    var world = World.new()
    world.map_profile = router.profile("map_coast_02")
    world.visual_quality = 2
    root.add_child(world)
    world.build(2,2)
    if not world.enter_building("shelter") or world.interior_building != "shelter":
        _error("Cannot enter authored V4 coastal shelter")
        return
    var art = world.root.get_node_or_null("InteriorArt")
    var camera: Camera2D = world.camera
    if art == null or camera == null or world.layer == null:
        _error("Real shelter world layers/camera missing")
        return
    art.set_visual_quality(2)
    var captures: Array = [
        ["day_overview",660,Vector2(36*32+16,26*32+16),1.03],
        ["day_west_ward",660,Vector2(27*32+16,26*32+16),1.55],
        ["day_triage",660,Vector2(39*32+16,26*32+16),1.55],
        ["day_east_recovery",660,Vector2(47*32+16,27*32+16),1.55],
        ["night_triage",1320,Vector2(39*32+16,26*32+16),1.55]
    ]
    var names: Array[String] = []
    for spec in captures:
        var name_id: String = str(spec[0])
        var captured: bool = await _frame(world,camera,output,
            name_id,int(spec[1]),spec[2],float(spec[3]))
        if not captured:
            _error("Failed to capture real Godot frame: " + name_id)
            return
        names.append(name_id)
    var manifest: Dictionary = {
        "schema":"starlit.shelter.godot_render_round2.v1",
        "scene":"map_coast_02__shelter",
        "engine":"Godot 4.7.2",
        "resolution":root.get_visible_rect().size,
        "frames":names,
        "comparison_type":"same runtime, same camera centers, day/night",
        "manually_approved":false
    }
    var output_file: FileAccess = FileAccess.open(
        output.path_join("capture_manifest.json"),FileAccess.WRITE)
    if output_file == null:
        _error("Could not save capture manifest")
        return
    output_file.store_string(JSON.stringify(manifest,"  "))
    output_file.close()
    world.queue_free()
    print("PASS: five unretouched actual shelter gameplay framebuffers")
    quit(0)
