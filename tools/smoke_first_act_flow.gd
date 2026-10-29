extends SceneTree
## Six-chapter controller-level regression: physical markers, story, choices, boss victories, side quests.
const Game = preload("res://scripts/first_act.gd")
var game
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _touch(target: String) -> void:
    if not game.world.nodes.has(target):
        failures.append("Missing map target: " + target)
        return
    game.world.hero.position = game.world.nodes[target].position + Vector2(0, 18)
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
    for i in range(30):
        if not game.ui.dialog_layer.visible or game.ui.choosing:
            break
        game.ui._next()
    if game.ui.dialog_layer.visible and not game.ui.choosing:
        failures.append("Dialogue did not finish in 30 steps")

func _run() -> void:
    var sandbox: String="user://qa_act01_six_marker_%d" % OS.get_process_id()
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))!=OK:
        push_error("Cannot create isolated first-act test save")
        quit(1)
        return
    game = Game.new()
    root.add_child(game)
    game.progress.save_path=sandbox+"/state.json"
    game.progress.backup_path=sandbox+"/backup.json"
    game.ui.title_overlay.hide()
    game._start(false)
    game.invincible = true  # CI only: ensure the path tests objectives rather than game balance.
    for idx in range(9):
        if game.progress.chapter != 0 or game.progress.scene_index != idx:
            failures.append("Prologue sequence interrupted at %d" % idx)
            break
        _touch("prologue_%d" % idx)
        _dialog()
    if game.progress.chapter != 1:
        failures.append("Prologue did not unlock chapter one")
    for chapter in range(1, 7):
        if game.progress.chapter != chapter:
            failures.append("Chapter progression stopped before %d" % chapter)
            break
        _enter_canonical_chapter(chapter)
        # Three distinct side-quest objects must actually be visited.
        _touch("side_start")
        _dialog()
        _touch("side_item")
        _dialog()
        _touch("side_return")
        _dialog()
        if game._side_step() != -1:
            failures.append("Chapter %d side quest did not complete" % chapter)
        _touch("key_npc")
        _dialog()
        _touch("clue")
        _dialog()
        _touch("witness")
        _touch("crisis")
        _dialog()
        if not game.ui.choosing:
            failures.append("Chapter %d failed to display actual branching choice" % chapter)
        else:
            var buttons: Array[Node] = game.ui.choice_area.get_children()
            if buttons.is_empty():
                failures.append("No choice available at %d" % chapter)
            else:
                var button: Button = buttons[0] as Button
                button.pressed.emit()
                if game.pending == "choice_reaction":
                    _dialog()
        if chapter > 1:
            if chapter in [2,3] and game.battle == null and game.progress.task_index == 1:
                _touch("crisis")
            var count := 0
            while game.battle != null and count < 100:
                game.battle._act("special")
                count += 1
            if game.battle != null:
                failures.append("Boss fight in chapter %d cannot finish" % chapter)
            if not bool(game.progress.flags.get("ch%03d.battle_won" % chapter, false)):
                failures.append("Chapter %d victory flag missing" % chapter)
        _touch("resolve")
        _dialog()
        if not bool(game.progress.flags.get("story.ch%03d.done" % chapter, false)):
            failures.append("Chapter %d completion flag missing" % chapter)
    if game.progress.actors.size() != 3:
        failures.append("Fourth-chapter companion not recruited")
    if game.progress.chapter != 7 or not bool(game.progress.flags.get("story.ch006.done", false)):
        failures.append("First Act did not unlock Act II")
    for snapshot_path in [game.progress.save_path,game.progress.backup_path,
            game.progress.save_path+".tmp",game.progress.backup_path+".tmp"]:
        if FileAccess.file_exists(snapshot_path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(snapshot_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
    if failures.is_empty():
        print("PASS: prologue + all six chapters, physical task markers, six side quests, dialogue, choices, five bosses, companion and final flag")
        quit(0)
    else:
        for error in failures:
            push_error(error)
        quit(1)
