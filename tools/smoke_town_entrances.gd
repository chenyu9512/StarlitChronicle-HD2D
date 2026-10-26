extends SceneTree
## C/B/D scoped physical map smoke. No save, quest or battle mutation.
## Run Godot 4.7.2 headlessly during the next integration test batch.
const Geography = preload("res://scripts/world_geography.gd")
const PlayableWorld = preload("res://scripts/first_act_world.gd")
var problems: Array[String]=[]
var selected: String=""

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool,detail: String) -> void:
    if not value:
        problems.append(detail)

func _on_interaction(target: String) -> void:
    selected=target

func center(cell: Vector2i) -> Vector2:
    return Vector2(cell*32)+Vector2(16,16)

func _run() -> void:
    var geo=Geography.new()
    var towns: Array[String]=[]
    for map_id in geo.zones.keys():
        if bool(geo.zone(str(map_id)).get("settlement",false)):
            towns.append(str(map_id))
    towns.sort()
    check(towns.size()==11,"Expected 11 canonical settlements")
    var building_count: int=0
    for map_id in towns:
        var layout: Dictionary=geo.layout(map_id,1)
        var features: Array=layout.get("features",[])
        var blockers: Dictionary=layout.get("blocked",{})
        var size: Vector2i=layout.get("size",Vector2i(72,48))
        var spawn: Vector2i=layout.get("spawn",Vector2i(10,23))
        for building in geo.zone(map_id).get("buildings",[]):
            var id: String=str(building.get("id",""))
            var centre_data: Array=building.get("pos",[])
            var size_data: Array=building.get("size",[])
            var door_data: Array=building.get("door",[])
            check(centre_data.size()==2 and size_data.size()==2 and door_data.size()==2,map_id+" malformed "+id)
            if centre_data.size()!=2 or size_data.size()!=2 or door_data.size()!=2:
                continue
            var body:=Vector2i(int(centre_data[0]),int(centre_data[1]))
            var dims:=Vector2i(int(size_data[0]),int(size_data[1]))
            var door:=Vector2i(int(door_data[0]),int(door_data[1]))
            var threshold: Vector2i=door+Vector2i.DOWN
            var inside:=geo._building_box(building)
            for yy in range(inside.position.y,inside.end.y):
                for xx in range(inside.position.x,inside.end.x):
                    check(blockers.has(Vector2i(xx,yy)),map_id+"/"+id+" ghost collision at "+str(Vector2i(xx,yy)))
            check(blockers.has(door),map_id+"/"+id+" door crosses a solid wall")
            check(not blockers.has(threshold),map_id+"/"+id+" threshold blocked")
            check(geo.reachable({"blocked":blockers,"size":size},[spawn],[threshold]),map_id+"/"+id+" entrance unreachable")
            var has_marker: bool=false
            for feature in features:
                if str(feature.get("building",""))==id:
                    has_marker=true
                    check(feature.get("door",Vector2i.ZERO)==door,map_id+"/"+id+" art/event ID mismatch")
            check(has_marker,map_id+"/"+id+" has no unique feature")
            building_count+=1
    check(building_count==66,"Expected 66 town building instances")
    var world=PlayableWorld.new()
    world.map_profile=geo.zone("map_coast_01")
    root.add_child(world)
    world.build(1,2)
    world.interacted.connect(_on_interaction)
    for building in geo.zone("map_coast_01").get("buildings",[]):
        var id: String=str(building["id"])
        var d: Array=building["door"]
        var door:=Vector2i(int(d[0]),int(d[1]))
        var door_key: String="building:"+id
        var marker: Node2D=world.nodes.get(door_key)
        check(marker!=null,"Missing runtime entrance "+id)
        check(world._blocked(center(door)),"World allows actor into "+id+" wall")
        check(not world._blocked(center(door+Vector2i.DOWN)),"World door apron blocked "+id)
        if marker!=null:
            check(marker.position.distance_to(center(door+Vector2i.DOWN))<1.0,"Entrance marker offset "+id)
            world.hero.position=marker.position
            selected=""
            world.interact()
            check(selected==door_key,"Door not selected from its own front step: "+id+" got "+selected)
    var entry_key: String="inn"
    var position_before: Vector2=world.nodes["building:"+entry_key].position
    world.hero.position=position_before
    check(world.enter_building(entry_key),"Inn interior transition failed")
    check(world.interior_building==entry_key,"Interior ID mismatch")
    check(world.leave_building(),"Inn exit transition failed")
    check(world.hero.position.distance_to(position_before)<1.0,"Exit did not restore front-door checkpoint")
    check(not world._blocked(world.hero.position),"Inn exit restored player into a wall")
    world.queue_free()
    if problems.is_empty():
        print("PASS town geometry: 11 towns, 66 solid houses, reachable front steps, live door selection and inn round-trip")
        quit(0)
    for issue in problems:
        push_error(issue)
    quit(1)
