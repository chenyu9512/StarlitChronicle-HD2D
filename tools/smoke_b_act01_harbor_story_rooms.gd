extends SceneTree
## Chapter 2/4 harbor story locations: REAL exterior doors and V4 interiors.
## This checks navigation / room content / B-only clue state; D must still
## bind live furniture inputs and chapter transitions before commercial QA.
const State=preload("res://scripts/first_act_state.gd")
const Registry=preload("res://scripts/world_registry.gd")
const World=preload("res://scripts/first_act_world.gd")
const Home=preload("res://scripts/world_home_interactions.gd")
const V4=preload("res://scripts/world_interior_v4.gd")
var failures: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,message: String) -> void:
    if not ok:
        failures.append(message)

func _run() -> void:
    var save=State.new()
    save.new_game()
    save.chapter=2
    var registry=Registry.new()
    registry.bind(save)
    var world=World.new()
    world.map_profile=registry.profile("map_coast_02")
    root.add_child(world)
    world.build(2,2)
    check(world.terrain_layout.get("zone",{}).get("id","")=="map_coast_02",
        "Actual game world is not White Sand Harbor")
    var reachable: Dictionary=world._walkable_tiles()
    var occupied: Dictionary=world.blocked
    var home=Home.new()
    var physics=V4.new()
    var checked: int=0
    for room_id in ["shelter","tavern"]:
        var marker_id: String="building:"+room_id
        check(world.nodes.has(marker_id),room_id+": missing physical exterior doorway")
        if not world.nodes.has(marker_id):
            continue
        var marker: Node2D=world.nodes[marker_id]
        var step: Vector2i=Vector2i(marker.position/32.0)
        check(reachable.has(step),room_id+": no valid walkable route to public door")
        check(not occupied.has(step),room_id+": doorstep blocked by authored building")
        var original: Vector2=marker.position
        world.hero.position=original
        check(world.enter_building(room_id),room_id+": first-act world refused room entry")
        check(world.interior_building==room_id,room_id+": wrong room mounted")
        check(str(world.terrain_layout.get("authored_source",""))=="v4",
            room_id+": generic fallback substituted for designed room")
        var room: Dictionary=physics.load_level("map_coast_02",room_id,room_id)
        check(not room.is_empty(),room_id+": V4 room geometry was rejected")
        if room.is_empty():
            break
        check(world.terrain_layout.get("layout_id","")=="map_coast_02#"+room_id,
            room_id+": wrong interior or mismatched stable ID")
        var positions: Dictionary=world.terrain_layout.get("interact_cells",{})
        for name in ["exit","service","storage"]:
            var stand: Vector2i=positions.get(name,Vector2i(-1,-1))
            check(not world.blocked.has(stand) and
                world.nodes.has("interior_"+name),
                room_id+": live indoor service/exit absent or blocked: "+name)
        var props: Array=home.objects("map_coast_02",room_id)
        check(props.size()==4,room_id+": four unique story clue interactions not authored")
        for prop in props:
            var id: String=str(prop.get("id",""))
            var raw: Array=prop.get("cell",[])
            var cell: Vector2i=Vector2i(int(raw[0]),int(raw[1]))
            check(not world.blocked.has(cell),room_id+"/"+id+": clue inside a wall")
            check(str(home.object_at("map_coast_02",room_id,cell).get("id",""))==id,
                room_id+"/"+id+": actual cell and inspectable ID do not match")
            var read_snapshot: Dictionary=save._pack().duplicate(true)
            var observation: Dictionary=home.preview("map_coast_02",room_id,id,save)
            check(bool(observation.get("available",false)),
                room_id+"/"+id+": no physical B clue observation")
            check(save._pack()==read_snapshot,room_id+"/"+id+": preview changed the saved world")
            var action: Dictionary=home.inspect_at("map_coast_02",room_id,cell,save)
            check(bool(action.get("changed",false)) and
                not str(action.get("message","")).is_empty(),
                room_id+"/"+id+": first observation unavailable")
            check(not bool(home.inspect_at("map_coast_02",room_id,cell,save).get("changed",true)),
                room_id+"/"+id+": repeated inspection modified state")
            checked+=1
        var snapshot: Dictionary=save._pack().duplicate(true)
        var recovered=State.new()
        check(recovered.restore_snapshot(snapshot),room_id+": clue state lost on restore")
        if not props.is_empty():
            var first_id: String=str(props[0].get("id",""))
            check(bool(home.preview("map_coast_02",room_id,first_id,recovered).get("seen",false)),
                room_id+": first-read clue not recovered")
        check(world.leave_building(),room_id+": exit button could not return outdoors")
        check(world.interior_building.is_empty() and world.hero.position==original,
            room_id+": exiting room did not restore original harbor position")
        reachable=world._walkable_tiles()
        occupied=world.blocked
    check(checked==8,"Both commercial Act-I story rooms must expose exactly eight clues")
    check(home.issues.is_empty(),"B home contracts reported invalid clue cells: "+str(home.issues))
    if failures.is_empty():
        print("PASS B: two harbor story doorways, playable V4 interiors, eight clue identities, repeat/save and roundtrip")
        quit(0)
        return
    for issue in failures:
        push_error(issue)
    quit(1)
