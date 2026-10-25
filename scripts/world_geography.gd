extends RefCounted
const WorldLevelV3 = preload("res://scripts/world_level_v3.gd")
## 72x48 real-world sector architecture, shared by collision, renderer, minimap and tests.
## Authored spatial zone configuration is in world_atlas_v2.json; geometry is deterministic.
const WIDTH: int = 72
const HEIGHT: int = 48
const TILE: int = 32
const ATLAS_PATH: String = "res://data/levels/world_atlas_v2.json"
const START: Vector2i = Vector2i(10,23)
const ICONS: Array[String] = ["palm_tree","rock","barrel","sea_crystal","star_lantern","flowerpot","beacon","sign"]
var zones: Dictionary = {}
var regions: Dictionary = {}
var faults: Array[String] = []
var authored = WorldLevelV3.new()

func _init() -> void:
    var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_PATH))
    if not document is Dictionary:
        faults.append("World spatial atlas not found")
        return
    for region in document.get("regions",[]):
        if region is Dictionary:
            regions[str(region.get("id",""))] = region
    for entry in document.get("zones",[]):
        if entry is Dictionary:
            zones[str(entry.get("id",""))] = entry
    if zones.size() != 42 or regions.size() != 8:
        faults.append("World atlas must define 42 sectors and 8 regions")
    for reason in authored.problems:
        faults.append(str(reason))

func zone(id: String) -> Dictionary:
    return zones.get(id,{})

func _hash(x: int,y: int,seed: int) -> int:
    var value: int = abs((x*73856093) ^ (y*19349663) ^ (seed*83492791))
    return value % 10000

func old_to_new(pos: Vector2i) -> Vector2i:
    return Vector2i(clampi(roundi(float(pos.x)*float(WIDTH)/44.0),2,WIDTH-3),clampi(roundi(float(pos.y)*float(HEIGHT)/28.0),2,HEIGHT-3))

func _paint(terrain: Dictionary, walls: Dictionary, cell: Vector2i, floor_atlas: Vector2i, blocked: bool) -> void:
    if cell.x < 0 or cell.x >= WIDTH or cell.y < 0 or cell.y >= HEIGHT:
        return
    terrain[cell] = floor_atlas
    if blocked:
        walls[cell] = true
    else:
        walls.erase(cell)

func _carve(terrain: Dictionary, walls: Dictionary, center: Vector2i, variant: int, thickness: int = 1) -> void:
    for yy in range(-thickness,thickness+1):
        for xx in range(-thickness,thickness+1):
            var pos: Vector2i = center+Vector2i(xx,yy)
            if pos.x >= 2 and pos.y >= 2 and pos.x < WIDTH-2 and pos.y < HEIGHT-2:
                _paint(terrain,walls,pos,Vector2i((variant+xx+yy+32)%8,3),false)

func _road(terrain: Dictionary, walls: Dictionary, a: Vector2i, b: Vector2i, seed: int, thickness: int = 1) -> void:
    # Deterministic street / switchback corridor; two orthogonal paths keep access legible.
    var x: int = a.x
    var y: int = a.y
    var horizontal_first: bool = (seed%2)==0
    for _step in range(2):
        if horizontal_first == (_step == 0):
            while x != b.x:
                _carve(terrain,walls,Vector2i(x,y),seed%8,thickness)
                x += 1 if x < b.x else -1
        else:
            while y != b.y:
                _carve(terrain,walls,Vector2i(x,y),seed%8,thickness)
                y += 1 if y < b.y else -1
    _carve(terrain,walls,b,seed%8,thickness)

func _room(terrain: Dictionary,walls: Dictionary,center: Vector2i,size: Vector2i,seed: int) -> void:
    for y in range(center.y-size.y/2,center.y+size.y/2+1):
        for x in range(center.x-size.x/2,center.x+size.x/2+1):
            var pos: Vector2i = Vector2i(x,y)
            if x < 2 or y < 2 or x >= WIDTH-2 or y >= HEIGHT-2:
                continue
            _paint(terrain,walls,pos,Vector2i(_hash(x,y,seed)%8,5),false)

func _anchors() -> Array[Vector2i]:
    # Main quest, five-stage side missions and ordinary services stay physically accessible.
    var originals: Array[Vector2i] = [
        Vector2i(6,13),Vector2i(16,11),Vector2i(32,10),Vector2i(27,20),
        Vector2i(34,19),Vector2i(10,19),Vector2i(20,8),Vector2i(9,10),
        Vector2i(7,19),Vector2i(39,12),Vector2i(19,24),
        Vector2i(8,8),Vector2i(36,12),Vector2i(23,8),Vector2i(25,22),
        Vector2i(13,17),Vector2i(36,21),Vector2i(12,9)
    ]
    for i in range(9):
        originals.append(Vector2i(7+(i%3)*12,10+int(i/3)*5))
    for i in range(5):
        originals.append(Vector2i(10+(i%3)*11,5+int(i/3)*18))
    var mapped: Array[Vector2i] = []
    for point in originals:
        var result: Vector2i = old_to_new(point)
        if result not in mapped:
            mapped.append(result)
    for landmark in [Vector2i(19,14),Vector2i(53,16),Vector2i(54,36),Vector2i(60,35),Vector2i(24,14)]:
        if landmark not in mapped:
            mapped.append(landmark)
    return mapped

func layout(map_id: String, chapter: int, target: String = "") -> Dictionary:
    var spec: Dictionary = zone(map_id)
    var map_kind: String = str(spec.get("archetype","field"))
    var biome: String = str(spec.get("biome","coastal"))
    var seed: int = int(spec.get("seed",1729))
    var terrain: Dictionary = {}
    var walls: Dictionary = {}
    var features: Array[Dictionary] = []
    var dungeon: bool = map_kind in ["dungeon","hall"]
    var village: bool = bool(spec.get("settlement",false))
    var shoreline: bool = biome in ["coastal","archipelago"]
    for y in range(HEIGHT):
        for x in range(WIDTH):
            var p: Vector2i = Vector2i(x,y)
            var random: int = _hash(x/3,y/3,seed)
            var detail: int = _hash(x,y,seed)
            var row: int = 0
            var wall: bool = x <= 1 or y <= 1 or x >= WIDTH-2 or y >= HEIGHT-2
            if biome in ["coastal","archipelago"]:
                row = 0 if detail%13<6 else 1
                if not village and (y > 39+(random%3) or (biome=="archipelago" and x<4)):
                    wall = true
                    row = 6
            elif biome == "highland":
                row = 2 if detail%10<6 else 1
                if not village and (random < 850 and (x<15 or x>56)):
                    wall = true
                    row = 6
            elif biome == "volcanic":
                row = 4 if detail%11<7 else 5
                if not village and random<1100:
                    wall = true
                    row = 6
            elif biome == "mistforest":
                row = 1 if detail%9<6 else 7
                if not village and random<1050:
                    wall = true
            elif biome == "badlands":
                row = 3 if detail%11<7 else 4
                if not village and random < 1150:
                    wall = true
            elif biome == "celestial":
                row = 7 if detail%10<7 else 2
                if not village and random<900:
                    wall = true
            else:
                row = 2 if detail%9<6 else 5
            if dungeon:
                wall = true
                row = 6
            _paint(terrain,walls,p,Vector2i(detail%8,row),wall)
    var hub: Vector2i = Vector2i(WIDTH/2,HEIGHT/2)
    var start: Vector2i = old_to_new(Vector2i(6,13))
    if dungeon:
        var chambers: Array[Vector2i] = []
        for chamber_data in spec.get("dungeon_chambers",[]):
            if chamber_data is Array and chamber_data.size()>=2:
                chambers.append(Vector2i(int(chamber_data[0]),int(chamber_data[1])))
        if chambers.is_empty():
            chambers = [start,Vector2i(19,14),Vector2i(38,10),Vector2i(55,16),Vector2i(54,36),Vector2i(35,35),Vector2i(18,34)]
        for i in range(chambers.size()):
            _room(terrain,walls,chambers[i],Vector2i(9+((seed+i*3)%5),7+((seed+i)%4)),seed)
        for i in range(chambers.size()-1):
            _road(terrain,walls,chambers[i],chambers[i+1],seed+i,1)
        _road(terrain,walls,chambers[-1],chambers[0],seed+21,1)
        if chambers.size()>=6:
            _road(terrain,walls,chambers[1],chambers[chambers.size()-2],seed+27,1)
        features.append({"kind":"sea_crystal","cell":chambers[mini(3,chambers.size()-1)],"name":"洞窟水晶"})
        features.append({"kind":"beacon","cell":chambers[mini(2,chambers.size()-1)],"name":"古代封印"})
    elif village:
        var district: String = str(spec.get("layout","central_square"))
        match district:
            "terraced_streets":
                for street_y in [14,25,36]:
                    _road(terrain,walls,Vector2i(4,street_y),Vector2i(67,street_y),seed+street_y,2)
                for street_x in [23,45]:
                    _road(terrain,walls,Vector2i(street_x,4),Vector2i(street_x,43),seed+street_x,1)
            "waterfront_docks":
                for street_y in [16,32,39]:
                    _road(terrain,walls,Vector2i(4,street_y),Vector2i(67,street_y),seed+street_y,2 if street_y==32 else 1)
                for street_x in [16,35,54]:
                    _road(terrain,walls,Vector2i(street_x,4),Vector2i(street_x,43),seed+street_x,1)
            "circular_market":
                for ring_step in range(80):
                    var angle: float = float(ring_step)*TAU/80.0
                    var arc: Vector2i = hub+Vector2i(roundi(24.0*cos(angle)),roundi(15.0*sin(angle)))
                    _carve(terrain,walls,arc,seed,2)
                _road(terrain,walls,Vector2i(4,24),Vector2i(67,24),seed,1)
                _road(terrain,walls,Vector2i(35,4),Vector2i(35,43),seed+3,1)
            "fortified_quarters":
                for street_y in [10,24,38]:
                    _road(terrain,walls,Vector2i(5,street_y),Vector2i(66,street_y),seed+street_y,1)
                for street_x in [12,35,60]:
                    _road(terrain,walls,Vector2i(street_x,5),Vector2i(street_x,42),seed+street_x,1)
            "canal_neighborhood":
                for canal_y in range(5,42):
                    for canal_x in range(28,32):
                        _paint(terrain,walls,Vector2i(canal_x,canal_y),Vector2i((canal_x+canal_y)%8,6),true)
                for street_y in [15,24,34]:
                    _road(terrain,walls,Vector2i(4,street_y),Vector2i(67,street_y),seed+street_y,2)
                for street_x in [16,44,60]:
                    _road(terrain,walls,Vector2i(street_x,5),Vector2i(street_x,42),seed+street_x,1)
            _:
                _road(terrain,walls,Vector2i(4,24),Vector2i(67,24),seed,2)
                _road(terrain,walls,Vector2i(35,4),Vector2i(35,43),seed,2)
        _room(terrain,walls,hub,Vector2i(18,12),seed)
        for building in spec.get("buildings",[]):
            var body: Vector2i = Vector2i(int(building["pos"][0]),int(building["pos"][1]))
            var size: Vector2i = Vector2i(int(building["size"][0]),int(building["size"][1]))
            for y in range(body.y-size.y/2,body.y+size.y/2+1):
                for x in range(body.x-size.x/2,body.x+size.x/2+1):
                    _paint(terrain,walls,Vector2i(x,y),Vector2i((x+y)%8,6),true)
            var door: Vector2i = Vector2i(int(building["door"][0]),int(building["door"][1]))
            _road(terrain,walls,door,hub,seed+body.x,1)
            _carve(terrain,walls,door,seed,2)
            features.append({"kind":str(building.get("kind","cottage")),"cell":body,"name":str(building.get("name","建筑")),"building":str(building["id"]),"door":door})
    else:
        var path_nodes: Array[Vector2i] = [start,Vector2i(24,14),hub,Vector2i(53,16),Vector2i(60,35),Vector2i(40,39),Vector2i(16,35)]
        for i in range(path_nodes.size()-1):
            _road(terrain,walls,path_nodes[i],path_nodes[i+1],seed+i,2 if map_kind=="field" else 1)
        _road(terrain,walls,path_nodes[-1],hub,seed+27,1)
        for i in range(32):
            var xx: int = 5 + _hash(i,12,seed)%(WIDTH-10)
            var yy: int = 5 + _hash(42,i,seed)%(HEIGHT-10)
            var p: Vector2i = Vector2i(xx,yy)
            if not walls.has(p) and p.distance_to(hub)>10:
                features.append({"kind":ICONS[_hash(i,24,seed)%ICONS.size()],"cell":p,"name":"探索景物"})
    # V3 wilderness is an editable per-zone layout, not the former global
    # star-shaped spawn-to-every-quest carve. All quest markers still remain
    # accessible by short connections to their nearest authored road waypoint.
    var authored_level: Dictionary = authored.level(map_id)
    if not dungeon and not village and not authored_level.is_empty():
        var route_nodes: Array[Vector2i] = authored.apply(authored_level,terrain,walls,features)
        for index in range(_anchors().size()):
            var anchor: Vector2i = _anchors()[index]
            var origin: Vector2i = authored.nearest_road(anchor,route_nodes)
            _road(terrain,walls,origin,anchor,seed+index,0)
    else:
        for index in range(_anchors().size()):
            _road(terrain,walls,start,_anchors()[index],seed+index,1)
    # Gate entrances sit inside passable terrain and connect existing registry neighbors.
    var gates: Array[Dictionary] = []
    var names: Array = spec.get("neighbors",[])
    for i in range(names.size()):
        var destination: String = str(names[i])
        var gate: Vector2i = Vector2i(4,24) if i%4==0 else (Vector2i(WIDTH-5,24) if i%4==1 else Vector2i(36,4))
        _road(terrain,walls,start,gate,seed+i,1)
        gates.append({"id":destination,"cell":gate})
    # A route may not be allowed across locked chapters; physical gate is still visible.
    return {"tiles":terrain,"blocked":walls,"features":features,"gates":gates,"spawn":start,"zone":spec,"size":Vector2i(WIDTH,HEIGHT)}

func interior(building: String,building_kind: String) -> Dictionary:
    var terrain: Dictionary = {}
    var blocked: Dictionary = {}
    var top: int = 10
    var left: int = 20
    var right: int = 51
    var bottom: int = 36
    var bias: int = abs(building.hash())
    for y in range(HEIGHT):
        for x in range(WIDTH):
            var inside: bool = x>left and x<right and y>top and y<bottom
            _paint(terrain,blocked,Vector2i(x,y),Vector2i((x+y+bias)%8,5 if inside else 6),not inside)
    for x in range(left+2,right-1):
        if x!=35:
            _paint(terrain,blocked,Vector2i(x,top+8),Vector2i((x+bias)%8,6),true)
    for y in range(top+2,bottom-2):
        if y!=25:
            _paint(terrain,blocked,Vector2i(37,y),Vector2i((y+bias)%8,6),true)
    var exit: Vector2i = Vector2i(35,bottom-2)
    _carve(terrain,blocked,exit,2,2)
    _carve(terrain,blocked,Vector2i(36,25),2,2)
    var feature: Array[Dictionary] = [
        {"kind":"sign","cell":Vector2i(29,17),"name":"室内公告"},
        {"kind":"barrel","cell":Vector2i(45,19),"name":"储物处"},
        {"kind":"star_lantern","cell":Vector2i(30,30),"name":"照明灯"},
        {"kind":"flowerpot","cell":Vector2i(44,29),"name":"室内装饰"}
    ]
    return {"tiles":terrain,"blocked":blocked,"features":feature,"gates":[],"spawn":Vector2i(35,bottom-5),"size":Vector2i(WIDTH,HEIGHT),"interior":building_kind}

func reachable(layout_data: Dictionary, origins: Array[Vector2i], targets: Array[Vector2i]) -> bool:
    var walls: Dictionary = layout_data.get("blocked",{})
    var explored: Dictionary = {}
    var queue: Array[Vector2i] = origins.duplicate()
    for start in queue:
        if not walls.has(start):
            explored[start]=true
    var index: int = 0
    while index<queue.size():
        var cur: Vector2i = queue[index]
        index += 1
        for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var n: Vector2i = cur+delta
            if n.x<2 or n.y<2 or n.x>=WIDTH-2 or n.y>=HEIGHT-2 or explored.has(n) or walls.has(n):
                continue
            explored[n]=true
            queue.append(n)
    for target in targets:
        if not explored.has(target):
            return false
    return true
