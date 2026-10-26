extends RefCounted
## B-line opt-in, grid-safe incremental NPC movement. D controller owns Sprite
## and calls step each frame; this module never moves an NPC by teleporting.
const NPCS = "res://data/content/npcs.json"
const TOWNS = "res://data/levels/town_director_v4.json"
const TILE: float = 32.0
const SPEED: float = 72.0
var by_id: Dictionary = {}
var towns: Dictionary = {}
var talking: Dictionary = {}
var issues: Array[String] = []

func _init() -> void:
    var npcs: Variant = JSON.parse_string(FileAccess.get_file_as_string(NPCS))
    var settings: Variant = JSON.parse_string(FileAccess.get_file_as_string(TOWNS))
    if not (npcs is Dictionary) or not (settings is Dictionary):
        issues.append("Missing authored NPC or town registry")
        return
    towns = settings.get("towns",{})
    for row in npcs.get("entries",[]):
        if not (row is Dictionary):
            continue
        var npc_id: String = str(row.get("id",""))
        if npc_id.is_empty() or by_id.has(npc_id):
            issues.append("Duplicate or empty NPC life identity "+npc_id)
        by_id[npc_id] = row

func schedule(npc_id: String,minutes: int) -> Dictionary:
    var record: Dictionary = by_id.get(npc_id,{})
    var minute_of_day: int = posmod(minutes,1440)
    for block in record.get("daily_routine",[]):
        var start: int = int(block.get("start",0))*60
        var end: int = int(block.get("end",0))*60
        if start<end and minute_of_day>=start and minute_of_day<end:
            return block
        if start>end and (minute_of_day>=start or minute_of_day<end):
            return block
    return {}

func destination(npc_id: String,map_id: String,minutes: int) -> Vector2i:
    var layout: Dictionary = towns.get(map_id,{})
    var part: Dictionary = schedule(npc_id,minutes)
    for district in layout.get("districts",[]):
        if str(district.get("name",""))==str(part.get("district","")):
            var pos: Array = district.get("center",[])
            if pos.size()==2:
                return Vector2i(int(pos[0]),int(pos[1]))
    return Vector2i(-1,-1)

func begin_talk(npc_id: String,player_position: Vector2) -> void:
    talking[npc_id]=player_position

func end_talk(npc_id: String) -> void:
    talking.erase(npc_id)

func _route(from_cell: Vector2i,goal: Vector2i,blocked: Dictionary,extent: Vector2i) -> Array[Vector2i]:
    var route: Array[Vector2i] = []
    if blocked.has(from_cell) or from_cell.x<2 or from_cell.y<2:
        return route
    var seen: Dictionary = {from_cell:from_cell}
    var todo: Array[Vector2i] = [from_cell]
    var cursor: int = 0
    var closest: Vector2i = from_cell
    var distance: int = from_cell.distance_squared_to(goal)
    while cursor<todo.size():
        var cell: Vector2i=todo[cursor]
        cursor+=1
        var here: int=cell.distance_squared_to(goal)
        if here<distance:
            distance=here
            closest=cell
        if cell==goal:
            closest=goal
            break
        for step in [Vector2i.UP,Vector2i.LEFT,Vector2i.DOWN,Vector2i.RIGHT]:
            var adjacent: Vector2i=cell+step
            if adjacent.x<2 or adjacent.y<2 or adjacent.x>=extent.x-2 or adjacent.y>=extent.y-2:
                continue
            if blocked.has(adjacent) or seen.has(adjacent):
                continue
            seen[adjacent]=cell
            todo.append(adjacent)
    if closest==from_cell:
        return route
    var rewind: Vector2i=closest
    while rewind!=from_cell:
        route.push_front(rewind)
        rewind=seen[rewind]
    return route

func step(npc_id: String,map_id: String,minutes: int,current: Vector2,
        seconds: float,blocked: Dictionary,extent: Vector2i) -> Dictionary:
    var previous: Dictionary = by_id.get(npc_id,{})
    if previous.is_empty() or str(previous.get("region_id",""))!=str(towns.get(map_id,{}).get("region_id",previous.get("region_id",""))):
        # The canonical map may host an NPC in a second settlement in D; the
        # unrecognized routine stays idle rather than warping into new terrain.
        return {"position":current,"state":"idle","moving":false}
    if talking.has(npc_id):
        var face: Vector2 = (talking[npc_id] as Vector2)-current
        return {"position":current,"state":"talk","moving":false,"facing":face.normalized()}
    var plan: Dictionary=schedule(npc_id,minutes)
    var destination_cell: Vector2i=destination(npc_id,map_id,minutes)
    if destination_cell.x<0 or seconds<=0:
        return {"position":current,"state":"idle","moving":false}
    var occupied: Vector2i=Vector2i(floori(current.x/TILE),floori(current.y/TILE))
    var route: Array[Vector2i]=_route(occupied,destination_cell,blocked,extent)
    if route.is_empty():
        return {"position":current,"state":str(plan.get("action","idle")),"moving":false}
    var next_center: Vector2=Vector2(route[0])*TILE+Vector2(TILE*0.5,TILE*0.5)
    var next_position: Vector2=current.move_toward(next_center,SPEED*minf(maxf(seconds,0.0),0.1))
    return {"position":next_position,"state":str(plan.get("action","patrol")),
        "moving":not next_position.is_equal_approx(current),
        "facing":(next_position-current).normalized(),"goal":destination_cell}
