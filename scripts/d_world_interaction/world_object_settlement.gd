extends RefCounted
## DQIX-inspired world object settlement: one authoritative V3 checkpoint.
## The original map/discovery/puzzle registries remain the source of truth.
## Never modifies scene UI, global signals, or legacy save schema.
const MAX_REWARD_GOLD: int = 1000000
const MAX_REWARD_ITEMS: int = 99

static func _valid_state(progress: Object) -> bool:
    return progress != null and progress.has_method("_pack") and progress.has_method("restore_snapshot") and progress.has_method("save")

static func transact(progress: Object, mutation: Callable) -> Dictionary:
    if not _valid_state(progress) or not mutation.is_valid():
        return {"ok":false,"reason":"invalid_transaction"}
    var packed: Variant = progress.call("_pack")
    if not (packed is Dictionary):
        return {"ok":false,"reason":"invalid_snapshot"}
    var before: Dictionary = (packed as Dictionary).duplicate(true)
    var response: Variant = mutation.call()
    if not (response is Dictionary):
        progress.call("restore_snapshot",before)
        return {"ok":false,"reason":"invalid_mutation"}
    var outcome: Dictionary = response
    if not bool(outcome.get("ok",false)):
        progress.call("restore_snapshot",before)
        return {"ok":false,"reason":str(outcome.get("reason","mutation_rejected"))}
    if not bool(outcome.get("changed",false)):
        # Even a buggy read-only handler may not leak an uncommitted mutation.
        progress.call("restore_snapshot",before)
        return {"ok":true,"changed":false,"outcome":outcome}
    if not bool(progress.call("save")):
        progress.call("restore_snapshot",before)
        return {"ok":false,"reason":"save_failed"}
    return {"ok":true,"changed":true,"outcome":outcome}

static func _valid_reward(core: Object, reward: Dictionary) -> bool:
    var gold_value: Variant = reward.get("gold",0)
    var count_value: Variant = reward.get("amount",0)
    if typeof(gold_value) not in [TYPE_INT,TYPE_FLOAT] or typeof(count_value) not in [TYPE_INT,TYPE_FLOAT]:
        return false
    var gold: int = int(gold_value)
    var count: int = int(count_value)
    if gold < 0 or gold > MAX_REWARD_GOLD or count < 0 or count > MAX_REWARD_ITEMS:
        return false
    var item_id: String = str(reward.get("item_id",""))
    if item_id.is_empty():
        return count == 0
    if count == 0 or core == null or not core.has_method("entry"):
        return false
    for category in ["items","weapons","armor"]:
        var row: Variant = core.call("entry",category,item_id)
        if row is Dictionary and not (row as Dictionary).is_empty():
            return true
    return false

static func _grant(progress: Object, core: Object, reward: Dictionary) -> void:
    progress.gold += int(reward.get("gold",0))
    var item_id: String = str(reward.get("item_id",""))
    if not item_id.is_empty():
        core.call("add_item",item_id,int(reward.get("amount",0)))

## Persistent flags are authoritative receipts for single-use objects.
## Existing save flags are retained unchanged, so old V3 saves stay valid.
static func claim(progress: Object, core: Object, flag: String, reward: Dictionary = {}) -> Dictionary:
    if not (flag.begins_with("map.") or flag.begins_with("discover.")) or flag.length() > 180:
        return {"ok":false,"reason":"invalid_object_id"}
    if not _valid_state(progress):
        return {"ok":false,"reason":"invalid_transaction"}
    if bool(progress.flags.get(flag,false)):
        return {"ok":true,"changed":false,"repeated":true}
    if not _valid_reward(core,reward):
        return {"ok":false,"reason":"invalid_reward"}
    return transact(progress,func() -> Dictionary:
        progress.flags[flag] = true
        _grant(progress,core,reward)
        return {"ok":true,"changed":true,"flag":flag}
    )

## An authored puzzle writes its own progress to the existing V7 bucket.
## Saving the puzzle state AND treasure in one snapshot prevents paid-but-unsolved
## and solved-but-unpaid states, including on seal retry after a failed save.
static func puzzle(progress: Object, core: Object, puzzle_runtime: Object,
        map_id: String, control_id: String) -> Dictionary:
    if puzzle_runtime == null or not puzzle_runtime.has_method("interact"):
        return {"ok":false,"reason":"missing_puzzle"}
    if map_id.is_empty() or control_id not in ["a","b","c","seal"]:
        return {"ok":false,"reason":"invalid_puzzle_control"}
    return transact(progress,func() -> Dictionary:
        var interaction: Variant = puzzle_runtime.call("interact",map_id,control_id,progress)
        if not (interaction is Dictionary):
            return {"ok":false,"reason":"invalid_puzzle_result"}
        var result: Dictionary = interaction
        if not bool(result.get("changed",false)):
            return {"ok":true,"changed":false,"result":result}
        var reward_value: Variant = result.get("reward",{})
        if not (reward_value is Dictionary) or not _valid_reward(core,reward_value):
            return {"ok":false,"reason":"invalid_reward"}
        _grant(progress,core,reward_value)
        return {"ok":true,"changed":true,"result":result}
    )

## Run authored B-line ecology rules inside a single V3 snapshot.
## Preview and B-line authored conditions remain authoritative; only this
## boundary may award items/gold and persist their corresponding state flags.
static func interact(progress: Object, core: Object, producer: Callable) -> Dictionary:
    if not producer.is_valid():
        return {"ok":false,"reason":"invalid_interaction"}
    return transact(progress,func() -> Dictionary:
        var value: Variant = producer.call()
        if not (value is Dictionary):
            return {"ok":false,"reason":"invalid_interaction_result"}
        var interaction: Dictionary = value
        if not bool(interaction.get("changed",false)):
            return {"ok":true,"changed":false,"result":interaction}
        var reward_value: Variant = interaction.get("reward",{})
        if not (reward_value is Dictionary) or not _valid_reward(core,reward_value):
            return {"ok":false,"reason":"invalid_reward"}
        _grant(progress,core,reward_value)
        return {"ok":true,"changed":true,"result":interaction}
    )
