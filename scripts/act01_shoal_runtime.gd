extends RefCounted
## Chapter-five rescue field data. Only the D-line V3 commit writes its state.
## Never mutate chapter flags, battle rewards or route ownership here.
const SOURCE: String = "res://data/levels/act01_shoal_runtime_v1.json"
const MAP_ID: String = "map_coast_03"
const CHAPTER: int = 5
const SAVE_BUCKET: String = "act01_shoal_observations_v1"
const REQUIRED: Array[String] = ["red_flag","star_chain","retreat_line"]
const STORY_KEYS: Array[String] = ["key_npc","clue","witness","crisis","resolve"]
var data: Dictionary = {}
var errors: Array[String] = []

func _init() -> void:
    if not FileAccess.file_exists(SOURCE):
        errors.append("Missing authored whale shoal")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not (parsed is Dictionary):
        errors.append("Invalid whale shoal JSON")
        return
    var record: Dictionary = parsed
    if str(record.get("schema","")) != "starlit.act01.shoal_runtime.v1" or str(record.get("map_id","")) != MAP_ID or int(record.get("chapter",0)) != CHAPTER:
        errors.append("Whale shoal identity differs from canonical chapter five")
        return
    var points: Variant = record.get("story_points",{})
    var visits: Variant = record.get("investigations",[])
    if not (points is Dictionary) or not (visits is Array):
        errors.append("Whale shoal coordinates unavailable")
        return
    for key in STORY_KEYS:
        if not _valid_cell((points as Dictionary).get(key,[])):
            errors.append("Missing shoal story point: "+key)
    var observed: Dictionary = {}
    for item in visits:
        if not (item is Dictionary):
            continue
        var id: String = str(item.get("id",""))
        if id in REQUIRED and not observed.has(id) and _valid_cell(item.get("cell",[])) and not str(item.get("first_text","")).is_empty():
            observed[id] = true
    if observed.size() != REQUIRED.size() or (record.get("order",[]) as Array) != REQUIRED:
        errors.append("Whale shoal evidence is incomplete or out of sequence")
    if errors.is_empty():
        data = record.duplicate(true)

func _valid_cell(value: Variant) -> bool:
    return value is Array and value.size()==2 and int(value[0]) >= 3 and int(value[0]) <= 90 and int(value[1]) >= 3 and int(value[1]) <= 50

func ready() -> bool:
    return not data.is_empty() and errors.is_empty()

func story_cell(id: String) -> Vector2i:
    if not ready() or id not in STORY_KEYS:
        return Vector2i(-1,-1)
    var raw: Array = data.get("story_points",{}).get(id,[])
    return Vector2i(int(raw[0]),int(raw[1]))

func investigations() -> Array:
    return (data.get("investigations",[]) as Array).duplicate(true) if ready() else []

func entry(id: String) -> Dictionary:
    if id not in REQUIRED or not ready():
        return {}
    for item in data.get("investigations",[]):
        if item is Dictionary and str(item.get("id",""))==id:
            return item.duplicate(true)
    return {}

func snapshot(progress) -> Dictionary:
    if progress == null:
        return {}
    var value: Variant = progress.rpg.get(SAVE_BUCKET,{})
    return (value as Dictionary).duplicate(true) if value is Dictionary else {}

func next_required(progress) -> String:
    var value: Dictionary = snapshot(progress)
    for id in REQUIRED:
        if not bool(value.get(id,false)):
            return id
    return ""

func fully_observed(progress) -> bool:
    return ready() and next_required(progress).is_empty()

func inspect(progress,id: String) -> Dictionary:
    var record: Dictionary = entry(id)
    if progress == null or record.is_empty():
        return {"ok":false,"changed":false,"message":"当前没有可以操作的浅滩证物。"}
    var state: Dictionary = snapshot(progress)
    if bool(state.get(id,false)):
        return {"ok":true,"changed":false,"message":str(record.get("repeat_text","此处已经调查过。"))}
    if next_required(progress) != id:
        return {"ok":true,"changed":false,"message":"请先观察渔民红旗，再核对古兽星锁，最后确认撤离路线。"}
    state[id] = true
    progress.rpg[SAVE_BUCKET] = state
    return {"ok":true,"changed":true,"message":"【%s】%s" % [
        str(record.get("title","浅滩线索")),
        str(record.get("first_text",""))]}
