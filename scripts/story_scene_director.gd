extends RefCounted
## Stage19-3: canonical evidence dressing for 120 authored quest locations.
## Never changes original quest rewards or converts a sector hub into a fabricated submap.
const SOURCE: String = "res://story/data/phase19_scene_dressing.json"
const VALID_PROPS: Array[String] = [
    "crate","sea_crystal","star_lantern","barrel","medicine_basket","flowerpot"
]
var dossiers: Dictionary = {}
var errors: Array[String] = []

func _init() -> void:
    if not FileAccess.file_exists(SOURCE):
        errors.append("scene dressing missing")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not (parsed is Dictionary):
        errors.append("scene dressing malformed")
        return
    var doc: Dictionary = parsed
    for entry in doc.get("quests",[]):
        if not (entry is Dictionary):
            continue
        var id: String = str(entry.get("quest_id",""))
        if id.is_empty() or dossiers.has(id):
            errors.append("duplicate quest dressing " + id)
            continue
        if str(entry.get("evidence_prop","")) not in VALID_PROPS:
            errors.append("unknown clue artwork " + id)
            continue
        for key in ["witness_name","evidence_label","record_label","observation","later_record"]:
            if str(entry.get(key,"")).strip_edges().is_empty():
                errors.append("missing " + key + " for " + id)
        dossiers[id] = entry
    if dossiers.size() != 120:
        errors.append("120 separate original quest dossiers required")

func dossier(quest_id: String) -> Dictionary:
    return dossiers.get(quest_id,{})

func stage(quest_id: String,event: Dictionary,step: int) -> Dictionary:
    var info: Dictionary = dossier(quest_id)
    if info.is_empty() or step < 0 or step > 2:
        return {}
    var witness: String = str(info.get("witness_name","见证人"))
    var place: String = str(info.get("location",""))
    var action: String = str(event.get("player_action","")).strip_edges()
    var kind: String = str(event.get("kind","followup"))
    var phase: String = "回访" if kind == "revisit" else ("社区" if kind == "community" else "调查")
    var label: String = ""
    var role: String = ["npc","evidence","notice"][step]
    var prop: String = ""
    var prompt: String = ""
    var action_label: String = ""
    match step:
        0:
            label = witness + " · " + phase
            prompt = "与%s在%s核对「%s」的后续。" % [witness,place,str(event.get("title",""))]
            action_label = "询问当事人"
        1:
            label = str(info.get("evidence_label","现场证据"))
            prompt = "现场证物：%s。\n原调查记录：%s" % [label,str(info.get("observation",""))]
            action_label = "检查实物并核对记录"
            prop = str(info.get("evidence_prop","sea_crystal"))
        2:
            label = str(info.get("record_label","后续公告"))
            prompt = "回访记录：%s。\n原处理结果：%s" % [label,str(info.get("later_record",""))]
            if not action.is_empty():
                prompt += "\n当前后续目标：" + action
            action_label = "核对当事人意见并登记"
            prop = "sign"
    return {"role":role,"label":label,"prompt":prompt,"action_label":action_label,
        "prop":prop,"quest_id":quest_id,"branch":str(event.get("branch","")),
        "kind":kind, "step":step,"location":place}

func evidence_for(quest_id: String) -> String:
    return str(dossier(quest_id).get("observation",""))

func finish_record(quest_id: String) -> String:
    return str(dossier(quest_id).get("later_record",""))
