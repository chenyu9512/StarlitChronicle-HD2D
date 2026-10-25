extends SceneTree
## Phase19-4 Godot: 12 independent V4 interiors, walkable clue exhibits,
## actual portal interactions, indoor restore and departure without lost state.
const Game = preload("res://scripts/first_act.gd")
const Geo = preload("res://scripts/world_geography.gd")
const Rooms = preload("res://scripts/story_quest_submaps.gd")
const State = preload("res://scripts/first_act_state.gd")
var problems: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,reason: String) -> void:
    if not ok:
        problems.append(reason)

func _run() -> void:
    var room_list = Rooms.new()
    check(room_list.errors.is_empty(),"room manifest: "+" / ".join(room_list.errors))
    check(room_list.entries.size()==12,"all twelve lost pages have rooms")
    var geography = Geo.new()
    for id in room_list.entries:
        var spec: Dictionary = room_list.detail(str(id))
        var layout: Dictionary = geography.interior(str(spec["building_id"]),str(spec["interior_name"]),str(spec["map_id"]))
        check(str(layout.get("authored_source",""))=="v4","genuinely authored room "+str(id))
        var clues: Array = layout.get("quest_points",[])
        check(clues.size()==3,"three investigation stations "+str(id))
        if clues.size()!=3:
            continue
        var start: Vector2i = layout.get("spawn",Vector2i(-1,-1))
        var end: Vector2i = layout.get("interact_cells",{}).get("exit",Vector2i(-1,-1))
        var destinations: Array[Vector2i] = [end,clues[0],clues[1],clues[2]]
        var origins: Array[Vector2i] = [start]
        check(geography.reachable(layout,origins,destinations),"walkable routes to all exhibits and exit "+str(id))
        for spot in destinations:
            check(not (layout.get("blocked",{}) as Dictionary).has(spot),
                "no clue or door inside solid tiles "+str(id))
    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    var visited: Dictionary = {}
    for id in room_list.entries:
        var info: Dictionary = room_list.detail(str(id))
        var quest_id: String = str(id)
        var world_state: Dictionary = game.progress.rpg["world"]
        world_state.erase("indoor_building")
        world_state.erase("outdoor_return")
        game.progress.chapter=int(str(info["open_chapter"]).trim_prefix("ch"))
        game.progress.scene_index=0
        world_state["current_map"]=str(info["map_id"])
        world_state["bound_chapter"]=game.progress.chapter
        game._enter_location()
        var portal_id: String = "questdoor:"+quest_id
        check(game.world.nodes.has(portal_id),"physical entrance exists "+quest_id)
        if not game.world.nodes.has(portal_id):
            continue
        check(game.world.interior_building.is_empty(),"starts outside "+quest_id)
        game.world.hero.position=game.world.nodes[portal_id].position
        game.world.interact()
        check(game.world.interior_building=="quest__"+quest_id,"entered quest interior by action "+quest_id)
        check(str(game.world.terrain_layout.get("authored_source",""))=="v4","loads V4 interior "+quest_id)
        var markers: Array = game.world.terrain_layout.get("quest_points",[])
        check(markers.size()==3,"three interactive markers "+quest_id)
        if markers.size()!=3:
            continue
        var gallery_id: String = "questcase:1"
        check(game.world.nodes.has(gallery_id),"exhibit is present "+quest_id)
        if game.world.nodes.has(gallery_id):
            game.world.hero.position=game.world.nodes[gallery_id].position
            game.world.interact()
            check(bool(game.progress.rpg.get("quest_gallery",{}).get(quest_id,{}).get("1",false)),
                "on-site inspection recorded without granting quest reward "+quest_id)
        if quest_id=="sq_page_01":
            var stored: Dictionary=game.progress.rpg["world"]
            check(stored.get("indoor_building","")=="quest__sq_page_01","save stores unique room ID")
            game._enter_location()
            check(game.world.interior_building=="quest__sq_page_01",
                "reload inside authored room without sending player to overworld")
        var exit_key: String="interior_exit"
        if game.world.nodes.has(exit_key):
            game.world.hero.position=game.world.nodes[exit_key].position
            game.world.interact()
        check(game.world.interior_building.is_empty(),"exit returns to original map "+quest_id)
        check(game.progress.rpg["world"].get("indoor_building","").is_empty(),
            "outdoor save clears quest interior "+quest_id)
        visited[quest_id]=true
    check(visited.size()==12,"all rooms visited and exited")
    var old = State.new()
    check(old.load_saved(),"disk save loads after visiting all twelve locations")
    check(old.rpg.get("quest_gallery",{}).size()==12,"independent visit record survives V3 save")
    if problems.is_empty():
        print("PASS: 12 V4 rooms, collision routes, real outdoor portals, questcase props, indoor resume and exit.")
        quit(0)
        return
    for issue in problems:
        push_error(issue)
    quit(1)
