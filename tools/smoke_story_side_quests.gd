extends SceneTree
## 地图侧剧情任务验收：五阶段航页、分支选择、一次性奖励和存档。
const Game = preload("res://scripts/first_act.gd")
var g
var faults: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _touch(stage: int) -> void:
    var name: String = "story_stage_%d" % stage
    if not g.world.nodes.has(name):
        faults.append("Missing physical story side marker: " + name)
        return
    g.world.hero.position = g.world.nodes[name].position + Vector2(0, 17)
    g.world.interact()

func _dialog() -> void:
    for i in range(40):
        if not g.ui.dialog_layer.visible or g.ui.choosing:
            break
        g.ui._next()

func _run() -> void:
    g = Game.new()
    root.add_child(g)
    g.ui.title_overlay.hide()
    g._start(false)
    g.progress.chapter = 5
    g.progress.scene_index = 0
    g._enter_location()
    var q: Dictionary = g.game_core.available_story_side(5)
    if q.is_empty():
        faults.append("No available story side quest at chapter 5")
    else:
        var id: String = str(q.get("id",""))
        var map_id: String = g.story_world_bindings.map_for(id)
        g.progress.rpg["world"]["current_map"] = map_id
        g.progress.rpg["world"]["bound_chapter"] = g.progress.chapter
        g._enter_location()
        if str(g.world.map_profile.get("id","")) != map_id:
            faults.append("Quest did not move to mapped sector "+map_id)
        if q.get("stages",[]).size() != 5:
            faults.append("Lost-page quest must have five stages")
        for index in range(5):
            _touch(index)
            _dialog()
            if g.ui.choosing:
                var buttons: Array[Node] = g.ui.choice_area.get_children()
                if buttons.is_empty():
                    faults.append("Stage has no branch choices")
                    break
                var first: Button = buttons[0] as Button
                first.pressed.emit()
                _dialog()
            if g.game_core.story_side_stage(id) != index + 1:
                faults.append("Stage %d did not update" % index)
                break
        if not bool(g.progress.rpg["narrative_side"].get(id+".done",false)):
            faults.append("Lost page not recorded as completed")
        if not bool(g.progress.flags.get("world.page_01",false)):
            faults.append("First lost page was not granted")
        if not g.progress.save() or not g.progress.load_saved():
            faults.append("Side quest save/load failed")
        if not bool(g.progress.rpg["narrative_side"].get(id+".done",false)):
            faults.append("Completed quest lost after reload")
    if faults.is_empty():
        print("PASS: five physical stage markers, decision dialogue, lost-page reward and saved quest state")
        quit(0)
    else:
        for message in faults:
            push_error(message)
        quit(1)
