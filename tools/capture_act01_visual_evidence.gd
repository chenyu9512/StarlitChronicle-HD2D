extends SceneTree
## Capture real, unobstructed first-act gameplay frames; manual art sign-off remains separate.
const Game = preload("res://scripts/first_act.gd")
const MAPS: Dictionary = {1:"map_coast_01",2:"map_coast_02",3:"map_coast_04",4:"map_coast_02",5:"map_coast_03",6:"map_coast_05"}
const INTERIORS: Dictionary = {1:"house",2:"shelter",4:"tavern"}
const LANDMARKS: Dictionary = {1:"great-oak",3:"cave_relic",5:"saltwind_shoal_tidal_step",6:"lighthouse_landmark"}

func _initialize() -> void:
    call_deferred("_capture")

func _save_frame(output: String, filename: String) -> bool:
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("No framebuffer for " + filename)
        return false
    var location: String = "%s/%s.png" % [output,filename]
    if image.save_png(ProjectSettings.globalize_path(location)) != OK:
        push_error("Frame write failed: " + location)
        return false
    print("CAPTURED (not manually approved): " + location)
    return true

func _save_clean_frame(game, output: String, filename: String) -> bool:
    # Separate art-only frame: HUD/minimap otherwise cover the scene.
    game.ui.root.hide()
    game.atlas.root.hide()
    for frame in range(3):
        await process_frame
    var saved: bool = _save_frame(output,filename+"_world")
    game.ui.root.show()
    game.atlas.root.show()
    return saved

func _save_landmark_frame(game, output: String, chapter: int, landmark_id: String) -> bool:
    # Extra camera-only evidence at the actual imported scenery node. Do not
    # teleport the party, mutate world state or present this as route QA.
    if not is_instance_valid(game.world.coastal_scene):
        push_error("No coastal scene for landmark: " + landmark_id)
        return false
    var landmark: Sprite2D = game.world.coastal_scene.authored_sprites.get(landmark_id, null) as Sprite2D
    # V18 authored Golden Horizon props live in the curated dresser, not the
    # older exterior scenery registry. Never fake a prop screenshot by moving
    # the actor to a guessed location on the map.
    if not is_instance_valid(landmark) and is_instance_valid(game.world.coastal_scene.hd2d_dressing):
        for candidate in game.world.coastal_scene.hd2d_dressing.placed.values():
            if candidate is Sprite2D and str(candidate.get_meta("art_kind",""))==landmark_id:
                landmark=candidate
                break
    if not is_instance_valid(landmark) or landmark.texture == null:
        push_error("Missing imported landmark sprite: " + landmark_id)
        return false
    var camera: Camera2D = game.world.camera
    var previous_offset: Vector2 = camera.offset
    var previous_smoothing: bool = camera.position_smoothing_enabled
    camera.position_smoothing_enabled = false
    camera.offset = landmark.global_position - game.world.hero.global_position
    for frame in range(6):
        await process_frame
    var name: String = "chapter_%02d_landmark" % chapter
    var saved: bool = _save_frame(output, name)
    if saved:
        saved = await _save_clean_frame(game, output, name)
    camera.offset = previous_offset
    camera.position_smoothing_enabled = previous_smoothing
    if saved:
        print("EVIDENCE_LANDMARK chapter=%d sprite=%s (camera-only inspection)" % [chapter, landmark_id])
    return saved

func _capture() -> void:
    # CI must install Noto CJK: an unreadable/tofu UI is not visual evidence.
    var cjk_font := SystemFont.new()
    cjk_font.font_names = PackedStringArray(["Noto Sans CJK SC","Noto Sans CJK JP","Noto Sans"])
    ThemeDB.fallback_font = cjk_font
    ThemeDB.get_default_theme().default_font = cjk_font
    var output: String = "res://build/main2-art-qa/visual"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    # Starting a real graphical game can play the prologue. Stop presentation
    # only; do not advance story flags or pretend an opening dialogue is a map.
    game.cinematic.cancel_all()
    game.cinematic_camera.restore()
    game.busy = false
    game.paused_for_dialogue = false
    game.ui.title_overlay.hide()
    game.ui.dialog_layer.hide()
    game.ui.menu_layer.hide()
    for chapter in range(1,7):
        var target: String = str(MAPS[chapter])
        if game.world_router.act01_target_map(chapter) != target:
            push_error("Chapter %d canonical map mismatch" % chapter)
            quit(1)
            return
        game.progress.chapter = chapter
        game.progress.scene_index = 0
        game.progress.rpg["world"]["current_map"] = target
        game.progress.rpg["world"]["bound_chapter"] = chapter
        game.progress.rpg["world"].erase("indoor_building")
        game.progress.rpg["world"].erase("outdoor_return")
        game.world.interior_building = ""
        game.world.interior_kind = ""
        game._enter_location()
        game.ui.dialog_layer.hide()
        if game.world_router.current_map() != target or not game.world.interior_building.is_empty():
            push_error("Chapter %d not rendered in expected exterior map" % chapter)
            quit(1)
            return
        for frame in range(12):
            await process_frame
        if not _save_frame(output,"chapter_%02d" % chapter):
            quit(1)
            return
        if not await _save_clean_frame(game,output,"chapter_%02d" % chapter):
            quit(1)
            return
        # Actual landmark evidence is captured below using the camera ONLY.
        # Do not teleport the hero or mutate quest/collision/save state for art QA.
        print("EVIDENCE_MAP chapter=%d map=%s" % [chapter,target])
        if LANDMARKS.has(chapter):
            if not await _save_landmark_frame(game, output, chapter, str(LANDMARKS[chapter])):
                quit(1)
                return
        if INTERIORS.has(chapter):
            var interior: String = str(INTERIORS[chapter])
            if not game.world.enter_building(interior) or game.world.interior_building != interior:
                push_error("Chapter %d missing actual %s interior" % [chapter,interior])
                quit(1)
                return
            game.ui.dialog_layer.hide()
            for frame in range(12):
                await process_frame
            if not _save_frame(output,"chapter_%02d_%s" % [chapter,interior]):
                quit(1)
                return
            if not await _save_clean_frame(game,output,"chapter_%02d_%s" % [chapter,interior]):
                quit(1)
                return
            print("EVIDENCE_INTERIOR chapter=%d map=%s room=%s" % [chapter,target,interior])
    quit(0)
