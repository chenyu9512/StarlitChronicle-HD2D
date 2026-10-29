extends RefCounted
## One transition at a time. Call begin -> perform actual world load -> complete/abort.
const TILE: float = 32.0
const COOLDOWN_MS: int = 350
var in_flight: bool = false
var pending: Dictionary = {}
var last_request: String = ""
var last_finished_at: int = -100000

func begin(request: Dictionary, now_ms: int) -> Dictionary:
    var key: String = str(request.get("id",""))
    var target: String = str(request.get("to_map",""))
    var mode: String = str(request.get("mode",""))
    if in_flight or key.is_empty() or target.is_empty() or mode not in ["enter","leave","gate","dungeon"]:
        return {"handled":false,"reason":"invalid_or_busy"}
    if key == last_request and now_ms - last_finished_at < COOLDOWN_MS:
        return {"handled":false,"reason":"cooldown"}
    if mode == "gate":
        var neighbors: Array = request.get("neighbors",[])
        if target not in neighbors or not bool(request.get("unlocked",false)):
            return {"handled":false,"reason":"locked_gate"}
    if mode == "enter" and not str(request.get("indoor_id","")).is_empty():
        return {"handled":false,"reason":"already_indoors"}
    if mode == "leave" and str(request.get("indoor_id","")).is_empty():
        return {"handled":false,"reason":"not_indoors"}
    in_flight = true
    pending = request.duplicate(true)
    return {"handled":true,"transition":pending.duplicate(true),"lock_input":true,
        "animation":"open" if mode=="enter" else "fade"}

func abort() -> void:
    in_flight = false
    pending = {}

func complete(now_ms: int) -> Dictionary:
    if not in_flight:
        return {"handled":false,"reason":"no_pending_transition"}
    last_request = str(pending.get("id",""))
    last_finished_at = now_ms
    var settled: Dictionary = pending.duplicate(true)
    in_flight = false
    pending = {}
    return {"handled":true,"transition":settled,"lock_input":false}

## Search outward from original door / saved player position; prevent wall-spawn.
## Excluded cells include door thresholds, NPC reservations, and story markers when supplied.
static func safe_spawn(desired: Vector2, blocked: Dictionary, bounds: Vector2i,
        reserved: Dictionary = {}, tile_size: float = TILE, radius: int = 12) -> Dictionary:
    if bounds.x <= 0 or bounds.y <= 0 or tile_size <= 0.0:
        return {"valid":false,"reason":"invalid_bounds"}
    var origin: Vector2i = Vector2i(floori(desired.x/tile_size),floori(desired.y/tile_size))
    for ring in range(0,radius+1):
        var matches: Array[Vector2i] = []
        for dy in range(-ring,ring+1):
            for dx in range(-ring,ring+1):
                if ring > 0 and maxi(absi(dx),absi(dy)) != ring:
                    continue
                var cell: Vector2i = origin+Vector2i(dx,dy)
                if cell.x < 2 or cell.y < 2 or cell.x >= bounds.x-2 or cell.y >= bounds.y-2:
                    continue
                if blocked.has(cell) or reserved.has(cell):
                    continue
                matches.append(cell)
        if not matches.is_empty():
            matches.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
                var a_pos: Vector2=(Vector2(a)+Vector2(0.5,0.5))*tile_size
                var b_pos: Vector2=(Vector2(b)+Vector2(0.5,0.5))*tile_size
                var ad: float=a_pos.distance_squared_to(desired)
                var bd: float=b_pos.distance_squared_to(desired)
                return ad<bd if not is_equal_approx(ad,bd) else (a.y<b.y if a.y!=b.y else a.x<b.x)
            )
            var chosen: Vector2i=matches[0]
            return {"valid":true,"cell":chosen,
                "position":(Vector2(chosen)+Vector2(0.5,0.5))*tile_size,
                "moved":ring>0}
    return {"valid":false,"reason":"no_free_cell"}
