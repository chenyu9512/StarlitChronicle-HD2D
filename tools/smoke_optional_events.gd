extends SceneTree
const State = preload("res://scripts/first_act_state.gd")
const Optional = preload("res://scripts/optional_director.gd")
const Game = preload("res://scripts/first_act.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok: errors.append(message)

func close_dialogue(game) -> void:
    for i in range(20):
        if not game.ui.dialog_layer.visible or game.ui.choosing:
            break
        game.ui._next()

func _run() -> void:
    var state = State.new()
    state.new_game()
    var service = Optional.new()
    service.bind(state)
    check(int(service.count()["optional_scenes"]) == 84,"84 optional scenes required")
    check(int(service.count()["choice_reactions"]) == 84,"84 reactions required")
    for chapter in [1,7,13,19,25,31,37]:
        state.chapter = chapter
        state.flags["ch%03d.started" % chapter] = true
        var town = service.offered(chapter,"town",1)
        check(not town.is_empty(),"Missing town scene %d" % chapter)
        if not town.is_empty():
            check(service.mark_seen(town),"Cannot mark town event watched")
            check(service.offered(chapter,"town",1).is_empty(),"Town event replayed after watched")
        state.flags["ch%03d.evidence" % chapter] = true
        var evidence = service.offered(chapter,"evidence",2)
        check(not evidence.is_empty(),"Missing evidence scene %d" % chapter)
        if not evidence.is_empty():
            service.mark_seen(evidence)
    var live = Game.new()
    root.add_child(live)
    live.ui.title_overlay.hide()
    live._start(false)
    live.progress.chapter = 1
    live.progress.flags["ch001.started"] = true
    live.progress.scene_index = 1
    live._enter_location()
    check(live.world.nodes.has("optional_town"),"Town event has no map target")
    check(live.world.nodes["optional_town"].visible,"Available town event hidden")
    live._interact("optional_town")
    check(live.pending == "optional_event","Town event not opened")
    close_dialogue(live)
    check(bool(live.progress.rpg["optional_events"].get("ch001.p8.town",false)),"Town event not persisted")
    check(live.progress.scene_index == 1,"Optional scene advanced the main story")
    check(live.progress.save(),"Cannot save optional events")
    var restored = State.new()
    check(restored.load_saved(),"Cannot restore optional save")
    check(bool(restored.rpg.get("optional_events",{}).get("ch001.p8.town",false)),"Watched flag lost")
    if errors.is_empty():
        print("PASS: first 42 chapter optional scene registry, skippable triggers, no duplicate rewards, world marker and save")
        quit(0)
    else:
        for issue in errors: push_error(issue)
        quit(1)
