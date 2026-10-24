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
        if chapter > 1:
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
    if failures.is_empty():
        print("PASS: prologue + all six chapters, physical task markers, six side quests, dialogue, choices, five bosses, companion and final flag")
        quit(0)
    else:
        for error in failures:
            push_error(error)
        quit(1)
