extends SceneTree
## Canonical 40-map gate directions + 68 doors + every authored room exit.
## Uses actual Godot scenes; does not touch game state or any saved file.
const Geography = preload("res://scripts/world_geography.gd")
const PlayableWorld = preload("res://scripts/first_act_world.gd")
const InteriorV4 = preload("res://scripts/world_interior_v4.gd")
const INTERIOR_ROOT = "res://data/levels/v4/interiors/"
var failures: Array[String] = []
var last_action: String = ""
const REGION_ORDER: Array[String] = [
    "coast","oaths","forge","isles","mirror","oldland","sanctum","city"]

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _selected(key: String) -> void:
    last_action = key

func _rank(map_id: String) -> int:
    var bits: PackedStringArray = map_id.split("_")
    return REGION_ORDER.find(str(bits[1]))*5+int(bits[2])

func _run() -> void:
    var geo := Geography.new()
    var checked_maps: int = 0
    var checked_roofs: int = 0
    var checked_rooms: int = 0
    var checked_doors: int = 0
    for raw_key in geo.zones.keys():
        var map_id: String = str(raw_key)
        var zone: Dictionary = geo.zone(map_id)
        if not bool(zone.get("playable", false)):
            continue
        checked_maps += 1
        var layout: Dictionary = geo.layout(map_id, 2)
        var blocked: Dictionary = layout.get("blocked", {})
        var extent: Vector2i = layout.get("size", Vector2i(72,48))
        var level: Dictionary = geo.authored.level(map_id)
        var roads: Array = level.get("roads", [])
        var spine: Array = (roads[0] as Dictionary).get("points", []) if not roads.is_empty() else []
        for gate in layout.get("gates", []):
            var to_id: String = str(gate.get("id",""))
            var cell: Vector2i = gate.get("cell",Vector2i.ZERO)
            var west: bool = _rank(to_id)<_rank(map_id)
            var expected_x: int = 4 if west else extent.x-5
            _check(cell.x==expected_x, "wrong side of map: "+map_id+" -> "+to_id)
            var point: Array = spine[0] if west and not spine.is_empty() else (
                spine[-1] if not spine.is_empty() else [expected_x,24])
            var expected_y: int = clampi(int(point[1]),6,extent.y-7)
            _check(cell.y==expected_y,"exit not aligned to authored road: "+map_id+" -> "+to_id)
            _check(not blocked.has(cell) and geo.reachable(layout,[layout["spawn"]],[cell]),
                "unreachable exit: "+map_id+" -> "+to_id)
        for house in zone.get("buildings", []):
            var size: Array = house.get("size",[])
            var box: Rect2i = geo._building_box(house)
            _check(box.size==Vector2i(int(size[0]),int(size[1])+1),
                "invisible extra facade blockers: "+map_id+"/"+str(house.get("id","")))
            var d: Array = house.get("door",[])
            var door: Vector2i = Vector2i(int(d[0]),int(d[1]))
            var step: Vector2i=door+Vector2i.DOWN
            _check(blocked.has(door) and not blocked.has(step)
                and geo.reachable(layout,[layout["spawn"]],[step]),
                "door apron blocked or disconnected: "+map_id+"/"+str(house.get("id","")))
            checked_roofs += 1
    var dir := DirAccess.open(INTERIOR_ROOT)
    _check(dir!=null, "missing V4 interiors folder")
    if dir!=null:
        for filename in dir.get_files():
            if not filename.ends_with(".json"):
                continue
            var name: String=filename.trim_suffix(".json")
            var separator: int=name.find("__")
            if separator<0:
                failures.append("no canonical room identity: "+name)
                continue
            var map_id: String=name.substr(0,separator)
            var building_id: String=name.substr(separator+2)
            var room: Dictionary=InteriorV4.new().load_level(map_id,building_id,building_id)
            _check(not room.is_empty(),"unloadable V4 room: "+name)
            if room.is_empty():
                continue
            var markers: Dictionary=room.get("interact_cells",{})
            var spawn: Vector2i=room.get("spawn",Vector2i.ZERO)
            var exit_cell: Vector2i=markers.get("exit",Vector2i(-1,-1))
            _check(not (room.get("blocked",{}) as Dictionary).has(exit_cell)
                and geo.reachable(room,[spawn],[exit_cell]),
                "room spawn cannot reach exit: "+name)
            checked_rooms += 1
    var world := PlayableWorld.new()
    root.add_child(world)
    world.interacted.connect(_selected)
    for map_id in ["map_coast_01","map_coast_02"]:
        world.map_profile=geo.zone(map_id)
        world.build(2,2)
        var kinds: Array[String]=["inn","shop","guild","smith","house","shrine"]
        if map_id!="map_coast_01":
            kinds.clear()
            kinds.append("shelter")
            kinds.append("tavern")
        for kind in kinds:
            var key: String="building:"+kind
            _check(world.nodes.has(key),"missing actual door: "+map_id+"/"+kind)
            if not world.nodes.has(key):
                continue
            var outside: Vector2=world.nodes[key].position
            world.hero.position=outside
            last_action=""
            world.interact()
            _check(last_action==key,"interactive entry not selected: "+map_id+"/"+kind)
            _check(world.enter_building(kind),"actual entry failed: "+map_id+"/"+kind)
            _check(world.nodes.has("interior_exit"),"no exit on entering "+map_id+"/"+kind)
            if world.nodes.has("interior_exit"):
                var mark: Node2D=world.nodes["interior_exit"]
                _check(mark.visible and mark.has_node("ReturnToExteriorLabel"),
                    "no readable way back from "+map_id+"/"+kind)
                _check(not world._blocked(mark.position),"exit placed on blocked cell "+map_id+"/"+kind)
                world.hero.position=mark.position
                last_action=""
                world.interact()
                _check(last_action=="interior_exit","real exit button hijacked: "+map_id+"/"+kind)
            _check(world.leave_building(),"failed to return from "+map_id+"/"+kind)
            _check(world.hero.position.distance_to(outside)<1.0 and not world._blocked(world.hero.position),
                "returned to wrong/blocked doorstep: "+map_id+"/"+kind)
            checked_doors += 1
    world.queue_free()
    _check(checked_maps==40 and checked_roofs==68 and checked_rooms==99 and checked_doors==8,
        "incomplete map/door/room coverage")
    if failures.is_empty():
        print("PASS: 40 canonical route-oriented gates, 68 exact collision footprints, "+
            str(checked_rooms)+" reachable V4 room exits, 8 actual gameplay enter/exit interactions")
        quit(0)
        return
    for err in failures:
        push_error(err)
    quit(1)
