extends SceneTree
const BossArt = preload("res://scripts/c_art_librarium_boss_idle.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, details: String) -> void:
    if not ok:
        errors.append(details)

func _run() -> void:
    check(BossArt.accepts("boss.ch017") and BossArt.accepts("boss.ch051"),"Exact boss identity mapping absent")
    check(not BossArt.accepts("boss.ch029"),"Octopus boss was misidentified as wolf or machine")
    var used: Dictionary = {}
    for chapter in [17, 51]:
        var id: String = "boss.ch%03d" % chapter
        var state := State.new()
        state.new_game()
        state.chapter = chapter
        var battle := Battle.new()
        root.add_child(battle)
        battle.invincible = true
        battle.start(state, chapter, true)
        check(is_instance_valid(battle.portrait),id+": actual boss portrait missing")
        check(battle.enemy.get("boss_id", "") == id,id+": story battle context incorrect")
        var actor: Node = battle.librarium_boss_idle
        check(actor != null and actor.enabled,id+": runtime source-original animation not applied")
        if actor != null and actor.enabled:
            check(battle.portrait.texture is AtlasTexture,id+": full uncut 3x4 source sheet exposed")
            check(actor.atlas.region.size == Vector2(actor.frame_size),id+": frame slicing dimensions incorrect")
            check(actor.atlas.atlas.get_size() == Vector2(actor.frame_size * Vector2i(3,4)),id+": imported runtime atlas lost")
            var source: String = str(BossArt.SELECTION[id].get("path",""))
            check(not used.has(source), "Two distinct storyline bosses share one asset")
            used[source] = true
            actor._process(0.25)
            check(actor.frame > 0,id+": no live animated idle frame change")
        battle.queue_free()
        await process_frame
    check(used.size() == 2,"Did not load two distinct story-accurate original enemy sheets")
    if errors.is_empty():
        print("PASS C source-asset promotion: two real source-original pixel bosses exported, sliced and moving in playable battle scenes")
        quit(0)
        return
    for item in errors:
        push_error(item)
    quit(1)
