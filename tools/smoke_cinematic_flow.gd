extends SceneTree
## Cinematic P0-P3 acceptance: fresh start, canonical prologue, skip and saves.
const Game=preload("res://scripts/first_act.gd")
const State=preload("res://scripts/first_act_state.gd")
const Director=preload("res://scripts/cinematic_director.gd")
var failures: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _complete_dialogue(game) -> void:
    for i in range(160):
        if not game.ui.dialog_layer.visible or game.ui.choosing:
            break
        game.ui._next()
    check(not game.ui.dialog_layer.visible,"Canon dialogue did not fully close in 160 inputs")

func _run() -> void:
    var game=Game.new()
    game.cinematic_force_play=true
    root.add_child(game)
    check(game.cinematic!=null,"Cinematic director never loaded")
    check(game.ui.title_overlay.visible,"Game title screen was not shown")
    game.ui.title_overlay.hide()
    game._start(false)
    check(game.progress.chapter==0,"New game bypassed canonical prologue chapter")
    check(game.cinematic.is_playing(),"New game immediately opened world without cold open")
    check(game.cinematic.active_id=="cold_open","Wrong new-game cinematic event")
    check(game.world.locked and game.busy,"Player controls were not locked for cold open")
    check(not game.ui.hud.visible,"Main HUD obscures opening cinematic")
    check(game.cinematic.narration.text.length()>4,"Cold open lacks playable story text")
    var original_chapter: int=game.progress.chapter
    var checkpoint_save=State.new()
    check(checkpoint_save.load_saved(),"Cold-open checkpoint did not reach the save file")
    check(str(checkpoint_save.rpg.get("cinematic_checkpoint",""))=="cold_open","Mid-cutscene save did not remember pending opening")
    # A separate restarted game should resume the unfinished scene, not drop the
    # player into the world or replay the canonical prologue from scene zero.
    var resumed_game=Game.new()
    resumed_game.cinematic_force_play=true
    root.add_child(resumed_game)
    resumed_game.ui.title_overlay.hide()
    resumed_game._start(true)
    check(resumed_game.cinematic.is_playing() and resumed_game.cinematic.active_id=="cold_open","Interrupted opening did not resume on actual continue")
    resumed_game.cinematic.skip()
    resumed_game.queue_free()
    game.cinematic.skip()
    check(not game.cinematic.is_playing(),"Cold open cannot be skipped")
    check(not game.busy and not game.world.locked,"Skipping cold open did not restore player control")
    check(bool(game.progress.flags.get("cinematic.cold_open.seen",false)),"Skipped cold open checkpoint was not saved")
    check(not game.progress.rpg.has("cinematic_checkpoint"),"Completed cinematic left an obsolete active checkpoint")
    check(game.progress.chapter==original_chapter,"Skipping cinema changed actual story chapter")
    var seen: Dictionary={}
    for i in range(9):
        var current: String="prologue_%d" % i
        check(game._target()==current,"Prologue task order changed at beat "+str(i))
        game._interact(current)
        check(game.cinematic.is_playing(),"Prologue cinematic missing at beat "+str(i))
        check(game.cinematic.active_id==current,"Incorrect director cue for prologue beat "+str(i))
        check(game.world.locked and not game.ui.hud.visible,"HUD visible while prologue cinematic is active")
        if i==5:
            check(game.cinematic.mode=="danger","Black Star event lacks crisis staging")
        var save_before: int=game.progress.scene_index
        game.cinematic.skip()
        check(bool(game.progress.flags.get("cinematic."+current+".seen",false)),"Cinematic skip failed to mark only the visual cue")
        check(game.progress.scene_index==save_before,"Cinematic skip incorrectly skipped the actual story dialogue")
        check(game.ui.dialog_layer.visible,"Canonical story dialogue was dropped after cinematic skip")
        _complete_dialogue(game)
        seen[current]=true
    check(seen.size()==9,"Not all nine original prologue scenes played")
    check(game.progress.chapter==1,"Prologue ending did not open chapter one")
    check(bool(game.progress.flags.get("story.prologue_done",false)),"Missing original prologue story flag")
    check(game.cinematic.banner.visible,"The First Act title transition did not play")
    check(not game.cinematic.is_playing(),"First Act chapter banner should not lock gameplay")
    check(bool(game.progress.flags.get("cinematic.dialogue.prologue.ten_years.seen",false)),"Last prologue's read dialogue was not remembered")
    var snapshot: Dictionary=game.progress._pack()
    var restored=State.new()
    check(restored.restore_snapshot(snapshot),"New cinema saves cannot migrate")
    check(bool(restored.flags.get("cinematic.cold_open.seen",false)),"Cinematic status was lost during save roundtrip")
    check(restored.chapter==1,"Save restore regressed after prologue")
    game._start(true)
    check(game.progress.chapter==1,"Continue game unexpectedly restarted prologue")
    check(not game.cinematic.is_playing(),"Continue game erroneously replayed new-game cinematic")
    var transitions: Dictionary=game.cinematic_chapters
    check((game.cinematic_scene_blocking.get("scenes",{}) as Dictionary).size()==289,"289 individual shooting-stage records are incomplete")
    check((transitions.get("chapters",[]) as Array).size()==72,"72 canonical chapter cards are incomplete")
    check((transitions.get("acts",[]) as Array).size()==12,"12 thematic act-title cards are incomplete")
    for number in range(1,73):
        game._chapter_card(number)
        check(not game.cinematic.banner_title.text.is_empty(),"No authored chapter title at "+str(number))
    game.cinematic.cancel_all()
    check(not game.cinematic.is_playing(),"Cinematic cancel failed")
    if failures.is_empty():
        print("PASS: first-load cold open, 9 sequential canonical storybeats, cinema skipping without narrative skipping, first act opening, 72 chapter/12 act titles, save/continue and control restoration")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
