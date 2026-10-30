extends Node
## Shared, player-operated campaign mechanism. Mutations are committed by
## first_act's V3ProgressTransition before any canonical story choice opens.
const DATA_PATH: String = "res://story/runtime/chapter_mechanics_steps.json"
var chapter_id: String = ""
var stages: Array = []

func configure(id: String) -> bool:
    chapter_id = ""
    stages.clear()
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if not (raw is Dictionary):
        return false
    var chapters: Variant = raw.get("chapters", {})
    if not (chapters is Dictionary):
        return false
    var chosen: Variant = chapters.get(id, [])
    if not (chosen is Array) or chosen.is_empty():
        return false
    chapter_id = id
    stages = chosen.duplicate(true)
    return true

func _valid_receipt_prefix(state: Dictionary) -> bool:
    if chapter_id.is_empty() or stages.is_empty():
        return false
    var index: int = int(state.get("step",0))
    if index < 0 or index > stages.size():
        return false
    var saved: Variant = state.get("completed_actions",[])
    if not (saved is Array):
        return false
    var receipts: Array = saved
    if receipts.size() != index:
        return false
    for slot in range(index):
        if not (stages[slot] is Dictionary) or str(receipts[slot]) != str(stages[slot].get("correct","")):
            return false
    return bool(state.get("done",false)) == (index == stages.size())


func verified_complete(state: Dictionary) -> bool:
    return _valid_receipt_prefix(state) and bool(state.get("done",false))


func get_prompt(state: Dictionary) -> Dictionary:
    if not _valid_receipt_prefix(state):
        return {}
    var index: int = int(state.get("step",0))
    if bool(state.get("done",false)):
        return {"done":true}
    var stage: Dictionary = stages[index]
    return {"prompt":"%s · 机关调查 %d/%d\n%s" % [
        chapter_id,index+1,stages.size(),str(stage.get("prompt",""))],
        "options":(stage.get("options",[]) as Array).duplicate(true)}

func apply_action(state: Dictionary, action_id: String) -> Dictionary:
    var index: int = int(state.get("step",0))
    if not _valid_receipt_prefix(state) or bool(state.get("done",false)) or index < 0 or index >= stages.size():
        return {"ok":false,"message":"当前机关无效或已经完成。"}
    var stage: Dictionary = stages[index]
    if action_id != str(stage.get("correct","")):
        return {"ok":false,"message":"这项操作不符合现场安全规程或证据记录。"}
    var receipts: Array = (state.get("completed_actions",[]) as Array).duplicate(true)
    receipts.append(action_id)
    state["completed_actions"] = receipts
    state["step"] = index+1
    if chapter_id == "ch015":
        var jobs: Array = (state.get("trial_jobs",[]) as Array).duplicate(true)
        jobs.append(str(stage.get("job","")))
        state["trial_jobs"] = jobs
    if chapter_id == "ch029":
        state["buoys_calibrated"] = index+1
    if chapter_id == "ch036" and index == 1:
        state["voluntary_exit_restored"] = true
        state["mirror_lamp_rekindled"] = true
    if chapter_id == "ch040":
        if index == 0: state["open_gate_testimony"] = "east_gate_witness"
        if index == 1: state["sealed_city_testimony"] = "west_citizen_witness"
        if index == 2: state["archived_mode"] = "PARALLEL_PRESERVATION"
    # Chapter-local, save-backed evidence only; no fabricated canonical rewards.
    match chapter_id:
        "ch058":
            if index == 2: state["human_override_plan_reviewed"] = true
        "ch059":
            if index == 2: state["voluntary_charter_drafted"] = true
        "ch060":
            if index == 4: state["consensual_network_reviewed"] = true
        "ch064":
            state["sky_rail_alignment_count"] = index + 1
        "ch066":
            if index == 2: state["seven_lamps_witness_verified"] = true
        "ch071":
            if index == 2: state["hessian_testimony_reviewed"] = true
        "ch072":
            if index == 1: state["ending_review_complete"] = true
    state["done"] = index+1 == stages.size()
    return {"ok":true,"done":bool(state["done"]),
        "message":"操作已记录 %d/%d。仍需按原主线完成选择和真实战斗。" % [index+1,stages.size()]}
