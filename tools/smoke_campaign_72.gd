extends SceneTree
## 72章剧情任务控制器回归：运行全部目标、选项、章节和战斗触发链。
const Game = preload("res://scripts/first_act.gd")
var game
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _touch(target: String) -> void:
    if not game.world.nodes.has(target):
        failures.append("Missing map node: " + target)
        return
    game.world.hero.position = game.world.nodes[target].position + Vector2(0,18)
    game.world.interact()

func _enter_canonical_chapter(chapter: int) -> void:
    if chapter>6 or chapter<1:
        return
    var required: String=game.world_router.act01_target_map(chapter)
    for hop in range(5):
        if game.world_router.current_map()==required:
            return
        var route: Array[String]=game.world_router.route_towards(required)
        if route.size()<2:
            failures.append("Chapter %d has no unlocked, physically adjacent route to %s" % [chapter,required])
            return
        var exit_node: String="exit:"+route[1]
        if not game.world.nodes.has(exit_node):
            failures.append("Missing physical border gate "+exit_node)
            return
        var previous: String=game.world_router.current_map()
        _touch(exit_node)
        if game.world_router.current_map()==previous:
            failures.append("Physical gate did not advance from "+previous+" to "+route[1])
            return
    failures.append("Chapter route exceeded five physical exits")

func _dialog() -> void:
    for i in range(60):
        if not game.ui.dialog_layer.visible or game.ui.choosing:
            break
        game.ui._next()
    if game.ui.dialog_layer.visible and not game.ui.choosing:
        failures.append("Dialogue remained open.")

func _run() -> void:
    game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    game.invincible = true
    for idx in range(9):
        _touch("prologue_%d" % idx)
        _dialog()
    if game.progress.chapter != 1:
        failures.append("Prologue never reached Chapter 1.")
    for chapter in range(1,73):
        if game.progress.chapter != chapter:
            failures.append("Expected chapter %d got %d" % [chapter,game.progress.chapter])
            break
        _enter_canonical_chapter(chapter)
        _touch("key_npc")
        _dialog()
        _touch("clue")
        _dialog()
        _touch("witness")
        _touch("crisis")
        _dialog()
        if game.ui.choosing:
            var buttons: Array[Node] = game.ui.choice_area.get_children()
            if buttons.is_empty():
                failures.append("No choice button in chapter %d" % chapter)
                break
            var b: Button = buttons[0] as Button
            b.pressed.emit()
            if game.pending == "choice_reaction":
                _dialog()
        if chapter in [2,3] and game.battle == null and game.progress.task_index == 1:
            _touch("crisis")
        if game.battle != null:
            # Exercise the actual encounter command loop, including Ch5
            # release and Ch6 testimony, rather than calling _finish(true).
            # The controller gate must catch any absent/invalid receipts.
            var command_count: int = 0
            while game.battle != null and command_count < 120:
                game.battle._act("special")
                command_count += 1
            if game.battle != null:
                failures.append("Chapter %d combat did not resolve by player commands" % chapter)
                break
            if chapter == 5 and not bool(game.progress.flags.get("ch005.beast_released",false)):
                failures.append("Chapter 5 nonlethal rescue receipt missing")
            if chapter == 6 and not bool(game.progress.flags.get("ch006.lighthouse_testimony",false)):
                failures.append("Chapter 6 shared testimony receipt missing")
        if chapter in [46,47]:
            # Physical gate interactions are mandatory and the final stage
            # of every squad depends on the actual chapter battle receipt.
            for gate in ["evac:east","evac:south","evac:west"]:
                if gate != "evac:east":
                    _touch("evac:command")
                for _stage in range(3):
                    _touch(gate)
            if not game.endgame_bridge.evacuation.finished:
                failures.append("Chapter %d multi-squad evacuation not completed" % chapter)
                break
        if chapter in [52,53,54]:
            _touch("endgame:handover")
            if game.endgame_bridge.noe.leadership_handover_phase != chapter - 51:
                failures.append("Chapter %d adult-Noe handover did not persist" % chapter)
                break
        _touch("resolve")
        _dialog()
        if chapter == 72:
            _touch("resolve")
            _dialog()
            if game.ui.choosing:
                var ending_buttons: Array[Node] = game.ui.choice_area.get_children()
                if ending_buttons.is_empty():
                    failures.append("No ending choice in final scene.")
                else:
                    var ending_choice: Button = ending_buttons[0] as Button
                    if ending_choice.disabled:
                        failures.append("Standard A ending is incorrectly locked.")
                    else:
                        ending_choice.pressed.emit()
                        _dialog()
            else:
                failures.append("Final A/B/C choice never opened.")
        if not bool(game.progress.flags.get("story.ch%03d.done" % chapter,false)):
            failures.append("Chapter %d completion flag missing." % chapter)
            break
        if chapter < 72 and game.progress.chapter != chapter + 1:
            failures.append("Chapter %d did not unlock next." % chapter)
            break
    if not bool(game.progress.flags.get("story.complete",false)):
        failures.append("Story completion flag missing.")
    if game.progress.chapter != 72:
        failures.append("End state chapter is not 72.")
    var old_g: int = game.progress.gold
    if not game.progress.save() or not game.progress.load_saved() or game.progress.gold != old_g:
        failures.append("Save/load roundtrip failed.")
    if not failures.is_empty():
        for err in failures:
            push_error(err)
        quit(1)
    else:
        print("PASS: prologue + all 72 chapters, real objective markers, branches, battle triggers, recruitments, save/load and final story flag")
        quit(0)
