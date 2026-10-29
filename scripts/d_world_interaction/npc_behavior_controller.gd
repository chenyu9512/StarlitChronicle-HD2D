extends RefCounted
## B: schedule/pathfinding; C: visual motion/turn/life action. D: occupancy arbiter.
const Daily = preload("res://scripts/world_npc_daily.gd")
const Router = preload("res://scripts/d_world_interaction/interaction_router.gd")
const TILE: float = 32.0
var schedule = Daily.new()
var occupant_cells: Dictionary = {}

func reserve(cell: Vector2i, owner_id: String) -> bool:
    if owner_id.is_empty() or occupant_cells.has(cell):
        return false
    occupant_cells[cell]=owner_id
    return true

func clear_reservations() -> void:
    occupant_cells.clear()

func begin_talk(npc_id: String, actor_position: Vector2, npc_visual: Node2D = null) -> void:
    schedule.begin_talk(npc_id,actor_position)
    if npc_visual != null and is_instance_valid(npc_visual) and npc_visual.has_method("face_player"):
        npc_visual.call("face_player",actor_position)

func end_talk(npc_id: String, npc_visual: Node2D = null) -> void:
    schedule.end_talk(npc_id)
    if npc_visual != null and is_instance_valid(npc_visual) and npc_visual.has_method("end_conversation"):
        npc_visual.call("end_conversation")

## protected: EXIT/door tiles, protagonist, companion and plot markers.
## A blocked B-line step remains in place; no teleport or script-owned mutation.
func update(npc_id: String, map_id: String, minutes: int, current: Vector2,
        seconds: float, blocked: Dictionary, extent: Vector2i,
        protected: Dictionary, npc_visual: Node2D = null) -> Dictionary:
    var restricted: Dictionary=blocked.duplicate()
    for cell in protected:
        restricted[cell]=true
    for cell in occupant_cells:
        if str(occupant_cells[cell]) != npc_id:
            restricted[cell]=true
    var old_cell: Vector2i=Vector2i(floori(current.x/TILE),floori(current.y/TILE))
    restricted.erase(old_cell)
    var outcome: Dictionary=schedule.step(npc_id,map_id,minutes,current,seconds,restricted,extent)
    var next_position: Vector2=outcome.get("position",current)
    var next_cell: Vector2i=Vector2i(floori(next_position.x/TILE),floori(next_position.y/TILE))
    if next_cell != old_cell and (restricted.has(next_cell) or next_cell.x<2 or next_cell.y<2
            or next_cell.x>=extent.x-2 or next_cell.y>=extent.y-2):
        next_position=current
        next_cell=old_cell
        outcome["moving"]=false
        outcome["state"]="wait"
    outcome["position"]=next_position
    occupant_cells.erase(old_cell)
    occupant_cells[next_cell]=npc_id
    if npc_visual != null and is_instance_valid(npc_visual):
        npc_visual.position=next_position
        if npc_visual.has_method("set_motion"):
            npc_visual.call("set_motion",seconds,outcome.get("facing",Vector2.ZERO) if bool(outcome.get("moving",false)) else Vector2.ZERO)
        if npc_visual.has_method("perform_life_action") and not bool(outcome.get("moving",false)):
            npc_visual.call("perform_life_action",str(outcome.get("state","observe")))
    return outcome

## Followers cannot enter collision, exits, occupied NPC tiles or quest pins.
static func safe_follower_position(current: Vector2, wanted: Vector2,
        blocked: Dictionary, protected: Dictionary, extent: Vector2i,
        delta: float, speed: float = 90.0) -> Vector2:
    var proposed: Vector2=current.move_toward(wanted,minf(maxf(0.0,delta),0.10)*speed)
    var cell: Vector2i=Vector2i(floori(proposed.x/TILE),floori(proposed.y/TILE))
    if cell.x<2 or cell.y<2 or cell.x>=extent.x-2 or cell.y>=extent.y-2:
        return current
    if blocked.has(cell) or protected.has(cell):
        return current
    if not Router.clear_path(current,proposed,blocked) or not Router.clear_path(current,proposed,protected):
        return current
    return proposed
