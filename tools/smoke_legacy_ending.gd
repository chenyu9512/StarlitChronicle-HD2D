extends SceneTree
## 向后兼容：v3旧存档在第72章直接标记complete但没有真实三结局的迁移路径。
const State = preload("res://scripts/first_act_state.gd")
const Game = preload("res://scripts/first_act.gd")
var problems: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var old = State.new()
    old.new_game()
    old.chapter = 72
    old.scene_index = 4
    old.gold = 678
    old.flags["story.ch072.done"] = true
    old.flags["ch071.battle_won"] = true
    old.flags["story.complete"] = true
    var legacy: Dictionary = old._pack()
    legacy.erase("rpg")
    var file: FileAccess = FileAccess.open(State.SAVE_PATH,FileAccess.WRITE)
    if file == null:
        push_error("Cannot make legacy fixture")
        quit(1)
        return
    file.store_string(JSON.stringify(legacy))
    file.close()
    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(true)
    if game.progress.gold != 678:
        problems.append("Migrated save lost money")
    if bool(game.progress.flags.get("story.complete",false)):
        problems.append("Old complete bit was not migrated into ending selection")
    if not game.ui.choosing:
        problems.append("Legacy save cannot reach ending selector")
    if game.ui.choosing:
        var buttons: Array[Node] = game.ui.choice_area.get_children()
        if buttons.is_empty() or (buttons[0] as Button).disabled:
            problems.append("Default A ending unavailable after migration")
        else:
            (buttons[0] as Button).pressed.emit()
            for i in range(70):
                if not game.ui.dialog_layer.visible:
                    break
                game.ui._next()
    if not bool(game.progress.flags.get("story.complete",false)) or str(game.progress.rpg.get("ending_id","")) != "A":
        problems.append("Legacy save could not complete A epilogue")
    if game.progress.gold != 678:
        problems.append("Legacy inventory/gold lost during epilogue")
    if problems.is_empty():
        print("PASS: old V3 ending save migration, preserved gold, A-choice unlocking, all epilogues and completion flag")
        quit(0)
    else:
        for msg in problems:
            push_error(msg)
        quit(1)
