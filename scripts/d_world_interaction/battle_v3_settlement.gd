extends RefCounted
## D line: commit all battle V3 rewards and the A receipt in ONE V3 save.
## A battle IDs are canonical; the D receipt is a second guard in that same snapshot.
## No UI, scene transitions, external saves or emitted events inside the mutation.
const AReceipt = preload("res://scripts/battle_reward_transaction.gd")
const V3Ledger = preload("res://scripts/d_world_interaction/v3_reward_ledger.gd")

static func settle_victory(progress: Variant, core: Variant, transaction_id: String, chapter: int,
        is_boss: bool, enemies: Array, monster_id: String, xp: int, gold: int,
        xp_multiplier: int = 1, story_resolution: String = "") -> Dictionary:
    if progress == null or core == null or not AReceipt.valid_id(transaction_id):
        return {"ok":false,"applied":false,"reason":"invalid_battle_transaction"}
    if bool(transaction_id.begins_with("boss:")) != is_boss or chapter != int(progress.get("chapter")):
        return {"ok":false,"applied":false,"reason":"battle_context_mismatch"}
    var rpg_value: Variant = progress.get("rpg")
    if not (rpg_value is Dictionary):
        return {"ok":false,"applied":false,"reason":"invalid_rpg_state"}
    var rpg: Dictionary = rpg_value
    var flags_value: Variant = progress.get("flags")
    if not (flags_value is Dictionary):
        return {"ok":false,"applied":false,"reason":"invalid_flags"}
    var flags: Dictionary = flags_value
    if is_boss and bool(flags.get("ch%03d.battle_won" % chapter, false)):
        return {"ok":true,"applied":false,"repeated":true,"reason":"legacy_or_settled_boss"}
    if AReceipt.already_applied(rpg, transaction_id):
        return {"ok":true,"applied":false,"repeated":true,"reason":"a_receipt_exists"}
    var awarded_xp: int = maxi(0,xp) * maxi(1,xp_multiplier)
    var awarded_gold: int = maxi(0,gold)
    # The first-act humane rescue and lighthouse resolution belong to the
    # same atomic receipt as the boss reward and chapter transition.
    if is_boss and chapter == 5 and not story_resolution.is_empty() and story_resolution != "nonlethal":
        return {"ok":false,"applied":false,"reason":"invalid_beast_resolution"}
    if is_boss and chapter == 6 and not story_resolution.is_empty() and story_resolution != "testimony":
        return {"ok":false,"applied":false,"reason":"invalid_lighthouse_resolution"}
    var intent: Dictionary = {"source":"battle_victory","chapter":chapter,
        "boss":is_boss,"xp":awarded_xp,"gold":awarded_gold,
        "story_resolution":story_resolution}
    var mutation: Callable = func() -> Dictionary:
        for raw_enemy in enemies:
            if not (raw_enemy is Dictionary):
                continue
            var foe: Dictionary = raw_enemy
            var mid: String = str(foe.get("monster_id",""))
            var bid: String = str(foe.get("boss_id",""))
            if not mid.is_empty():
                core.record_enemy_resolution("monsters",mid)
            if not bid.is_empty():
                core.record_enemy_resolution("story_bosses",bid)
        var levels: Array[String] = progress.give_rewards(awarded_xp,awarded_gold)
        var job_levels: Array[String] = core.award_job_xp(maxi(5,int(float(xp)/5.0)),is_boss)
        var loot: Array[String] = core.roll_monster_loot(monster_id)
        if is_boss:
            progress.flags["ch%03d.battle_won" % chapter] = true
            if chapter == 5 and story_resolution == "nonlethal":
                progress.flags["ch005.beast_released"] = true
            if chapter == 6 and story_resolution == "testimony":
                progress.flags["ch006.lighthouse_testimony"] = true
            progress.scene_index += 1
            progress.task_index = 0
            progress.dialogue_seen = false
        if not AReceipt.mark_applied(progress.rpg,transaction_id,
                {"chapter":chapter,"xp":awarded_xp,"gold":awarded_gold}):
            return {"ok":false,"reason":"a_receipt_failed"}
        return {"ok":true,"levels":levels,"job_levels":job_levels,"loot":loot,
            "xp":awarded_xp,"gold":awarded_gold}
    return V3Ledger.settle(progress,transaction_id,intent,mutation)

static func settle_defeat(progress: Variant, transaction_id: String, chapter: int,
        is_boss: bool) -> Dictionary:
    if progress == null or not AReceipt.valid_id(transaction_id):
        return {"ok":false,"applied":false,"reason":"invalid_battle_transaction"}
    if int(progress.get("chapter")) != chapter:
        return {"ok":false,"applied":false,"reason":"battle_context_mismatch"}
    var event_id: String = "defeat:" + transaction_id
    var intent: Dictionary = {"source":"battle_defeat","chapter":chapter,"boss":is_boss}
    var mutation: Callable = func() -> Dictionary:
        progress.gold = maxi(0,int(progress.gold)-15)
        progress.heal_all()
        return {"ok":true,"lost_gold":15}
    return V3Ledger.settle(progress,event_id,intent,mutation)
