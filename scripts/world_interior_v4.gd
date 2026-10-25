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
    for raw_cell in data.get("art_collision_cells",[]):
        var occupied: Vector2i = _point(raw_cell)
        if occupied.x>=2 and occupied.x<WIDTH-2 and occupied.y>=2 and occupied.y<HEIGHT-2:
            walls[occupied] = true
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
    var features: Array[Dictionary]=[]
    for prop in data.get("features",[]):
        if not prop is Dictionary:
            continue
        var cell: Vector2i=_point(prop.get("cell",[]))
        if cell.x>=2 and cell.x<WIDTH-2 and cell.y>=2 and cell.y<HEIGHT-2 and not walls.has(cell):
            features.append({"kind":str(prop.get("kind","barrel")),"cell":cell,"name":str(prop.get("name","室内陈设"))})
    return {"tiles":tiles,"blocked":walls,"features":features,
        "gates":[],"spawn":points["spawn"],"size":Vector2i(WIDTH,HEIGHT),
        "interior":kind,"interact_cells":points,"authored_source":"v4",
        "layout_id":map_id+"#"+building_id,
        "quest_points":quest_points,
        "art_profile":str(data.get("art_profile","")),
        "art_tileset":str(data.get("art_tileset","")),
        "visuals":data.get("visuals",[]),
        "light_sources":data.get("light_sources",[]),
        "solid_regions":data.get("solid_regions",[])}
