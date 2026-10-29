extends Node2D
## Production-facing 2D blocking for Chapter 47. All lines are routed only
## through the same reachable floor component used by the playable world.
## This layer never mutates story flags, collision, combat, quest rewards or saves.
const NPCVisual = preload("res://scripts/world_npc_visual.gd")
const TEAM_CONFIG := {
    "EAST_GATE_LEISO": {"accent": Color("a7d4e7"), "role": "雷索／岚音 · 救护队"},
    "SOUTH_GATE_SHUOXIAN": {"accent": Color("d8bd80"), "role": "朔弦 · 儿童护送"},
    "WEST_GATE_TIFA": {"accent": Color("cbb0e7"), "role": "缇珐 · 机械抢修"}
}
var world
var bridge
var trails: Dictionary = {}
var signposts: Dictionary = {}
var rendered_signature: String = ""
var route_to_marker: String = ""
var last_route_cell: Vector2i = Vector2i(-1,-1)
var follow_actor
var follow_destination: String = ""
var follow_team: String = ""
var follow_repath: float = 0.0
var follow_waypoints: Array[Vector2] = []
var follow_index: int = 0
var escort_joined: bool = false
var escort_start_marker: String = ""
var guide_destination: String = ""
const ESCORT_DESTINATIONS := {
    "evac:east:escort": "医疗担架队 · 请带到东门",
    "evac:south:route": "儿童护送队 · 请带到南门"
}

func bind_world(world_source, runtime_bridge) -> void:
    world = world_source
    bridge = runtime_bridge
    rendered_signature = ""
    route_to_marker = ""
    last_route_cell = Vector2i(-1,-1)
    follow_actor = null
    follow_destination = ""
    escort_joined = false
    escort_start_marker = ""
    guide_destination = ""
    follow_waypoints.clear()
    # Stay outside world.root: world.build() frees that root on map reload.
    # This director survives and rebuilds only its disposable visual children.
    if get_parent() != world:
        if get_parent() != null:
            get_parent().remove_child(self)
        world.add_child(self)
    position = Vector2.ZERO
    refresh()

func refresh() -> void:
    if world == null or bridge == null or not bridge.registry_loaded or world.chapter != 47 or not world.interior_building.is_empty():
        visible = false
        return
    visible = true
    var model = bridge.evacuation
    var sig: String = "%s/%s/%s/%s" % [
        str(model.active_controlled_squad),
        str(model.squad_statuses),
        str(model.failed), str(model.finished)]
    if rendered_signature == sig:
        return
    rendered_signature = sig
    for child in get_children():
        remove_child(child)
        child.queue_free()
    trails.clear()
    signposts.clear()
    follow_actor = null
    follow_destination = ""
    follow_team = ""
    escort_joined = false
    escort_start_marker = ""
    guide_destination = ""
    follow_waypoints.clear()
    follow_index = 0
    last_route_cell = Vector2i(-1,-1)
    route_to_marker = ""
    var walkable: Dictionary = world._walkable_tiles()
    for team_id in model.OBJECTIVE_MARKERS:
        var config: Dictionary = TEAM_CONFIG.get(team_id,{})
        var markers: Array = model.OBJECTIVE_MARKERS[team_id]
        var next_marker: String = model.current_objective_marker(team_id)
        var active: bool = team_id == model.active_controlled_squad
        if active and not next_marker.is_empty() and world.nodes.has(next_marker):
            _spawn_rescue_cast(team_id,world.nodes[next_marker].position)
        for marker_id in markers:
            if not world.nodes.has(marker_id):
                continue
            var target: Node2D = world.nodes[marker_id]
            if not is_instance_valid(target):
                continue
            var indicator := Node2D.new()
            indicator.position = target.position + Vector2(0, -16)
            indicator.z_index = 8
            add_child(indicator)
            _draw_checkpoint(indicator,str(config.get("role","撤离点")),
                config.get("accent",Color.WHITE),active and next_marker==marker_id)
            signposts[marker_id] = indicator
        if next_marker.is_empty() or not active or not world.nodes.has(next_marker):
            continue
        _begin_escort_if_required(str(team_id),str(next_marker),markers,walkable)
        var route_target: String = _effective_guide_target(str(next_marker))
        if not world.nodes.has(route_target):
            continue
        var route: Array[Vector2] = _floor_route(world.hero.position,
            world.nodes[route_target].position,walkable)
        if route.is_empty():
            push_warning("Chapter 47 presentation route has no verified walkable path: " + next_marker)
            continue
        var line := Line2D.new()
        line.width = 5.0
        line.default_color = config.get("accent",Color.WHITE)
        line.antialiased = true
        line.z_index = 6
        line.begin_cap_mode = Line2D.LINE_CAP_ROUND
        line.end_cap_mode = Line2D.LINE_CAP_ROUND
        line.joint_mode = Line2D.LINE_JOINT_ROUND
        line.points = PackedVector2Array(route)
        add_child(line)
        trails[team_id] = line
        route_to_marker = str(next_marker)
        guide_destination = route_target
        last_route_cell = _as_cell(world.hero.position)

func _process(delta: float) -> void:
    if not visible or world == null or bridge == null or not bridge.registry_loaded or world.chapter != 47:
        return
    if not is_instance_valid(world.hero):
        return
    # Refresh the tactical guide only when the player changes floor cells.
    # Never simulate task completion or move any game collision object.
    var current_cell: Vector2i = _as_cell(world.hero.position)
    if not escort_joined and is_instance_valid(follow_actor) and not world.locked:
        # The assembled civilian group must be reached before following.
        if follow_actor.position.distance_to(world.hero.position) <= 66.0:
            escort_joined = true
            follow_actor.perform_life_action("wave")
            last_route_cell = Vector2i(-1,-1)
    var next_target: String = _effective_guide_target(route_to_marker)
    if route_to_marker != "" and (current_cell != last_route_cell or guide_destination != next_target):
        last_route_cell = current_cell
        guide_destination = next_target
        var chosen: String = bridge.evacuation.active_controlled_squad
        if trails.has(chosen) and is_instance_valid(trails[chosen]) and world.nodes.has(next_target):
            var route: Array[Vector2] = _floor_route(world.hero.position,
                world.nodes[next_target].position,world._walkable_tiles())
            trails[chosen].points = PackedVector2Array(route)
    _follow_hero_on_floor(delta)

func _effective_guide_target(marker_id: String) -> String:
    if marker_id == follow_destination and not escort_joined and not escort_start_marker.is_empty():
        return escort_start_marker
    return marker_id

func escort_status(marker_id: String) -> String:
    if not ESCORT_DESTINATIONS.has(marker_id):
        return ""
    if marker_id != follow_destination or not is_instance_valid(follow_actor):
        return "请返回上一集结点重新接队"
    if not escort_joined:
        return "尚未接队 · 先前往集结点与居民会合"
    if not world.nodes.has(marker_id):
        return "目标未载入，无法确认护送"
    var destination: Node2D = world.nodes[marker_id]
    var distance_to_exit: int = ceili(follow_actor.position.distance_to(destination.position)/32.0)
    return "护送中 · 队伍距终点约%d格" % distance_to_exit

func escort_in_progress() -> bool:
    return not follow_destination.is_empty() and escort_joined and is_instance_valid(follow_actor)

func _as_cell(point: Vector2) -> Vector2i:
    return Vector2i(floori(point.x/32.0),floori(point.y/32.0))

func _begin_escort_if_required(team_id: String, marker_id: String,
        checkpoints: Array, walkable: Dictionary) -> void:
    if not ESCORT_DESTINATIONS.has(marker_id):
        return
    var previous: int = checkpoints.find(marker_id)-1
    if previous < 0 or not world.nodes.has(checkpoints[previous]):
        return
    var origin: Vector2 = world.nodes[checkpoints[previous]].position
    if not walkable.has(_as_cell(origin)):
        return
    var citizen = NPCVisual.new()
    citizen.setup({"id":"", "name":str(ESCORT_DESTINATIONS[marker_id]),"role":"quest"})
    citizen.position = origin
    citizen.scale = Vector2(0.83,0.83)
    citizen.z_index = 9
    add_child(citizen)
    follow_actor = citizen
    follow_destination = marker_id
    follow_team = team_id
    escort_joined = false
    escort_start_marker = str(checkpoints[previous])
    follow_repath = 0.0
    follow_waypoints.clear()
    follow_index = 0

func _follow_hero_on_floor(delta: float) -> void:
    if not is_instance_valid(follow_actor) or follow_destination.is_empty() or world.locked:
        return
    if bridge.evacuation.active_controlled_squad != follow_team or not bridge.evacuation.running or not escort_joined:
        return
    var distance: float = follow_actor.position.distance_to(world.hero.position)
    # Maintain a natural escort gap so the resident visibly accompanies the
    # walking player instead of snapping directly onto the hero.
    if distance <= 33.0:
        follow_actor.set_motion(delta,Vector2.ZERO)
        return
    follow_repath -= delta
    if follow_repath <= 0.0 or follow_index >= follow_waypoints.size():
        follow_repath = 0.28
        follow_waypoints = _floor_route(follow_actor.position,world.hero.position,world._walkable_tiles())
        follow_index = 1 if follow_waypoints.size()>1 else 0
    if follow_waypoints.size() < 2 or follow_index>=follow_waypoints.size():
        follow_actor.set_motion(delta,Vector2.ZERO)
        return
    var next_point: Vector2 = follow_waypoints[follow_index]
    var heading: Vector2 = next_point-follow_actor.position
    var movement: float = 112.0*delta
    follow_actor.position = follow_actor.position.move_toward(next_point,movement)
    follow_actor.set_motion(delta,heading.normalized())
    if follow_actor.position.distance_to(next_point)<2.0:
        follow_index += 1

func escort_arrived(marker_id: String) -> bool:
    if not ESCORT_DESTINATIONS.has(marker_id):
        return true
    if world == null or bridge == null or not bridge.registry_loaded or not is_instance_valid(follow_actor):
        return false
    if not bridge.evacuation.running or bridge.evacuation.current_objective_marker(follow_team) != marker_id:
        return false
    if marker_id != follow_destination or not world.nodes.has(marker_id) or not escort_joined:
        return false
    var destination: Node2D = world.nodes[marker_id]
    if not is_instance_valid(destination):
        return false
    return world.hero.position.distance_to(destination.position)<=48.0 and follow_actor.position.distance_to(destination.position)<=56.0

func _spawn_rescue_cast(squad_id: String, anchor: Vector2) -> void:
    # world.hero / companion already show this squad's real fighters. Only
    # render NONCOMBAT support here, avoiding duplicate LeiSuo / LanYin /
    # ShuoXian / TiFa silhouettes. Child Noe is not a combat party member.
    var roles: Array = []
    match squad_id:
        "EAST_GATE_LEISO":
            roles = [{"name":"救护队 · 担架协助者","role":"lore"}]
        "SOUTH_GATE_SHUOXIAN":
            roles = [{"name":"诺依（受保护的孩子）","role":"lore"}]
        "WEST_GATE_TIFA":
            roles = [{"name":"西门机械助手","role":"craft"}]
    var walkable: Dictionary = world._walkable_tiles()
    var offsets: Array[Vector2i] = [Vector2i(-2,1),Vector2i(2,1),Vector2i(-1,-2),Vector2i(1,-2)]
    for index in range(roles.size()):
        var selected: Vector2i = Vector2i(-1,-1)
        var home: Vector2i = Vector2i(floori(anchor.x/32.0),floori(anchor.y/32.0))
        for candidate in offsets:
            var tile: Vector2i = home+candidate+Vector2i(index*2,0)
            if walkable.has(tile) and not world._blocked(Vector2(tile*32)+Vector2(16,16)):
                selected = tile
                break
        if selected.x<0:
            continue
        var actor = NPCVisual.new()
        actor.setup(roles[index])
        actor.position = Vector2(selected*32)+Vector2(16,16)
        actor.scale = Vector2.ONE*(0.75 if squad_id=="SOUTH_GATE_SHUOXIAN" else 1.0)
        actor.z_index = 6
        add_child(actor)
        if str(roles[index].get("role",""))=="craft":
            actor.perform_life_action("work")
        elif index==0:
            actor.perform_life_action("observe")

func play_checkpoint(squad_id: String) -> void:
    # Only call after the canonical V3 rescue action was actually saved.
    if world == null or bridge == null or world.chapter != 47:
        return
    var state: Dictionary = bridge.evacuation.squad_statuses.get(squad_id,{})
    var completed: Array = state.get("completed_objectives",[])
    var markers: Array = bridge.evacuation.OBJECTIVE_MARKERS.get(squad_id,[])
    if completed.is_empty() or completed.size() >= markers.size():
        return
    var source_id: String = str(markers[completed.size()-1])
    var dest_id: String = str(markers[completed.size()])
    if not world.nodes.has(source_id) or not world.nodes.has(dest_id):
        return
    var floor: Dictionary = world._walkable_tiles()
    var route: Array[Vector2] = _floor_route(world.nodes[source_id].position,world.nodes[dest_id].position,floor)
    if route.size() < 2:
        return
    var courier = NPCVisual.new()
    courier.name = "SavedRescueEscort"
    courier.setup({"name":"已完成现场救援","role":"quest"})
    courier.position = route[0]
    courier.z_index = 9
    courier.scale = Vector2(0.82,0.82)
    add_child(courier)
    courier.perform_life_action("wave")
    var tween := create_tween()
    for index in range(1,route.size()):
        tween.tween_property(courier,"position",route[index],0.08)
    tween.finished.connect(func() -> void:
        if is_instance_valid(courier):
            courier.queue_free()
    )

func _draw_checkpoint(container: Node2D, caption: String, accent: Color, selected: bool) -> void:
    var marker := Polygon2D.new()
    marker.polygon = PackedVector2Array([
        Vector2(0,-18), Vector2(13,-6), Vector2(13,7),
        Vector2(0,14), Vector2(-13,7), Vector2(-13,-6)])
    marker.color = accent if selected else accent.darkened(0.5)
    marker.modulate.a = 0.87 if selected else 0.48
    container.add_child(marker)
    if selected:
        var glint := Polygon2D.new()
        glint.polygon = PackedVector2Array([
            Vector2(-5,-4),Vector2(0,-10),Vector2(5,-4),
            Vector2(0,2)])
        glint.color = Color(1.0,0.97,0.79)
        container.add_child(glint)
        var name_label := Label.new()
        name_label.text = caption
        name_label.position = Vector2(-70,-51)
        name_label.add_theme_font_size_override("font_size",12)
        name_label.add_theme_color_override("font_color",accent)
        container.add_child(name_label)

func _floor_route(from_world: Vector2,to_world: Vector2,walkable: Dictionary) -> Array[Vector2]:
    var from_cell: Vector2i = Vector2i(floori(from_world.x/world.TILE),floori(from_world.y/world.TILE))
    var to_cell: Vector2i = Vector2i(floori(to_world.x/world.TILE),floori(to_world.y/world.TILE))
    if not walkable.has(from_cell) or not walkable.has(to_cell):
        return []
    var queue: Array[Vector2i] = [from_cell]
    var came_from: Dictionary = {from_cell:from_cell}
    var cursor: int = 0
    while cursor < queue.size() and queue.size() <= world.WIDTH*world.HEIGHT:
        var cell: Vector2i = queue[cursor]
        cursor += 1
        if cell == to_cell:
            break
        for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var neighbor: Vector2i = cell+direction
            if walkable.has(neighbor) and not came_from.has(neighbor):
                came_from[neighbor] = cell
                queue.append(neighbor)
    if not came_from.has(to_cell):
        return []
    var cells: Array[Vector2i] = [to_cell]
    var current: Vector2i = to_cell
    while current != from_cell and cells.size() < world.WIDTH*world.HEIGHT:
        current = came_from[current]
        cells.push_front(current)
    var points: Array[Vector2] = []
    for index in range(cells.size()):
        if index > 0 and index < cells.size()-1:
            var previous: Vector2i = cells[index-1]
            var next: Vector2i = cells[index+1]
            if previous.x==next.x or previous.y==next.y:
                continue
        points.append(Vector2(cells[index]*world.TILE)+Vector2(16,16))
    return points
