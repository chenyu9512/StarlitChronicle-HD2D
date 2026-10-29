extends Node2D
## Original City-IV/V ground inlays. Unlike an interactive building these are
## deliberately FLAT civic mosaics, placed on existing connected walkable tiles.
## They never edit walls, exits, collisions, quest markers or save flags.
const TILE: int = 32
const MATERIALS: Dictionary = {
    "map_city_04": {
        "path":"res://assets/art/world/city_districts/lantern_grid_inlay.svg",
        "goal":[67,39],
        "completed_flag":"world.distributed_network"
    },
    "map_city_05": {
        "path":"res://assets/art/world/city_districts/west_rebuild_plan_inlay.svg",
        "goal":[59,36],
        "completed_flag":"story.ch055.done"
    }
}
var map_id: String = ""
var required_flag: String = ""
var mural: Sprite2D

func configure(map_key: String, geometry: Dictionary, reachable: Dictionary,
        protected_sites: Dictionary, story_flags: Dictionary) -> bool:
    map_id = map_key
    var spec: Dictionary = MATERIALS.get(map_key,{})
    if spec.is_empty():
        return false
    var art_path: String = str(spec.get("path",""))
    if not ResourceLoader.exists(art_path):
        push_warning("City ground mosaic missing: " + art_path)
        return false
    var resource: Resource = load(art_path)
    if not (resource is Texture2D):
        return false
    var extent: Vector2i = geometry.get("size",Vector2i(72,48))
    var blocked: Dictionary = geometry.get("blocked",{})
    var water: Dictionary = geometry.get("water_mask",{})
    var floor: Dictionary = geometry.get("tiles",{})
    var reserved: Dictionary = {}
    var spawn: Vector2i = geometry.get("spawn",Vector2i(10,23))
    reserved[spawn] = true
    for name in protected_sites:
        reserved[protected_sites[name]] = true
    for item in geometry.get("features",[]):
        if item is Dictionary:
            reserved[(item as Dictionary).get("cell",Vector2i(-1,-1))] = true
            if (item as Dictionary).has("door"):
                reserved[(item as Dictionary).get("door",Vector2i(-1,-1))] = true
    for gate in geometry.get("gates",[]):
        if gate is Dictionary:
            reserved[(gate as Dictionary).get("cell",Vector2i(-1,-1))] = true
    var wanted: Array = spec.get("goal",[60,36])
    var center: Vector2i = Vector2i(int(wanted[0]),int(wanted[1]))
    var target: Vector2i = Vector2i(-1,-1)
    for radius in range(0,31):
        if target.x>=0:
            break
        for dy in range(-radius,radius+1):
            if target.x>=0:
                break
            for dx in range(-radius,radius+1):
                if absi(dx)+absi(dy)!=radius:
                    continue
                var at: Vector2i = center+Vector2i(dx,dy)
                if _free_floor_patch(at,extent,blocked,water,floor,reachable,reserved):
                    target=at
                    break
    if target.x<0:
        # A crowded route should retain its accurate collision and quest
        # geometry rather than forcing an unapproved scenery position.
        return false
    required_flag = str(spec.get("completed_flag",""))
    mural = Sprite2D.new()
    mural.name = "AuthoredCivicFloorInlay"
    mural.texture = resource as Texture2D
    mural.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    mural.scale = Vector2(0.53,0.53)
    mural.position = Vector2(target*TILE)+Vector2(16,16)
    mural.z_index = -4
    mural.set_meta("city_ground_map",map_key)
    mural.set_meta("no_collision_no_interaction",true)
    add_child(mural)
    refresh(story_flags)
    return true

func _free_floor_patch(at: Vector2i, extent: Vector2i, blocked: Dictionary,
        water: Dictionary, floor: Dictionary, reachable: Dictionary,
        reserved: Dictionary) -> bool:
    # 256x128 *0.53 fits within five by three terrain tiles. Protect the
    # actual path, doorway and story markers, even if the image is walkable.
    for dy in range(-1,2):
        for dx in range(-2,3):
            var p: Vector2i=at+Vector2i(dx,dy)
            if p.x<3 or p.y<3 or p.x>=extent.x-3 or p.y>=extent.y-3:
                return false
            if blocked.has(p) or water.has(p) or reserved.has(p) or not floor.has(p):
                return false
            if not reachable.has(p):
                return false
    return true

func refresh(flags: Dictionary) -> void:
    if not is_instance_valid(mural):
        return
    var finished: bool=bool(flags.get(required_flag,false))
    if map_id=="map_city_04":
        mural.modulate = Color(1.0,0.96,0.84,0.90) if finished else Color(0.61,0.72,0.86,0.58)
    else:
        mural.modulate = Color(1.0,0.96,0.83,0.94) if finished else Color(0.78,0.78,0.73,0.64)
