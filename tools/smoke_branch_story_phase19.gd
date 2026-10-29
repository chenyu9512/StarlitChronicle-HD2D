extends SceneTree
## Phase19-1: actual Godot persistence and event dispatch, not mere manifest counting.
const State = preload("res://scripts/first_act_state.gd")
const Branch = preload("res://scripts/story_branch_runtime.gd")
const Game = preload("res://scripts/first_act.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        errors.append(label)

func _run() -> void:
    var state = State.new()
    state.new_game()
    var service = Branch.new()
    check(service.load_all(),"all four manifests and 48 codas must load: " + " / ".join(service.errors))
    service.bind(state)
    check(service.counts()["quests"] == 120,"all 120 original quests indexed")
    check(service.counts()["optional_events"] == 720,"720 candidate scenes indexed")
    check(service.counts()["ending_codas"] == 48,"48 ending codas indexed")
    var a: String = "sq_page_01.p17.a.followup"
    var b: String = "sq_page_01.p17.b.followup"
    check(not service.eligible(a),"uncompleted original cannot start")
    state.flags["side.sq_page_01.done"] = true
    check(not service.eligible(a),"legacy save missing a/b must not infer a route")
    state.flags["side.sq_page_01.approach"] = "a"
    check(service.eligible(a),"correct route should unlock after completion")
    check(not service.eligible(b),"opposite branch must stay locked")
    check(service.begin(a),"begin branch event")
    check(not service.begin(a),"double begin blocked")
    check(service.current_line().get("id","") == a + ".l01","first line correctly restored")
    check(service.advance(),"save after first dialogue line")
    var snapshot: Dictionary = state._pack()
    var restored = State.new()
    check(restored.restore_snapshot(snapshot),"V3 snapshot with progress readable")
    var continuation = Branch.new()
    check(continuation.load_all(),"reload scripts after save")
    continuation.bind(restored)
    check(continuation.resume().get("id","") == a,"resume active event")
    check(continuation.current_line().get("id","") == a + ".l02","resume second line")
    check(continuation.advance(),"advance to third line")
    check(continuation.advance(),"finish event and persist seen")
    check(continuation.is_seen(a),"event marked exactly once")
    check(bool(restored.flags.get("side.sq_page_01.p17.a.followup.seen",false)),"contract seen flag persisted")
    check(not continuation.begin(a),"cannot regrant completed event")
    var next: Dictionary = continuation.next_for_quest("sq_page_01")
    check(next.get("id","") == "sq_page_01.p17.a.community","second stage requires first seen")
    check(continuation.begin(str(next.get("id",""))),"second stage begins")
    for step in range(3):
        check(continuation.advance(),"second stage line step")
    check(not continuation.eligible("sq_page_01.p17.a.revisit"),"later chapter not unlocked")
    restored.flags["story.ch012.done"] = true
    check(continuation.eligible("sq_page_01.p17.a.revisit"),"late revisit unlocks only with chapter flag")
    var legacy: Dictionary = State.new()._pack()
    legacy["rpg"].erase("branch_story")
    var legacy_state = State.new()
    check(legacy_state.restore_snapshot(legacy),"old V3 save still loads unchanged")
    var legacy_branch = Branch.new()
    check(legacy_branch.load_all(),"load for old save")
    legacy_branch.bind(legacy_state)
    check(legacy_state.rpg.get("branch_story",{}).get("seen",{}) is Dictionary,
        "missing V3 branch state lazily initializes")

    # Companion presence and decision gates. No bond/reward mutation.
    var quest: String = "cq_lanyin_01"
    restored.flags["side." + quest + ".done"] = true
    restored.flags["side." + quest + ".approach"] = "b"
    check(not continuation.eligible(quest + ".p18.b.followup"),"companion must be present")
    restored.rpg["party"] = ["char_tidecaller"]
    check(continuation.eligible(quest + ".p18.b.followup"),"available companion enables route")
    check(not continuation.eligible(quest + ".p18.a.followup"),"unselected companion route locked")
    var old_gold: int = restored.gold
    var old_levels: int = int(restored.actors[0]["level"])
    check(continuation.begin(quest + ".p18.b.followup"),"companion event start")
    for step in range(3):
        check(continuation.advance(),"companion event playback")
    check(restored.gold == old_gold and int(restored.actors[0]["level"]) == old_levels,
        "phase19 optional events never repeat XP or money")

    restored.flags["side.cq_lanyin_06.done"] = true
    restored.flags["side.cq_lanyin_06.approach"] = "b"
    restored.flags["world.ending"] = "A"
    var coda: String = "coda.p18.lanyin.a.b"
    check(not continuation.eligible(coda),"cannot play coda before actual ending complete")
    restored.rpg["ending_complete"] = true
    check(continuation.eligible(coda),"matching ending and branch enable coda")
    check(not continuation.eligible("coda.p18.lanyin.a.a"),"opposite coda branch blocked")
    check(not continuation.eligible("coda.p18.lanyin.b.b"),"other ending coda blocked")

    # Wire to the main scene and its RPG menu, then execute real dialogue.
    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    check(game.adventure_menu.branch_runtime == game.branch_runtime,
        "RPG menu bound to live branch runtime")
    game.progress.flags["side.sq_page_01.done"] = true
    game.progress.flags["side.sq_page_01.approach"] = "a"
    check(game.branch_runtime.eligible(a),"game save can trigger optional branch")
    game._open_adventure_book()
    game.adventure_menu.render("剧情后续")
    var found_branch_button: bool = false
    for node in game.adventure_menu.content.get_children():
        if node is HBoxContainer:
            for control in node.get_children():
                if control is Button and str(control.text) == "回顾对白":
                    found_branch_button = true
                    (control as Button).pressed.emit()
                    break
        if found_branch_button:
            break
    check(found_branch_button,"playable RPG menu actually lists unlocked branch")
    check(game.pending == "branch_event" and game.ui.dialog_layer.visible,
        "menu selection opens authored dialogue")
    for step in range(3):
        # The current UI types text progressively. A player's first tap may
        # reveal the line; the second advances it. Explicitly finish the type
        # animation before each simulated input.
        game.ui.dialog_text.visible_characters = -1
        game.ui._next()
    check(game.branch_runtime.is_seen(a),"dialogue completion persisted in game")
    check(game.pending == "","world unlock after optional scene")
    check(game.branch_runtime.next_for_quest("sq_page_01").get("id","") ==
        "sq_page_01.p17.a.community","game menu can show next scene")
    check(game.progress.save(),"save phase19 progress through V3")
    var loaded = State.new()
    check(loaded.load_saved(),"reload V3 save with branch events")
    check(bool(loaded.rpg.get("branch_story",{}).get("seen",{}).get(a,false)),
        "phase19 viewed status survived disk save")

    if errors.is_empty():
        print("PASS: Phase19-1 768 events indexed, A/B locks, no assumed legacy choice, ")
        print("  chapter gates, actual dialogue, save/load resume, no repeat rewards, codas after endings.")
        quit(0)
    else:
        for issue in errors:
            push_error(issue)
        quit(1)
