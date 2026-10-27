extends SceneTree
## B-line batch: traversal and saved choice projection, no fabricated progression.
const Geo = preload("res://scripts/world_geography.gd")
const Registry = preload("res://scripts/world_registry.gd")
const Echoes = preload("res://scripts/story_choice_echoes.gd")
const SceneDirector = preload("res://scripts/story_scene_director.gd")
const Ambient = preload("res://scripts/chapter_ambient.gd")
const Binder = preload("res://scripts/story_world_bindings.gd")
const Puzzles = preload("res://scripts/world_dungeon_puzzles.gd")
const State = preload("res://scripts/first_act_state.gd")
var failures: Array[String] = []

func check(ok: bool,why: String) -> void:
    if not ok:
        failures.append(why)

func _initialize() -> void:
    call_deferred("_run")

func _read(path: String) -> Dictionary:
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}

func _run() -> void:
    var geo=Geo.new()
    var registry=Registry.new()
    var echoes=Echoes.new()
    var director=SceneDirector.new()
    var ambient=Ambient.new()
    var binder=Binder.new()
    var puzzles=Puzzles.new()
    check(geo.faults.is_empty(),"Atlas errors "+str(geo.faults))
    check(registry.errors.is_empty(),"Registry errors "+str(registry.errors))
    check(echoes.errors.is_empty(),"Echo errors "+str(echoes.errors))
    check(director.errors.is_empty(),"Director errors "+str(director.errors))
    check(binder.errors.is_empty(),"Quest anchor errors "+str(binder.errors))
    check(puzzles.issues.is_empty(),"Dungeon errors "+str(puzzles.issues))
    check(echoes.all_events.size()==72,"Expected 72 canonical choices")
    check(not geo.reachable({"size":Vector2i(24,24),"blocked":{Vector2i(10,10):true}},
        [Vector2i(10,10)],[Vector2i(10,11)]),"Blocked origin BFS bypass")
    for event in echoes.all_events:
        var id: String=str(event.get("chapter_id",""))
        var chapter: int=int(event.get("number",0))
        check((event.get("routes",[]) as Array).size()==2,"Missing route "+id)
        check(echoes.latest_world_echo(str(event.get("map_id","")) ,{}).is_empty(),"Unselected branch "+id)
        for route in event.get("routes",[]):
            var state=State.new()
            state.new_game()
            state.chapter=mini(chapter+1,72)
            state.flags[str(event.get("choice_flag",""))]=route.get("value","")
            state.flags[str(event.get("completed_flag",""))]=true
            var actual: Dictionary=echoes.latest_world_echo(str(event.get("map_id","")),state.flags)
            check(str(actual.get("event_id",""))==str(event.get("event_id",""))+"."+str(route.get("id","")),
                "Wrong region choice "+id)
            if chapter<72:
                check(ambient.latest_prior_choice(chapter+1,state.flags).get("event_id","")==actual.get("event_id",""),
                    "Lost next-chapter response "+id)
            var loaded=State.new()
            check(loaded.restore_snapshot(state._pack()),"Old save failed "+id)
            check(loaded.flags.get(str(event.get("choice_flag","")))==route.get("value"),"Saved branch lost "+id)
    var count: int=0
    for entry in _read("res://data/content/maps.json").get("entries",[]):
        if str(entry.get("type",""))=="prototype":
            continue
        var id: String=str(entry.get("id",""))
        var layout: Dictionary=geo.layout(id,1)
        var story_targets: Dictionary=geo.resolve_story_targets(layout,geo._anchors())
        check((story_targets.get("missing",[]) as Array).is_empty(),
            "No accessible actual story marker: "+id+" / "+str(story_targets.get("missing",[])))
        var targets: Array[Vector2i]=story_targets.get("points",[])
        for gate in layout.get("gates",[]):
            targets.append(gate.get("cell",Vector2i.ZERO))
        for device in puzzles.devices(id):
            var cell: Array=device.get("cell",[])
            if cell.size()==2:
                targets.append(Vector2i(int(cell[0]),int(cell[1])))
        check(geo.reachable(layout,[layout.get("spawn",Vector2i.ZERO)],targets),
            "Unreachable actual gate/story/device "+id)
        count+=1
    check(count==40,"Expected 40 playable layouts")
    var sites: Array=_read("res://story/data/phase19_quest_world_anchors.json").get("quests",[])
    check(sites.size()==120,"Expected 120 quest anchors")
    var unique: Dictionary={}
    for site in sites:
        var id: String=str(site.get("quest_id",""))
        check(not unique.has(id),"Duplicate quest "+id)
        unique[id]=true
        check(registry.maps.has(str(site.get("map_id",""))),"Quest map missing "+id)
        check(binder.locations.has(id),"Quest binder missing "+id)
    check(_read("res://story/data/side_quests.json").get("quests",[]).size()==36,"Original side quests")
    check(_read("res://story/data/regional_quests_v2.json").get("quests",[]).size()==36,"Regional quests")
    check(_read("res://story/data/companion_quests.json").get("quests",[]).size()==48,"Companion quests")
    if failures.is_empty():
        print("PASS B-line: 40 maps, 72x2 choice continuations, 120 quest anchors, eight dungeon models")
        quit(0)
        return
    for reason in failures:
        push_error(reason)
    quit(1)
