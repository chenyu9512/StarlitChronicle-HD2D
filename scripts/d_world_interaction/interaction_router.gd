extends RefCounted
## D-owned deterministic target selection; no mutation or reward.
const TILE: float = 32.0
const MAX_RANGE: float = 68.0
const PRIORITY: Dictionary = {
    "main": 0, "story": 1, "quest": 2, "quest_door": 3,
    "interior_exit": 4, "door": 5, "npc": 6, "furniture": 7,
    "service": 8, "gate": 9, "ambient": 10
}

static func context(map_id: String, chapter: int, target_id: String, target_type: String,
        actor_id: String, minutes: int, flags: Dictionary, indoor_id: String) -> Dictionary:
    return {"map_id": map_id, "chapter": chapter, "target_id": target_id,
        "target_type": target_type, "actor_id": actor_id, "minutes": minutes,
        "story_flags": flags.duplicate(true), "indoor_id": indoor_id}

static func kind_of(target_id: String, focus_id: String = "", side_id: String = "") -> String:
    if not focus_id.is_empty() and target_id == focus_id:
        return "main"
    if not side_id.is_empty() and target_id == side_id:
        return "story"
    if target_id.begins_with("story_stage_") or target_id in ["key_npc","clue","witness","crisis","resolve"]:
        return "quest"
    if target_id.begins_with("questdoor:"):
        return "quest_door"
    if target_id == "interior_exit":
        return "interior_exit"
    if target_id.begins_with("building:") or target_id == "home_door":
        return "door"
    if target_id.begins_with("citizen:") or target_id == "ambient_npc":
        return "npc"
    if target_id.begins_with("questcase:") or target_id.begins_with("inspect_"):
        return "furniture"
    if target_id.begins_with("exit:"):
        return "gate"
    if target_id.begins_with("interior_"):
        return "service"
    return "ambient"

static func clear_path(origin: Vector2, target: Vector2, walls: Dictionary,
        tile_size: float = TILE) -> bool:
    var line: Vector2 = target - origin
    var distance: float = line.length()
    if distance < 0.001:
        return true
    var steps: int = maxi(1, ceili(distance / maxf(4.0, tile_size * 0.20)))
    var source_cell: Vector2i = Vector2i(floori(origin.x/tile_size), floori(origin.y/tile_size))
    var target_cell: Vector2i = Vector2i(floori(target.x/tile_size), floori(target.y/tile_size))
    for index in range(1, steps):
        var position: Vector2 = origin + line * (float(index)/float(steps))
        var cell: Vector2i = Vector2i(floori(position.x/tile_size),floori(position.y/tile_size))
        if cell != source_cell and cell != target_cell and walls.has(cell):
            return false
    return true

## targets: [{id,position,visible,enabled,range,kind}]; only visible, legal, unobstructed.
## Story targets take priority among actually reachable targets; a distant story target cannot steal input.
static func select_target(targets: Array, origin: Vector2, facing: Vector2,
        walls: Dictionary, focus_id: String = "", side_id: String = "") -> Dictionary:
    var best: Dictionary = {}
    var best_rank: int = 2147483647
    var best_distance: float = INF
    var direction: Vector2 = facing.normalized()
    for item in targets:
        if not (item is Dictionary):
            continue
        var candidate: Dictionary = item
        var target_id: String = str(candidate.get("id",""))
        if target_id.is_empty() or not bool(candidate.get("visible",true)) or not bool(candidate.get("enabled",true)):
            continue
        var point: Variant = candidate.get("position",null)
        if not (point is Vector2):
            continue
        var position: Vector2 = point
        var dist: float = origin.distance_to(position)
        var kind: String = str(candidate.get("kind",kind_of(target_id,focus_id,side_id)))
        var reach: float = minf(MAX_RANGE,maxf(0.0,float(candidate.get("range",45.0))))
        if dist > reach:
            continue
        if not clear_path(origin,position,walls):
            continue
        if direction.length_squared() > 0.001 and dist > 17.0 and kind not in ["main","story","quest","interior_exit"]:
            if direction.dot((position-origin).normalized()) < -0.25:
                continue
        var rank: int = int(PRIORITY.get(kind,PRIORITY["ambient"]))
        if rank < best_rank or (rank == best_rank and (dist < best_distance-0.01 or (
                absf(dist-best_distance) <= 0.01 and target_id < str(best.get("id","~"))))):
            best = {"id":target_id,"kind":kind,"position":position,"distance":dist}
            best_rank = rank
            best_distance = dist
    return best
