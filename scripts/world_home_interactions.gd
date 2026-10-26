extends RefCounted
## Safe, save-compatible B-line furniture investigation. D adds visible markers
## for layout.investigations and calls inspect; never advances main quest flags.
const ROOM_PATH = "res://data/levels/v4/interiors/"
const SAVE_BUCKET: String = "home_investigations_v1"
var issues: Array[String] = []

func dossier(map_id: String,building_id: String) -> Dictionary:
    var file: String=ROOM_PATH+map_id+"__"+building_id+".json"
    if not FileAccess.file_exists(file):
        return {}
    var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
    if not (parsed is Dictionary):
        return {}
    if str(parsed.get("map_id",""))!=map_id or str(parsed.get("building_id",""))!=building_id:
        return {}
    return parsed

func objects(map_id: String,building_id: String) -> Array:
    return dossier(map_id,building_id).get("investigations",[]).duplicate(true)

func _lookup(map_id: String,building_id: String,object_id: String) -> Dictionary:
    for item in objects(map_id,building_id):
        if str(item.get("id",""))==object_id:
            return item
    return {}

func snapshot(state,map_id: String,building_id: String,object_id: String) -> Dictionary:
    if state==null:
        return {}
    var all_saved: Dictionary=state.rpg.get(SAVE_BUCKET,{})
    return (all_saved.get(map_id+"#"+building_id+"#"+object_id,{}) as Dictionary).duplicate(true)

func inspect(map_id: String,building_id: String,object_id: String,state,
        owner_present: bool = false) -> Dictionary:
    var item: Dictionary=_lookup(map_id,building_id,object_id)
    if item.is_empty() or state==null:
        return {"changed":false,"message":"这里没有可调查的家具。"}
    var key: String=map_id+"#"+building_id+"#"+object_id
    var saved: Dictionary=snapshot(state,map_id,building_id,object_id)
    var completed: bool=bool(state.flags.get(str(item.get("after_flag","")),false))
    var phase: String="after" if completed else "before"
    var already: bool=bool(saved.get("seen_"+phase,false))
    var name: String=str(item.get("name","室内物件"))
    var line: String=""
    if already:
        line=str(item.get("repeat_text","它仍放在原来的地方。"))
    elif completed:
        line=str(item.get("after_text",item.get("first_text","")))
    else:
        line=str(item.get("first_text",""))
    if not owner_present and not str(item.get("owner_absent_text","")).is_empty():
        line+="\n"+str(item.get("owner_absent_text",""))
    elif owner_present and not str(item.get("owner_present_text","")).is_empty():
        line+="\n"+str(item.get("owner_present_text",""))
    if already:
        return {"changed":false,"message":"【"+name+"】"+line,"phase":phase,"seen":true}
    # Set only the investigation's namespaced mark. Never set chNNN.done or
    # side quest flags, never grant furniture loot by merely reading text.
    var all_saved: Dictionary=state.rpg.get(SAVE_BUCKET,{})
    saved["seen_"+phase]=true
    saved["last_phase"]=phase
    all_saved[key]=saved
    state.rpg[SAVE_BUCKET]=all_saved
    return {"changed":true,"message":"【"+name+"】"+line,"phase":phase,
        "event_id":"b.home."+map_id+"."+building_id+"."+object_id+"."+phase,
        "requires_save":true,"reward":{},"seen":true}

func occupancy_response(map_id: String,building_id: String,owner_present: bool) -> String:
    var room: Dictionary=dossier(map_id,building_id)
    if room.is_empty():
        return "这栋房屋尚未开放。"
    if owner_present:
        return "屋主正忙着自己的事情。可以交谈，但请先询问是否能查看私人物件。"
    return "屋里暂时没人应声。可查看公开摆设，私人信件和物品不能自行带走。"
