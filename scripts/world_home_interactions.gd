extends RefCounted
## B-line furniture investigation: cached authored definitions and independent,
## save-compatible per-phase inspection state. D owns input and actor ownership.
const ROOT: String = "res://data/levels/v4/interiors/"
const SAVE_BUCKET: String = "home_investigations_v1"
const InteriorGeometry = preload("res://scripts/world_interior_v4.gd")
var issues: Array[String] = []
var room_cache: Dictionary = {}
var index_cache: Dictionary = {}

static func _valid_part(value: String) -> bool:
    # Prevent path traversal or accidental reading of unrelated res:// files.
    return not value.is_empty() and value.length()<=96 and \
        not value.contains("/") and not value.contains("\\") and \
        not value.contains(".") and not value.contains(":") and \
        not value.contains(" ") and not value.contains("%")

static func _room_key(map_id: String,building_id: String) -> String:
    return map_id+"#"+building_id

func dossier(map_id: String,building_id: String) -> Dictionary:
    if not _valid_part(map_id) or not _valid_part(building_id):
        return {}
    var key: String=_room_key(map_id,building_id)
    if room_cache.has(key):
        return (room_cache[key] as Dictionary).duplicate(true)
    var path: String=ROOT+map_id+"__"+building_id+".json"
    if not FileAccess.file_exists(path):
        return {}
    var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (raw is Dictionary):
        issues.append("Bad room JSON: "+key)
        return {}
    var record: Dictionary=raw
    if str(record.get("schema",""))!="starlit.interior.v4" or \
            str(record.get("map_id",""))!=map_id or str(record.get("building_id",""))!=building_id:
        issues.append("Room identity mismatch: "+key)
        return {}
    # Match the SAME V4 loader used by the real room scene. D must never
    # advertise a furniture hotspot which has been dropped by its collision
    # validator (e.g. a painting moved onto a blocked wall after an art update).
    var physical: Dictionary=InteriorGeometry.new().load_level(map_id,building_id,
        str(record.get("name",building_id)))
    var allowed: Dictionary={}
    for visible in physical.get("investigations",[]):
        if visible is Dictionary:
            allowed[str(visible.get("id",""))]=true
    var lookup: Dictionary={}
    var cells: Dictionary={}
    for object in record.get("investigations",[]):
        if not (object is Dictionary):
            issues.append("Non-object investigation: "+key)
            continue
        var id: String=str(object.get("id",""))
        var cell: Array=object.get("cell",[])
        if not _valid_part(id) or lookup.has(id) or cell.size()!=2:
            issues.append("Invalid/duplicate investigation: "+key+"/"+id)
            continue
        if not allowed.has(id):
            issues.append("Investigation not live on passable V4 room terrain: "+key+"/"+id)
            continue
        var pos: Vector2i=Vector2i(int(cell[0]),int(cell[1]))
        if cells.has(pos):
            issues.append("Overlapping investigation marker: "+key+"/"+id)
            continue
        cells[pos]=id
        lookup[id]=object
    room_cache[key]=record.duplicate(true)
    index_cache[key]={"ids":lookup.duplicate(true),"cells":cells.duplicate(true)}
    return record.duplicate(true)

func objects(map_id: String,building_id: String) -> Array:
    var source: Dictionary=dossier(map_id,building_id)
    if source.is_empty():
        return []
    var key: String=_room_key(map_id,building_id)
    var approved: Dictionary=(index_cache.get(key,{}) as Dictionary).get("ids",{})
    var result: Array=[]
    for candidate in source.get("investigations",[]):
        if candidate is Dictionary and approved.has(str(candidate.get("id",""))):
            result.append(candidate.duplicate(true))
    return result

func _lookup(map_id: String,building_id: String,object_id: String) -> Dictionary:
    if not _valid_part(object_id):
        return {}
    var key: String=_room_key(map_id,building_id)
    # Load the dossier once, then use O(1) lookup on subsequent interactions.
    if not index_cache.has(key):
        dossier(map_id,building_id)
    var indexed: Dictionary=index_cache.get(key,{})
    var found: Variant=(indexed.get("ids",{}) as Dictionary).get(object_id,{})
    return (found as Dictionary).duplicate(true) if found is Dictionary else {}

func object_at(map_id: String,building_id: String,cell: Vector2i) -> Dictionary:
    var key: String=_room_key(map_id,building_id)
    if not index_cache.has(key):
        dossier(map_id,building_id)
    var cells: Dictionary=(index_cache.get(key,{}) as Dictionary).get("cells",{})
    var id: String=str(cells.get(cell,""))
    return _lookup(map_id,building_id,id) if not id.is_empty() else {}

func snapshot(state,map_id: String,building_id: String,object_id: String) -> Dictionary:
    if state==null:
        return {}
    var source: Variant=state.rpg.get(SAVE_BUCKET,{})
    if not (source is Dictionary):
        return {}
    var saved: Variant=(source as Dictionary).get(_room_key(map_id,building_id)+"#"+object_id,{})
    return (saved as Dictionary).duplicate(true) if saved is Dictionary else {}

func preview(map_id: String,building_id: String,object_id: String,state) -> Dictionary:
    var prop: Dictionary=_lookup(map_id,building_id,object_id)
    if prop.is_empty() or state==null:
        return {"available":false}
    var phase: String="after" if bool(state.flags.get(str(prop.get("after_flag","")),false)) else "before"
    var progress: Dictionary=snapshot(state,map_id,building_id,object_id)
    return {"available":true,"name":str(prop.get("name","室内陈设")),
        "phase":phase,"seen":bool(progress.get("seen_"+phase,false)),
        "cell":prop.get("cell",[]),"reward_available":false}

func inspect_at(map_id: String,building_id: String,cell: Vector2i,state,
        owner_present: bool=false) -> Dictionary:
    var found: Dictionary=object_at(map_id,building_id,cell)
    if found.is_empty():
        return {"changed":false,"message":"这里没有可调查的家具。","reward":{}}
    return inspect(map_id,building_id,str(found.get("id","")),state,owner_present)

func inspect(map_id: String,building_id: String,object_id: String,state,
        owner_present: bool=false) -> Dictionary:
    var prop: Dictionary=_lookup(map_id,building_id,object_id)
    if prop.is_empty() or state==null:
        return {"changed":false,"message":"这里没有可调查的家具。","reward":{}}
    var before: Dictionary=preview(map_id,building_id,object_id,state)
    var phase: String=str(before.get("phase","before"))
    var already: bool=bool(before.get("seen",false))
    var title: String=str(prop.get("name","室内陈设"))
    var line: String
    if already:
        line=str(prop.get("repeat_text","它仍放在原来的地方。"))
    elif phase=="after":
        line=str(prop.get("after_text",prop.get("first_text","")))
    else:
        line=str(prop.get("first_text",""))
    # This flag is supplied by D only when the owner is visibly present.
    # Being absent never authorizes looting; every scene is observe-only.
    var privacy_key: String="owner_present_text" if owner_present else "owner_absent_text"
    var notice: String=str(prop.get(privacy_key,""))
    if not notice.is_empty():
        line+="\n"+notice
    var message: String="【"+title+"】"+line
    if already:
        return {"changed":false,"message":message,"phase":phase,
            "seen":true,"requires_save":false,"reward":{}}
    var bucket: Variant=state.rpg.get(SAVE_BUCKET,{})
    var saved_all: Dictionary=(bucket as Dictionary).duplicate(true) if bucket is Dictionary else {}
    var key: String=_room_key(map_id,building_id)+"#"+object_id
    var progress: Dictionary=snapshot(state,map_id,building_id,object_id)
    progress["seen_"+phase]=true
    progress["last_phase"]=phase
    saved_all[key]=progress
    state.rpg[SAVE_BUCKET]=saved_all
    return {"changed":true,"message":message,"phase":phase,"seen":true,
        "event_id":"b.home."+map_id+"."+building_id+"."+object_id+"."+phase,
        "requires_save":true,"reward":{}}

func occupancy_response(map_id: String,building_id: String,owner_present: bool) -> String:
    if dossier(map_id,building_id).is_empty():
        return "这栋房屋尚未开放。"
    if owner_present:
        return "屋主正忙着自己的事情。可以交谈，但请先询问是否能查看私人物件。"
    return "屋里暂时没人应声。可查看公开摆设，私人信件和物品不能自行带走。"
