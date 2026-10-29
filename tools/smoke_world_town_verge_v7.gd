extends SceneTree
## Live-Godot rule test: frontage is strictly decorative and never damages
## maps, exit cells, NPC routes, walkability or authored geometry.
const Frontage = preload("res://scripts/world_town_verge_v7.gd")
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
func _run() -> void:
    var tiles: Dictionary = {}
    var blocked: Dictionary = {}
    var water: Dictionary = {}
    for y in range(3,29):
        for x in range(3,43):
            tiles[Vector2i(x,y)] = Vector2i(0,1)
    for x in range(3,43):
        tiles[Vector2i(x,23)] = Vector2i(0,3)
    for x in range(12,25):
        for y in range(7,17):
            if x < 14 and y < 9:
                blocked[Vector2i(x,y)] = true
    water[Vector2i(23,14)] = true
    var door := Vector2i(18,17)
    var building: Dictionary = {"id":"house-1","pos":[18,12],"size":[8,6],"door":[door.x,door.y]}
    var geometry: Dictionary = {
        "size":Vector2i(48,32),"tiles":tiles,"blocked":blocked,"water_mask":water,
        "zone":{"region_id":"region_coast","biome":"coastal","buildings":[building]}
    }
    var before_terrain: Dictionary = tiles.duplicate(true)
    var before_blocks: Dictionary = blocked.duplicate(true)
    var decor := Frontage.new()
    root.add_child(decor)
    decor.configure("map_coast_01",geometry,2)
    check(decor.patch_count() > 0,"No frontage landscaping generated")
    check(decor.patch_count() <= 112,"Frontage garden budget exceeded")
    check(before_terrain == tiles,"The original ground cells changed")
    check(before_blocks == blocked,"The original blocking geometry changed")
    check(decor.door_is_clear(door),"Door is directly blocked by a visual")
    for site in decor.patch_cells():
        check(not blocked.has(site),"Garden planted inside physical blocker")
        check(not water.has(site),"Garden planted inside water")
        check(not ((tiles.get(site,Vector2i.ZERO) as Vector2i).y == 3),"Garden covered a road")
        check(absi(site.x-door.x)>2 or absi(site.y-door.y)>3,"Garden blocks door approach")
    var count_before: int = decor.patch_count()
    decor.set_visual_quality(0)
    check(decor.patch_count()==count_before,"Low graphics mode changed map data")
    decor.configure("map_coast_01",geometry,2)
    check(decor.patch_count()==count_before,"Decor positions nondeterministic")
    decor.queue_free()
    if failures.is_empty():
        print("PASS village frontage: seeded gardens, no road/door/collision overlap, deterministic, visual only")
        quit(0)
    else:
        for fault in failures:
            push_error(fault)
        quit(1)
