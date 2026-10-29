extends SceneTree
## B town domain regression. Pure query does not create save buckets or rewards.
## This test does not claim that D has integrated atomic guild settlement.
const State = preload("res://scripts/first_act_state.gd")
const TownLife = preload("res://scripts/world_town_life.gd")
var issues: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,message: String) -> void:
    if not ok:
        issues.append(message)

func _run() -> void:
    var life=TownLife.new()
    for region_id in TownLife.REGIONS:
        var progress=State.new()
        progress.new_game()
        var packed_before: Dictionary=progress._pack().duplicate(true)
        var available: Dictionary=life.guild_progress(region_id,progress)
        _check(str(available.get("state",""))=="available",region_id+" did not offer contract")
        _check(progress._pack()==packed_before,region_id+" status read mutated unsaved data")
        var accepted: String=life.guild_action(region_id,progress)
        _check(accepted.contains("已接取"),region_id+" contract not accepted")
        _check(str(life.guild_progress(region_id,progress).get("state",""))=="active",
            region_id+" active contract not recorded")
        var gold: int=progress.gold
        progress.rpg["event_counters"]={"battle_victory":3}
        _check(str(life.guild_progress(region_id,progress).get("state",""))=="ready",
            region_id+" completed battle counter not recognized")
        var payout: String=life.guild_action(region_id,progress)
        _check(payout.contains("获得"),region_id+" guild payout missing")
        _check(progress.gold>gold,region_id+" confirmed guild contract awarded no gold")
        gold=progress.gold
        _check(str(life.guild_progress(region_id,progress).get("state",""))=="claimed",
            region_id+" claim flag was not set")
        life.guild_action(region_id,progress)
        _check(progress.gold==gold,region_id+" duplicate guild claim paid twice")
    var invalid=State.new()
    invalid.new_game()
    var before: Dictionary=invalid._pack().duplicate(true)
    _check(str(life.guild_progress("invalid",invalid).get("state",""))=="unavailable",
        "Unknown guild region should not expose rewards")
    _check(life.guild_action("invalid",invalid).contains("尚未开放"),
        "Unknown guild region allowed reward")
    _check(invalid._pack()==before,"Invalid region query changed state")
    if issues.is_empty():
        print("PASS B guild: eight regions, read-only UI status, stage transition, repeat claim and invalid region protection")
        quit(0)
        return
    for issue in issues:
        push_error(issue)
    quit(1)
