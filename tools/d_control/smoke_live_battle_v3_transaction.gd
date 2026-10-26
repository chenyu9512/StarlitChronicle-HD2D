extends SceneTree
## Real GDScript fault injection for D BattleV3Settlement; no player save IO.
const Settlement = preload("res://scripts/d_world_interaction/battle_v3_settlement.gd")
const AReceipt = preload("res://scripts/battle_reward_transaction.gd")
const V3Ledger = preload("res://scripts/d_world_interaction/v3_reward_ledger.gd")

class FakeProgress:
    extends RefCounted
    var rpg: Dictionary = {}
    var flags: Dictionary = {}
    var gold: int = 20
    var xp: int = 0
    var chapter: int = 3
    var scene_index: int = 2
    var task_index: int = 1
    var dialogue_seen: bool = true
    var heal_count: int = 0
    var fail_save: bool = false
    var on_disk: Dictionary = {}
    func _pack() -> Dictionary:
        return {"rpg":rpg.duplicate(true),"flags":flags.duplicate(true),"gold":gold,
            "xp":xp,"chapter":chapter,"scene_index":scene_index,
            "task_index":task_index,"dialogue_seen":dialogue_seen,
            "heal_count":heal_count}
    func restore_snapshot(d: Dictionary) -> bool:
        rpg = d["rpg"].duplicate(true)
        flags = d["flags"].duplicate(true)
        gold = int(d["gold"])
        xp = int(d["xp"])
        chapter = int(d["chapter"])
        scene_index = int(d["scene_index"])
        task_index = int(d["task_index"])
        dialogue_seen = bool(d["dialogue_seen"])
        heal_count = int(d["heal_count"])
        return true
    func save() -> bool:
        if fail_save:
            return false
        on_disk = _pack().duplicate(true)
        return true
    func give_rewards(reward_xp: int, reward_gold: int) -> Array[String]:
        gold += reward_gold
        xp += reward_xp
        return ["XP+%d" % reward_xp]
    func heal_all() -> void:
        heal_count += 1

class FakeCore:
    extends RefCounted
    var progress: FakeProgress
    func _init(p: FakeProgress) -> void:
        progress = p
    func record_enemy_resolution(kind: String, id: String) -> void:
        var seen: Dictionary = progress.rpg.get("resolved",{})
        seen[kind + "/" + id] = int(seen.get(kind + "/" + id,0))+1
        progress.rpg["resolved"] = seen
    func award_job_xp(points: int, _is_boss: bool) -> Array[String]:
        progress.rpg["job_xp"] = int(progress.rpg.get("job_xp",0)) + points
        return ["JOB+%d" % points]
    func roll_monster_loot(monster_id: String) -> Array[String]:
        if monster_id.is_empty():
            return []
        progress.rpg["loot_count"] = int(progress.rpg.get("loot_count",0))+1
        return ["草药"]

var problems: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, label: String) -> void:
    if not ok:
        problems.append(label)

func _run() -> void:
    var id: String = "boss:boss.ch003/tide_guard"
    var enemies: Array = [{"boss_id":"boss.ch003/tide_guard","monster_id":"qa_monster"}]
    var p := FakeProgress.new()
    var core := FakeCore.new(p)
    var win: Dictionary = Settlement.settle_victory(p,core,id,3,true,enemies,"qa_monster",100,30)
    check(bool(win.get("applied",false)), "Boss first win was not persisted")
    check(p.xp==100 and p.gold==50 and p.scene_index==3, "Boss effects incorrect")
    check(p.on_disk.get("scene_index",-1)==3, "Boss scene not durable")
    check(AReceipt.already_applied(p.rpg,id), "A receipt missing")
    check(p.rpg.get(V3Ledger.BUCKET,{}).get("consumed",{}).has(id), "D receipt missing")
    var snapshot: Dictionary = p._pack().duplicate(true)
    var duplicate: Dictionary = Settlement.settle_victory(p,core,id,3,true,enemies,"qa_monster",100,30)
    check(bool(duplicate.get("repeated",false)) and p._pack()==snapshot, "Duplicate Boss replayed effects")
    var restarted := FakeProgress.new()
    restarted.restore_snapshot(p.on_disk)
    var restart_core := FakeCore.new(restarted)
    var replay: Dictionary = Settlement.settle_victory(restarted,restart_core,id,3,true,
        enemies,"qa_monster",100,30)
    check(bool(replay.get("repeated",false)) and restarted.gold==50, "Restart replayed Boss money")
    var legacy := FakeProgress.new()
    legacy.flags["ch003.battle_won"] = true
    var old: Dictionary = Settlement.settle_victory(legacy,FakeCore.new(legacy),id,3,true,
        enemies,"qa_monster",100,30)
    check(bool(old.get("repeated",false)) and legacy.gold==20, "Old V3 boss was paid again")

    var random_id: String = AReceipt.make_id(false,3)
    var fresh := FakeProgress.new()
    var random_core := FakeCore.new(fresh)
    fresh.fail_save = true
    var before: Dictionary = fresh._pack().duplicate(true)
    var failed: Dictionary = Settlement.settle_victory(fresh,random_core,random_id,3,false,
        enemies,"qa_monster",40,15)
    check(str(failed.get("reason",""))=="save_failed", "Save failure not propagated")
    check(fresh._pack()==before and fresh.on_disk.is_empty(), "Failed save leaked rewards")
    fresh.fail_save = false
    var retry: Dictionary = Settlement.settle_victory(fresh,random_core,random_id,3,false,
        enemies,"qa_monster",40,15)
    check(bool(retry.get("applied",false)) and fresh.gold==35, "Retry did not commit once")
    var random_duplicate: Dictionary = Settlement.settle_victory(fresh,random_core,random_id,3,false,
        enemies,"qa_monster",40,15)
    check(bool(random_duplicate.get("repeated",false)) and fresh.gold==35, "Random duplicate payout")
    var loss_id: String = AReceipt.make_id(false,3)
    var defeat: Dictionary = Settlement.settle_defeat(fresh,loss_id,3,false)
    check(bool(defeat.get("applied",false)) and fresh.gold==20 and fresh.heal_count==1,"Defeat not persisted")
    var repeat_loss: Dictionary = Settlement.settle_defeat(fresh,loss_id,3,false)
    check(bool(repeat_loss.get("repeated",false)) and fresh.gold==20,"Duplicate defeat penalty")
    if problems.is_empty():
        print("PASS: Batch 0.1 battle V3 single snapshot, legacy, nonce replay, save failure, restart and defeat")
        quit(0)
    else:
        for problem in problems:
            push_error(problem)
        quit(1)
