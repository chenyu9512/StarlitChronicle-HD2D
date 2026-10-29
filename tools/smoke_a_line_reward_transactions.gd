extends SceneTree
## A-line P0 transaction contract smoke; no writes to player save files.
const Tx = preload("res://scripts/battle_reward_transaction.gd")
const State = preload("res://scripts/first_act_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, why: String) -> void:
    if not ok:
        failures.append(why)

func _run() -> void:
    var state = State.new()
    var story_id: String = Tx.make_id(true,3,"boss.ch003/tide_guard")
    check(story_id == Tx.make_id(true,3,"boss.ch003/tide_guard"),"boss transaction ID must be stable")
    check(not Tx.already_applied(state.rpg,story_id),"new save already settled boss")
    check(Tx.mark_applied(state.rpg,story_id,{"chapter":3,"xp":100,"gold":30}),"initial boss claim rejected")
    check(not Tx.mark_applied(state.rpg,story_id),"duplicate boss claim accepted")
    check(Tx.already_applied(state.rpg,story_id),"committed boss missing from ledger")
    var saved: Dictionary = state._pack().duplicate(true)
    var loaded = State.new()
    check(loaded.restore_snapshot(saved),"V3 restore failed with transaction ledger")
    check(Tx.already_applied(loaded.rpg,story_id),"boss claim disappeared after reload")
    var random_a: String = Tx.make_id(false,3)
    var random_b: String = Tx.make_id(false,3)
    check(Tx.valid_id(random_a),"invalid random transaction ID")
    check(random_a != random_b,"two random encounters reused the same transaction ID")
    check(Tx.mark_applied(loaded.rpg,random_a,{"chapter":3}),"random claim rejected")
    check(not Tx.mark_applied(loaded.rpg,random_a),"duplicate random claim accepted")
    check(not Tx.mark_applied(loaded.rpg,"",{}),"empty claim accepted")
    check(not Tx.mark_applied(loaded.rpg,"boss:",{}),"malformed boss claim accepted")
    var old_save = State.new()
    check(not Tx.already_applied(old_save.rpg,story_id),"legacy V3 without ledger became invalid")
    if failures.is_empty():
        print("PASS: A-line stable boss IDs, random IDs, duplicate claim rejection and V3 reload persistence")
        quit(0)
        return
    for problem in failures:
        push_error(problem)
    quit(1)
