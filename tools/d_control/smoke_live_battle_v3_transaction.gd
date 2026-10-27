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
    var progress
    func _init(p) -> void:
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
    var saved_journal: Dictionary = p.rpg.get(V3Ledger.BUCKET,{})
    var saved_receipts: Dictionary = saved_journal.get("consumed",{})
    check(saved_receipts.has(id), "D receipt missing")
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
    # Act-I Ch5/6 resolutions must share the same atomic save/receipt as
    # XP, money, boss victory and scene advance. A wrong result cannot pay.
    var beast := FakeProgress.new()
    beast.chapter = 5
    var beast_id: String = AReceipt.make_id(true,5,"boss.ch005")
    var wrong_beast: Dictionary = Settlement.settle_victory(
        beast,FakeCore.new(beast),beast_id,5,true,[],"",125,40,1,"legacy_story")
    check(str(wrong_beast.get("reason",""))=="invalid_beast_resolution",
        "Lethal result was accepted as nonlethal rescue")
    var freed: Dictionary = Settlement.settle_victory(
        beast,FakeCore.new(beast),beast_id,5,true,[],"",125,40,1,"nonlethal")
    check(bool(freed.get("applied",false)) and bool(beast.flags.get("ch005.beast_released",false)),
        "Star-chain rescue was not committed")
    check(bool(beast.on_disk.get("flags",{}).get("ch005.beast_released",false)),
        "Beast release flag missing after save")
    var already_freed: Dictionary = Settlement.settle_victory(
        beast,FakeCore.new(beast),beast_id,5,true,[],"",125,40,1,"nonlethal")
    check(bool(already_freed.get("repeated",false)) and beast.gold==60,
        "Beast rescue paid twice")

    var lantern := FakeProgress.new()
    lantern.chapter = 6
    lantern.fail_save = true
    var lantern_id: String = AReceipt.make_id(true,6,"boss.ch006")
    var original_lantern: Dictionary = lantern._pack().duplicate(true)
    var failed_lantern: Dictionary = Settlement.settle_victory(
        lantern,FakeCore.new(lantern),lantern_id,6,true,[],"",180,65,1,"testimony")
    check(str(failed_lantern.get("reason",""))=="save_failed" and lantern._pack()==original_lantern,
        "Failed lighthouse save leaked chapter progress")
    lantern.fail_save = false
    var wrong_lantern: Dictionary = Settlement.settle_victory(
        lantern,FakeCore.new(lantern),lantern_id,6,true,[],"",180,65,1,"legacy_story")
    check(str(wrong_lantern.get("reason",""))=="invalid_lighthouse_resolution",
        "Old lethal lighthouse outcome was accepted")
    var relight: Dictionary = Settlement.settle_victory(
        lantern,FakeCore.new(lantern),lantern_id,6,true,[],"",180,65,1,"testimony")
    check(bool(relight.get("applied",false)) and bool(lantern.flags.get("ch006.lighthouse_testimony",false)),
        "Shared testimony did not persist")
    check(bool(lantern.on_disk.get("flags",{}).get("ch006.lighthouse_testimony",false)),
        "Saved lighthouse testimony was missing")
    if problems.is_empty():
        print("PASS: V3 rewards/rollback plus real Act-I humane rescue and lighthouse testimony receipts")
        quit(0)
    else:
        for problem in problems:
            push_error(problem)
        quit(1)
