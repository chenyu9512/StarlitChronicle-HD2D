extends RefCounted
## One V3 state transaction for D-owned world effects. Never emits victory/reward
## signals; story and combat payouts must remain with A/B until shared integration.
const BUCKET: String = "d_world_interaction_v1"
const HOME_BUCKET: String = "home_investigations_v1"

static func _valid_effect(effect: Dictionary) -> bool:
    var kind: String=str(effect.get("type",""))
    if kind=="home_seen":
        return not str(effect.get("key","")).is_empty() and str(effect.get("phase","")) in ["before","after"]
    if kind=="set_flag":
        return str(effect.get("key","")).begins_with("world.d.") and effect.get("value",true) is bool
    if kind=="add_gold":
        return int(effect.get("amount",0))>0 and int(effect.get("amount",0))<=100000
    if kind=="add_item":
        return str(effect.get("item_id","")).begins_with("item_") and int(effect.get("count",0))>0 and int(effect.get("count",0))<=99
    return false

static func _apply(progress, effect: Dictionary) -> void:
    match str(effect.get("type","")):
        "home_seen":
            var all_saved: Dictionary=progress.rpg.get(HOME_BUCKET,{})
            var key: String=str(effect["key"])
            var record: Dictionary=all_saved.get(key,{})
            var phase: String=str(effect["phase"])
            record["seen_"+phase]=true
            record["last_phase"]=phase
            all_saved[key]=record
            progress.rpg[HOME_BUCKET]=all_saved
        "set_flag":
            progress.flags[str(effect["key"])]=bool(effect.get("value",true))
        "add_gold":
            progress.gold+=int(effect["amount"])
        "add_item":
            var item_id: String=str(effect["item_id"])
            progress.inventory[item_id]=int(progress.inventory.get(item_id,0))+int(effect["count"])

## Result schema: handled/dialogue/message/effects/animation/transition/event_id.
## An effect is persisted in the same authoritative V3 state as its nonce.
## It is never applied when save fails, and repeat event IDs cannot pay twice.
static func commit(progress, result: Dictionary) -> Dictionary:
    if progress==null or not bool(result.get("handled",false)):
        return {"handled":false,"saved":false,"reason":"unhandled"}
    var events: Array=result.get("effects",[])
    if events.is_empty():
        return {"handled":true,"saved":true,"applied":false,"result":result}
    var event_id: String=str(result.get("event_id",""))
    if event_id.is_empty():
        return {"handled":false,"saved":false,"reason":"missing_event_id"}
    for raw in events:
        if not (raw is Dictionary) or not _valid_effect(raw):
            return {"handled":false,"saved":false,"reason":"unsupported_effect"}
    var journal: Dictionary=progress.rpg.get(BUCKET,{})
    var consumed: Dictionary=journal.get("consumed",{})
    if bool(consumed.get(event_id,false)):
        return {"handled":true,"saved":true,"applied":false,"repeated":true,"result":result}
    var before: Dictionary=progress._pack().duplicate(true)
    for effect in events:
        _apply(progress,effect)
    consumed[event_id]=true
    journal["consumed"]=consumed
    journal["version"]=1
    progress.rpg[BUCKET]=journal
    if not progress.save():
        progress.restore_snapshot(before)
        return {"handled":false,"saved":false,"reason":"save_failed"}
    return {"handled":true,"saved":true,"applied":true,"result":result}
