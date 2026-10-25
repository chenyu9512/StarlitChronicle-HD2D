extends SceneTree
## A12 evidence capture: image files from actual Godot 2D gameplay.
## Requires a real rendering display (CI uses Xvfb), never --headless.
const World = preload("res://scripts/first_act_world.gd")
const Registry = preload("res://scripts/world_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
const OUT: String = "res://build/art-qa/"
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_capture")

func _record(id: String,world) -> Dictionary:
    var image: Image = root.get_texture().get_image()
    var outfile: String=OUT+id+".png"
    var file: String=ProjectSettings.globalize_path(outfile)
    var result: Error=image.save_png(file)
    var width: int=image.get_width()
    var height: int=image.get_height()
    var center: Color=image.get_pixel(width/2,height/2) if width>0 and height>0 else Color.BLACK
    if result!=OK or width<640 or height<360:
        errors.append("Capture missing/undersized: "+id)
    return {"map":id,"file":outfile,"width":width,"height":height,
        "center_rgb":[snappedf(center.r,0.001),snappedf(center.g,0.001),snappedf(center.b,0.001)],
        "scene_art":world.coastal_scene!=null,"ground_cells":world.layer.get_used_cells().size()}

func _capture() -> void:
    var path: String=ProjectSettings.globalize_path(OUT)
    DirAccess.make_dir_recursive_absolute(path)
    root.size=Vector2i(1152,648)
    var state=State.new()
    var registry=Registry.new()
    registry.bind(state)
    var world=World.new()
    root.add_child(world)
    var result: Array[Dictionary]=[]
    for id in ["map_coast_01","map_coast_02","map_coast_03","map_coast_04"]:
        world.map_profile=registry.profile(id)
        world.build(3,2)
        if world.coastal_scene!=null and not world.coastal_scene.authored_sprites.is_empty():
            var first_key: String=str(world.coastal_scene.authored_sprites.keys()[0])
            var subject: Sprite2D=world.coastal_scene.authored_sprites[first_key]
            # Move camera subject to a genuine scenery feature, without saving.
            world.hero.position=subject.position+Vector2(60,56)
        world.camera.position_smoothing_enabled=false
        world.camera.reset_smoothing()
        for step in range(4):
            await process_frame
        await RenderingServer.frame_post_draw
        result.append(_record(id,world))
    world.map_profile=registry.profile("map_coast_01")
    world.build(3,2)
    if not world.enter_building("inn"):
        errors.append("Cannot enter inn for interior evidence")
    else:
        world.camera.position_smoothing_enabled=false
        for step in range(4):
            await process_frame
        await RenderingServer.frame_post_draw
        result.append(_record("morning_dew_inn",world))
    var manifest: Dictionary={
        "schema":"starlit.art.qa.v1","engine":"Godot 4.7.2",
        "resolution":[1152,648],"mode":"desktop Xvfb GL Compatibility capture",
        "passes":errors.is_empty(),"evidence":result,
        "device_signoff":{"windows_human_review":false,"iphone_real_device":false},
        "notes":"Screenshots prove actual rendered scenes, not subjective final-art quality"}
    var handle: FileAccess=FileAccess.open(OUT+"manifest.json",FileAccess.WRITE)
    if handle==null:
        errors.append("Cannot write screenshot manifest")
    else:
        handle.store_string(JSON.stringify(manifest,"  ")+"\n")
        handle.close()
    if errors.is_empty() and result.size()==5:
        print("PASS A12: 5 real Godot visual captures at 1152x648; device QA remains human")
        quit(0)
    else:
        for failure in errors:
            push_error(failure)
        quit(1)
