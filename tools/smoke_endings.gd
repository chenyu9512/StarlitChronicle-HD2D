extends SceneTree
## 三结局：正典前置条件、失落航页实际收集、命运选择、4场后日谈、永久存档/回放。
const Game = preload("res://scripts/first_act.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")
const Ending = preload("res://scripts/ending_director.gd")
var faults: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, text: String) -> void:
    if not ok:
        faults.append(text)

func drain(game) -> void:
    for i in range(80):
        if not game.ui.dialog_layer.visible or game.ui.choosing:
            break
        game.ui._next()

func _run() -> void:
    var director = Ending.new()
    var state = State.new()
    var core = RPG.new()
    core.bind(state)
    verify(director.endings.size() == 3, "Expected three canon endings")
    var raw: Dictionary = core.chapter_data(72)
    var scene: Dictionary = raw.get("scenes", [])[4]
    var ending_choice: Dictionary = scene.get("choice", {})
    state.flags["story.ch072.done"] = true
    state.flags["ch071.battle_won"] = true
    var start_options: Array = director.choices(ending_choice, state.flags).get("options", [])
    verify(start_options.size() == 3, "Final story must have three options")
    verify(not bool(start_options[0].get("locked",false)), "A locked")
    verify(not bool(start_options[1].get("locked",false)), "B locked")
    verify(bool(start_options[2].get("locked",false)), "C must be locked without world conditions")
    var page_count: int = 0
    for quest in core.narrative_side_quests:
        if str(quest.get("type","")) != "lost_page":
            continue
        page_count += 1
        for stage in quest.get("stages", []):
            var choice: Dictionary = stage.get("choice", {})
            var options: Array = choice.get("options", [])
            core.advance_story_side(quest, options[0] if not options.is_empty() else {})
    verify(page_count == 12, "Expected 12 lost-page quests")
    verify(bool(state.flags.get("world.all_twelve_pages",false)), "12-page completion flag missing")
    state.flags["world.distributed_network"] = true
    state.flags["world.seven_lanterns"] = true
    verify(director.can_choose("C", state.flags), "Canon true ending must be unlocked after all conditions")
    verify(director.scenes("C").size() == 4, "True ending must have four complete scenes")
    for label in ["A","B","C"]:
        verify(director.scenes(label).size() == 4, "Ending %s scenes missing" % label)
    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    game.progress.chapter = 72
    game.progress.scene_index = 4
    for key in state.flags.keys():
        game.progress.flags[key] = state.flags[key]
    game._enter_location()
    game._begin_ending_choice()
    verify(game.ui.choosing, "Ending picker is not open")
    var buttons: Array[Node] = game.ui.choice_area.get_children()
    verify(buttons.size() == 3, "Three ending buttons must show")
    if buttons.size() == 3:
        verify(not (buttons[2] as Button).disabled, "True ending button is still disabled")
        (buttons[2] as Button).pressed.emit()
        verify(game.ui.dialog_layer.visible, "Ending epilogue must begin")
        drain(game)
    verify(bool(game.progress.flags.get("story.complete",false)), "Game completion flag not written")
    verify(str(game.progress.rpg.get("ending_id","")) == "C", "Chosen ending not saved")
    verify(bool((game.progress.rpg.get("ending_archive",{}) as Dictionary).get("C",false)), "True ending not archived")
    verify(int(game.progress.rpg.get("ending_scene_index",0)) == 4, "All four ending scenes must be completed")
    verify(game.progress.scene_index == 5, "Final chapter must not restart")
    verify(game.progress.save() and game.progress.load_saved(), "Ending save reload failed")
    verify(str(game.progress.rpg.get("ending_id","")) == "C", "Ending lost after reload")
    game._replay_ending("C")
    drain(game)
    verify(game.ending_replay_id.is_empty(), "Epilogue replay did not finish")
    verify(str(game.progress.rpg.get("ending_id","")) == "C", "Replay changed canonical ending")
    if faults.is_empty():
        print("PASS: endings A/B/C requirements, twelve collectible pages, C unlock, four epilogue scenes, archive, save/resume and replay")
        quit(0)
    else:
        for fault in faults:
            push_error(fault)
        quit(1)
