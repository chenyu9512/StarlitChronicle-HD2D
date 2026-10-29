extends SceneTree
## Six actual Godot 4.7.2 scene screenshots for five unique first-act map IDs.
## Not an AI illustration: direct off-screen Xvfb GL frame-buffer captures.
const World = preload("res://scripts/first_act_world.gd")
const Registry = preload("res://scripts/world_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
const OUT: String = "res://build/layout-qa/"
const SHOTS: Array[Dictionary] = [
    {"file":"01_dew_village","map":"map_coast_01","focus":"dew_round_square_oak"},
    {"file":"02_white_sand_harbor","map":"map_coast_02","focus":"harbor_crane"},
    {"file":"03_saltwind_switchbacks","map":"map_coast_03","focus":"saltwind_high_watch_rock"},
    {"file":"04_sea_cave_loops","map":"map_coast_04","focus":"cave_boss_arena"},
    {"file":"05_whale_shoal","map":"map_coast_03","focus":"shoal_whalebone_recovery_glow"},
    {"file":"06_tide_lighthouse","map":"map_coast_05","focus":"lighthouse_landmark"}
]
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    root.size=Vector2i(1152,648)
    var progress:=State.new()
    progress.new_game()
    var registry:=Registry.new()
    registry.bind(progress)
    var world:=World.new()
    root.add_child(world)
    var evidence: Array[Dictionary]=[]
    for shot in SHOTS:
        var map_id: String=str(shot["map"])
        world.map_profile=registry.profile(map_id)
        world.build(3,2)
        world.set_visual_quality(2)
        var focus: String=str(shot["focus"])
        var scene_node: Node2D=null
        if world.coastal_scene!=null:
            scene_node=world.coastal_scene.authored_sprites.get(focus,null)
        if scene_node==null:
            errors.append(map_id+": missing real visible art "+focus)
            continue
        world.hero.position=scene_node.position+Vector2(42,52)
        world.camera.position_smoothing_enabled=false
        world.camera.reset_smoothing()
        for frame in range(5):
            await process_frame
        await RenderingServer.frame_post_draw
        var screen: Image=root.get_texture().get_image()
        var filename: String=OUT+str(shot["file"])+".png"
        var saved: Error=screen.save_png(ProjectSettings.globalize_path(filename))
        if saved!=OK or screen.get_width()<640 or screen.get_height()<360:
            errors.append("Failed genuine framebuffer capture: "+filename)
        else:
            evidence.append({"map":map_id,"file":filename,"focus":focus,
                "view":"hero-scale","size":[screen.get_width(),screen.get_height()]})
        # The close hero camera cannot show a complete 94x54 authored
        # settlement. Also capture a separate true engine frame from map
        # center at a calculated full-map zoom, so layout topology can be
        # reviewed without replacing the normal player's camera settings.
        var extent: Vector2i=world.terrain_layout.get("size",Vector2i(96,56))
        var overview_zoom: float=minf(1152.0/(float(extent.x)*32.0),
            648.0/(float(extent.y)*32.0))*0.94
        world.camera.zoom=Vector2.ONE*overview_zoom
        world.hero.position=Vector2(float(extent.x)*16.0,float(extent.y)*16.0)
        world.camera.reset_smoothing()
        for frame in range(5):
            await process_frame
        await RenderingServer.frame_post_draw
        var overview: Image=root.get_texture().get_image()
        var overview_name: String=OUT+str(shot["file"])+"_overview.png"
        var overview_saved: Error=overview.save_png(ProjectSettings.globalize_path(overview_name))
        if overview_saved!=OK or overview.get_width()<640:
            errors.append("Failed full map overview: "+overview_name)
        else:
            evidence.append({"map":map_id,"file":overview_name,
                "view":"complete-map","size":[overview.get_width(),overview.get_height()]})
    var manifest: Dictionary={
        "schema":"starlit.main2.act01.distinct_layout_capture.v1",
        "engine":"Godot 4.7.2","kind":"genuine_xvfb_gl_game_frame",
        "note":"Twelve actual Godot frames: six hero views and six whole-map views, covering five real map IDs. No AI images used.",
        "evidence":evidence,"passes":errors.is_empty() and evidence.size()==12,
        "human_visual_accepted":false
    }
    var handle=FileAccess.open(OUT+"manifest.json",FileAccess.WRITE)
    if handle==null:
        errors.append("Cannot write layout QA manifest")
    else:
        handle.store_string(JSON.stringify(manifest,"  ")+"\n")
        handle.close()
    world.queue_free()
    if errors.is_empty() and evidence.size()==12:
        print("PASS: six hero views plus six real full-layout map overviews from Godot, awaiting human visual approval")
        quit(0)
        return
    for error in errors:
        push_error(error)
    quit(1)
