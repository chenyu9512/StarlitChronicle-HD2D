extends SceneTree
## D-line fault injection; fake V3 snapshots, never touching player save files.
const Ledger = preload("res://scripts/d_world_interaction/v3_reward_ledger.gd")

class FakeProgress:
    extends RefCounted
    var rpg: Dictionary = {}
    var gold: int = 0
    var fail_save: bool = false
    var on_disk: Dictionary = {}
    func _pack() -> Dictionary:
        return {"rpg": rpg.duplicate(true), "gold": gold}
    func restore_snapshot(d: Dictionary) -> bool:
        rpg = d["rpg"].duplicate(true)
        gold = int(d["gold"])
        return true
    func save() -> bool:
        if fail_save:
            return false
        on_disk = _pack().duplicate(true)
        return true

var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
func _run() -> void:
    var p := FakeProgress.new()
    var intent: Dictionary = {"source":"qa:battle","encounter":"qa001","xp":12,"gold":35}
    var mutation: Callable = func() -> Dictionary:
        p.gold += 35
        return {"ok":true,"gold":35}
    var first: Dictionary = Ledger.settle(p,"qa:battle:001",intent,mutation)
    check(bool(first.get("applied",false)) and p.on_disk.get("gold",-1)==35,"initial commit failed")
    var second: Dictionary = Ledger.settle(p,"qa:battle:001",intent,mutation)
    check(bool(second.get("repeated",false)) and p.gold==35,"duplicate payout")
    var conflict: Dictionary = Ledger.settle(p,"qa:battle:001",{"source":"qa:battle","gold":999},mutation)
    check(str(conflict.get("reason",""))=="event_id_collision","nonce collision accepted")
    var reloaded := FakeProgress.new()
    reloaded.restore_snapshot(p.on_disk)
    var reload_mutation: Callable = func() -> Dictionary:
        reloaded.gold += 35
        return {"ok":true}
    var reload: Dictionary = Ledger.settle(reloaded,"qa:battle:001",intent,reload_mutation)
    check(bool(reload.get("repeated",false)) and reloaded.gold==35,"restarted duplicate payout")
    reloaded.fail_save = true
    var before: Dictionary = reloaded._pack().duplicate(true)
    var intent2: Dictionary = {"source":"qa:battle","encounter":"qa002"}
    var failed: Dictionary = Ledger.settle(reloaded,"qa:battle:002",intent2,reload_mutation)
    check(str(failed.get("reason",""))=="save_failed" and reloaded._pack()==before,"failed save leaked state")
    reloaded.fail_save = false
    var retry: Dictionary = Ledger.settle(reloaded,"qa:battle:002",intent2,reload_mutation)
    check(bool(retry.get("applied",false)) and reloaded.gold==70,"safe retry failed")
    var invalid: Dictionary = Ledger.settle(reloaded,"",intent,reload_mutation)
    check(str(invalid.get("reason",""))=="invalid_event_id","empty ID accepted")
    var bad_mutation: Callable = func() -> Dictionary:
        reloaded.gold += 99
        return {"ok":false}
    var rejected: Dictionary = Ledger.settle(reloaded,"qa:battle:003",intent,bad_mutation)
    check(str(rejected.get("reason",""))=="mutation_failed" and reloaded.gold==70,"failed mutation not rolled back")
    if failures.is_empty():
        print("PASS: D isolated V3 receipts, replay, restart, collision, failed-save rollback")
        quit(0)
    else:
        for problem in failures:
            push_error(problem)
        quit(1)
