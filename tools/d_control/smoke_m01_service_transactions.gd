extends SceneTree
## M0.1 real-V3 service rollback: separate user:// save, no default-player data.
const State = preload("res://scripts/first_act_state.gd")
const Core = preload("res://scripts/rpg_core.gd")
const Events = preload("res://scripts/game_events.gd")
const Life = preload("res://scripts/world_town_life.gd")
const Service = preload("res://scripts/d_world_interaction/service_v3_settlement.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        errors.append(label)

func _run() -> void:
    var directory: String = "user://m01_service_%d" % OS.get_process_id()
    var base: String = ProjectSettings.globalize_path(directory)
    if DirAccess.make_dir_recursive_absolute(base) != OK:
        push_error("Cannot create isolated service V3 test directory")
        quit(1)
        return
    var state = State.new()
    var good: String = directory + "/v3.json"
    var bad: String = directory + "/missing/v3.json"
    state.save_path = good
    state.backup_path = directory + "/v3.backup.json"
    state.chapter = 2
    state.gold = 1000
    var core = Core.new()
    core.bind(state)
    var events = Events.new()
    events.bind(state)
    var life = Life.new()

    var start: Dictionary = state._pack().duplicate(true)
    var starting_herbs: int = core.count("item_herb_01")
    state.save_path = bad
    var failed_buy: Dictionary = Service.execute(state,core,life,events,"buy:item_herb_01","region_coast")
    check(str(failed_buy.get("reason",""))=="save_failed" and state._pack()==start,
        "Failed shop purchase leaked money, inventory or event receipt")
    state.save_path = good
    var bought: Dictionary = Service.execute(state,core,life,events,"buy:item_herb_01","region_coast")
    check(bool(bought.get("ok",false)) and bool(bought.get("changed",false))
        and core.count("item_herb_01")==starting_herbs+1 and state.gold<1000,
        "Shop purchase was not atomically saved")

    var before_sell: Dictionary = state._pack().duplicate(true)
    state.save_path = bad
    var failed_sell: Dictionary = Service.execute(state,core,life,events,"sell:item_herb_01","region_coast")
    check(str(failed_sell.get("reason",""))=="save_failed" and state._pack()==before_sell,
        "Failed sale leaked gold or consumed inventory")
    state.save_path = good
    var sold: Dictionary = Service.execute(state,core,life,events,"sell:item_herb_01","region_coast")
    check(bool(sold.get("ok",false)) and bool(sold.get("changed",false))
        and core.count("item_herb_01")==starting_herbs,
        "Sale did not commit once")

    var no_forge: Dictionary = state._pack().duplicate(true)
    var refused: Dictionary = Service.execute(state,core,life,events,"forge:wpn_sword_01","region_coast")
    check(bool(refused.get("ok",false)) and not bool(refused.get("changed",true))
        and state._pack()==no_forge, "Invalid forge request mutated or rewrote progress")

    state.actors[0]["hp"] = 10
    var before_rest: Dictionary = state._pack().duplicate(true)
    state.save_path = bad
    var failed_rest: Dictionary = Service.execute(state,core,life,events,"rest","region_coast")
    check(str(failed_rest.get("reason",""))=="save_failed" and state._pack()==before_rest,
        "Failed inn payment changed time, healing, gold or event counters")
    state.save_path = good
    var rested: Dictionary = Service.execute(state,core,life,events,"rest","region_coast")
    check(bool(rested.get("ok",false)) and bool(rested.get("changed",false))
        and int(state.actors[0]["hp"])==int(state.actors[0]["max_hp"])
        and state.gold==int(before_rest.get("gold",0))-30
        and int(state.rpg.get("game_clock",{}).get("minutes",480))!=480,
        "Inn recovery and world time were not saved atomically")

    var before_bless: Dictionary = state._pack().duplicate(true)
    state.save_path = bad
    var failed_bless: Dictionary = Service.execute(state,core,life,events,"blessing","region_coast")
    check(str(failed_bless.get("reason",""))=="save_failed" and state._pack()==before_bless,
        "Failed shrine blessing changed gold, HP/MP or game time")
    state.save_path = good
    var blessed: Dictionary = Service.execute(state,core,life,events,"blessing","region_coast")
    check(bool(blessed.get("ok",false)) and bool(blessed.get("changed",false))
        and state.gold==int(before_bless.get("gold",0))-20,
        "Shrine payment not committed")

    var before_accept: Dictionary = state._pack().duplicate(true)
    state.save_path = bad
    var failed_accept: Dictionary = Service.execute(state,core,life,events,"guild","region_coast")
    check(str(failed_accept.get("reason",""))=="save_failed" and state._pack()==before_accept,
        "Failed guild acceptance kept an active commission")
    state.save_path = good
    var accepted: Dictionary = Service.execute(state,core,life,events,"guild","region_coast")
    check(bool(accepted.get("ok",false))
        and str(life.guild_progress("region_coast",state).get("state",""))=="active",
        "Guild commission was not saved")
    for n in range(3):
        events.record("battle_victory",{"xp":10})
    check(str(life.guild_progress("region_coast",state).get("state",""))=="ready",
        "Guild cannot recognize the three canonical victories")
    var before_claim: Dictionary = state._pack().duplicate(true)
    state.save_path = bad
    var failed_claim: Dictionary = Service.execute(state,core,life,events,"guild","region_coast")
    check(str(failed_claim.get("reason",""))=="save_failed" and state._pack()==before_claim,
        "Failed guild claim leaked reward gold or claimed receipt")
    state.save_path = good
    var claimed: Dictionary = Service.execute(state,core,life,events,"guild","region_coast")
    check(bool(claimed.get("ok",false)) and state.gold>int(before_claim.get("gold",0))
        and str(life.guild_progress("region_coast",state).get("state",""))=="claimed",
        "Guild claim not committed")
    var final_gold: int = state.gold
    var repeated: Dictionary = Service.execute(state,core,life,events,"guild","region_coast")
    check(bool(repeated.get("ok",false)) and state.gold==final_gold,
        "Repeated guild interaction paid twice")

    var recovered = State.new()
    recovered.save_path = good
    recovered.backup_path = state.backup_path
    check(recovered.load_saved() and recovered.gold==final_gold
        and bool(recovered.rpg.get("guild_contracts",{}).get("region_coast",{}).get("claimed",false)),
        "Regional service transactions were lost after real disk reload")

    for file_path in [good,good+".tmp",state.backup_path,state.backup_path+".tmp"]:
        if FileAccess.file_exists(file_path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
    DirAccess.remove_absolute(base)
    if errors.is_empty():
        print("PASS: M0.1 shop, sell, forge rejection, inn, shrine, guild rollback/retry and V3 reload")
        quit(0)
    else:
        for reason in errors:
            push_error(reason)
        quit(1)
