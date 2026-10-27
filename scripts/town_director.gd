extends RefCounted
## Authored street composition: recognizable approaches, purposeful urban districts,
## negative space, nonblocking lived-in scene dressing, and service-linked residents.
const SOURCE: String = "res://data/levels/town_director_v4.json"
const WIDTH: int = 72
const HEIGHT: int = 48
var plans: Dictionary = {}
var problems: Array[String] = []

func _init() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not raw is Dictionary or str(raw.get("schema","")) != "starlit.town_director.v1":
        problems.append("Authored town district plans missing")
        return
    plans = raw.get("towns",{})
    if plans.size() != 11:
        problems.append("Expected eleven individually composed town plans")
    for id in plans.keys():
        var p: Dictionary = plans[id]
        var districts: Array = p.get("districts",[])
        var details: Array = p.get("details",[])
        if districts.size()<4 or details.size()<14:
            problems.append("Insufficient district or street detail: "+str(id))
        var spots: Dictionary = {}
        for record in details:
            var at: Vector2i = _cell(record.get("cell",[]))
            if not _inside(at) or spots.has(at):
                problems.append("Repeated or out-of-map staged prop in "+str(id))
            spots[at]=true

func has_town(id: String) -> bool:
    return plans.has(id)

func plan(id: String) -> Dictionary:
    return plans.get(id,{})

func _cell(value: Variant) -> Vector2i:
    if value is Array and value.size()>=2:
        return Vector2i(int(value[0]),int(value[1]))
    return Vector2i(-1,-1)

func _inside(at: Vector2i) -> bool:
    return at.x>=3 and at.y>=3 and at.x<WIDTH-3 and at.y<HEIGHT-3

func _pave(ground: Dictionary,blocked: Dictionary,cell: Vector2i,theme: String,border: bool) -> void:
    if not _inside(cell) or blocked.has(cell):
        return
    var row: int = 2 if theme in ["山地关隘","王都中枢","王都公共议厅","王都生活街区"] else 5
    if theme in ["火山工坊城市","荒原遗民聚落"]:
        row=4
    if border:
        row=2
    var variation: int = posmod(cell.x+cell.y*3,8)
    ground[cell]=Vector2i(variation,row)

func apply_town(id: String,ground: Dictionary,walls: Dictionary,features: Array[Dictionary]) -> Dictionary:
    var design: Dictionary = plan(id)
    if design.is_empty():
        return {}
    var focus: Vector2i = _cell(design.get("focal_point",[35,24]))
    var plaza: Dictionary = design.get("plaza",{})
    var span: Array = plaza.get("radius",[9,6])
    var rx: int=int(span[0])
    var ry: int=int(span[1])
    var character: String = str(design.get("urban_form",""))
    for y in range(focus.y-ry,focus.y+ry+1):
        for x in range(focus.x-rx,focus.x+rx+1):
            var at: Vector2i=Vector2i(x,y)
            var border: bool=absi(x-focus.x)==rx or absi(y-focus.y)==ry
            # Keep plaza legible without hiding roads, businesses or collision.
            _pave(ground,walls,at,character,border)
    # A deliberate approach towards the plaza rather than arbitrary tiling.
    for x in range(10,focus.x+1):
        for thickness in [-1,0,1]:
            _pave(ground,walls,Vector2i(x,focus.y+thickness),character,thickness!=0)
    for district in design.get("districts",[]):
        var center: Vector2i=_cell(district.get("center",[]))
        var radius: Array=district.get("radius",[8,6])
        var half_w: int=mini(10,int(radius[0]))
        var half_h: int=mini(6,int(radius[1]))
        # Edge pavement frames sections without painting every free tile.
        for dx in range(-half_w,half_w+1):
            if posmod(dx+half_w,2)==0:
                _pave(ground,walls,center+Vector2i(dx,-half_h),character,true)
                _pave(ground,walls,center+Vector2i(dx,half_h),character,true)
        for dy in range(-half_h,half_h+1):
            if posmod(dy+half_h,2)==0:
                _pave(ground,walls,center+Vector2i(-half_w,dy),character,true)
                _pave(ground,walls,center+Vector2i(half_w,dy),character,true)
    # Authored prop staging is completely cosmetic; never occupy walk blockers.
    for record in design.get("details",[]):
        var at: Vector2i=_cell(record.get("cell",[]))
        if not _inside(at) or walls.has(at):
            continue
        features.append({
            "kind":"flowerpot" if str(record.get("kind","rock"))=="sign" else str(record.get("kind","rock")),
            "cell":at,
            "name":str(record.get("id","street detail")),
            "town_dressing":true
        })
    return design

func resident_anchor(id: String,role: String,index: int,hour: int, buildings: Array = []) -> Vector2i:
    var design: Dictionary = plan(id)
    if design.is_empty():
        return Vector2i(35,24)
    var priority: Array[String]=[]
    match role:
        "shop": priority=["market","dock","square"]
        "craft": priority=["industry","market","barracks"]
        "quest": priority=["square","barracks","shrine"]
        "rumor": priority=["dock","residential","market","garden","square"]
        _: priority=["residential","garden","square"]
    var selected: Dictionary={}
    for wanted in priority:
        for district in design.get("districts",[]):
            if str(district.get("kind",""))==wanted:
                selected=district
                break
        if not selected.is_empty():
            break
    if selected.is_empty():
        selected=design.get("districts",[])[index%design.get("districts",[]).size()]
    var center: Vector2i=_cell(selected.get("center",[35,24]))
    var near: Array[Vector2i]=[Vector2i(-3,-2),Vector2i(3,1),Vector2i(-3,3),Vector2i(4,-3),Vector2i(2,4)]
    var at: Vector2i=center+near[index%near.size()]
    var work_place: String = ""
    match role:
        "shop": work_place = "shop"
        "craft": work_place = "smith"
        "quest": work_place = "guild"
        "rumor": work_place = "inn"
        "lore": work_place = "house"
    if not work_place.is_empty():
        for workplace in buildings:
            if str(workplace.get("id","")) == work_place:
                # Citizen stands outside their workplace, NOT on a generic
                # plaza marker or underneath the impassable roof.
                at=_cell(workplace.get("door",[]))+Vector2i(0,4)+near[index%near.size()]
                break
    if hour<6 or hour>=20:
        if role in ["rumor","lore"]:
            for district in design.get("districts",[]):
                if str(district.get("kind",""))=="residential":
                    at=_cell(district.get("center",[35,24]))+near[index%near.size()]
                    break
    return Vector2i(clampi(at.x,4,WIDTH-5),clampi(at.y,4,HEIGHT-5))
