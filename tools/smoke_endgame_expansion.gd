extends SceneTree
## Endgame batch integration smoke: physical markers, no invented victory,
## V3 save/reload, canonical content counts and Noe provenance.
const Game = preload("res://scripts/first_act.gd")
var game
var faults: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        faults.append(message)

func _touch(marker_id: String) -> void:
    if not game.world.nodes.has(marker_id):
        faults.append("Missing live interaction marker: " + marker_id)
        return
    game.world.hero.position = game.world.nodes[marker_id].position
    game.world.interact()

func _run() -> void:
    game = Game.new()
    root.add_child(game)
    game.progress.save_path = "user://smoke_endgame_v3.json"
    game.progress.backup_path = "user://smoke_endgame_v3.bak.json"
    game.ui.title_overlay.hide()
    game._start(false)
    var bridge = game.endgame_bridge
    _check(bridge.ready, "Endgame registry did not mount")
    _check(bridge.quests.all_side_quests.size()==120, "Quest loader count is not 120")
    _check(bridge.quests.lore_documents.size()==27, "Lore loader count is not 27")
    _check(not bridge.quests.is_quest_available("rq_002", {}), "rq_002 bypassed the chapter-5 lock")
    # New chapter fixture exercises the real world/interact path, but does not
    # directly grant story battle victory or fabricated XP/reward callbacks.
    game.progress.chapter = 46
    game.progress.scene_index = 0
    game._enter_location()
    for marker in ["evac:command","evac:east","evac:south","evac:west"]:
        _check(game.world.nodes.has(marker), "Evacuation marker not physically present: " + marker)
    _touch("evac:east")
    _touch("evac:east")
    _touch("evac:east")
    var squad: Dictionary = bridge.evacuation.squad_statuses.get("EAST_GATE_LEISO", {})
    _check(squad.get("completed_objectives",[]).size()==2,
        "Squad got a forged third-stage victory without real battle receipt")
    _check(not bridge.evacuation.finished, "Unfinished evacuation incorrectly marked successful")
    _check(game._save_progress(), "Endgame V3 save failed")
    var before: Dictionary = bridge.evacuation.export_state()
    _check(game.progress.load_saved(), "Endgame V3 reload failed")
    _check(bridge.bind_progress(game.progress), "Endgame bridge rejected its own saved state")
    _check(before == bridge.evacuation.export_state(), "Evacuation state changed after V3 reload")
    # Canonical ch39 provenance is the same stable object across the 12-year shift.
    # Chapter flags below are a unit-test fixture, not a gameplay completion.
    game.progress.flags["story.ch039.done"] = true
    _check(bridge.ensure_ticket_provenance(game.progress.flags), "Ch39 ticket not captured")
    var ticket: Dictionary = bridge.noe.chapter39_ticket.duplicate(true)
    game.progress.flags["story.ch048.done"] = true
    game.progress.flags["ch049.started"] = true
    game.progress.chapter = 49
    game._enter_location()
    _check(bridge.noe.is_adult_noe_playable, "Adult Noe not enabled by canonical ch49 flags")
    _check(bridge.noe.chapter39_ticket == ticket, "Ch39 ticket identity lost on time skip")
    game.progress.flags["story.ch051.done"] = true
    for chapter_id in [52,53]:
        game.progress.chapter = chapter_id
        game._enter_location()
        _touch("endgame:handover")
        _check(bridge.noe.leadership_handover_phase == chapter_id - 51,
            "Leadership step did not advance at chapter %d" % chapter_id)
        game.progress.flags["story.ch%03d.done" % chapter_id] = true
    game.progress.chapter = 54
    game.progress.flags["ch054.decision_made"] = true
    game.progress.flags["ch054.battle_won"] = true
    game._enter_location()
    _touch("endgame:handover")
    _check(bridge.noe.leadership_handover_phase==3, "Noe leadership phase 3 missing")
    var memorial: Dictionary = bridge.after_scene_committed(game.progress.flags)
    _check(memorial.get("changed",false) and bridge.noe.memorial_finalized,
        "Chapter 54 memorial did not consume the persisted chapter 39 ticket")
    _check(bridge.noe.chapter39_ticket==ticket, "Chapter 54 altered the original ticket")
    _check(game._save_progress(), "Adult Noe V3 save failed")
    _check(game.progress.load_saved() and bridge.bind_progress(game.progress),
        "Adult Noe V3 reload failed")
    _check(bridge.noe.memorial_finalized and bridge.noe.chapter39_ticket==ticket,
        "Noe memorial or ticket lost after reload")
    if faults.is_empty():
        print("PASS: endgame registry, 120+27, rq_002 gate, physical rescue markers, anti-fake-win, V3 recovery, 12-year Noe handover and original ticket")
        quit(0)
    else:
        for fault in faults:
            push_error(fault)
        quit(1)
