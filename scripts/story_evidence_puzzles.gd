extends RefCounted
## Phase19-5: optional evidence deductions. Never controls the canonical five-stage quest.
const SOURCE: String = "res://story/data/phase19_lost_page_puzzles.json"
var cases: Dictionary = {}
var errors: Array[String] = []

func _init() -> void:
    if not FileAccess.file_exists(SOURCE):
        errors.append("missing evidence cases")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not (parsed is Dictionary):
        errors.append("invalid evidence case JSON")
        return
    for raw in parsed.get("quests",[]):
        if not (raw is Dictionary):
            continue
        var record: Dictionary = raw
        var id: String = str(record.get("quest_id",""))
        if id.is_empty() or cases.has(id) or record.get("options",[]).size()!=3:
            errors.append("duplicate or incomplete room case: " + id)
            continue
        var correct: String = str(record.get("correct_option_id",""))
        if not record.get("options",[]).any(func(option): return str(option.get("id",""))==correct):
            errors.append("case has no answer: " + id)
            continue
        cases[id] = record
    if cases.size()!=12:
        errors.append("expected 12 individual puzzles")

func entry(quest_id: String) -> Dictionary:
    return cases.get(quest_id,{})

func can_attempt(rpg: Dictionary,quest_id: String) -> bool:
    if not cases.has(quest_id) or solved(rpg,quest_id):
        return false
    var observed: Dictionary = rpg.get("quest_gallery",{}).get(quest_id,{})
    return bool(observed.get("0",false)) and bool(observed.get("1",false))

func solved(rpg: Dictionary,quest_id: String) -> bool:
    return bool(rpg.get("quest_puzzles",{}).get(quest_id,{}).get("solved",false))

func result(rpg: Dictionary,quest_id: String,answer_id: String,chapter: int) -> Dictionary:
    if not can_attempt(rpg,quest_id):
        return {"accepted":false,"solved":false,"message":"请先核对两处原始证物。"}
    var data: Dictionary = entry(quest_id)
    if not data.get("options",[]).any(func(option): return str(option.get("id",""))==answer_id):
        return {"accepted":false,"solved":false,"message":"无效的记录选择。"}
    if not (rpg.get("quest_puzzles") is Dictionary):
        rpg["quest_puzzles"] = {}
    var container: Dictionary = rpg["quest_puzzles"]
    var old: Dictionary = container.get(quest_id,{})
    var attempts: int = int(old.get("attempts",0))+1
    var ok: bool = answer_id==str(data.get("correct_option_id",""))
    container[quest_id] = {
        "solved":ok,"attempts":attempts,"last_choice":answer_id,
        "chapter":chapter if ok else -1,
        "mechanic":str(data.get("mechanic",""))
    }
    return {"accepted":true,"solved":ok,"message":str(data.get("success","")) if ok else str(data.get("retry","")), "attempts":attempts}
