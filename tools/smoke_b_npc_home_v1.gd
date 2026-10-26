extends SceneTree
## B-only batch tests; no D-controlled world or UI methods are required.
const TownLife = preload("res://scripts/world_town_life.gd")
const TownEcology = preload("res://scripts/world_town_ecology.gd")
const NpcDaily = preload("res://scripts/world_npc_daily.gd")
const Interior = preload("res://scripts/world_interior_v4.gd")
const Home = preload("res://scripts/world_home_interactions.gd")
const State = preload("res://scripts/first_act_state.gd")
var errors: Array[String] = []

func check(value: bool,description: String) -> void:
    if not value:
        errors.append(description)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var life=TownLife.new()
    var ecology=TownEcology.new()
    var motion=NpcDaily.new()
    var interiors=Interior.new()
    var homes=Home.new()
    check(motion.issues.is_empty(),"invalid authored motion data")
    check(ecology.issues.is_empty(),"invalid local town life")
    var records: Dictionary={}
    for region_id in TownLife.REGIONS:
        var locals: Array=life.residents(region_id)
        check(locals.size()==5,"missing five local identities "+region_id)
        for npc in locals:
            var id: String=str(npc.get("id",""))
            check(not records.has(id),"duplicate npc "+id)
            records[id]=true
            check(not str(npc.get("occupation","")).is_empty(),"occupation "+id)
            check((npc.get("daily_routine",[]) as Array).size()==5,"routine "+id)
            check((npc.get("dialogue_states",{}) as Dictionary).size()==6,"dialogue states "+id)
            var player=State.new()
            player.new_game()
            player.chapter=2
            var first: Dictionary=life.talk(id,region_id,{"day":1,"minutes":480},player)
            var another: Dictionary=life.talk(id,region_id,{"day":1,"minutes":480},player)
            check(bool(first.get("first",false)),"first contact "+id)
            check(not bool(another.get("first",true)),"repeat contact "+id)
            check(str(first.get("text",""))!=str(another.get("text","")),"repeated dialogue "+id)
            check(player.rpg.get("talked_to",{}).has(id),"missing legacy talked flag "+id)
            var night: Dictionary=life.talk(id,region_id,{"day":1,"minutes":1320},player)
            check(str(night.get("dialogue_phase",""))=="night","night talk "+id)
            var town_map: String=str(npc.get("map_id",""))
            var done: Dictionary={}
            done[town_map]={"prepare":true,"coordinate":true,"handoff":true}
            player.rpg["town_ecology_v7"]=done
            var aftermath: Dictionary=life.talk(id,region_id,{"day":1,"minutes":720},player)
            check(str(aftermath.get("dialogue_phase",""))=="after_quest",
                "Town completion not reflected "+id)
            check(not motion.schedule(id,1320).is_empty(),"night schedule "+id)
    check(records.size()==40,"Expected 40 canonical NPC identities")
    var block: Dictionary={Vector2i(10,10):true}
    var start: Vector2=Vector2(16*32+16,16*32+16)
    motion.begin_talk("npc_coast_01",start+Vector2(100,0))
    var paused: Dictionary=motion.step("npc_coast_01","map_coast_01",600,start,0.1,block,Vector2i(96,56))
    check(str(paused.get("state",""))=="talk" and (paused.get("position",Vector2.ZERO) as Vector2)==start,
        "Talking NPC moved despite pause")
    motion.end_talk("npc_coast_01")
    var moved: Dictionary=motion.step("npc_coast_01","map_coast_01",600,start,0.1,block,Vector2i(96,56))
    check((moved.get("position",Vector2.ZERO) as Vector2).distance_to(start)<=8.0,
        "NPC improperly teleported when resuming")
    var queries: int=motion.path_queries
    for tick in range(6):
        var iterated: Dictionary=motion.step("npc_coast_01","map_coast_01",600,start,0.016,block,Vector2i(96,56))
        check((iterated.get("position",Vector2.ZERO) as Vector2).distance_to(start)<3.0,
            "Motion contract skipped a movement frame")
    check(motion.path_queries==queries,"Pathfinder reran for identical NPC tile/goal")
    var incorrect: Dictionary=motion.step("npc_coast_01","map_city_01",600,start,0.1,block,Vector2i(96,56))
    check(not bool(incorrect.get("moving",true)),"NPC moved on incorrect map")
    check(motion.destination("npc_coast_01","map_city_01",600)==Vector2i(-1,-1),
        "NPC home map restriction missing")
    motion.reset_route("npc_coast_01")
    var boxed: Dictionary={Vector2i(16,16):true}
    var unsafe: Dictionary=motion.step("npc_coast_01","map_coast_01",600,start,0.1,boxed,Vector2i(96,56))
    check(str(unsafe.get("state",""))=="blocked" and not bool(unsafe.get("moving",true)),
        "NPC escaped blocked origin")
    var all_rooms: int=0
    var total: int=0
    for map_id in ["map_coast_01","map_coast_02"]:
        for room_id in ["inn","shop","house","guild","smith","shrine"]:
            var room: Dictionary=interiors.load_level(map_id,room_id,room_id)
            check(not room.is_empty(),"V4 room cannot load "+map_id+"/"+room_id)
            if room.is_empty():
                continue
            var inspected: Array=homes.objects(map_id,room_id)
            check(inspected.size()>=4,"Room lacks 4 unique inspectables "+map_id+"/"+room_id)
            check((room.get("investigations",[]) as Array).size()==inspected.size(),"Room loader lost inspectable markers")
            var used: Dictionary={}
            for obj in room.get("investigations",[]):
                var id: String=str(obj.get("id",""))
                var at: Vector2i=obj.get("cell",Vector2i(-1,-1))
                check(not used.has(id),"Duplicate room prop "+id)
                used[id]=true
                check(not (room.get("blocked",{}) as Dictionary).has(at),"Furniture marker blocked "+id)
            if inspected.is_empty():
                continue
            var player=State.new()
            player.new_game()
            var first_id: String=str(inspected[0].get("id",""))
            var target_raw: Array=inspected[0].get("cell",[])
            var target: Vector2i=Vector2i(int(target_raw[0]),int(target_raw[1]))
            check(str(homes.object_at(map_id,room_id,target).get("id",""))==first_id,
                "Furniture target cannot resolve by cell "+first_id)
            check(bool(homes.preview(map_id,room_id,first_id,player).get("available",false)),
                "Furniture preview missing "+first_id)
            check(not bool(homes.preview(map_id,room_id,first_id,player).get("seen",true)),
                "Furniture state unexpectedly already inspected "+first_id)
            var first: Dictionary=homes.inspect_at(map_id,room_id,target,player,false)
            var repeat: Dictionary=homes.inspect(map_id,room_id,first_id,player,false)
            check(bool(first.get("changed",false)),"First inspection failed "+first_id)
            check(not bool(repeat.get("changed",true)),"Repeat inspection awarded "+first_id)
            check(bool(homes.preview(map_id,room_id,first_id,player).get("seen",false)),
                "First inspection did not persist "+first_id)
            var invalid_probe: Dictionary=homes.inspect(map_id,"../private",first_id,player,false)
            check(not bool(invalid_probe.get("changed",true)),"Untrusted path escaped room registry")
            check((homes.dossier(map_id,"../private") as Dictionary).is_empty(),"Traversal bypassed validation")
            player.flags[str(inspected[0].get("after_flag",""))]=true
            var after: Dictionary=homes.inspect(map_id,room_id,first_id,player,true)
            check(bool(after.get("changed",false)),"Post-chapter furniture did not change "+first_id)
            var restored=State.new()
            check(restored.restore_snapshot(player._pack()),"Old V3 save failed "+map_id+"/"+room_id)
            check(not bool(homes.inspect(map_id,room_id,first_id,restored,true).get("changed",true)),
                "Furniture duplicate state after save "+map_id+"/"+room_id)
            all_rooms+=1
            total+=inspected.size()
    check(all_rooms==12 and total==52,"Expected 12 real rooms, 52 inspections")
    check(ecology.towns.size()==11,"Expected 11 individual town plans")
    for map_id in ecology.towns.keys():
        var saved=State.new()
        saved.new_game()
        var daytime: String=ecology.social_feedback(str(map_id),saved,11)
        var nighttime: String=ecology.social_feedback(str(map_id),saved,22)
        check(not daytime.is_empty() and daytime!=nighttime,"Town lacks changing neighborhood testimony "+str(map_id))
        var finished_communities: Dictionary={}
        finished_communities[str(map_id)]={"prepare":true,"coordinate":true,"handoff":true}
        saved.rpg["town_ecology_v7"]=finished_communities
        var after: String=ecology.social_feedback(str(map_id),saved,11)
        check(after!=daytime,"Community didn't react to project "+str(map_id))
    check(homes.issues.is_empty(),"Furniture registry has malformed records")
    if errors.is_empty():
        print("PASS B NPC/home code: 40 distinct NPCs, 11 community cycles, 12 rooms and 52 stateful furniture nodes")
        quit(0)
        return
    for message in errors:
        push_error(message)
    quit(1)
