extends SceneTree
## B-line Act-I real player maps (not story-marker teleport tests).
## Walkability and physical interaction separation are checked against the
## SAME World object that the main game instantiates.
const State=preload("res://scripts/first_act_state.gd")
const Registry=preload("res://scripts/world_registry.gd")
const World=preload("res://scripts/first_act_world.gd")
const Discovery=preload("res://scripts/world_discoveries.gd")
var failures: Array[String]=[]


func _initialize() -> void:
    call_deferred("_run")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failures.append(reason)


func _cell(object: Node2D) -> Vector2i:
    return Vector2i(floori(object.position.x/32.0),floori(object.position.y/32.0))


func _near_walkable(point: Vector2i,reachable: Dictionary) -> bool:
    for step in [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,
            Vector2i.LEFT,Vector2i.RIGHT]:
        if reachable.has(point+step):
            return true
    return false


func _run() -> void:
    var catalogue=Discovery.new()
    check(catalogue.issues.is_empty(),"Existing forty-map event library invalid")
    var visited: int=0
    for map_id in ["map_coast_03","map_coast_04","map_coast_05"]:
        var state=State.new()
        state.new_game()
        state.chapter=5
        var router=Registry.new()
        router.bind(state)
        var world=World.new()
        world.map_profile=router.profile(map_id)
        root.add_child(world)
        world.build(5,2)
        check(str(world.map_profile.get("id",""))==map_id,
            "World built wrong authored Act-I map: "+map_id)
        var reachable: Dictionary=world._walkable_tiles()
        check(reachable.size()>200,map_id+": no walkable terrain connected to real spawn")
        var saved: Dictionary=state._pack().duplicate(true)
        var occupied: Dictionary={}
        var chapter_clues: Array=catalogue.entries(map_id)
        check(chapter_clues.size()==3,map_id+": lost its three-stage exploration")
        for record in chapter_clues:
            var event_id: String=str(record.get("id",""))
            var node_id: String="discovery:"+event_id
            check(world.nodes.has(node_id),map_id+": live input marker missing "+node_id)
            if not world.nodes.has(node_id):
                continue
            var prop: Node2D=world.nodes[node_id]
            var pos: Vector2i=_cell(prop)
            check(_near_walkable(pos,reachable),
                map_id+": no connected player stand tile for "+node_id)
            check(not occupied.has(pos),
                map_id+": two interactive discoveries overlap at "+str(pos))
            occupied[pos]=node_id
            var expected_flag: String=catalogue.flag(map_id,event_id)
            check(expected_flag=="discover."+map_id+"."+event_id,
                map_id+": stable old-save event ID changed")
            visited+=1
        if map_id=="map_coast_04":
            for action in ["a","b","c","seal"]:
                var node_id: String="puzzle:"+action
                check(world.nodes.has(node_id),map_id+": live cave puzzle device missing "+action)
                if not world.nodes.has(node_id):
                    continue
                var pos: Vector2i=_cell(world.nodes[node_id])
                check(_near_walkable(pos,reachable),
                    "Cave stone valve inaccessible to player: "+node_id)
                check(not occupied.has(pos),
                    "Cave evidence shares exact interactive cell with puzzle: "+str(pos))
                occupied[pos]=node_id
        check(state._pack()==saved,
            map_id+": rendering or inspecting site metadata changed V3 save")
        world.queue_free()
        await process_frame
    check(visited==9,"Not all nine live coastal story clues were accessible")
    if failures.is_empty():
        print("PASS B Act-I: physical cave valves and nine distinct coastal clues on reachable player maps")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
