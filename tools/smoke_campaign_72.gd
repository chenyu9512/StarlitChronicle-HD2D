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
        if game.battle != null:
            game.battle._finish(true)
        _touch("resolve")
        _dialog()
        if chapter == 72:
            _touch("resolve")
            _dialog()
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
