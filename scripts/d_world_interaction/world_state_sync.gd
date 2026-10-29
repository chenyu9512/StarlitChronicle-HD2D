extends RefCounted
## Versioned nested world snapshot; preserves legacy world/player_checkpoint keys.
const Transition = preload("res://scripts/d_world_interaction/scene_transition.gd")
const BUCKET: String = "d_world_interaction_v1"

static func capture(progress, map_id: String, chapter: int, indoor_id: String,
        position: Vector2, facing: Vector2, minutes: int,
        exterior: Vector2, last_door_id: String) -> Dictionary:
    if progress == null or map_id.is_empty():
        return {}
    var world_data: Dictionary=progress.rpg.get("world",{}).duplicate(true)
    world_data[BUCKET]={
        "version":1,"map_id":map_id,"chapter":chapter,"indoor_id":indoor_id,
        "position":[position.x,position.y],"facing":[facing.x,facing.y],
        "minutes":posmod(minutes,1440),"outdoor_return":[exterior.x,exterior.y],
        "door_id":last_door_id
    }
    return world_data

static func _point(value: Variant) -> Dictionary:
    if not (value is Array) or value.size()!=2:
        return {"valid":false}
    if typeof(value[0]) not in [TYPE_INT,TYPE_FLOAT] or typeof(value[1]) not in [TYPE_INT,TYPE_FLOAT]:
        return {"valid":false}
    var point: Vector2=Vector2(float(value[0]),float(value[1]))
    if is_nan(point.x) or is_nan(point.y) or is_inf(point.x) or is_inf(point.y):
        return {"valid":false}
    return {"valid":true,"position":point}

## Does not change progress or bypass map unlocks; caller supplies validated map/room.
static func restore(world_data: Dictionary, expected_map: String, chapter: int,
        expected_indoor: String, walls: Dictionary, extent: Vector2i,
        map_spawn: Vector2, protected: Dictionary = {}) -> Dictionary:
    var data: Dictionary=world_data.get(BUCKET,{})
    var origin: Dictionary={}
    var original_format: String="v1"
    if int(data.get("version",0))==1 and str(data.get("map_id",""))==expected_map \
            and int(data.get("chapter",-1))==chapter \
            and str(data.get("indoor_id",""))==expected_indoor:
        origin=_point(data.get("position",[]))
    if not bool(origin.get("valid",false)):
        var legacy: Dictionary=world_data.get("player_checkpoint",{})
        if str(legacy.get("map_id",""))==expected_map and int(legacy.get("chapter",-1))==chapter \
                and str(legacy.get("indoor_building",""))==expected_indoor:
            origin=_point(legacy.get("xy",[]))
            original_format="legacy"
    var intended: Vector2=origin.get("position",map_spawn)
    var safe: Dictionary=Transition.safe_spawn(intended,walls,extent,protected)
    if not bool(safe.get("valid",false)):
        safe=Transition.safe_spawn(map_spawn,walls,extent,protected)
    if not bool(safe.get("valid",false)):
        return {"valid":false,"reason":"no_safe_spawn","source":original_format}
    var facing: Vector2=Vector2.DOWN
    if original_format=="v1":
        var saved_facing: Dictionary=_point(data.get("facing",[]))
        if bool(saved_facing.get("valid",false)):
            facing=(saved_facing["position"] as Vector2).normalized()
    return {"valid":true,"position":safe["position"],"facing":facing,
        "indoor_id":expected_indoor,"map_id":expected_map,
        "source":original_format if bool(origin.get("valid",false)) else "spawn",
        "relocated":bool(safe.get("moved",false)) or not bool(origin.get("valid",false))}
