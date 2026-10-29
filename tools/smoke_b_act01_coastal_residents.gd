extends SceneTree
## Act-I offline population quality gate. Stable 40 NPC IDs remain unchanged,
## and each of the first two actual settlements has residents with valid
## authored districts and one active routine at every hour.
const State=preload("res://scripts/first_act_state.gd")
const Registry=preload("res://scripts/world_registry.gd")
const World=preload("res://scripts/first_act_world.gd")
const Daily=preload("res://scripts/world_npc_daily.gd")
const Town=preload("res://scripts/world_town_life.gd")
var errors: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,reason: String) -> void:
    if not ok:
        errors.append(reason)

func _run() -> void:
    var daily=Daily.new()
    var town=Town.new()
    check(daily.issues.is_empty(),"Town NPC authoring errors: "+str(daily.issues))
    check(town.by_id.size()==40,"Canonical 40 NPC IDs were changed")
    check(town.residents_for_map("map_coast_01").size()==3,
        "Morning Dew should retain three living residents")
    check(town.residents_for_map("map_coast_02").size()==2,
        "White Sand Harbor should have two distinct local residents")
    for npc_id in ["npc_coast_04","npc_coast_05"]:
        var person: Dictionary=town.citizen(npc_id)
        check(str(person.get("map_id",""))=="map_coast_02",
            "Harbor resident still placed in Morning Dew "+npc_id)
        check(not str(person.get("dialogue_states",{}).get("first","")).is_empty(),
            "Harbor resident has no introductory dialogue "+npc_id)
        for hour in range(24):
            var time: int=hour*60
            var schedule: Dictionary=daily.schedule(npc_id,time)
            var destination: Vector2i=daily.destination(npc_id,"map_coast_02",time)
            check(not schedule.is_empty() and destination.x>=2,
                "Harbor NPC cannot reach an authored district at "+str(hour)+": "+npc_id)
            check(daily.destination(npc_id,"map_coast_01",time)==Vector2i(-1,-1),
                "Harbor NPC still has a village destination "+npc_id)
    for chapter in [1,2]:
        var state=State.new()
        state.new_game()
        state.chapter=chapter
        var router=Registry.new()
        router.bind(state)
        var map_id: String=router.current_map()
        var world=World.new()
        world.map_profile=router.profile()
        root.add_child(world)
        world.build(chapter,2)
        var population: Array=town.residents_for_map(map_id)
        for resident in population:
            var id: String="citizen:"+str(resident.get("id",""))
            check(world.nodes.has(id),
                "Live chapter %d lacks scheduled citizen %s" % [chapter,id])
            if not world.nodes.has(id):
                continue
            var actor: Node2D=world.nodes[id]
            var cell: Vector2i=Vector2i(actor.position/32.0)
            check(not world.blocked.has(cell),
                "Live resident spawned inside a physical wall: "+id)
        for npc_key in world.nodes.keys():
            if str(npc_key).begins_with("citizen:"):
                var identity: String=str(npc_key).trim_prefix("citizen:")
                check(str(town.citizen(identity).get("map_id",""))==map_id,
                    "Other map's resident was wrongly duplicated in "+map_id)
        world.queue_free()
        await process_frame
    if errors.is_empty():
        print("PASS B Act-I: 40 stable NPCs, 3 villagers+2 harbor residents, 24h schedules, live map-local spawns")
        quit(0)
        return
    for error in errors:
        push_error(error)
    quit(1)
