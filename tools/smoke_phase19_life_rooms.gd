extends SceneTree
## Phase19-6: 19 genuine life interiors, original world entry, original/outdoor continuity and V3 saves.
const Rooms = preload("res://scripts/story_quest_submaps.gd")
const Geo = preload("res://scripts/world_geography.gd")
const Game = preload("res://scripts/first_act.gd")
const State = preload("res://scripts/first_act_state.gd")
var problems: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func ck(ok: bool,message: String) -> void:
    if not ok:
        problems.append(message)

func _run() -> void:
    var catalogue=Rooms.new()
    ck(catalogue.errors.is_empty(),"life-room manifest errors "+" / ".join(catalogue.errors))
    ck(catalogue.entries.size()==12,"original 12 lost-page rooms unchanged")
    ck(catalogue.life_entries.size()==19,"19 unique indoor life locations")
    var geo=Geo.new()
    for raw_id in catalogue.life_entries:
        var id: String=str(raw_id)
        var info: Dictionary=catalogue.detail(id)
        var layout: Dictionary=geo.interior(str(info.get("building_id","")),
            str(info.get("interior_name","")),str(info.get("map_id","")))
        ck(str(layout.get("authored_source",""))=="v4","real authored life-room V4 layout "+id)
        var stops: Array=layout.get("quest_points",[])
        ck(stops.size()==3,"three independent case exhibits "+id)
        if stops.size()==3:
            var targets: Array[Vector2i]=[
                stops[0],stops[1],stops[2],layout.get("interact_cells",{}).get("exit",Vector2i(-1,-1))
            ]
            var beginnings: Array[Vector2i]=[layout.get("spawn",Vector2i(-1,-1))]
            ck(geo.reachable(layout,beginnings,targets),"no blocked clues or exit "+id)
        ck(layout.get("visuals",[]).size()>=4,"artwork and props present "+id)
        ck(not catalogue.matches(id,str(info["map_id"]),
            int(str(info["open_chapter"]).trim_prefix("ch"))-1),
            "cannot enter early "+id)

    var game=Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    var visited: Dictionary={}
    for raw_id in catalogue.life_entries:
        var quest_id: String=str(raw_id)
        var info: Dictionary=catalogue.detail(quest_id)
        var outside: Dictionary=game.progress.rpg.get("world",{})
        outside.erase("indoor_building")
        outside.erase("outdoor_return")
        game.progress.chapter=int(str(info["open_chapter"]).trim_prefix("ch"))
        game.progress.scene_index=0
        outside["current_map"]=str(info["map_id"])
        outside["bound_chapter"]=game.progress.chapter
        game._enter_location()
        var key: String="questdoor:"+quest_id
        ck(game.world.nodes.has(key),"real world entrance for "+quest_id)
        if not game.world.nodes.has(key):
            continue
        game.world.hero.position=game.world.nodes[key].position
        game.world.interact()
        ck(game.world.interior_building=="quest__"+quest_id,
            "physical E interaction opens own room "+quest_id)
        if game.world.interior_building!="quest__"+quest_id:
            continue
        ck(game.world.terrain_layout.get("quest_points",[]).size()==3,"visible three clue sites "+quest_id)
        ck(game.world.nodes.has("interior_exit"),"real return portal "+quest_id)
        for index in range(3):
            var clue_id: String="questcase:"+str(index)
            ck(game.world.nodes.has(clue_id),"life quest has named clue "+quest_id)
            if not game.world.nodes.has(clue_id):
                continue
            game.world.hero.position=game.world.nodes[clue_id].position
            game.world.interact()
            ck(bool(game.progress.rpg.get("quest_gallery",{}).get(quest_id,{}).get(str(index),false)),
                "case exhibit tracked in V3 data "+quest_id+":"+str(index))
        if quest_id=="sq_life_01":
            game._enter_location()
            ck(game.world.interior_building=="quest__sq_life_01",
                "load same life scene after saving indoor room")
            game.progress.flags["side.sq_life_01.done"]=true
            game.progress.flags["side.sq_life_01.approach"]="a"
            game._focus()
            ck(not game.branch_runtime.eligible("sq_life_01.p17.b.followup"),
                "wrong A/B narrative route locked")
            ck(game.world.nodes.has("branchmap:sq_life_01.p17.a.followup:0"),
                "one playable authored postscript inside life room")
        if game.world.nodes.has("interior_exit"):
            game.world.hero.position=game.world.nodes["interior_exit"].position
            game.world.interact()
        ck(game.world.interior_building.is_empty(),"returned to original map "+quest_id)
        ck(game.progress.rpg["world"].get("indoor_building","").is_empty(),
            "cleared room identity in V3 "+quest_id)
        visited[quest_id]=true
    ck(visited.size()==19,"all nineteen entered and exited")
    ck(game.progress.save(),"persist independent life-room discoveries")
    var loaded=State.new()
    ck(loaded.load_saved(),"V3 read after life-room travel")
    ck(loaded.rpg.get("quest_gallery",{}).size()>=19,"all 19 life inspection logs survived reload")
    var world_quests=["sq_life_08","sq_life_10","sq_life_15","sq_life_18","sq_life_22"]
    for id in world_quests:
        ck(catalogue.detail(id).is_empty(),"natural open-world quest remains outdoors "+id)
    if problems.is_empty():
        print("PASS: 19 life interiors, collision, 57 clue stations, A/B, exit/save, 5 genuine outdoor quests")
        quit(0)
        return
    for problem in problems:
        push_error(problem)
    quit(1)
