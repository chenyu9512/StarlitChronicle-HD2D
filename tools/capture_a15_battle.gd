extends SceneTree
## A15: actual battle UI raster evidence, rendered via Xvfb GL compatibility.
## Uses visual-only calls for poses: no combat health, rewards or turns altered.
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")
const OUT: String="res://build/art-qa/"
var errors: Array[String]=[]

func _initialize() -> void:
    call_deferred("_capture")

func _save(label: String,battle) -> Dictionary:
    await RenderingServer.frame_post_draw
    var output: String=OUT+label+".png"
    var picture: Image=root.get_texture().get_image()
    var result: Error=picture.save_png(ProjectSettings.globalize_path(output))
    if result!=OK or picture.get_width()<800 or picture.get_height()<450:
        errors.append("Failed to render "+label)
    return {"name":label,"image":output,"width":picture.get_width(),"height":picture.get_height(),
        "boss_visible":is_instance_valid(battle.enemy_grounding) and battle.enemy_grounding.visible,
        "party_count":battle.actor_stage.avatars.size() if is_instance_valid(battle.actor_stage) else 0,
        "vfx_instances":battle.vfx.effects.size() if is_instance_valid(battle.vfx) else 0}

func _capture() -> void:
    root.size=Vector2i(1152,648)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    var state=State.new()
    var core=RPG.new()
    core.bind(state)
    var battle=Battle.new()
    root.add_child(battle)
    battle.game_core=core
    battle.invincible=true
    battle.start(state,2,true)
    for n in range(6):
        await process_frame
    var evidence: Array[Dictionary]=[]
    evidence.append(await _save("a15_boss_idle",battle))
    var actor_id: String="char_wayfarer"
    var actor_origin: Vector2=battle.actor_stage.actor_point(actor_id)
    var foe_point: Vector2=Vector2(575,285)
    battle.actor_stage.play_action(actor_id,"skill")
    battle.vfx.play_skill(actor_origin,foe_point,{"element":"水","job_id":"tidecaller","tier":6},42,true)
    for n in range(5):
        await process_frame
    evidence.append(await _save("a15_skill_cast",battle))
    battle.actor_stage.play_hit(actor_id,false)
    battle.vfx.play_enemy_attack(foe_point,actor_origin,12)
    for n in range(4):
        await process_frame
    evidence.append(await _save("a15_enemy_impact",battle))
    # Boss phase frame evidence is triggered directly on the same live
    # first_act_battle, without invoking the combat damage handler.
    if is_instance_valid(battle.boss_animation):
        battle.boss_animation.awaken()
        battle.vfx.play_boss_cue(foe_point,2,true)
        for n in range(16):
            await process_frame
        evidence.append(await _save("a16_boss_phase",battle))
    else:
        errors.append("Live Boss missing six-frame awakening stage")
    var manifest: Dictionary={"schema":"starlit.a15.battle-visual.v1","engine":"Godot 4.7.2",
        "size":[1152,648],"captures":evidence,"passes":errors.is_empty(),
        "source":"actual first_act_battle.gd CanvasLayer",
        "device_approval":{"windows":false,"iphone":false},
        "notes":"Presentation-only screenshot checks are not final art-direction approval."}
    var file:=FileAccess.open(OUT+"a15_battle_manifest.json",FileAccess.WRITE)
    if file==null:
        errors.append("Cannot write battle screenshot manifest")
    else:
        file.store_string(JSON.stringify(manifest,"  ")+"\n")
        file.close()
    battle.queue_free()
    if errors.is_empty() and evidence.size()==4:
        print("PASS A16: four actual Godot boss idle/elemental spell/hit/phase screenshots")
        quit(0)
    else:
        for issue in errors:
            push_error(issue)
        quit(1)
