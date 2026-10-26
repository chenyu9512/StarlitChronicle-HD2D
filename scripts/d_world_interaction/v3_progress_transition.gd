extends RefCounted
## D Batch 0.3: a single durable checkpoint for a V3 progression mutation.
## No UI, world I/O, event signal or auxiliary save inside mutator.
## Works on V3 FirstActState and on isolated fault-injection fixtures.
static func commit(progress: Object, mutator: Callable) -> Dictionary:
    if progress == null or not mutator.is_valid():
        return {"ok":false,"reason":"invalid_transition"}
    if not progress.has_method("_pack") or not progress.has_method("restore_snapshot") or not progress.has_method("save"):
        return {"ok":false,"reason":"invalid_v3_state"}
    var old_value: Variant = progress.call("_pack")
    if not (old_value is Dictionary):
        return {"ok":false,"reason":"invalid_snapshot"}
    var before: Dictionary = (old_value as Dictionary).duplicate(true)
    var changed: Variant = mutator.call()
    if not (changed is Dictionary) or not bool(changed.get("ok",false)):
        progress.call("restore_snapshot",before)
        return {"ok":false,"reason":"transition_rejected"}
    if not bool(progress.call("save")):
        progress.call("restore_snapshot",before)
        return {"ok":false,"reason":"save_failed"}
    return {"ok":true,"mutation":changed}
