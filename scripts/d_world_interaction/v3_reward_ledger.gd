extends RefCounted
## D-only V3 payout transaction (not connected to gameplay until Batch 0 freeze).
## Mutator MUST ONLY change fields serialized by progress._pack().
## Encounter nonce must be stable and persisted before beginning a battle.
const BUCKET: String = "d_reward_receipts_v1"
const MAX_EVENT_ID: int = 160

static func settle(progress: Object, event_id: String, intent: Dictionary, mutator: Callable) -> Dictionary:
    if progress == null or not progress.has_method("_pack") or not progress.has_method("restore_snapshot") or not progress.has_method("save"):
        return {"ok": false, "applied": false, "reason": "invalid_progress"}
    if event_id.strip_edges().is_empty() or event_id.length() > MAX_EVENT_ID or event_id != event_id.strip_edges():
        return {"ok": false, "applied": false, "reason": "invalid_event_id"}
    if intent.is_empty() or not (intent.get("source", null) is String) or str(intent["source"]).is_empty():
        return {"ok": false, "applied": false, "reason": "invalid_intent"}
    if not mutator.is_valid():
        return {"ok": false, "applied": false, "reason": "invalid_mutator"}
    var rpg_value: Variant = progress.get("rpg")
    if not (rpg_value is Dictionary):
        return {"ok": false, "applied": false, "reason": "missing_v3_rpg"}
    var rpg: Dictionary = rpg_value
    var journal_value: Variant = rpg.get(BUCKET, {})
    if not (journal_value is Dictionary):
        return {"ok": false, "applied": false, "reason": "invalid_ledger"}
    var journal: Dictionary = journal_value
    if int(journal.get("version", 1)) != 1:
        return {"ok": false, "applied": false, "reason": "unknown_ledger_version"}
    var consumed_value: Variant = journal.get("consumed", {})
    if not (consumed_value is Dictionary):
        return {"ok": false, "applied": false, "reason": "invalid_receipts"}
    var consumed: Dictionary = consumed_value
    if consumed.has(event_id):
        var receipt_value: Variant = consumed[event_id]
        if not (receipt_value is Dictionary) or receipt_value.get("intent", {}) != intent:
            return {"ok": false, "applied": false, "reason": "event_id_collision"}
        return {"ok": true, "applied": false, "repeated": true, "receipt": receipt_value.duplicate(true)}

    var snapshot_value: Variant = progress.call("_pack")
    if not (snapshot_value is Dictionary):
        return {"ok": false, "applied": false, "reason": "invalid_preimage"}
    var before: Dictionary = snapshot_value.duplicate(true)
    # No non-V3 writes, world events, external object mutations, or UI side effects here.
    var changed: Variant = mutator.call()
    if not (changed is Dictionary) or not bool(changed.get("ok", false)):
        progress.call("restore_snapshot", before)
        return {"ok": false, "applied": false, "reason": "mutation_failed"}
    var after_rpg: Variant = progress.get("rpg")
    if not (after_rpg is Dictionary):
        progress.call("restore_snapshot", before)
        return {"ok": false, "applied": false, "reason": "rpg_invalid_after_mutation"}
    var updated_rpg: Dictionary = after_rpg
    var post_journal: Variant = updated_rpg.get(BUCKET, {})
    if not (post_journal is Dictionary) or not (post_journal.get("consumed", {}) is Dictionary):
        progress.call("restore_snapshot", before)
        return {"ok": false, "applied": false, "reason": "ledger_modified_by_mutator"}
    var updated_journal: Dictionary = post_journal.duplicate(true)
    var updated_consumed: Dictionary = updated_journal.get("consumed", {}).duplicate(true)
    if updated_consumed.has(event_id):
        progress.call("restore_snapshot", before)
        return {"ok": false, "applied": false, "reason": "receipt_modified_by_mutator"}
    # Receipt and all V3 party/economy changes enter the SAME save snapshot.
    var receipt: Dictionary = {"intent": intent.duplicate(true), "version": 1}
    updated_consumed[event_id] = receipt
    updated_journal["version"] = 1
    updated_journal["consumed"] = updated_consumed
    updated_rpg[BUCKET] = updated_journal
    progress.set("rpg", updated_rpg)
    if not bool(progress.call("save")):
        progress.call("restore_snapshot", before)
        return {"ok": false, "applied": false, "reason": "save_failed"}
    return {"ok": true, "applied": true, "repeated": false, "receipt": receipt, "mutation": changed}
