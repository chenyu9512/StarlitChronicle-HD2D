extends SceneTree
## Engine-level smoke test: load actual first-act sprites, TileMapLayer, save model and battle UI.
const StateCode = preload("res://scripts/first_act_state.gd")
const WorldCode = preload("res://scripts/first_act_world.gd")
const BattleCode = preload("res://scripts/first_act_battle.gd")
const StoryCode = preload("res://scripts/story_catalog.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var catalog = StoryCode.new()
    if not catalog.load_all():
        push_error(catalog.get_errors_text())
        quit(1)
        return
    var state = StateCode.new()
    var world = WorldCode.new()
    root.add_child(world)
    for i in range(7):
        world.build(i, 3 if i >= 5 else 2)
        if world.layer == null or world.hero == null:
            push_error("Playable map could not be created for chapter %d" % i)
            quit(1)
            return
        for target in ["key_npc", "clue", "witness", "crisis", "resolve"]:
            if not world.nodes.has(target):
                push_error("Missing physical story target " + target)
                quit(1)
                return
    world.queue_free()
    for chapter_no in range(2, 7):
        var battle = BattleCode.new()
        root.add_child(battle)
        battle.start(state, chapter_no, true)
        if str(battle.enemy.get("name", "")).is_empty():
            push_error("Boss enemy not loaded for chapter %d" % chapter_no)
            quit(1)
            return
        battle.queue_free()
    print("PASS: first act seven maps, physical triggers and five enemy battle scenes")
    quit(0)
