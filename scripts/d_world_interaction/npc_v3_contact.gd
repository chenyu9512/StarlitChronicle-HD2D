extends RefCounted
## D consumes B's read-only preview and persists the first-contact marker
## with its stable receipt in the authoritative FirstAct V3 checkpoint.
const Ledger = preload("res://scripts/d_world_interaction/v3_reward_ledger.gd")

static func converse(progress: Object, town_life: Object, npc_id: String,
        region_id: String, map_id: String, clock: Dictionary) -> Dictionary:
    if progress == null or town_life == null or npc_id.is_empty() or map_id.is_empty():
        return {"ok":false,"reason":"invalid_npc_context"}
    if not town_life.has_method("preview_talk") or not town_life.has_method("citizen"):
        return {"ok":false,"reason":"missing_b_preview"}
    var npc: Dictionary = town_life.citizen(npc_id)
    if npc.is_empty() or str(npc.get("map_id",""))!=map_id or str(npc.get("region_id",""))!=region_id:
        return {"ok":false,"reason":"npc_wrong_map"}
    var preview: Dictionary = town_life.preview_talk(npc_id,region_id,clock,progress)
    if str(preview.get("npc_id",""))!=npc_id:
        return {"ok":false,"reason":"npc_preview_mismatch"}
    if not bool(preview.get("first",false)):
        return {"ok":true,"applied":false,"repeated":true,"preview":preview}
    var event_id: String = "b.npc.first."+npc_id
    if str(preview.get("event_id",""))!=event_id or not bool(preview.get("requires_save",false)):
        return {"ok":false,"reason":"npc_event_mismatch"}
    var intent: Dictionary = {"source":"b_npc_first_contact","npc_id":npc_id,
        "map_id":map_id,"region_id":region_id}
    var mutation: Callable = func() -> Dictionary:
        var recorded: Variant = progress.rpg.get("talked_to",{})
        if not (recorded is Dictionary):
            return {"ok":false,"reason":"invalid_talked_to_bucket"}
        var talked: Dictionary = (recorded as Dictionary).duplicate(true)
        talked[npc_id] = true
        progress.rpg["talked_to"] = talked
        return {"ok":true,"npc_id":npc_id}
    var result: Dictionary = Ledger.settle(progress,event_id,intent,mutation)
    if not bool(result.get("ok",false)):
        return {"ok":false,"reason":str(result.get("reason","v3_save_failed")),
            "preview":preview}
    result["preview"] = preview
    return result
