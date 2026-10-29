extends SceneTree
## Commercial First-Act physical-path gate.
## Unlike marker-teleport story scripts, this verifies 32px in-game collision
## from the real player spawn to each main/side-quest marker and each map exit.
## It does NOT call chapter completion, win fights or change saved progress.
const World = preload("res://scripts/first_act_world.gd")
const Registry = preload("res://scripts/world_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
const REQUIRED: Array[String] = [
    "key_npc","clue","witness","crisis","resolve",
    "side_start","side_item","side_return"
]
var errors: Array[String] = []
var checked: int=0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        errors.append(message)

func _tile(point: Vector2) -> Vector2i:
    return Vector2i(floori(point.x/32.0),floori(point.y/32.0))

func _walkable(world) -> Dictionary:
    var spawn: Vector2i=world.terrain_layout.get("spawn",Vector2i(10,23))
    var visited: Dictionary={}
    if world.blocked.has(spawn):
        return visited
    visited[spawn]=true
    var todo: Array[Vector2i]=[spawn]
    var cursor: int=0
    while cursor<todo.size():
        var here: Vector2i=todo[cursor]
        cursor+=1
        for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var next: Vector2i=here+step
            if next.x<2 or next.y<2 or next.x>=world.WIDTH-2 or next.y>=world.HEIGHT-2:
                continue
            if visited.has(next) or world.blocked.has(next):
                continue
            visited[next]=true
            todo.append(next)
    return visited

func _can_interact_from_path(world,marker: Node2D,reachable: Dictionary) -> bool:
    # Formal interaction radii differ across marker types (28-65px).
    # Require a nearby reachable standing tile without putting a foot inside
    # a solid roof. One-tile adjacency is more conservative than all radii.
    var loc: Vector2i=_tile(marker.position)
    for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,
            Vector2i.UP,Vector2i.DOWN]:
        if reachable.has(loc+offset):
            return true
    return false

func _run() -> void:
    for chapter in range(1,7):
        var save=State.new()
        save.new_game()
        save.chapter=chapter
        var router=Registry.new()
        router.bind(save)
        check(router.errors.is_empty(),"Chapter %d catalog faults" % chapter)
        var scene=World.new()
        root.add_child(scene)
        scene.map_profile=router.profile()
        scene.build(chapter,2 if chapter<4 else 3)
        var map_id: String=str(scene.map_profile.get("id",""))
        var walkable: Dictionary=_walkable(scene)
        check(not walkable.is_empty(),
            "Act I chapter %d (%s) spawns inside a solid tile" % [chapter,map_id])
        for name in REQUIRED:
            var key: String=name
            check(scene.nodes.has(key),
                "Chapter %d missing physical marker %s" % [chapter,key])
            if not scene.nodes.has(key):
                continue
            var node: Node2D=scene.nodes[key]
            check(is_instance_valid(node) and _can_interact_from_path(scene,node,walkable),
                "Chapter %d (%s) has no player walking path to %s" % [chapter,map_id,key])
            checked+=1
        for neighbor in router.current_info().get("neighbors",[]):
            var gate: String="exit:"+str(neighbor)
            check(scene.nodes.has(gate),
                "Chapter %d missing real exit %s" % [chapter,gate])
            if scene.nodes.has(gate):
                check(_can_interact_from_path(scene,scene.nodes[gate],walkable),
                    "Chapter %d exit %s is unreachable" % [chapter,gate])
                checked+=1
        # Act-I Chapter 3 is not playable if its actual four tidal-valve
        # world objects are inside cave collision or disconnected from spawn.
        # Inspect the same physical game nodes and BFS as the player's route;
        # a virtual puzzle solve or nearby marker relocation cannot pass.
        if chapter == 3:
            for mechanism in scene.dungeon_puzzles.devices(map_id):
                var device_name: String = "puzzle:" + str(mechanism.get("id",""))
                var raw_cell: Array = mechanism.get("cell",[])
                check(raw_cell.size() == 2, "Cave V7 mechanism lacks its authored grid coordinate: " + device_name)
                if raw_cell.size() != 2:
                    continue
                var actual_cell := Vector2i(int(raw_cell[0]),int(raw_cell[1]))
                check(not scene.blocked.has(actual_cell) and walkable.has(actual_cell),
                    "Cave V7 valve or seal cannot be reached on foot: " + device_name + " at " + str(actual_cell))
                check(scene.nodes.has(device_name),
                    "Cave V7 interactive world object was not built: " + device_name)
                if scene.nodes.has(device_name):
                    var device_marker: Node2D = scene.nodes[device_name]
                    check(_tile(device_marker.position) == actual_cell,
                        "Cave V7 marker was moved away from authored walkable position: " + device_name)
                    checked += 1
        # Main/sidequest markers may never be painted into solid colliders.
        # No 'unrestricted fast travel' is accepted as a workaround.
        var before: Dictionary=save._pack().duplicate(true)
        check(router.shortest_route(map_id)==[map_id],
            "Passive path preview for current chapter is invalid")
        check(save._pack()==before,
            "Computing local travel plan changed the story save")
        scene.queue_free()
        await process_frame
    check(checked>=48,"Fewer than 48 actual Act-I main/side nodes were checked")
    if errors.is_empty():
        print("PASS B act01: 6 authored chapter maps, real collision BFS, 8 quest markers and all exits per chapter")
        quit(0)
        return
    for error in errors:
        push_error(error)
    quit(1)
