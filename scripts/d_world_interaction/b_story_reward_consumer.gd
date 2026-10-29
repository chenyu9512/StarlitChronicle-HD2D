extends RefCounted
## D-line durable consumer for B.story_runtime reward_outbox.
## B V2 is an at-least-once producer; FirstAct V3 is the authority for payouts.
## It MUST NOT instantiate StoryRuntime in the main game or simulate story wins.
const Ledger = preload("res://scripts/d_world_interaction/v3_reward_ledger.gd")

static func _is_nonnegative_number(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and float(value) >= 0.0 and float(value) <= 10000000.0

static func consume_one(runtime: Object, progress: Object, core: Object, payload: Dictionary) -> Dictionary:
    if runtime == null or progress == null or core == null:
        return {"ok":false,"reason":"missing_runtime_or_consumer"}
    if not runtime.has_method("pending_reward_receipts") or not runtime.has_method("acknowledge_reward"):
        return {"ok":false,"reason":"invalid_b_story_api"}
    var event_id: String = str(payload.get("event_id",""))
    if event_id.is_empty() or event_id.length() > 160 or not event_id.begins_with("b.story."):
        return {"ok":false,"reason":"invalid_b_reward_id"}
    if not bool(payload.get("receipt_required",false)):
        return {"ok":false,"reason":"missing_b_receipt_requirement"}
    var queued_value: Variant = runtime.call("pending_reward_receipts")
    if not (queued_value is Dictionary):
        return {"ok":false,"reason":"invalid_b_outbox"}
    var queued: Dictionary = queued_value
    if not queued.has(event_id) or not (queued[event_id] is Dictionary):
        return {"ok":false,"reason":"b_reward_not_pending"}
    # Never accept a forged / changed payload with a previously valid event ID.
    if (queued[event_id] as Dictionary) != payload:
        return {"ok":false,"reason":"b_reward_payload_mismatch"}
    var kind: String = str(payload.get("type",""))
    if kind not in ["","grant"]:
        return {"ok":false,"reason":"unsupported_b_reward_type"}
    for field in ["xp","gold"]:
        if not _is_nonnegative_number(payload.get(field,0)):
            return {"ok":false,"reason":"invalid_reward_"+field}
    var xp: int = int(payload.get("xp",0))
    var gold: int = int(payload.get("gold",0))
    var page: String = str(payload.get("lost_page",""))
    if not page.is_empty():
        if not page.begins_with("page_") or page.length() != 7 or not page.substr(5).is_valid_int():
            return {"ok":false,"reason":"invalid_lost_page"}
        if int(page.substr(5)) < 1 or int(page.substr(5)) > 12:
            return {"ok":false,"reason":"unknown_lost_page"}
    # Story catalogue normally pays XP, gold and the lost-page flag only.
    # Extra unknown economic kinds require an explicit versioned contract.
    if payload.has("item_id") or payload.has("items") or payload.has("potions"):
        return {"ok":false,"reason":"unsupported_b_item_contract"}
    var intent: Dictionary = {"source":"b_story_reward","event_id":event_id,
        "xp":xp,"gold":gold,"lost_page":page}
    var mutation: Callable = func() -> Dictionary:
        var levels: Array[String] = progress.give_rewards(xp,gold)
        if not page.is_empty():
            progress.flags["world."+page] = true
            var collected: bool = true
            for number in range(1,13):
                if not bool(progress.flags.get("world.page_%02d" % number,false)):
                    collected = false
                    break
            if collected:
                progress.flags["world.all_twelve_pages"] = true
        return {"ok":true,"xp":xp,"gold":gold,"lost_page":page,"levels":levels}
    var saved: Dictionary = Ledger.settle(progress,event_id,intent,mutation)
    if not bool(saved.get("ok",false)):
        return {"ok":false,"reason":str(saved.get("reason","v3_save_failed")),"v3_saved":false}
    # ACK only after V3 success. If ACK write fails, B keeps the outbox and
    # the replay sees a durable V3 receipt, so the player never gets paid twice.
    var acknowledged: bool = bool(runtime.call("acknowledge_reward",event_id))
    return {"ok":true,"v3_saved":true,"acknowledged":acknowledged,
        "applied":bool(saved.get("applied",false)),
        "repeated":bool(saved.get("repeated",false)),
        "event_id":event_id}

static func drain_pending(runtime: Object, progress: Object, core: Object) -> Dictionary:
    if runtime == null or not runtime.has_method("pending_reward_receipts"):
        return {"ok":false,"reason":"invalid_b_story_api"}
    var pending_value: Variant = runtime.call("pending_reward_receipts")
    if not (pending_value is Dictionary):
        return {"ok":false,"reason":"invalid_b_outbox"}
    var pending: Dictionary = pending_value
    var keys: Array[String] = []
    for key in pending.keys():
        keys.append(str(key))
    keys.sort()
    var applied: int = 0
    var confirmed: int = 0
    for event_id in keys:
        if not (pending[event_id] is Dictionary):
            return {"ok":false,"reason":"invalid_pending_payload"}
        var result: Dictionary = consume_one(runtime,progress,core,pending[event_id])
        if not bool(result.get("ok",false)):
            return {"ok":false,"reason":result.get("reason","consumer_failed"),
                "applied":applied,"acknowledged":confirmed,"failed_id":event_id}
        if bool(result.get("applied",false)):
            applied += 1
        if bool(result.get("acknowledged",false)):
            confirmed += 1
        else:
            return {"ok":false,"reason":"b_ack_failed_after_v3_commit",
                "v3_saved":true,"applied":applied,"acknowledged":confirmed,
                "failed_id":event_id}
    return {"ok":true,"applied":applied,"acknowledged":confirmed}
