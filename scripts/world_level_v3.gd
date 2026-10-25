extends RefCounted
## Version 3 authored gameplay layers. Each level has a separate editable record.
## Draw order: geology -> waterways -> routes -> clearings -> editor overrides.
const SOURCE: String = "res://data/levels/world_levels_v3.json"
const WIDTH: int = 72
const HEIGHT: int = 48
var levels: Dictionary = {}
var problems: Array[String] = []

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not parsed is Dictionary or str(parsed.get("schema","")) != "starlit.world_level_collection.v3":
        problems.append("V3 map dataset is absent or invalid")
        return
    levels = parsed.get("levels",{})
    if levels.size() != 40:
        problems.append("Expected 40 individually editable production map definitions")
    for id in levels.keys():
        var entry: Dictionary = levels[id]
        var dimensions: Array = entry.get("size",[])
        if str(entry.get("map_id","")) != str(id) or dimensions.size()!=2 or int(dimensions[0])!=WIDTH or int(dimensions[1])!=HEIGHT:
            problems.append("Broken V3 level identity or dimensions: "+str(id))
        if not entry.get("roads",[]) is Array or entry.get("roads",[]).is_empty():
            problems.append("No authored primary roads: "+str(id))

func level(id: String) -> Dictionary:
    return levels.get(id,{})

func _valid(p: Vector2i) -> bool:
    return p.x >= 2 and p.y >= 2 and p.x < WIDTH-2 and p.y < HEIGHT-2

func _point(value: Variant) -> Vector2i:
    if value is Array and value.size() >= 2:
        return Vector2i(int(value[0]),int(value[1]))
    return Vector2i(-10,-10)

func _stamp(ground: Dictionary,walls: Dictionary,center: Vector2i,width: int,row: int,solid: bool) -> void:
    for yy in range(-width,width+1):
        for xx in range(-width,width+1):
            var p: Vector2i = center+Vector2i(xx,yy)
            if _valid(p) and abs(xx)+abs(yy) <= maxi(1,width*2):
                ground[p]=Vector2i(posmod(p.x+p.y,8),row)
                if solid:
                    walls[p]=true
                else:
                    walls.erase(p)

func _draw_polyline(ground: Dictionary,walls: Dictionary,points: Array,thickness: int,row: int,solid: bool) -> void:
    if points.size()<2:
        return
    for i in range(points.size()-1):
        var a: Vector2i = _point(points[i])
        var b: Vector2i = _point(points[i+1])
        var span: int = maxi(absi(a.x-b.x),absi(a.y-b.y))
        if span <= 0:
            _stamp(ground,walls,a,thickness,row,solid)
            continue
        for j in range(span+1):
            var t: float = float(j)/float(span)
            var p: Vector2i = Vector2i(roundi(lerpf(float(a.x),float(b.x),t)),roundi(lerpf(float(a.y),float(b.y),t)))
            _stamp(ground,walls,p,thickness,row,solid)

func apply(level_info: Dictionary,ground: Dictionary,walls: Dictionary,features: Array[Dictionary]) -> Array[Vector2i]:
    var roadway: Array[Vector2i] = []
    if level_info.is_empty():
        return roadway
    for kind in ["obstacles","waterways"]:
        for record in level_info.get(kind,[]):
            var thickness: int = clampi(int(record.get("width",1)),1,6)
            _draw_polyline(ground,walls,record.get("points",[]),thickness,clampi(int(record.get("tile_row",6)),0,7),true)
    for road in level_info.get("roads",[]):
        var points: Array = road.get("points",[])
        var thickness: int = clampi(int(road.get("width",1)),0,5)
        _draw_polyline(ground,walls,points,thickness,3,false)
        for item in points:
            var where: Vector2i = _point(item)
            if _valid(where):
                roadway.append(where)
    for clearing in level_info.get("clearings",[]):
        var center: Vector2i = _point(clearing.get("center",[]))
        if _valid(center):
            _stamp(ground,walls,center,clampi(int(clearing.get("radius",2)),1,6),1,false)
    for override in level_info.get("paint_overrides",[]):
        var cell: Vector2i = _point(override.get("cell",[]))
        if not _valid(cell):
            continue
        _stamp(ground,walls,cell,0,clampi(int(override.get("row",1)),0,7),bool(override.get("blocked",false)))
    for override in level_info.get("collision_overrides",[]):
        var cell: Vector2i = _point(override.get("cell",[]))
        if not _valid(cell):
            continue
        if bool(override.get("blocked",true)):
            walls[cell]=true
        else:
            walls.erase(cell)
    for point in level_info.get("landmarks",[]):
        var cell: Vector2i = _point(point.get("cell",[]))
        if _valid(cell) and not walls.has(cell):
            features.append({"kind":str(point.get("kind","rock")),"cell":cell,"name":str(point.get("id","landmark"))})
    return roadway

func nearest_road(point: Vector2i,roadway: Array[Vector2i]) -> Vector2i:
    if roadway.is_empty():
        return Vector2i(10,23)
    var closest: Vector2i = roadway[0]
    var best: int = 999999
    for candidate in roadway:
        var dist: int = absi(candidate.x-point.x)+absi(candidate.y-point.y)
        if dist < best:
            closest=candidate
            best=dist
    return closest
