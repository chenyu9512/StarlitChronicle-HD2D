extends RefCounted
const WorldLevelV3 = preload("res://scripts/world_level_v3.gd")
const TownDirector = preload("res://scripts/town_director.gd")
const InteriorV4 = preload("res://scripts/world_interior_v4.gd")
## 72x48 real-world sector architecture, shared by collision, renderer, minimap and tests.
## Authored spatial zone configuration is in world_atlas_v2.json; geometry is deterministic.
const WIDTH: int = 72
const HEIGHT: int = 48
var map_width: int = WIDTH
var map_height: int = HEIGHT
const TILE: int = 32
const ATLAS_PATH: String = "res://data/levels/world_atlas_v2.json"
const START: Vector2i = Vector2i(10,23)
const ICONS: Array[String] = ["palm_tree","rock","barrel","sea_crystal","star_lantern","flowerpot","beacon","sign"]
var zones: Dictionary = {}
var regions: Dictionary = {}
var faults: Array[String] = []
var authored = WorldLevelV3.new()
var town_design = TownDirector.new()

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
    for reason in town_design.problems:
        faults.append(str(reason))

func zone(id: String) -> Dictionary:
    return zones.get(id,{})

func _hash(x: int,y: int,seed: int) -> int:
    var value: int = abs((x*73856093) ^ (y*19349663) ^ (seed*83492791))
    return value % 10000

func old_to_new(pos: Vector2i) -> Vector2i:
    return Vector2i(clampi(roundi(float(pos.x)*float(WIDTH)/44.0),2,WIDTH-3),clampi(roundi(float(pos.y)*float(HEIGHT)/28.0),2,HEIGHT-3))

func _paint(terrain: Dictionary, walls: Dictionary, cell: Vector2i, floor_atlas: Vector2i, blocked: bool) -> void:
    if cell.x < 0 or cell.x >= map_width or cell.y < 0 or cell.y >= map_height:
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
            if pos.x >= 2 and pos.y >= 2 and pos.x < map_width-2 and pos.y < map_height-2:
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
            if x < 2 or y < 2 or x >= map_width-2 or y >= map_height-2:
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
    var authored_level: Dictionary = authored.level(map_id)
    var extent: Array = authored_level.get("size",[WIDTH,HEIGHT])
    map_width = int(extent[0]) if extent.size()==2 else WIDTH
    map_height = int(extent[1]) if extent.size()==2 else HEIGHT
    var terrain: Dictionary = {}
    var walls: Dictionary = {}
    var features: Array[Dictionary] = []
    # A civic hall is a populated settlement, not a cave or boss dungeon.
    var dungeon: bool = map_kind == "dungeon"
    var village: bool = bool(spec.get("settlement",false))
    var shoreline: bool = biome in ["coastal","archipelago"]
    for y in range(map_height):
        for x in range(map_width):
            var p: Vector2i = Vector2i(x,y)
            var random: int = _hash(x/3,y/3,seed)
            var detail: int = _hash(x,y,seed)
            var row: int = 0
            var wall: bool = x <= 1 or y <= 1 or x >= map_width-2 or y >= map_height-2
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
    var hub: Vector2i = Vector2i(map_width/2,map_height/2)
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
            var xx: int = 5 + _hash(i,12,seed)%(map_width-10)
            var yy: int = 5 + _hash(42,i,seed)%(map_height-10)
            var p: Vector2i = Vector2i(xx,yy)
            if not walls.has(p) and p.distance_to(hub)>10:
                features.append({"kind":ICONS[_hash(i,24,seed)%ICONS.size()],"cell":p,"name":"探索景物"})
    # V3 wilderness is an editable per-zone layout, not the former global
    # star-shaped spawn-to-every-quest carve. All quest markers still remain
    # accessible by short connections to their nearest authored road waypoint.
    if not dungeon and not village and not authored_level.is_empty():
        var route_nodes: Array[Vector2i] = authored.apply(authored_level,terrain,walls,features)
        # Every hand-authored road family shares an actual junction, rather
        # than joining quest targets to disconnected decorative polylines.
        var junction: Vector2i = Vector2i(36,24)
        _road(terrain,walls,start,junction,seed+79,1)
        var road_index: int = 0
        for authored_road in authored_level.get("roads",[]):
            var stations: Array = authored_road.get("points",[])
            if not stations.is_empty():
                var first_station: Array = stations[0]
                var terminus: Vector2i = Vector2i(int(first_station[0]),int(first_station[1]))
                _road(terrain,walls,junction,terminus,seed+road_index+81,0)
            road_index += 1
        for index in range(_anchors().size()):
            var anchor: Vector2i = _anchors()[index]
            var origin: Vector2i = authored.nearest_road(anchor,route_nodes)
            _road(terrain,walls,origin,anchor,seed+index,0)
    else:
        for index in range(_anchors().size()):
            _road(terrain,walls,start,_anchors()[index],seed+index,1)
        if not authored_level.is_empty():
            # Town and dungeon geometry remains chapter-safe, while artist-painted
            # per-cell surface/collision corrections are now genuinely applied.
            authored.apply_safe_paths(authored_level,terrain,walls,features,dungeon)
    # Gate entrances sit inside passable terrain and connect existing registry neighbors.
    var gates: Array[Dictionary] = []
    var names: Array = spec.get("neighbors",[])
    for i in range(names.size()):
        var destination: String = str(names[i])
        var gate: Vector2i = Vector2i(4,24) if i%4==0 else (Vector2i(map_width-5,24) if i%4==1 else Vector2i(36,4))
        _road(terrain,walls,start,gate,seed+i,1)
        gates.append({"id":destination,"cell":gate})
    # A route may not be allowed across locked chapters; physical gate is still visible.
    # Deliberate urban composition respects original pathing and buildings.
    var district_plan: Dictionary = {}
    if village:
        district_plan = town_design.apply_town(map_id,terrain,walls,features)
    # Distinct authored wings expand the map without moving historic quest anchors.
    # Join wings from the northern passage, not across authored water/cliffs at 66,32–36.
    var wing_origin: Vector2i = Vector2i(71,16)
    _road(terrain,walls,Vector2i(53,16),wing_origin,seed+101,1)
    for extension in authored_level.get("expansion_nodes",[]):
        if not extension is Dictionary:
            continue
        var coordinates: Array = extension.get("cell",[])
        if coordinates.size()!=2:
            continue
        var site: Vector2i = Vector2i(int(coordinates[0]),int(coordinates[1]))
        if site.x<3 or site.y<3 or site.x>=map_width-3 or site.y>=map_height-3:
            continue
        _room(terrain,walls,site,Vector2i(11,9) if dungeon else (Vector2i(13,11) if village else Vector2i(7,7)),seed+site.x)
        _road(terrain,walls,wing_origin,site,seed+site.y,1)
        features.append({"kind":str(extension.get("kind","beacon")),"cell":site,"name":str(extension.get("name","独立区域地标"))})
        wing_origin=site
    # Keep every legacy story marker reachable in formerly sealed dungeon rooms.
    # Do this after wing carving but BEFORE the final artist collision overrides.
    if dungeon:
        for anchor in _anchors():
            if not reachable({"blocked":walls,"size":Vector2i(map_width,map_height)},[start],[anchor]):
                _road(terrain,walls,start,anchor,seed+anchor.x+anchor.y,0)
    # Manual cell edits are the LAST authority. The initial V3 apply happened
    # before automatic quest links and gates, which could erase editor changes.
    # A blocked quest marker or exit is deliberately caught by map QA rather
    # than being silently removed from the designer's data.
    if not authored_level.is_empty():
        authored.apply_editor_patches(authored_level,terrain,walls)
    # Final spatial integrity: reconnect only genuinely isolated story target cells.
    # A manual collision layer or regional cliff cannot strand an original quest.
    # Do not alter accessible authored paths or override navigable bridge layouts.
    for essential in _anchors():
        if village and _inside_town_building(essential,spec):
            # Legacy quest positions can fall under the now-solid roof. The
            # interaction layer relocates those markers to reachable pavement.
            continue
        if not reachable({"blocked":walls,"size":Vector2i(map_width,map_height)},[start],[essential]):
            _road(terrain,walls,start,essential,seed+essential.x*7+essential.y,1)
    if village:
        # LAST physical authority: roads, quests, gates and expansion passes
        # must never drill invisible holes through a house facade.
        _seal_town_buildings(terrain,walls,spec,start)
    var wet: Dictionary = {}
    if not authored_level.is_empty():
        wet = authored.open_water_tiles(authored_level,walls)
    return {"tiles":terrain,"blocked":walls,"water_mask":wet,"features":features,"gates":gates,"town_plan":district_plan,"spawn":start,"zone":spec,"size":Vector2i(map_width,map_height)}

## One footprint / one entrance rule for every settlement. The map artist
## owns the shape and the D interaction layer owns whether the door can open.
func _building_box(building: Dictionary) -> Rect2i:
    var center: Array = building.get("pos",[])
    var dimensions: Array = building.get("size",[])
    if center.size()!=2 or dimensions.size()!=2:
        return Rect2i()
    var body := Vector2i(int(center[0]),int(center[1]))
    var size := Vector2i(int(dimensions[0]),int(dimensions[1]))
    var half := Vector2i(size.x / 2,size.y / 2)
    return Rect2i(body-half,half*2+Vector2i.ONE)

func _inside_town_building(cell: Vector2i,spec: Dictionary) -> bool:
    for raw in spec.get("buildings",[]):
        if raw is Dictionary and _building_box(raw).has_point(cell):
            return true
    return false

func _path_around_roofs(start: Vector2i,goal: Vector2i,roofs: Dictionary) -> Array[Vector2i]:
    # Sparse 4-neighbour routing. Only invoked for a disconnected front door;
    # never erases roof blockers or teleports the player into the interior.
    if roofs.has(start) or roofs.has(goal):
        return []
    var frontier: Array[Vector2i] = [start]
    var parents: Dictionary = {start:start}
    var index: int = 0
    var steps: Array[Vector2i] = [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]
    while index<frontier.size():
        var current: Vector2i=frontier[index]
        index+=1
        if current==goal:
            var result: Array[Vector2i]=[]
            while current!=start:
                result.append(current)
                current=parents[current]
            result.append(start)
            result.reverse()
            return result
        for offset in steps:
            var next: Vector2i=current+offset
            if next.x<2 or next.y<2 or next.x>=map_width-2 or next.y>=map_height-2 or roofs.has(next) or parents.has(next):
                continue
            parents[next]=current
            frontier.append(next)
    return []

func _seal_town_buildings(ground: Dictionary,walls: Dictionary,spec: Dictionary,spawn: Vector2i) -> void:
    var roofs: Dictionary={}
    var entrances: Array[Vector2i]=[]
    for raw in spec.get("buildings",[]):
        if not raw is Dictionary:
            continue
        var box: Rect2i=_building_box(raw)
        if box.size.x==0 or box.size.y==0:
            continue
        for y in range(box.position.y,box.end.y):
            for x in range(box.position.x,box.end.x):
                var cell:=Vector2i(x,y)
                if cell.x>=2 and cell.y>=2 and cell.x<map_width-2 and cell.y<map_height-2:
                    roofs[cell]=true
        var door: Array=raw.get("door",[])
        if door.size()==2:
            entrances.append(Vector2i(int(door[0]),int(door[1]))+Vector2i.DOWN)
    for cell in roofs.keys():
        # Preserve the original grid/blocker representation used by collision,
        # path tests and the editor; the building scene draws the actual roof.
        _paint(ground,walls,cell,Vector2i(posmod(cell.x+cell.y,8),6),true)
    var layout_size:=Vector2i(map_width,map_height)
    for entrance in entrances:
        if roofs.has(entrance):
            push_warning("Town entrance overlaps another building: "+str(entrance))
            continue
        # Solid doorway tile remains inside the footprint; stand one tile in
        # front of it and press interact, just like a classic tile JRPG.
        for distance in [1,2]:
            var apron: Vector2i=entrance+Vector2i(0,distance-1)
            if not roofs.has(apron):
                _paint(ground,walls,apron,Vector2i(posmod(apron.x+apron.y,8),3),false)
        if reachable({"blocked":walls,"size":layout_size},[spawn],[entrance]):
            continue
        var link: Array[Vector2i]=_path_around_roofs(entrance,spawn,roofs)
        if link.is_empty():
            push_warning("Town entrance has no non-roof route: "+str(entrance))
            continue
        for cell in link:
            if not roofs.has(cell):
                _paint(ground,walls,cell,Vector2i(posmod(cell.x+cell.y,8),3),false)

func interior(building: String,building_kind: String,map_id: String = "") -> Dictionary:
    map_width = WIDTH
    map_height = HEIGHT
    var custom: Dictionary = InteriorV4.new().load_level(map_id,building,building_kind)
    if not custom.is_empty():
        return custom
    # Existing V2-generated room remains an old-save-compatible fallback.
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
        {"kind":"sign","cell":Vector2i(29,17),"name":"室内服务告示"},
        {"kind":"barrel","cell":Vector2i(45,19),"name":"储物处"},
        {"kind":"star_lantern","cell":Vector2i(30,30),"name":"照明灯"},
        {"kind":"flowerpot","cell":Vector2i(44,29),"name":"室内装饰"}
    ]
    # Building functions have distinctly staged furniture, not four identical
    # props and the same vacant room for every shop, inn and shrine.
    var furniture: Dictionary = {
        "inn":[
            ["fish_stall",Vector2i(26,16),"旅馆接待台"],
            ["barrel",Vector2i(26,27),"厨房储物"],
            ["barrel",Vector2i(25,30),"客厅茶点"],
            ["flowerpot",Vector2i(44,14),"窗边绿植"],
            ["star_lantern",Vector2i(48,27),"客房灯"],
            ["medicine_basket",Vector2i(43,31),"住客行李"],
            ["crate",Vector2i(25,23),"床边柜"],
            ["crate",Vector2i(47,32),"行李箱"]
        ],
        "shop":[
            ["fish_stall",Vector2i(28,16),"商店柜台"],
            ["medicine_basket",Vector2i(24,24),"药品展示"],
            ["crate",Vector2i(23,16),"进货箱"],
            ["crate",Vector2i(25,27),"储备货物"],
            ["barrel",Vector2i(43,15),"零散商品"],
            ["barrel",Vector2i(46,30),"货箱"],
            ["flowerpot",Vector2i(44,31),"装饰花"],
            ["sign",Vector2i(47,24),"商品价格牌"]
        ],
        "guild":[
            ["sign",Vector2i(25,17),"任务布告栏"],
            ["sign",Vector2i(46,17),"公会远征地图"],
            ["fish_stall",Vector2i(26,26),"登记接待台"],
            ["crate",Vector2i(45,29),"委托卷宗"],
            ["barrel",Vector2i(24,30),"远征补给"],
            ["star_lantern",Vector2i(48,25),"集会灯"],
            ["medicine_basket",Vector2i(44,14),"补给货架"],
            ["flowerpot",Vector2i(23,15),"壁龛植物"]
        ],
        "smith":[
            ["beacon",Vector2i(44,15),"熔炉"],
            ["rock",Vector2i(42,18),"铁砧"],
            ["barrel",Vector2i(47,22),"冷却槽"],
            ["crate",Vector2i(47,29),"矿料箱"],
            ["crate",Vector2i(24,18),"金属原矿"],
            ["sign",Vector2i(27,16),"工坊工艺板"],
            ["star_lantern",Vector2i(27,29),"工作照明"],
            ["rock",Vector2i(44,32),"磨刀台"]
        ],
        "shrine":[
            ["beacon",Vector2i(35,15),"祈灯圣坛"],
            ["sea_crystal",Vector2i(33,15),"星纹水晶"],
            ["sea_crystal",Vector2i(37,15),"星纹水晶"],
            ["flowerpot",Vector2i(25,23),"祈祷花束"],
            ["flowerpot",Vector2i(46,23),"祈祷花束"],
            ["star_lantern",Vector2i(29,27),"长明灯"],
            ["star_lantern",Vector2i(43,27),"长明灯"],
            ["sign",Vector2i(47,16),"仪式铭文"]
        ],
        "house":[
            ["crate",Vector2i(25,16),"收纳柜"],
            ["barrel",Vector2i(25,23),"厨房储藏"],
            ["medicine_basket",Vector2i(43,15),"日常药包"],
            ["flowerpot",Vector2i(45,25),"窗台花盆"],
            ["star_lantern",Vector2i(28,30),"卧室灯"],
            ["crate",Vector2i(43,30),"小木桌"],
            ["sign",Vector2i(44,18),"家人留言板"],
            ["barrel",Vector2i(24,30),"生活储物"]
        ]
    }
    for item in furniture.get(building,[]):
        feature.append({"kind":str(item[0]),"cell":item[1],"name":str(item[2])})
    return {"tiles":terrain,"blocked":blocked,"features":feature,"gates":[],"spawn":Vector2i(35,bottom-5),"size":Vector2i(WIDTH,HEIGHT),"interior":building_kind,"building":building}

func reachable(layout_data: Dictionary, origins: Array[Vector2i], targets: Array[Vector2i]) -> bool:
    var walls: Dictionary = layout_data.get("blocked",{})
    var extent: Vector2i = layout_data.get("size",Vector2i(WIDTH,HEIGHT))
    var explored: Dictionary = {}
    var queue: Array[Vector2i] = []
    # Never traverse a blocked or out-of-map origin. The old queue leaked
    # through blocked starting cells and reported false-positive reachability.
    for start in origins:
        if start.x<2 or start.y<2 or start.x>=extent.x-2 or start.y>=extent.y-2:
            continue
        if walls.has(start) or explored.has(start):
            continue
        explored[start]=true
        queue.append(start)
    if queue.is_empty():
        return false
    var index: int = 0
    while index<queue.size():
        var cur: Vector2i = queue[index]
        index += 1
        for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var n: Vector2i = cur+delta
            if n.x<2 or n.y<2 or n.x>=extent.x-2 or n.y>=extent.y-2 or explored.has(n) or walls.has(n):
                continue
            explored[n]=true
            queue.append(n)
    for target in targets:
        if not explored.has(target):
            return false
    return true
