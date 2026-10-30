extends RefCounted
## A-line world/battle transaction. D-line owns controller and world wiring.
## No reward, quest or save mutation is performed here.
const WIN_GRACE_PIXELS: float = 420.0
const DEFEAT_GRACE_PIXELS: float = 900.0
const SEARCH_RADIUS_TILES: int = 12
const TILE_SIZE: float = 32.0

var active: bool = false
var settled: bool = false
var finished: bool = false
var sequence: int = 0
var checkpoint_data: Dictionary = {}
var result_data: Dictionary = {}

static func eligible(mode: String, context: Dictionary) -> Dictionary:
    if mode not in ["random", "boss"]:
        return {"ok":false,"reason":"invalid_mode"}
    if bool(context.get("already_battling",false)):
        return {"ok":false,"reason":"already_battling"}
    if bool(context.get("busy",false)) or bool(context.get("dialogue_open",false)):
        return {"ok":false,"reason":"input_busy"}
    if bool(context.get("cinematic",false)) or bool(context.get("transitioning",false)):
        return {"ok":false,"reason":"world_transition"}
    if not bool(context.get("player_valid",true)):
        return {"ok":false,"reason":"player_unavailable"}
    if mode == "random":
        if bool(context.get("no_encounters",false)):
            return {"ok":false,"reason":"disabled"}
        if int(context.get("chapter",0)) < 2:
            return {"ok":false,"reason":"early_chapter"}
        if bool(context.get("settlement",false)):
            return {"ok":false,"reason":"safe_town"}
        if not str(context.get("interior_building","")).is_empty():
            return {"ok":false,"reason":"safe_interior"}
        if bool(context.get("encounter_cooldown",false)):
            return {"ok":false,"reason":"cooldown"}
    else:
        if bool(context.get("boss_resolved",false)):
            return {"ok":false,"reason":"boss_resolved"}
        if bool(context.get("boss_pending",false)):
            return {"ok":false,"reason":"boss_pending"}
        if str(context.get("trigger_id","")).is_empty():
            return {"ok":false,"reason":"missing_boss_trigger"}
    return {"ok":true,"reason":"allowed"}

func begin(world: Node, mode: String, context: Dictionary) -> Dictionary:
    if active or (settled and not finished):
        return {"ok":false,"reason":"handoff_already_active"}
    var verdict: Dictionary = eligible(mode,context)
    if not bool(verdict.get("ok",false)):
        return verdict
    if not is_instance_valid(world):
        return {"ok":false,"reason":"world_missing"}
    var avatar: Node2D = world.get("hero") as Node2D
    if not is_instance_valid(avatar):
        return {"ok":false,"reason":"hero_missing"}
    var profile: Dictionary = world.get("map_profile")
    var region_id: String = str(profile.get("id",""))
    if region_id.is_empty():
        return {"ok":false,"reason":"map_missing"}
    var position: Vector2 = avatar.position
    if not _valid_position(position):
        return {"ok":false,"reason":"position_invalid"}
    var facing_value: int = int(avatar.get("facing"))
    sequence += 1
    checkpoint_data = {
        "schema":"starlit.battle_world_handoff.v1",
        "sequence":sequence,
        "mode":mode,
        "trigger_id":str(context.get("trigger_id","")),
        "chapter":int(context.get("chapter",world.get("chapter"))),
        "map_id":region_id,
        "interior_building":str(world.get("interior_building")),
        "position":[position.x,position.y],
        "facing":clampi(facing_value,0,3),
        "encounter_meter":float(world.get("encounter_meter")),
        "next_encounter":float(world.get("next_encounter")),
        "clock":context.get("clock",{}).duplicate(true) if context.get("clock",{}) is Dictionary else {},
        "weather":str(context.get("weather","")),
        "audio_cue":str(context.get("audio_cue","")),
        "width_tiles":maxi(8,int(context.get("width_tiles",72))),
        "height_tiles":maxi(8,int(context.get("height_tiles",48)))
    }
    result_data.clear()
    active = true
    settled = false
    finished = false
    return {"ok":true,"sequence":sequence,"checkpoint":checkpoint()}

func abort() -> bool:
    if not active or settled:
        return false
    active = false
    finished = true
    return true

## Call after an interior exit / map transition to prevent instant re-encounters.
static func grant_exploration_grace(world: Node, distance_px: float = 520.0) -> bool:
    if not is_instance_valid(world) or distance_px <= 0.0:
        return false
    world.set("encounter_meter",minf(float(world.get("encounter_meter")),0.0)-distance_px)
    world.set("next_encounter",maxf(float(world.get("next_encounter")),350.0))
    return true

func checkpoint() -> Dictionary:
    return checkpoint_data.duplicate(true)

func mark_result(victory: bool, settlement: String = "") -> Dictionary:
    if not active or finished:
        return {"ok":false,"reason":"handoff_inactive"}
    if settled:
        return {"ok":false,"reason":"duplicate_result"}
    settled = true
    result_data = {
        "ok":true,
        "sequence":int(checkpoint_data.get("sequence",0)),
        "victory":victory,
        "mode":str(checkpoint_data.get("mode","")),
        "boss_settlement":settlement if victory and str(checkpoint_data.get("mode",""))=="boss" else "",
        "map_id":str(checkpoint_data.get("map_id",""))
    }
    return result_data.duplicate(true)

func restore(world: Node) -> Dictionary:
    if not active or not settled or finished:
        return {"ok":false,"reason":"handoff_not_ready"}
    if not is_instance_valid(world):
        return {"ok":false,"reason":"world_missing"}
    var avatar: Node2D = world.get("hero") as Node2D
    if not is_instance_valid(avatar):
        return {"ok":false,"reason":"hero_missing"}
    var info: Dictionary = world.get("map_profile")
    var same_map: bool = str(info.get("id",""))==str(checkpoint_data.get("map_id","")) and str(world.get("interior_building"))==str(checkpoint_data.get("interior_building",""))
    var won: bool = bool(result_data.get("victory",false))
    var destination: Vector2 = avatar.position
    var safe_found: bool = true
    var relocated: bool = false
    if not won:
        var layout: Dictionary = world.get("terrain_layout")
        var spawn_cell: Variant = layout.get("spawn",Vector2i(10,23))
        if spawn_cell is Vector2i:
            destination = Vector2(spawn_cell)*TILE_SIZE+Vector2(16,16)
        elif spawn_cell is Vector2:
            destination = spawn_cell*TILE_SIZE+Vector2(16,16)
        else:
            destination = avatar.position
        var fallback: Dictionary = find_safe_position(world,destination)
        safe_found = bool(fallback.get("ok",false))
        if safe_found:
            destination = fallback["position"]
            relocated = true
    elif same_map:
        var raw_position: Array = checkpoint_data.get("position",[])
        if raw_position.size()==2:
            var original := Vector2(float(raw_position[0]),float(raw_position[1]))
            var verified: Dictionary = find_safe_position(world,original)
            safe_found = bool(verified.get("ok",false))
            if safe_found:
                destination = verified["position"]
                relocated = true
    else:
        # A cinematic/map transition may have moved the world while combat was
        # running. Never return to the OLD map or accept a blocked arrival in
        # the NEW map; only resolve against the live destination geometry.
        var arrival: Dictionary = find_safe_position(world,avatar.position)
        if not bool(arrival.get("ok",false)):
            # An old-map coordinate may be nowhere near the destination's
            # actual walkable component. Use the NEW map's authored spawn,
            # never the checkpoint/map we just left.
            var live_layout: Variant = world.get("terrain_layout")
            if live_layout is Dictionary:
                var spawn_value: Variant = live_layout.get("spawn",null)
                if spawn_value is Vector2i:
                    arrival = find_safe_position(world,Vector2(spawn_value)*TILE_SIZE+Vector2(16,16))
        safe_found = bool(arrival.get("ok",false))
        if safe_found:
            destination = arrival["position"]
            relocated = avatar.position.distance_squared_to(destination)>0.01
    if not safe_found:
        # Failed recovery must remain retryable after a blocking collision is removed.
        # Never finalize the handoff or mutate world cooldown/position on this path.
        var failure: Dictionary = result_data.duplicate(true)
        failure["ok"] = false
        failure["reason"] = "no_safe_spawn"
        failure["restored"] = false
        failure["resume_world"] = false
        failure["save_required"] = false
        failure["same_map"] = same_map
        return failure
    if relocated:
        avatar.position = destination
        # A relocated victory also needs its followers beside the avatar,
        # instead of leaving them stranded behind the old map/blocked tile.
        _reset_party_followers(world,destination)
    if same_map:
        avatar.set("facing",clampi(int(checkpoint_data.get("facing",0)),0,3))
    world.set("movement",Vector2.ZERO)
    # Never clear world.locked here: the controller owns dialogue/cinematic/input state.
    var cooldown: float = WIN_GRACE_PIXELS if won else DEFEAT_GRACE_PIXELS
    world.set("encounter_meter",minf(0.0,float(world.get("encounter_meter")))-cooldown)
    world.set("next_encounter",maxf(350.0,float(world.get("next_encounter"))))
    if world.has_method("_reveal_nearby"):
        world.call("_reveal_nearby")
    finished = true
    active = false
    var answer: Dictionary = result_data.duplicate(true)
    answer["restored"] = true
    answer["same_map"] = same_map
    answer["relocated"] = relocated
    answer["cooldown_distance"] = cooldown
    answer["audio_cue"] = str(checkpoint_data.get("audio_cue",""))
    answer["resume_world"] = true
    answer["save_required"] = true
    result_data = answer.duplicate(true)
    return answer

func find_safe_position(world: Node, origin: Vector2) -> Dictionary:
    if not is_instance_valid(world) or not _valid_position(origin):
        return {"ok":false,"reason":"invalid_world_or_position"}
    # Map dimensions must come from the LIVE map after story transitions, not
    # from the pre-combat checkpoint (which might be a different room/map).
    var width: int = maxi(8,int(checkpoint_data.get("width_tiles",72)))
    var height: int = maxi(8,int(checkpoint_data.get("height_tiles",48)))
    var live_layout: Variant = world.get("terrain_layout")
    if live_layout is Dictionary:
        var live_size: Variant = live_layout.get("size",null)
        if live_size is Vector2i:
            width = maxi(8,live_size.x)
            height = maxi(8,live_size.y)
    var cell: Vector2i = Vector2i(floori(origin.x/TILE_SIZE),floori(origin.y/TILE_SIZE))
    # FirstActWorld._walkable_tiles is the spawn-connected component after
    # authored collision, so a bare _blocked check alone is insufficient.
    # Simple isolated test worlds without this method retain legacy behavior.
    var has_connected_floor: bool = world.has_method("_walkable_tiles")
    var connected: Dictionary = {}
    if has_connected_floor:
        var live_floor: Variant = world.call("_walkable_tiles")
        if not (live_floor is Dictionary):
            return {"ok":false,"reason":"invalid_connected_floor"}
        connected = live_floor
        if connected.is_empty():
            return {"ok":false,"reason":"no_connected_floor"}
    if cell.x>=1 and cell.y>=1 and cell.x<width-1 and cell.y<height-1:
        var origin_blocked: bool = bool(world.call("_blocked",origin)) if world.has_method("_blocked") else false
        if not origin_blocked and (not has_connected_floor or connected.has(cell)):
            return {"ok":true,"position":origin,"tile":cell}
    for radius in range(SEARCH_RADIUS_TILES+1):
        for y in range(-radius,radius+1):
            for x in range(-radius,radius+1):
                if radius>0 and absi(x)!=radius and absi(y)!=radius:
                    continue
                var candidate_cell: Vector2i=cell+Vector2i(x,y)
                if candidate_cell.x<1 or candidate_cell.y<1 or candidate_cell.x>=width-1 or candidate_cell.y>=height-1:
                    continue
                if has_connected_floor and not connected.has(candidate_cell):
                    continue
                var candidate: Vector2=Vector2(candidate_cell)*TILE_SIZE+Vector2(16,16)
                var blocked: bool = bool(world.call("_blocked",candidate)) if world.has_method("_blocked") else false
                if not blocked:
                    return {"ok":true,"position":candidate,"tile":candidate_cell}
    return {"ok":false,"reason":"all_connected_spawn_candidates_blocked"}

func _reset_party_followers(world: Node, position: Vector2) -> void:
    var offsets: Array[Vector2]=[Vector2(-28,20),Vector2(-53,27),Vector2(-78,40)]
    var properties: Array[String]=["companion","third","fourth"]
    for i in range(properties.size()):
        var follower: Node2D=world.get(properties[i]) as Node2D
        if is_instance_valid(follower):
            follower.position=position+offsets[i]

static func _valid_position(point: Vector2) -> bool:
    return not (is_nan(point.x) or is_nan(point.y) or is_inf(point.x) or is_inf(point.y))
