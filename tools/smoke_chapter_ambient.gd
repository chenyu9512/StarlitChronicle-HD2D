extends SceneTree
## 72章独立线索与NPC文本的运行测试，不要求美术关卡已经人工精修。
const Game = preload("res://scripts/first_act.gd")
const Ambient = preload("res://scripts/chapter_ambient.gd")
var game
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func assert_true(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func tap(name: String) -> void:
    if not game.world.nodes.has(name):
        failures.append("Missing stage marker " + name)
        return
    game.world.hero.position = game.world.nodes[name].position + Vector2(0,18)
    game.world.interact()

func drain() -> void:
    for index in range(30):
        if not game.ui.dialog_layer.visible or game.ui.choosing:
            break
        game.ui._next()

func _run() -> void:
    var ambience = Ambient.new()
    var totals: Dictionary = ambience.counts()
    assert_true(int(totals.get("objects",0)) == 72,"Expected objects for 72 chapters")
    assert_true(int(totals.get("npcs",0)) == 72,"Expected NPC state for 72 chapters")
    assert_true(int(totals.get("midpoints",0)) == 72,"Expected optional midpoint for 72 chapters")
    game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    for chapter in [1,36,72]:
        game.progress.chapter = chapter
        game.progress.scene_index = 1
        game.progress.flags["ch%03d.started" % chapter] = true
        game._enter_location()
        var objects: Array = ambience.objects(chapter)
        assert_true(objects.size() == 2,"Missing two inspectable objects in chapter %d" % chapter)
        for index in range(2):
            tap("inspect_%d" % (index + 1))
            drain()
            var item: Dictionary = objects[index]
            var flag: String = str(item.get("investigation_flag",""))
            assert_true(bool(game.progress.flags.get(flag,false)),"Inspection flag not saved in chapter %d" % chapter)
        tap("midpoint")
        drain()
        assert_true(bool(game.progress.flags.get("explore.ch%03d.midpoint" % chapter,false)),"Midpoint did not fire in chapter %d" % chapter)
        tap("ambient_npc")
        drain()
        assert_true(not game.busy,"NPC dialogue did not close in chapter %d" % chapter)
    assert_true(game.progress.save(),"Cannot save optional chapter state")
    assert_true(game.progress.load_saved(),"Cannot restore optional chapter state")
    assert_true(bool(game.progress.flags.get("explore.ch072.midpoint",false)),"Saved chapter 72 midpoint missing")
    if failures.is_empty():
        print("PASS: 72 chapter NPC states, 144 optional objects, 72 midpoint scenes, physical markers and save")
        quit(0)
    else:
        for error in failures:
            push_error(error)
        quit(1)
