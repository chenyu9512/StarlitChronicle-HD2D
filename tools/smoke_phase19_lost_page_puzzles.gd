extends SceneTree
## Stage19-5: authored puzzle cases and real Godot player interaction in first lost-page room.
const Game = preload("res://scripts/first_act.gd")
const State = preload("res://scripts/first_act_state.gd")
const Puzzle = preload("res://scripts/story_evidence_puzzles.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func ck(ok: bool,msg: String) -> void:
    if not ok:
        errors.append(msg)

func _run() -> void:
    var system = Puzzle.new()
    ck(system.errors.is_empty() and system.cases.size()==12,"load twelve unique inference cases")
    var state = State.new()
    state.new_game()
    var before_gold: int = state.gold
    var before_level: int = int(state.actors[0].get("level",1))
    for id in system.cases:
        var quest_id: String = str(id)
        var case: Dictionary = system.entry(quest_id)
        ck(not system.can_attempt(state.rpg,quest_id),"no blind puzzle guessing "+quest_id)
        var observations: Dictionary = state.rpg.get("quest_gallery",{})
        observations[quest_id]={"0":true}
        state.rpg["quest_gallery"] = observations
        ck(not system.can_attempt(state.rpg,quest_id),"need two observations "+quest_id)
        observations[quest_id]["1"]=true
        ck(system.can_attempt(state.rpg,quest_id),"case unlocks after two evidence records "+quest_id)
        var answer: String = str(case["correct_option_id"])
        var bad: String = ""
        for option in case["options"]:
            if str(option["id"])!=answer:
                bad=str(option["id"])
                break
        var failed: Dictionary = system.result(state.rpg,quest_id,bad,25)
        ck(bool(failed.get("accepted",false)) and not bool(failed.get("solved",false)),
            "wrong conclusions are replayable "+quest_id)
        ck(system.can_attempt(state.rpg,quest_id),"failed attempt never locks case "+quest_id)
        var correct: Dictionary = system.result(state.rpg,quest_id,answer,25)
        ck(bool(correct.get("solved",false)) and system.solved(state.rpg,quest_id),
            "individual correct evidence conclusion "+quest_id)
        ck(int(state.rpg["quest_puzzles"][quest_id].get("attempts",0))==2,
            "persistent retry history "+quest_id)
        ck(not system.can_attempt(state.rpg,quest_id),"completed case cannot duplicate award "+quest_id)
    ck(state.gold==before_gold and int(state.actors[0]["level"])==before_level,
        "evidence gameplay does not change gold or player experience")
    ck(state.save(),"twelve solved cases persist in V3")
    var loaded = State.new()
    ck(loaded.load_saved(),"V3 save with deduction records can be reloaded")
    ck(loaded.rpg.get("quest_puzzles",{}).size()==12,"all 12 puzzle outcomes persisted")
    # Player actually enters the unique world room and interacts with evidence.
    var game=Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    var room_id: String="sq_page_01"
    game.progress.chapter=5
    game.progress.rpg["world"]["current_map"]="map_coast_02"
    game.progress.rpg["world"]["bound_chapter"]=5
    game.progress.rpg["quest_gallery"]={}
    game.progress.rpg["quest_puzzles"]={}
    game.progress.flags["side.sq_page_01.done"]=true
    game.progress.rpg["narrative_side"]["sq_page_01.done"]=true
    game._enter_location()
    var portal: String="questdoor:"+room_id
    ck(game.world.nodes.has(portal),"first author room has physical portal")
    if game.world.nodes.has(portal):
        game.world.hero.position=game.world.nodes[portal].position
        game.world.interact()
    ck(game.world.interior_building=="quest__"+room_id,
        "Godot physically enters the authored room")
    for index in range(3):
        var key: String="questcase:"+str(index)
        ck(game.world.nodes.has(key),"interactive real clue prop "+key)
        if not game.world.nodes.has(key):
            continue
        game.world.hero.position=game.world.nodes[key].position
        game.world.interact()
        ck(bool(game.progress.rpg.get("quest_gallery",{}).get(room_id,{}).get(str(index),false)),
            "player interaction records original clue "+key)
    ck(game.pending=="quest_puzzle_choice" and game.ui.choosing,
        "after two observations the third object shows a real deduction interface")
    if game.pending=="quest_puzzle_choice":
        (game.ui.choice_area.get_child(0) as Button).pressed.emit()
        ck(not system.solved(game.progress.rpg,room_id),"incorrect chosen argument stays unsolved")
        game.world.interact()
        ck(game.pending=="quest_puzzle_choice","wrong attempt can be retried at same object")
        (game.ui.choice_area.get_child(1) as Button).pressed.emit()
        ck(system.solved(game.progress.rpg,room_id),"correct inference saved from actual UI")
        ck(game.world.nodes["questcase:2"].modulate==Color("7cecc4"),
            "solved clue changes room appearance")
        ck(not game.branch_runtime.eligible("sq_page_01.p17.b.followup"),
            "evidence cannot fabricate the unchosen side quest A/B route")
    ck(game.progress.save(),"on-site solved puzzle saved")
    var reloaded = State.new()
    ck(reloaded.load_saved(),"on-site puzzle save loads from disk")
    ck(system.solved(reloaded.rpg,room_id),"on-site correct choice survives disk reload")
    if errors.is_empty():
        print("PASS: 12 unique cases, correct/wrong retry, room UI, no rewards, visual state, V3 persistence")
        quit(0)
        return
    for error in errors:
        push_error(error)
    quit(1)
