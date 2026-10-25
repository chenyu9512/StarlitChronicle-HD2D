extends SceneTree
## Phase19-2A..F Godot runtime verification: 120 canonical sector positions,
## real walkable interaction cells, branch NPC/prop/board sequence, UI and save.
const Geo = preload("res://scripts/world_geography.gd")
const Binder = preload("res://scripts/story_world_bindings.gd")
const Game = preload("res://scripts/first_act.gd")
const State = preload("res://scripts/first_act_state.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,message: String) -> void:
    if not ok:
        errors.append(message)

func reachable(layout: Dictionary) -> Dictionary:
    var walls: Dictionary = layout.get("blocked",{})
    var start: Vector2i = layout.get("spawn",Vector2i(10,23))
    var visited: Dictionary = {start:true}
    var queue: Array[Vector2i] = [start]
    var cursor: int = 0
    while cursor < queue.size():
        var cell: Vector2i = queue[cursor]
        cursor += 1
        for pos in [cell+Vector2i.LEFT,cell+Vector2i.RIGHT,cell+Vector2i.UP,cell+Vector2i.DOWN]:
            if pos.x<2 or pos.y<2 or pos.x>=70 or pos.y>=46 or walls.has(pos) or visited.has(pos):
                continue
            visited[pos] = true
            queue.append(pos)
    return visited

func _run() -> void:
    var binding = Binder.new()
    check(binding.errors.is_empty(),"120 quest location schema " + " / ".join(binding.errors))
    check(binding.locations.size()==120,"120 quest to sector mappings")
    var geo = Geo.new()
    var cache: Dictionary = {}
    var sector_count: int = 0
    var placed: int = 0
    for id in binding.locations.keys():
        var entry: Dictionary = binding.site(str(id))
        var mid: String = str(entry.get("map_id",""))
        check(not mid.begins_with("map_legacy"),"no prototype area " + str(id))
        if not cache.has(mid):
            var chapter: int = maxi(1,int(str(entry.get("first_chapter","ch001")).trim_prefix("ch")))
            var layout: Dictionary = geo.layout(mid,chapter)
            var path: Dictionary = reachable(layout)
            cache[mid] = {"layout":layout,"path":path}
            sector_count += 1
        var area: Dictionary = cache[mid]
        var walk: Dictionary = area["path"]
        var geom: Dictionary = area["layout"]
        var cell: Vector2i = binding.position_for(entry,walk,[],0)
        check(cell.x>=2 and walk.has(cell) and not (geom["blocked"] as Dictionary).has(cell),
            "unreachable quest location " + str(id) + " at " + mid)
        placed += 1
    check(placed==120 and sector_count>=28,"world sector coverage")

    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    game.progress.chapter = 5
    game.progress.scene_index = 0
    game.progress.rpg["world"]["current_map"] = "map_coast_02"
    game.progress.rpg["world"]["bound_chapter"] = 5
    game._enter_location()
    check(game.world.map_profile.get("id","")=="map_coast_02","travel to authored port sector")
    check(game.world.nodes.has("story_stage_0") and game.world.nodes["story_stage_0"].visible,
        "original quest now appears at assigned map")
    var source: String = "sq_page_01"
    var a: String = source + ".p17.a.followup"
    game.progress.flags["side."+source+".done"] = true
    game.progress.rpg["narrative_side"][source+".done"] = true
    game.progress.flags["side."+source+".approach"] = "a"
    game._track_branch_event(a)
    check(str(game.progress.rpg.get("tracked_branch_event",""))==a,"map navigation saved")
    check(game.atlas.quest_destination=="map_coast_02","atlas points to tracked quest sector")
    check(game.atlas.small_view.quest_destination=="map_coast_02","minimap destination bound")
    check(game.branch_runtime.eligible(a),"authored A path eligible on coast sector")
    check(not game.branch_runtime.eligible(source+".p17.b.followup"),"B route locked")

    var position_history: Array[Vector2i] = []
    var original_gold: int = game.progress.gold
    var original_level: int = int(game.progress.actors[0]["level"])
    for stage in range(3):
        var marker: String = "branchmap:"+a+":"+str(stage)
        check(game.world.nodes.has(marker),"3-stage mapped marker present " + str(stage))
        if not game.world.nodes.has(marker):
            continue
        var point: Node2D = game.world.nodes[marker]
        var cell: Vector2i = Vector2i(point.position/game.world.TILE)
        check(not game.world.blocked.has(cell),"interactive marker on walkable cell " + str(stage))
        position_history.append(cell)
        if stage==0:
            check(point is Sprite2D,"quest NPC has physical visual node")
        game.world.hero.position = point.position
        game.world.interact()
        check(game.pending=="branch_field","world interaction dispatch " + str(stage))
        check(game.ui.dialog_layer.visible,"branch dialog visible " + str(stage))
        game.ui.dialog_text.visible_characters = -1
        game.ui._next()
        if stage<2:
            check(int(game.progress.rpg["branch_story"]["active"]["line"])==stage+1,
                "one field step saved " + str(stage))
            check(not game.branch_runtime.is_seen(a),"cannot finish with fewer than three interactions")
    if position_history.size()==3:
        check(position_history[0].distance_to(position_history[1])>=3.0,
            "npc and evidence must be physically separate")
        check(position_history[1].distance_to(position_history[2])>=3.0,
            "evidence and notice must be physically separate")
    check(game.branch_runtime.is_seen(a),"all three world interactions mark scene seen")
    check(game.progress.gold==original_gold and int(game.progress.actors[0]["level"])==original_level,
        "no gold or EXP granted from old A/B postscript")
    check(not game.branch_runtime.eligible(a),"completed branch cannot repeat")
    check(game.branch_runtime.next_for_quest(source).get("id","")==
        source+".p17.a.community","next phase now unlocked")
    check(game.progress.save(),"V3 auto save accepted map story progress")
    var loaded = State.new()
    check(loaded.load_saved(),"world branch progress load")
    check(bool(loaded.rpg.get("branch_story",{}).get("seen",{}).get(a,false)),
        "saved world event durable after reload")
    check(str(loaded.flags.get("side."+source+".approach",""))=="a",
        "original branch choice never overwritten")
    check(game.world.nodes.get("branchmap:"+a+":0",null)==null,
        "completed marker disappears from world")
    if errors.is_empty():
        print("PASS: Phase19-2 all 120 quest maps, %d authored sectors, walking positions," % sector_count)
        print(" NPC/evidence/notice progression, A/B locking, minimap, save and anti-farming.")
        quit(0)
    else:
        for issue in errors:
            push_error(issue)
        quit(1)
