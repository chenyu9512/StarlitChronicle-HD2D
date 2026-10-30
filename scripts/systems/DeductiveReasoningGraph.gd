class_name DeductiveReasoningGraph
extends RefCounted
## Knowledge types are epistemic labels, not truth permissions.
## Pure, evidence-backed deductions; neither signals nor results create
## quest rewards, chapter completion flags or invented proof.
enum EpistemicType {
    HARDWARE_LOG, PHYSICAL_TRACE, SUBJECT_TESTIMONY,
    PENDING_HYPOTHESIS, SYNTHESIZED_TRUTH
}
const RULES: Dictionary = {
    "DEDUCE_CH001_SALT_RECEIPT":{
        "chapter":1,"inputs":["trace_ch001_blue_salt","trace_ch001_receipt_indent"],
        "outcome":"FACT_ESTABLISHED","title":"退信在本地被截留"
    },
    "DEDUCE_CH007_SEAL_NOTCH":{
        "chapter":7,"inputs":["log_ch007_rejected_notice","trace_ch007_seal_rubbing"],
        "outcome":"FACT_ESTABLISHED","title":"多份退件使用同一缺口印章"
    },
    "DEDUCE_CH008_RELIEF_EXONERATION":{
        "chapter":8,"inputs":["hyp_ch008_relief_station_suspicion",
            "trace_ch008_armory_arrow_serial","trace_ch008_requisition_ledger"],
        "outcome":"INNOCENCE_PROVEN","title":"流民嫌疑得到物证反驳"
    },
    "DEDUCE_CH040_PARALLEL_ARCHIVE":{
        "chapter":40,"inputs":["testimony_ch040_east_guard_opened",
            "testimony_ch040_west_citizen_sealed"],
        "outcome":"PARALLEL_TESTIMONY_ARCHIVE",
        "title":"东侧放行与西门封锁的见证并列保存"
    }
}
const INPUT_TYPES: Dictionary = {
    "trace_ch001_blue_salt":EpistemicType.PHYSICAL_TRACE,
    "trace_ch001_receipt_indent":EpistemicType.PHYSICAL_TRACE,
    "log_ch007_rejected_notice":EpistemicType.HARDWARE_LOG,
    "trace_ch007_seal_rubbing":EpistemicType.PHYSICAL_TRACE,
    "hyp_ch008_relief_station_suspicion":EpistemicType.PENDING_HYPOTHESIS,
    "trace_ch008_armory_arrow_serial":EpistemicType.PHYSICAL_TRACE,
    "trace_ch008_requisition_ledger":EpistemicType.PHYSICAL_TRACE,
    "testimony_ch040_east_guard_opened":EpistemicType.SUBJECT_TESTIMONY,
    "testimony_ch040_west_citizen_sealed":EpistemicType.SUBJECT_TESTIMONY
}

static func _evidence_seen(rpg: Dictionary, evidence_id: String, point: String) -> bool:
    var collection: Variant = rpg.get("canon_evidence",{})
    if not (collection is Dictionary):
        return false
    var entry: Variant = collection.get(evidence_id,{})
    return entry is Dictionary and bool(entry.get(point,false))

static func recorded_nodes(rpg: Dictionary, flags: Dictionary) -> Dictionary:
    var nodes: Dictionary = {}
    var facts: Array = [
        ["trace_ch001_blue_salt","ev_ch001_envelope","back_salt"],
        ["trace_ch001_receipt_indent","ev_ch001_envelope","indent_mark"],
        ["trace_ch007_seal_rubbing","ev_ch007_rejected_letters","seal_rubbing"],
        ["hyp_ch008_relief_station_suspicion","ev_ch008_caravan_site","spilled_powder"],
        ["trace_ch008_armory_arrow_serial","ev_ch008_caravan_site","arrow_shaft"]
    ]
    for record in facts:
        if _evidence_seen(rpg,str(record[1]),str(record[2])):
            nodes[record[0]]={"id":record[0],
                "type":INPUT_TYPES[record[0]],"source":"canon_evidence",
                "chapter":int(str(record[0]).substr(8,3))}
    # Official refusal is never automatically accepted as truth.
    if bool(flags.get("ch007.evidence",false)) and             _evidence_seen(rpg,"ev_ch007_rejected_letters","seal_rubbing"):
        nodes["log_ch007_rejected_notice"]={
            "id":"log_ch007_rejected_notice","type":EpistemicType.HARDWARE_LOG,
            "source":"story.ch007 + verified stamp"}
    # The seizure ledger must be inspected as a real field object (not inferred
    # from a powder hypothesis, or from having completed chapter 8).
    var sources: Variant = rpg.get("deductive_physical_sources_v1",{})
    if sources is Dictionary:
        var requisition: Variant = sources.get("ch008_requisition_ledger",{})
        if requisition is Dictionary and                 str(requisition.get("source",""))=="world_field_inspection" and                 bool(requisition.get("requisition_batch_read",false)):
            nodes["trace_ch008_requisition_ledger"]={
                "id":"trace_ch008_requisition_ledger",
                "type":EpistemicType.PHYSICAL_TRACE,
                "source":"ch008_requisition_ledger"}
    # Chapter 40's actual mechanic saves two individual witness receipts.
    var mechanic: Variant = rpg.get("chapter_mechanics_v2",{})
    if mechanic is Dictionary:
        var ch40: Variant = mechanic.get("ch040",{})
        if ch40 is Dictionary:
            var completed: Variant = ch40.get("completed_actions",[])
            if completed is Array and completed.size() >= 1 and                     str(ch40.get("open_gate_testimony",""))=="east_gate_witness":
                nodes["testimony_ch040_east_guard_opened"]={
                    "id":"testimony_ch040_east_guard_opened",
                    "type":EpistemicType.SUBJECT_TESTIMONY,"source":"ch040_east_gate_witness"}
            if completed is Array and completed.size() >= 2 and                     str(ch40.get("sealed_city_testimony",""))=="west_citizen_witness":
                nodes["testimony_ch040_west_citizen_sealed"]={
                    "id":"testimony_ch040_west_citizen_sealed",
                    "type":EpistemicType.SUBJECT_TESTIMONY,"source":"ch040_west_citizen_witness"}
    return nodes

static func evaluate(rule_id: String, rpg: Dictionary, flags: Dictionary) -> Dictionary:
    var rule: Dictionary = RULES.get(rule_id,{})
    if rule.is_empty():
        return {"ok":false,"reason":"unknown_reasoning_rule"}
    var nodes: Dictionary = recorded_nodes(rpg,flags)
    var missing: Array[String] = []
    for id in rule["inputs"]:
        if not nodes.has(str(id)):
            missing.append(str(id))
    if not missing.is_empty():
        return {"ok":false,"reason":"source_evidence_missing","missing":missing}
    # Two testimony nodes never automatically imply one universal account.
    var outcome: String = str(rule["outcome"])
    var result: Dictionary = {"ok":true,"rule_id":rule_id,"title":rule["title"],
        "outcome":outcome,"inputs":(rule["inputs"] as Array).duplicate(),
        "sources":nodes}
    if outcome=="PARALLEL_TESTIMONY_ARCHIVE":
        result["archive_mode"]="retain_parallel_sources_not_one_conclusion"
    if outcome=="INNOCENCE_PROVEN":
        result["inference_status"]="exonerated_not_convicted"
    return result

static func available_rules(chapter: int) -> Array[String]:
    var ids: Array[String]=[]
    for id in RULES:
        if int(RULES[id]["chapter"]) <= chapter:
            ids.append(str(id))
    ids.sort()
    return ids
