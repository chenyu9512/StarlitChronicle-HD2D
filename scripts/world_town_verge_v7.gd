extends Node2D
## Noninteractive frontage gardens for the true V3 town footprints.
## Uses the final map geometry after buildings and roads have been sealed.
## Drawn below people/facades; no collision, navigation, save or reward writes.
const TILE: int = 32
const MAX_PATCHES: int = 112

const REGION_LEAVES: Dictionary = {
    "region_coast": Color("658d62"),
    "region_oaths": Color("879969"),
    "region_forge": Color("8e815c"),
    "region_isles": Color("5c9d7b"),
    "region_mirror": Color("8e9d97"),
    "region_oldland": Color("758b60"),
    "region_sanctum": Color("a1ae86"),
    "region_city": Color("858d73")
}

var _patches: Array[Dictionary] = []
var _door_cells: Dictionary = {}
var _quality: int = 2

static func _hash(a: int, b: int, seed: int) -> int:
    var h: int = (a * 73856093) ^ (b * 19349663) ^ (seed * 83492791)
    return posmod(h, 2147483647)

static func _box(spec: Dictionary) -> Rect2i:
    var point: Array = spec.get("pos", [])
    var dims: Array = spec.get("size", [])
    if point.size() != 2 or dims.size() != 2:
        return Rect2i()
    var center := Vector2i(int(point[0]), int(point[1]))
    var extent := Vector2i(maxi(1, int(dims[0])), maxi(1, int(dims[1])))
    return Rect2i(center - Vector2i(extent.x / 2, extent.y / 2),
        Vector2i(extent.x, extent.y + 1))

static func _near_door(cell: Vector2i, doors: Dictionary) -> bool:
    for raw in doors.keys():
        var door: Vector2i = raw
        if absi(cell.x - door.x) <= 2 and absi(cell.y - door.y) <= 3:
            return true
    return false

func configure(map_id: String, layout: Dictionary, quality: int = 2) -> void:
    _quality = clampi(quality, 0, 2)
    _patches.clear()
    _door_cells.clear()
    var buildings: Array = (layout.get("zone", {}) as Dictionary).get("buildings", [])
    var floor_tiles: Dictionary = layout.get("tiles", {})
    var blocked: Dictionary = layout.get("blocked", {})
    var water: Dictionary = layout.get("water_mask", {})
    var extent: Vector2i = layout.get("size", Vector2i(72,48))
    if buildings.is_empty() or floor_tiles.is_empty():
        queue_redraw()
        return
    var roofs: Dictionary = {}
    for item in buildings:
        if not item is Dictionary:
            continue
        var box: Rect2i = _box(item)
        if box.size.x <= 0:
            continue
        for y in range(box.position.y, box.end.y):
            for x in range(box.position.x, box.end.x):
                roofs[Vector2i(x,y)] = true
        var pair: Array = item.get("door", [])
        if pair.size() == 2:
            _door_cells[Vector2i(int(pair[0]), int(pair[1]))] = true
    # Map story, NPC and exit markers are not reliably marked as solid.
    # Reserve their approach radius as strictly as the physical front doors.
    var reserved: Dictionary = {}
    var spawn: Vector2i = layout.get("spawn",Vector2i(-99,-99))
    if spawn.x >= 0:
        for dy in range(-3,4):
            for dx in range(-3,4):
                reserved[spawn+Vector2i(dx,dy)] = true
    for group in ["features","gates"]:
        for point in layout.get(group,[]):
            if not point is Dictionary:
                continue
            var target: Variant = point.get("cell",null)
            if target is Vector2i:
                for dy in range(-2,3):
                    for dx in range(-2,3):
                        reserved[target+Vector2i(dx,dy)] = true
    for value in (layout.get("interact_cells",{}) as Dictionary).values():
        if value is Vector2i:
            for dy in range(-2,3):
                for dx in range(-2,3):
                    reserved[value+Vector2i(dx,dy)] = true
    var occupied: Dictionary = {}
    var seed: int = absi(map_id.hash())
    var region: String = str((layout.get("zone", {}) as Dictionary).get("region_id", "region_coast"))
    if region not in REGION_LEAVES:
        var biome: String = str((layout.get("zone", {}) as Dictionary).get("biome",""))
        region = "region_coast" if biome == "coastal" else "region_oldland"
    var leaf: Color = REGION_LEAVES.get(region, Color("658d62"))
    for raw in buildings:
        if not raw is Dictionary or _patches.size() >= MAX_PATCHES:
            continue
        var footprint: Rect2i = _box(raw)
        if footprint.size.x <= 0:
            continue
        # Frontage gardens belong beyond the single-tile legal pavement apron.
        # They must not form an invisible ring of foliage in walking routes.
        for y in range(footprint.position.y - 3, footprint.end.y + 3):
            for x in range(footprint.position.x - 3, footprint.end.x + 3):
                var cell := Vector2i(x,y)
                if cell.x < 3 or cell.y < 3 or cell.x >= extent.x - 3 or cell.y >= extent.y - 3:
                    continue
                if roofs.has(cell) or blocked.has(cell) or water.has(cell) or occupied.has(cell) or reserved.has(cell):
                    continue
                if _near_door(cell, _door_cells):
                    continue
                if not floor_tiles.has(cell):
                    continue
                var ground: Vector2i = floor_tiles[cell]
                # Only real meadow/garden terrain, never plaza cobbles, main
                # access lanes or stone steps. No scenery on a door approach.
                if ground.y not in [0,1,7]:
                    continue
                var dx: int = maxi(maxi(footprint.position.x-x,x-footprint.end.x+1),0)
                var dy: int = maxi(maxi(footprint.position.y-y,y-footprint.end.y+1),0)
                if maxi(dx,dy) < 2 or maxi(dx,dy) > 3:
                    continue
                var roll: int = _hash(x,y,seed) % 100
                if roll >= 32:
                    continue
                var tint: Color = leaf.lightened(float(_hash(x+7,y,seed)%13)/100.0)
                _patches.append({"cell":cell,"leaf":tint,"flower":roll < 9,
                    "seed":_hash(x,y,seed+11)})
                occupied[cell] = true
                if _patches.size() >= MAX_PATCHES:
                    break
            if _patches.size() >= MAX_PATCHES:
                break
    queue_redraw()

func patch_count() -> int:
    return _patches.size()

func patch_cells() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for item in _patches:
        result.append(item["cell"])
    return result

func door_is_clear(cell: Vector2i) -> bool:
    # True means no actual drawn garden occupies the interaction zone;
    # being listed as a protected door itself is not an obstruction.
    for item in _patches:
        var plant: Vector2i = item["cell"]
        if absi(plant.x-cell.x) <= 2 and absi(plant.y-cell.y) <= 3:
            return false
    return true

func set_visual_quality(value: int) -> void:
    _quality = clampi(value,0,2)
    queue_redraw()

func _draw() -> void:
    if _quality == 0:
        return
    for item in _patches:
        var cell: Vector2i = item["cell"]
        var h: int = int(item["seed"])
        var origin: Vector2 = Vector2(cell * TILE) + Vector2(16,18)
        var leaf: Color = item["leaf"]
        # A short cluster of differently sized leaves, not a repeated stamp.
        # It reads as low garden vegetation from the normal player camera.
        var clumps: int = 3 if _quality >= 2 else 2
        for n in range(clumps):
            var px: float = float(posmod(h + n * 13, 19) - 9)
            var py: float = float(posmod(h / 13 + n * 7, 13) - 6)
            var stem: Vector2 = origin + Vector2(px, py)
            draw_line(stem + Vector2(0,4),stem - Vector2(1,5),
                leaf.darkened(0.30),1.4)
            draw_colored_polygon(PackedVector2Array([
                stem + Vector2(-4,0),stem + Vector2(-1,-6),
                stem + Vector2(2,-3),stem + Vector2(1,2)]),leaf)
            draw_colored_polygon(PackedVector2Array([
                stem + Vector2(0,-2),stem + Vector2(4,-6),
                stem + Vector2(5,-1),stem + Vector2(1,3)]),leaf.lightened(0.16))
        if bool(item["flower"]):
            var bloom: Vector2 = origin + Vector2(posmod(h,11)-5,-3)
            draw_circle(bloom,2.2,Color("f1d59c"))
            draw_circle(bloom + Vector2(3,-2),1.6,Color("dba3a4"))
