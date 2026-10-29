extends RefCounted
## Chapter-six authoritative field observations; mutator is committed by
## V3ProgressTransition in the main controller, never by a visual node.
const SOURCE: String = "res://data/levels/act01_lighthouse_runtime_v1.json"
const MAP_ID: String = "map_coast_05"
const SAVE_BUCKET: String = "act01_lighthouse_fragments_v1"
const REQUIRED: Array[String] = ["breakwater_wick","keeper_wick","summit_wick"]
const MAIN_IDS: Array[String] = ["key_npc","clue","witness","crisis","resolve"]
var data: Dictionary = {}
var errors: Array[String] = []

func _init() -> void:
    if not FileAccess.file_exists(SOURCE):
        errors.append("Missing lighthouse scene contract")
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not (raw is Dictionary):
        errors.append("Invalid lighthouse JSON")
        return
    var record: Dictionary = raw
    if str(record.get("schema","")) != "starlit.act01.lighthouse_runtime.v1" or str(record.get("map_id","")) != MAP_ID or int(record.get("chapter",0)) != 6:
        errors.append("Lighthouse identity mismatch")
        return
    var points: Variant = record.get("story_points",{})
    if not (points is Dictionary):
        errors.append("Lighthouse story locations missing")
        return
    for marker in MAIN_IDS:
        if not _valid_cell((points as Dictionary).get(marker,[])):
            errors.append("Bad story marker: "+marker)
    var fragments: Variant = record.get("fragments",[])
    if not (fragments is Array):
        errors.append("Lighthouse fragments missing")
        return
    var found: Dictionary = {}
    for fragment in fragments:
        if not (fragment is Dictionary):
            continue
        var id: String = str(fragment.get("id",""))
        if id in REQUIRED and not found.has(id) and _valid_cell(fragment.get("cell",[])) and not str(fragment.get("first_text","")).is_empty():
            found[id] = true
    if found.size() != 3 or record.get("order",[]) != REQUIRED:
        errors.append("Three distinct wick fragments required")
    var testimony: Variant = record.get("testimonies",[])
    var seen: Dictionary = {}
    if testimony is Array:
        for item in testimony:
            if item is Dictionary:
                var t_id: String = str(item.get("id",""))
                if t_id.is_empty() or seen.has(t_id) or str(item.get("line","")).is_empty():
                    errors.append("Duplicate or empty witness")
                else:
                    seen[t_id] = true
    if seen.size()!=4:
        errors.append("Four distinct shared testimonies required")
    if errors.is_empty():
        data = record.duplicate(true)

func _valid_cell(raw: Variant) -> bool:
    return raw is Array and raw.size()==2 and int(raw[0])>=3 and int(raw[0])<=94 and int(raw[1])>=3 and int(raw[1])<=48

func ready() -> bool:
    return not data.is_empty() and errors.is_empty()

func story_cell(id: String) -> Vector2i:
    if not ready() or id not in MAIN_IDS:
        return Vector2i(-1,-1)
    var point: Array = data.get("story_points",{}).get(id,[])
    return Vector2i(int(point[0]),int(point[1]))

func fragments() -> Array:
    return (data.get("fragments",[]) as Array).duplicate(true) if ready() else []

func fragment(id: String) -> Dictionary:
    if not ready() or id not in REQUIRED:
        return {}
    for record in data.get("fragments",[]):
        if record is Dictionary and str(record.get("id",""))==id:
            return record.duplicate(true)
    return {}

func snapshot(progress) -> Dictionary:
    if progress == null:
        return {}
    var raw: Variant = progress.rpg.get(SAVE_BUCKET,{})
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}

func next_required(progress) -> String:
    var state: Dictionary = snapshot(progress)
    for id in REQUIRED:
        if not bool(state.get(id,false)):
            return id
    return ""

func all_fragments_found(progress) -> bool:
    return ready() and next_required(progress).is_empty()

func inspect(progress,id: String) -> Dictionary:
    var record: Dictionary = fragment(id)
    if progress == null or record.is_empty():
        return {"ok":false,"changed":false,"message":"灯塔碎片位置不存在。"}
    var state: Dictionary = snapshot(progress)
    if bool(state.get(id,false)):
        return {"ok":true,"changed":false,"message":str(record.get("repeat_text","灯芯已记录。"))}
    if next_required(progress)!=id:
        return {"ok":true,"changed":false,"message":"请沿正式山路先调查海堤供能室，再到塔底维修箱，最后登上塔顶取得第三枚灯芯。"}
    state[id]=true
    progress.rpg[SAVE_BUCKET]=state
    return {"ok":true,"changed":true,"message":"【%s】%s" % [
        str(record.get("title","灯芯碎片")),
        str(record.get("first_text",""))]}

func testimony_rows() -> Array:
    return (data.get("testimonies",[]) as Array).duplicate(true) if ready() else []
