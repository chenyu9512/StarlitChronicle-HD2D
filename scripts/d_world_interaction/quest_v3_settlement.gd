extends RefCounted
## Batch 0.2: authoritative V3 transactions for three distinct quest routes.
## Event IDs and all economic effects share a single V3 snapshot. Fail closed.
const Ledger = preload("res://scripts/d_world_interaction/v3_reward_ledger.gd")

static func settle_local_stage(progress: Object, chapter: int,
        quest: Dictionary, stage: String) -> Dictionary:
    var quest_id: String = str(quest.get("id",""))
    if progress == null or quest_id.is_empty() or chapter != int(progress.get("chapter")):
        return {"ok":false,"reason":"invalid_local_stage"}
    if stage not in ["accepted","found"]:
        return {"ok":false,"reason":"invalid_stage"}
    var previous: String = "side." + quest_id + ".accepted"
    var key: String = "side." + quest_id + "." + stage
    if bool(progress.flags.get("side."+quest_id+".done",false)) or bool(progress.flags.get(key,false)):
        return {"ok":true,"applied":false,"repeated":true}
    if stage == "found" and not bool(progress.flags.get(previous,false)):
        return {"ok":false,"reason":"missing_acceptance"}
    var intent: Dictionary = {"source":"local_side_stage","quest_id":quest_id,
        "chapter":chapter,"stage":stage}
    var mutation: Callable = func() -> Dictionary:
        progress.flags[key] = true
        return {"ok":true,"stage":stage}
    return Ledger.settle(progress,"d.quest.local."+quest_id+"."+stage,intent,mutation)

static func settle_local(progress: Object, core: Object, chapter: int, quest: Dictionary) -> Dictionary:
    var quest_id: String = str(quest.get("id",""))
    if progress == null or core == null or quest_id.is_empty() or int(progress.get("chapter")) != chapter:
        return {"ok":false,"reason":"invalid_local_quest"}
    var flag: String = "side." + quest_id + ".done"
    # Legacy V3 saves may already have paid this quest without a receipt.
    if bool(progress.flags.get(flag,false)):
        return {"ok":true,"applied":false,"repeated":true,"reason":"legacy_local_complete"}
    var reward_value: Variant = quest.get("reward",{})
    if not (reward_value is Dictionary):
        return {"ok":false,"reason":"invalid_local_reward"}
    var reward: Dictionary = reward_value
    var xp: int = maxi(0,int(reward.get("xp",0)))
    var gold: int = maxi(0,int(reward.get("gold",0)))
    var herbs: int = maxi(0,int(reward.get("potions",0)))
    var event_id: String = "d.quest.local." + quest_id + ".reward"
    var intent: Dictionary = {"source":"local_side_quest","quest_id":quest_id,
        "chapter":chapter,"xp":xp,"gold":gold,"potions":herbs}
    var mutation: Callable = func() -> Dictionary:
        progress.flags[flag] = true
        var levels: Array[String] = progress.give_rewards(xp,gold)
        if herbs > 0:
            core.add_item("item_herb_01",herbs)
        return {"ok":true,"xp":xp,"gold":gold,"potions":herbs,"levels":levels}
    return Ledger.settle(progress,event_id,intent,mutation)

static func settle_catalog(progress: Object, quest: Dictionary) -> Dictionary:
    if progress == null:
        return {"ok":false,"reason":"invalid_progress"}
    var quest_id: String = str(quest.get("id",""))
    if quest_id.is_empty() or not (progress.rpg.get("quests",null) is Dictionary):
        return {"ok":false,"reason":"invalid_catalog_quest"}
    # Old completed quest IDs are authoritative, never retrospectively re-pay.
    if progress.rpg["quests"].has(quest_id):
        return {"ok":true,"applied":false,"repeated":true,"reason":"legacy_catalog_complete"}
    var reward_value: Variant = quest.get("rewards",{})
    if not (reward_value is Dictionary):
        return {"ok":false,"reason":"invalid_catalog_reward"}
    var rewards: Dictionary = reward_value
    var xp: int = maxi(0,int(rewards.get("xp",0)))
    var gold: int = maxi(0,int(rewards.get("gold",0)))
    var intent: Dictionary = {"source":"catalog_quest","id":quest_id,"xp":xp,"gold":gold}
    var mutation: Callable = func() -> Dictionary:
        var completed: Dictionary = progress.rpg.get("quests",{})
        completed[quest_id] = true
        progress.rpg["quests"] = completed
        var levels: Array[String] = progress.give_rewards(xp,gold)
        return {"ok":true,"xp":xp,"gold":gold,"levels":levels}
    return Ledger.settle(progress,"d.quest.catalog."+quest_id,intent,mutation)

static func advance_story_side(progress: Object, quest: Dictionary, choice: Dictionary,
        advance_uncommitted: Callable) -> Dictionary:
    if progress == null or not advance_uncommitted.is_valid():
        return {"ok":false,"reason":"invalid_story_stage"}
    var quest_id: String = str(quest.get("id",""))
    var stages_value: Variant = quest.get("stages",[])
    if quest_id.is_empty() or not (stages_value is Array):
        return {"ok":false,"reason":"invalid_story_quest"}
    var stages: Array = stages_value
    var side_value: Variant = progress.rpg.get("narrative_side",{})
    if not (side_value is Dictionary):
        return {"ok":false,"reason":"invalid_story_progress"}
    var side: Dictionary = side_value
    if bool(side.get(quest_id+".done",false)):
        return {"ok":true,"applied":false,"repeated":true,"reason":"story_already_complete"}
    var stage: int = int(side.get(quest_id,0))
    if stage < 0 or stage >= stages.size():
        return {"ok":false,"reason":"invalid_stage_index"}
    var sets_value: Variant = choice.get("sets",{})
    if not (sets_value is Dictionary):
        return {"ok":false,"reason":"invalid_choice_flags"}
    var intent: Dictionary = {"source":"story_side_stage","quest_id":quest_id,
        "stage":stage,"choice_id":str(choice.get("id","")),
        "choice_sets":(sets_value as Dictionary).duplicate(true)}
    var mutation: Callable = func() -> Dictionary:
        var result: String = str(advance_uncommitted.call(quest,choice))
        if result.begins_with("委托已经完成") or result.begins_with("任务阶段记录无效"):
            return {"ok":false,"reason":"stage_rejected"}
        return {"ok":true,"message":result}
    return Ledger.settle(progress,"d.quest.story."+quest_id+".stage."+str(stage),intent,mutation)

## Main-story effects use the same V3 idempotency contract as quest payouts.
## The caller must not move the scene index when this save fails.
static func settle_scene_effects(progress: Object, scene: Dictionary) -> Dictionary:
    if progress == null:
        return {"ok":false,"reason":"invalid_progress"}
    var scene_id: String = str(scene.get("id",""))
    if scene_id.is_empty():
        return {"ok":false,"reason":"missing_scene_id"}
    var effects_value: Variant = scene.get("effects",[])
    if not (effects_value is Array):
        return {"ok":false,"reason":"invalid_scene_effects"}
    var effects: Array = effects_value
    if effects.is_empty():
        return {"ok":true,"applied":false,"empty":true}
    for raw in effects:
        if not (raw is Dictionary):
            return {"ok":false,"reason":"invalid_scene_effect"}
        var effect: Dictionary = raw
        var kind: String = str(effect.get("type",""))
        if kind == "set_flag":
            if str(effect.get("key","")).is_empty():
                return {"ok":false,"reason":"invalid_flag_effect"}
        elif kind == "grant":
            for key in ["xp","gold"]:
                var number: Variant = effect.get(key,0)
                if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or float(number) < 0.0 or float(number) > 10000000.0:
                    return {"ok":false,"reason":"invalid_grant_amount"}
        elif kind not in ["time_skip","finish_chapter"]:
            return {"ok":false,"reason":"unsupported_scene_effect"}
    var event_id: String = "d.story.scene." + scene_id + ".effects"
    var intent: Dictionary = {"source":"main_story_effects","scene_id":scene_id,
        "effects":effects.duplicate(true)}
    var mutation: Callable = func() -> Dictionary:
        var levels: Array[String] = []
        for raw in effects:
            var effect: Dictionary = raw
            match str(effect.get("type","")):
                "set_flag":
                    progress.flags[str(effect["key"])] = effect.get("value",true)
                "grant":
                    levels.append_array(progress.give_rewards(
                        maxi(0,int(effect.get("xp",0))),maxi(0,int(effect.get("gold",0)))))
                "time_skip":
                    progress.flags["world.years_passed"] = true
                "finish_chapter":
                    pass
        return {"ok":true,"levels":levels}
    return Ledger.settle(progress,event_id,intent,mutation)
