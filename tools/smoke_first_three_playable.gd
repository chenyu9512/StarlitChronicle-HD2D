extends SceneTree
## New-save first-three controller flow with real combat and unmodified party stats.
## Marker positioning bypasses walking; this is NOT human navigation/visual acceptance.
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

func _dialog() -> void:
    for i in range(30):
        if not game.ui.dialog_layer.visible or game.ui.choosing:
            break
        game.ui._next()
    if game.ui.dialog_layer.visible and not game.ui.choosing:
        failures.append("Dialogue did not finish in 30 steps")

func _run() -> void:
    game = Game.new()
    root.add_child(game)
    var folder: String = "user://first_three_flow_%d" % OS.get_process_id()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    game.progress.save_path = folder + "/save.json"
    game.progress.backup_path = folder + "/backup.json"
    game.ui.title_overlay.hide()
    game._start(false)
    if game.invincible or game.five_xp:
        failures.append("New game enabled cheats")
    for idx in range(9):
        if game.progress.chapter != 0 or game.progress.scene_index != idx:
            failures.append("Prologue sequence interrupted at %d" % idx)
            break
        _touch("prologue_%d" % idx)
        _dialog()
    if game.progress.chapter != 1:
        failures.append("Prologue did not unlock chapter one")
    for chapter in range(1, 4):
        if game.progress.chapter != chapter:
            failures.append("Chapter progression stopped before %d" % chapter)
            break
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
                if not game._save_progress() or not game.progress.load_saved():
                    failures.append("Pre-boss save/load failed")
                game._enter_location()
                _touch("crisis")
                if game.battle != null:
                    game.battle.dice.seed = 731 + chapter
            var count := 0
            while game.battle != null and count < 100:
                var b = game.battle
                var member: Dictionary = game.progress.actors[b.hero_turn]
                if int(member["hp"]) < int(member["max_hp"]) / 2 and game.progress.potions > 0:
                    b._act("potion")
                elif float(b.round_boss_intent.get("multiplier",1.0)) > 1.5:
                    b._act("guard")
                else:
                    b._act("special")
                count += 1
            if game.battle != null:
                failures.append("Boss fight in chapter %d cannot finish" % chapter)
            if not bool(game.progress.flags.get("ch%03d.battle_won" % chapter, false)):
                failures.append("Chapter %d victory flag missing" % chapter)
        _touch("resolve")
        _dialog()
        if not bool(game.progress.flags.get("story.ch%03d.done" % chapter, false)):
            failures.append("Chapter %d completion flag missing" % chapter)
    if game.progress.chapter != 4 or not bool(game.progress.flags.get("story.ch003.done",false)):
        failures.append("First three chapters did not unlock chapter four")
    if failures.is_empty():
        print("PASS: new save, prologue and chapters 1-3, side quests, pre-boss save/load, normal-stat real-command victories; walking and human UX not tested")
        quit(0)
    else:
        for error in failures:
            push_error(error)
        quit(1)
