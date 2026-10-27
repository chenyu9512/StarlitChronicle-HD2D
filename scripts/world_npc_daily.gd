extends RefCounted
## B-line predictable, incremental motion contract. The D scene controller must
## apply returned coordinates; this module NEVER relocates an actor on its own.
const NPCS: String = "res://data/content/npcs.json"
const TOWNS: String = "res://data/levels/town_director_v4.json"
const TILE: float = 32.0
const SPEED: float = 72.0
const MAX_VISITS: int = 8192
var by_id: Dictionary = {}
var towns: Dictionary = {}
var talking: Dictionary = {}
var route_cache: Dictionary = {}
var path_queries: int = 0
var issues: Array[String] = []

func _init() -> void:
    var registry: Variant=JSON.parse_string(FileAccess.get_file_as_string(NPCS))
    var settings: Variant=JSON.parse_string(FileAccess.get_file_as_string(TOWNS))
    if not (registry is Dictionary) or not (settings is Dictionary):
        issues.append("Invalid NPC or town registry")
        return
    towns=settings.get("towns",{})
    if not (towns is Dictionary):
        issues.append("Town registry has no map")
        return
    for row in registry.get("entries",[]):
        if not (row is Dictionary):
            continue
        var id: String=str(row.get("id",""))
        if id.is_empty() or by_id.has(id):
            issues.append("Duplicate or missing NPC id: "+id)
            continue
        var map_id: String=str(row.get("map_id",""))
        var plan: Dictionary=towns.get(map_id,{})
        if plan.is_empty():
            issues.append("NPC has no authored home settlement: "+id+"/"+map_id)
        var districts: Dictionary={}
        for place in plan.get("districts",[]):
            districts[str(place.get("name",""))]=true
        var routine: Array=row.get("daily_routine",[])
        if routine.size()!=5:
            issues.append("NPC routine is incomplete: "+id)
        for period in routine:
            if not districts.has(str(period.get("district",""))):
                issues.append("NPC routine names unknown district: "+id)
        by_id[id]=row

func schedule(npc_id: String,minutes: int) -> Dictionary:
    var record: Dictionary=by_id.get(npc_id,{})
    var minute: int=posmod(minutes,1440)
    for block in record.get("daily_routine",[]):
        var start: int=int(block.get("start",-1))*60
        var stop: int=int(block.get("end",-1))*60
        if start<0 or stop<0:
            continue
        if start<stop and minute>=start and minute<stop:
            return block
        if start>stop and (minute>=start or minute<stop):
            return block
    return {}

func destination(npc_id: String,map_id: String,minutes: int) -> Vector2i:
    var person: Dictionary=by_id.get(npc_id,{})
    if str(person.get("map_id",""))!=map_id:
        return Vector2i(-1,-1)
    var plan: Dictionary=towns.get(map_id,{})
    var action: Dictionary=schedule(npc_id,minutes)
    for district in plan.get("districts",[]):
        if str(district.get("name",""))==str(action.get("district","")):
            var at: Array=district.get("center",[])
            if at.size()==2:
                return Vector2i(int(at[0]),int(at[1]))
    return Vector2i(-1,-1)

func begin_talk(npc_id: String,player_position: Vector2) -> void:
    if by_id.has(npc_id):
        talking[npc_id]=player_position

func end_talk(npc_id: String) -> void:
    talking.erase(npc_id)

func reset_route(npc_id: String = "") -> void:
    if npc_id.is_empty():
        route_cache.clear()
    else:
        route_cache.erase(npc_id)

static func _within(cell: Vector2i,extent: Vector2i) -> bool:
    return cell.x>=2 and cell.y>=2 and cell.x<extent.x-2 and cell.y<extent.y-2

## A district anchor may land on new scenery after a C-line art pass. Find
## a nearby clear stand tile, without editing geometry or teleporting the NPC.
## Stable Manhattan-ring ordering ensures determinism across game reloads.
static func safe_destination(wanted: Vector2i,walls: Dictionary,extent: Vector2i) -> Vector2i:
    for radius in range(5):
        for y in range(-radius,radius+1):
            for x in range(-radius,radius+1):
                if absi(x)+absi(y)!=radius:
                    continue
                var cell: Vector2i=wanted+Vector2i(x,y)
                if _within(cell,extent) and not walls.has(cell):
                    return cell
    return Vector2i(-1,-1)

func _route(start: Vector2i,goal: Vector2i,walls: Dictionary,extent: Vector2i) -> Array[Vector2i]:
    path_queries+=1
    var empty: Array[Vector2i]=[]
    if not _within(start,extent) or walls.has(start) or not _within(goal,extent) or walls.has(goal):
        return empty
    var parent: Dictionary={}
    # A variable-key dictionary MUST use indexed assignment, not {start:start},
    # which would create the literal "start" key in GDScript.
    parent[start]=start
    var queue: Array[Vector2i]=[start]
    var index: int=0
    var best: Vector2i=start
    var closest: int=start.distance_squared_to(goal)
    # The largest authored settlement can exceed 4096 cells; still cap
    # searches by the grid area and our hard safety limit.
    var visit_limit: int=mini(MAX_VISITS,maxi(1,(extent.x-4)*(extent.y-4)))
    while index<queue.size() and index<visit_limit:
        var at: Vector2i=queue[index]
        index+=1
        var d: int=at.distance_squared_to(goal)
        if d<closest:
            closest=d
            best=at
        if at==goal:
            best=goal
            break
        for offset in [Vector2i.UP,Vector2i.LEFT,Vector2i.DOWN,Vector2i.RIGHT]:
            var next: Vector2i=at+offset
            if not _within(next,extent) or walls.has(next) or parent.has(next):
                continue
            parent[next]=at
            queue.append(next)
    if best==start:
        return [start]
    var path: Array[Vector2i]=[best]
    var cursor: Vector2i=best
    while cursor!=start:
        cursor=parent[cursor]
        path.push_front(cursor)
    return path

func _waypoint(npc_id: String,map_id: String,at: Vector2i,goal: Vector2i,
        walls: Dictionary,extent: Vector2i,seconds: float=0.0) -> Vector2i:
    var memo: Dictionary=route_cache.get(npc_id,{})
    var path: Array=memo.get("path",[])
    var valid: bool=str(memo.get("map_id",""))==map_id and memo.get("goal",Vector2i(-1,-1))==goal \
        and memo.get("extent",Vector2i.ZERO)==extent and int(memo.get("wall_count",-1))==walls.size()
    var index: int=path.find(at) if valid else -1
    if index>=0 and index+1<path.size():
        if walls.has(path[index+1]):
            index=-1
    # A partial BFS path may end NEAR an unreachable destination, not only
    # in a one-cell dead end. Once an NPC reaches that final tile, retry at
    # a bounded interval instead of running the same town-wide BFS every
    # rendered frame. This also lets temporary obstacles clear naturally.
    if index>=0 and index==path.size()-1 and at!=goal:
        var retry: float=maxf(0.0,float(memo.get("retry_after",1.25))-maxf(0.0,seconds))
        if retry>0.0:
            memo["retry_after"]=retry
            route_cache[npc_id]=memo
        else:
            index=-1
    if index<0:
        var rebuilt: Array[Vector2i]=_route(at,goal,walls,extent)
        memo={"map_id":map_id,"goal":goal,"extent":extent,
            "wall_count":walls.size(),"path":rebuilt,
            "retry_after":1.25}
        route_cache[npc_id]=memo
        path=rebuilt
        index=0 if not path.is_empty() else -1
    if index>=0 and index+1<path.size():
        return path[index+1]
    return at

func step(npc_id: String,map_id: String,minutes: int,current: Vector2,
        seconds: float,walls: Dictionary,extent: Vector2i) -> Dictionary:
    var person: Dictionary=by_id.get(npc_id,{})
    if person.is_empty() or str(person.get("map_id",""))!=map_id:
        reset_route(npc_id)
        return {"position":current,"state":"idle","moving":false}
    if talking.has(npc_id):
        var facing: Vector2=(talking[npc_id] as Vector2)-current
        return {"position":current,"state":"talk","moving":false,"facing":facing.normalized()}
    var task: Dictionary=schedule(npc_id,minutes)
    var goal: Vector2i=destination(npc_id,map_id,minutes)
    if goal.x<0 or seconds<=0.0 or extent.x<5 or extent.y<5:
        return {"position":current,"state":"idle","moving":false}
    var at: Vector2i=Vector2i(floori(current.x/TILE),floori(current.y/TILE))
    if not _within(at,extent) or walls.has(at):
        reset_route(npc_id)
        return {"position":current,"state":"blocked","moving":false}
    var searches_before: int=path_queries
    var navigation_goal: Vector2i=safe_destination(goal,walls,extent)
    if navigation_goal.x<0:
        reset_route(npc_id)
        return {"position":current,"state":"blocked","moving":false,"goal":goal}
    var next: Vector2i=_waypoint(npc_id,map_id,at,navigation_goal,walls,extent,seconds)
    var center: Vector2=Vector2(at)*TILE+Vector2.ONE*(TILE*0.5)
    # Stop at the center before rounding a corner: diagonal interpolation from
    # an offset actor position can otherwise cut through a blocked tile.
    var target: Vector2=center
    if current.distance_to(center)<=0.5 and next!=at:
        target=Vector2(next)*TILE+Vector2.ONE*(TILE*0.5)
    var moved: Vector2=current.move_toward(target,SPEED*minf(maxf(seconds,0.0),0.1))
    var direction: Vector2=(moved-current).normalized()
    return {"position":moved,"state":str(task.get("action","idle")),
        "moving":not moved.is_equal_approx(current),"facing":direction,
        "goal":goal,"navigation_goal":navigation_goal,
        "path_cached":path_queries==searches_before}
