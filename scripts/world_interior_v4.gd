extends RefCounted
## Distinct authored indoor terrain with the existing world geometry contract.
## Unauthored buildings continue using the previous interior() fallback.
const WIDTH: int = 72
const HEIGHT: int = 48
const ROOT: String = "res://data/levels/v4/interiors/"

func _point(raw: Variant) -> Vector2i:
    if raw is Array and raw.size() == 2:
        return Vector2i(int(raw[0]),int(raw[1]))
    return Vector2i(-1,-1)

func _fill(ground: Dictionary,walls: Dictionary,record: Variant,base_row: int,solid: bool) -> void:
    if not record is Dictionary:
        return
    var r: Array = record.get("rect",[])
    if r.size()!=4:
        return
    var x0: int = clampi(int(r[0]),2,WIDTH-3)
    var y0: int = clampi(int(r[1]),2,HEIGHT-3)
    var x1: int = clampi(int(r[2]),2,WIDTH-3)
    var y1: int = clampi(int(r[3]),2,HEIGHT-3)
    var row: int = clampi(int(record.get("tile_row",base_row)),0,7)
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):
            var p: Vector2i=Vector2i(x,y)
            ground[p]=Vector2i(posmod(x+y,8),row)
            if solid:
                walls[p]=true
            else:
                walls.erase(p)

## Production B-line fallthrough for authored regional rooms that have
## physical V4 geometry but have not yet received artist-staged furniture.
## Uses existing A-line semantic furniture roles; no asset registry duplication.
## Never changes floor, walls, door, spawn, IDs, or investigation coordinates.
const REGIONAL_ROLES: Dictionary = {
    "inn":["counter","travelers_shelf","provisions_shelves","lantern","tideway_chart","harbor_guest_bed","guild_noticeboard","barrels"],
    "shop":["merchant_counter","provisions_shelves","barrels","lantern","bookshelf","barrels","guild_noticeboard","provisions_shelves"],
    "guild":["counter","bookshelf","provisions_shelves","lantern","tideway_chart","barrels","guild_noticeboard","bookshelf"],
    "smith":["smith_toolwall","provisions_shelves","smith_forge","lantern","smith_anvil","barrels","smith_toolwall","bookshelf"],
    "house":["table","home_hutch","barrels","lantern","window","harbor_guest_bed","tideway_chart","saltgrass_planter"],
    "shrine":["shrine_starseal","bookshelf","shrine_altar","lantern","shrine_incense","barrels","guild_noticeboard","saltgrass_planter"]
}
const REGION_TINTS: Dictionary = {
    "oaths":["d8d2bd","a8a6a0"],"forge":["e4c9b5","aa8578"],
    "isles":["d7e0db","91adb2"],"mirror":["d1dbd6","9ba7b3"],
    "oldland":["ddcdb8","a49c8d"],"sanctum":["ded9e6","aaa3c2"],
    "city":["dad0bf","a7a0a2"]
}

func _assemble_regional_visuals(data: Dictionary) -> void:
    var kind: String = str(data.get("building_id",""))
    if not REGIONAL_ROLES.has(kind):
        return
    var roles: Array = REGIONAL_ROLES[kind]
    var furniture: Array = data.get("features",[])
    var visuals: Array = []
    for i in range(mini(roles.size(),furniture.size())):
        var record: Dictionary = furniture[i]
        var position: Array = record.get("cell",[])
        if position.size()!=2:
            continue
        var asset: String = str(roles[i])
        visuals.append({
            "id":"regional_"+kind+"_"+str(i),"asset":asset,
            "cell":position.duplicate(),
            "layer":"wall" if asset in ["window","guild_noticeboard","tideway_chart","smith_toolwall","bookshelf"] else "furniture",
            "footprint":[106,82] if asset in ["shrine_altar","smith_forge","harbor_guest_bed"] else [66,74],
            "offset":[0,0]
        })
    visuals.append({"id":"regional_entry_rug","asset":"rug",
        "cell":[35,29],"layer":"floor","footprint":[94,62],"offset":[0,0]})
    visuals.append({"id":"regional_wall_window","asset":"window",
        "cell":[36,12],"layer":"wall","footprint":[66,66],"offset":[0,0]})
    var inspection_records: Array = data.get("investigations",[])
    for i in range(mini(2,inspection_records.size())):
        var entry: Dictionary = inspection_records[i]
        visuals.append({"id":"regional_inquiry_"+str(i),
            "asset":"tideway_chart" if i==0 else "guild_noticeboard",
            "cell":entry.get("cell",[]),"layer":"wall",
            "footprint":[54,60],"offset":[0,0]})
    if visuals.is_empty():
        return
    data["visuals"] = visuals
    data["art_profile"] = "regional_functional_v1"
    data["light_sources"] = [
        {"id":"entry_lamp","cell":[35,30],"scale":1.25,"energy":0.74},
        {"id":"service_lamp","cell":[25,20],"scale":1.15,"energy":0.68},
        {"id":"room_corner_lamp","cell":[46,21],"scale":1.10,"energy":0.59}
    ]
    var parts: PackedStringArray = str(data.get("map_id","")).split("_")
    var region: String = str(parts[1]) if parts.size()>2 else ""
    var colors: Array = REGION_TINTS.get(region,["d8d1c2","a5a2a1"])
    data["room_day_tint"] = str(colors[0])
    data["room_night_tint"] = str(colors[1])

func load_level(map_id: String,building_id: String,kind: String) -> Dictionary:
    if map_id.is_empty() or building_id.is_empty():
        return {}
    var path: String = ROOT+"%s__%s.json" % [map_id,building_id]
    if not FileAccess.file_exists(path):
        return {}
    var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not record is Dictionary:
        return {}
    var data: Dictionary = record
    if str(data.get("schema",""))!="starlit.interior.v4" or str(data.get("map_id",""))!=map_id or str(data.get("building_id",""))!=building_id:
        return {}
    if not str(data.get("region_design","")).is_empty() and str(data.get("art_profile","")).is_empty():
        _assemble_regional_visuals(data)
    var tiles: Dictionary = {}
    var walls: Dictionary = {}
    for y in range(HEIGHT):
        for x in range(WIDTH):
            var p: Vector2i=Vector2i(x,y)
            tiles[p]=Vector2i(posmod(x+y,8),6)
            walls[p]=true
    for region in data.get("floor_regions",[]):
        _fill(tiles,walls,region,5,false)
    for partition in data.get("solid_regions",[]):
        _fill(tiles,walls,partition,6,true)
    for doorway in data.get("door_regions",[]):
        _fill(tiles,walls,doorway,3,false)
    # Authored furniture collision is merged before marker validation; other
    # interiors have no art_collision_cells and retain their exact behavior.
    var furniture_footprints: Dictionary = {}
    for raw_cell in data.get("art_collision_cells",[]):
        var occupied: Vector2i = _point(raw_cell)
        if occupied.x>=2 and occupied.x<WIDTH-2 and occupied.y>=2 and occupied.y<HEIGHT-2:
            walls[occupied] = true
            furniture_footprints[occupied] = true
    var authored_points: Dictionary=data.get("points",{})
    var points: Dictionary={}
    for key in ["spawn","exit","service","storage"]:
        var cell: Vector2i=_point(authored_points.get(key,[]))
        if cell.x<2 or cell.x>=WIDTH-2 or cell.y<2 or cell.y>=HEIGHT-2 or walls.has(cell):
            return {}
        points[key]=cell
    var quest_points: Array[Vector2i] = []
    if building_id.begins_with("quest__"):
        if str(data.get("script_quest_id",""))!=building_id.trim_prefix("quest__"):
            return {}
        for raw_point in data.get("quest_points",[]):
            var quest_cell: Vector2i = _point(raw_point)
            if quest_cell.x<2 or quest_cell.x>=WIDTH-2 or quest_cell.y<2 or quest_cell.y>=HEIGHT-2 or walls.has(quest_cell):
                return {}
            quest_points.append(quest_cell)
        if quest_points.size()!=3:
            return {}
    var story_stage_points: Array[Vector2i] = []
    var branch_stage_points: Array[Vector2i] = []
    if building_id.begins_with("quest__"):
        for raw_stage in data.get("story_stage_points",[]):
            var place: Vector2i = _point(raw_stage)
            if place.x<2 or place.x>=WIDTH-2 or place.y<2 or place.y>=HEIGHT-2 or walls.has(place):
                return {}
            story_stage_points.append(place)
        for raw_branch in data.get("branch_stage_points",[]):
            var place: Vector2i = _point(raw_branch)
            if place.x<2 or place.x>=WIDTH-2 or place.y<2 or place.y>=HEIGHT-2 or walls.has(place):
                return {}
            branch_stage_points.append(place)
        if not story_stage_points.is_empty() and story_stage_points.size()!=5:
            return {}
        if not branch_stage_points.is_empty() and branch_stage_points.size()!=3:
            return {}
    # Chapter 2 shelter and Chapter 4 tavern own physically reachable
    # main-story stations. No other V4 room may silently acquire story points.
    # This preserves existing house/service and standalone quest-room IDs.
    var main_story_points: Dictionary = {}
    var raw_story_points: Variant = data.get("act01_main_story_points",{})
    if raw_story_points is Dictionary and not (raw_story_points as Dictionary).is_empty():
        if map_id != "map_coast_02" or building_id not in ["shelter","tavern"]:
            return {}
        var occupied_story_cells: Dictionary = {}
        for objective_id in ["key_npc","clue","witness","crisis","resolve"]:
            var story_cell: Vector2i = _point(raw_story_points.get(objective_id,[]))
            if story_cell.x < 2 or story_cell.x >= WIDTH-2 or story_cell.y < 2 or story_cell.y >= HEIGHT-2 or walls.has(story_cell) or occupied_story_cells.has(story_cell):
                return {}
            occupied_story_cells[story_cell] = true
            main_story_points[objective_id] = story_cell
        var connected: Dictionary = {}
        var spawn_cell: Vector2i = points["spawn"]
        connected[spawn_cell] = true
        var frontier: Array[Vector2i] = [spawn_cell]
        var index: int = 0
        while index < frontier.size():
            var walk: Vector2i = frontier[index]
            index += 1
            for direction in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
                var neighbor: Vector2i = walk + direction
                if neighbor.x < 2 or neighbor.y < 2 or neighbor.x >= WIDTH-2 or neighbor.y >= HEIGHT-2 or walls.has(neighbor) or connected.has(neighbor):
                    continue
                connected[neighbor] = true
                frontier.append(neighbor)
        for story_cell in main_story_points.values():
            if not connected.has(story_cell):
                return {}
    var features: Array[Dictionary]=[]
    for prop in data.get("features",[]):
        if not prop is Dictionary:
            continue
        var cell: Vector2i=_point(prop.get("cell",[]))
        # A solid furniture footpoint still needs its real visible sprite.
        # Structural wall cells remain prohibited, while an art_collision
        # footprint can be drawn AND physically block the same game tile.
        if cell.x>=2 and cell.x<WIDTH-2 and cell.y>=2 and cell.y<HEIGHT-2 and (not walls.has(cell) or furniture_footprints.has(cell)):
            features.append({"kind":str(prop.get("kind","barrel")),"cell":cell,"name":str(prop.get("name","室内陈设"))})
    var inspections: Array[Dictionary] = []
    var used_inspections: Dictionary = {}
    for authored in data.get("investigations",[]):
        if not (authored is Dictionary):
            continue
        var id: String = str(authored.get("id",""))
        var cell: Vector2i = _point(authored.get("cell",[]))
        if id.is_empty() or used_inspections.has(id) or cell.x<2 or cell.y<2 or cell.x>=WIDTH-2 or cell.y>=HEIGHT-2 or walls.has(cell):
            push_warning("Interior inspection has invalid identity or blocked cell: "+map_id+"/"+building_id+"/"+id)
            continue
        used_inspections[id]=true
        var item: Dictionary = authored.duplicate(true)
        item["cell"]=cell
        inspections.append(item)
    var required_story_evidence: Array = data.get("act01_main_story_evidence",[])
    if not main_story_points.is_empty():
        if required_story_evidence.size()!=2:
            return {}
        var evidence_seen: Dictionary = {}
        for evidence_id in required_story_evidence:
            var entry_id: String = str(evidence_id)
            if evidence_seen.has(entry_id) or not used_inspections.has(entry_id):
                return {}
            evidence_seen[entry_id] = true
        # The story cannot demand that the player examine evidence lying in
        # an isolated room behind walls. Validate the exact same 4-neighbor
        # component used for the five main-story stations.
        var visited: Dictionary = {points["spawn"]:true}
        var frontier: Array[Vector2i] = [points["spawn"]]
        var head: int = 0
        while head < frontier.size():
            var here: Vector2i = frontier[head]
            head += 1
            for direction in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
                var next: Vector2i = here + direction
                if next.x < 2 or next.y < 2 or next.x >= WIDTH-2 or next.y >= HEIGHT-2 or walls.has(next) or visited.has(next):
                    continue
                visited[next] = true
                frontier.append(next)
        for item in inspections:
            if str(item.get("id","")) in evidence_seen and not visited.has(item.get("cell",Vector2i(-1,-1))):
                return {}
    # B-line physical acceptance shared by all authored V4 interiors.
    # Validate every interactive station against the SAME final walls that
    # the player collides with, including furniture art_collision_cells.
    # This is real four-direction walking, not a teleport or cheat path.
    var accessible: Dictionary = {}
    var queue: Array[Vector2i] = [points["spawn"]]
    accessible[points["spawn"]] = true
    var walk_cursor: int = 0
    while walk_cursor < queue.size():
        var at: Vector2i = queue[walk_cursor]
        walk_cursor += 1
        for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var next: Vector2i = at + direction
            if next.x<2 or next.y<2 or next.x>=WIDTH-2 or next.y>=HEIGHT-2:
                continue
            if walls.has(next) or accessible.has(next):
                continue
            accessible[next] = true
            queue.append(next)
    var critical: Array[Vector2i] = [
        points["exit"],points["service"],points["storage"]]
    critical.append_array(quest_points)
    critical.append_array(story_stage_points)
    critical.append_array(branch_stage_points)
    for value in main_story_points.values():
        critical.append(value)
    for inspection in inspections:
        critical.append(inspection.get("cell",Vector2i(-1,-1)))
    for destination in critical:
        if not accessible.has(destination):
            push_error("V4 interior has no physical walking path: "+map_id+
                "#"+building_id+" -> "+str(destination))
            return {}
    # Visual furniture cannot rewrite walls here; the exported contract
    # is now guaranteed to have connected exits and interactive stations.
    return {"tiles":tiles,"blocked":walls,"features":features,
        "gates":[],"spawn":points["spawn"],"size":Vector2i(WIDTH,HEIGHT),
        "interior":kind,"interact_cells":points,"authored_source":"v4",
        "layout_id":map_id+"#"+building_id,
        "investigations":inspections,
        "act01_main_story_points":main_story_points,
        "act01_main_story_evidence":required_story_evidence.duplicate(),
        "interior_owner_id":str(data.get("interior_owner_id","")),
        "interior_interactions_runtime":"pending_D_binding",
        "quest_points":quest_points,
        "story_stage_points":story_stage_points,
        "branch_stage_points":branch_stage_points,
        "art_profile":str(data.get("art_profile","")),
        "art_tileset":str(data.get("art_tileset","")),
        "visuals":data.get("visuals",[]),
        "light_sources":data.get("light_sources",[]),
        "solid_regions":data.get("solid_regions",[])}
