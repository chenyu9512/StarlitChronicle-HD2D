extends SceneTree
## Five real first-act Bosses: verify defending mitigates actual strikes.
## Isolated new State and Battle instances; no forged victory or player save IO.
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")
const Registry = preload("res://scripts/encounter_registry.gd")

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)

func _measure(chapter_no: int, guarding: bool) -> Dictionary:
    var state = State.new()
    state.chapter = chapter_no
    if chapter_no >= 4:
        state.recruit_sailor()
    var core = RPG.new()
    core.bind(state)
    var battle = Battle.new()
    root.add_child(battle)
    battle.game_core = core
    battle.start(state,chapter_no,true)
    check(not battle.invincible,"Chapter %d test accidentally used invincibility" % chapter_no)
    check(not battle.formation.units.is_empty(),"Chapter %d missing real Boss" % chapter_no)
    # Freeze the real Boss heavy strike once: same party, attack intent and RNG
    # seed for the defended and undefended cases of each chapter.
    var round_no: int = maxi(2,int(battle.boss_mechanics.spec.get("cadence",3))) if battle.boss_mechanics.enabled() else 3
    battle.current_round = round_no
    battle._begin_round()
    if guarding:
        for i in range(state.actors.size()):
            battle.defense[i] = true
    battle.dice.seed = 20261030 + chapter_no
    var total_before: int = 0
    for member in state.actors:
        total_before += int(member.get("hp",0))
    battle._enemy_strike(0)
    var total_after: int = 0
    for member in state.actors:
        total_after += int(member.get("hp",0))
    var result: Dictionary = {"chapter":chapter_no,"guarded":guarding,
        "damage":total_before-total_after,"enemy_strikes":battle.enemy_strike_count,
        "damage_recorded":battle.enemy_damage_dealt,
        "guarded_strikes":battle.enemy_guarded_strikes,
        "intent":battle.round_boss_intent.duplicate(true)}
    battle.queue_free()
    return result

func _run() -> void:
    var registry = Registry.new()
    for chapter_no in range(2,7):
        var open_result: Dictionary = _measure(chapter_no,false)
        var guard_result: Dictionary = _measure(chapter_no,true)
        var raw_damage: int = int(open_result.get("damage",-1))
        var defended_damage: int = int(guard_result.get("damage",-1))
        check(int(open_result.get("enemy_strikes",0))==1 and int(guard_result.get("enemy_strikes",0))==1,
            "Chapter %d did not actually execute its Boss attack" % chapter_no)
        check(raw_damage > 0,"Chapter %d Boss attack dealt no damage" % chapter_no)
        check(defended_damage >= 0 and defended_damage < raw_damage,
            "Chapter %d defending did not reduce the actual Boss damage" % chapter_no)
        check(int(open_result.get("damage_recorded",-1))==raw_damage and
            int(guard_result.get("damage_recorded",-1))==defended_damage,
            "Chapter %d telemetry disagrees with real party HP loss" % chapter_no)
        check(int(open_result.get("guarded_strikes",-1))==0 and
            int(guard_result.get("guarded_strikes",-1))==1,
            "Chapter %d guard hit count incorrect" % chapter_no)
        var recommendation: int = int(registry.progression(chapter_no).get("recommended_level",0))
        print("ACT01_BOSS_GUARD " + JSON.stringify({"chapter":chapter_no,
            "recommended_level":recommendation,"damage_no_guard":raw_damage,
            "damage_guard":defended_damage,"mitigated":raw_damage-defended_damage}))
    if failures.is_empty():
        print("PASS Act-I Boss pressure: all five real Boss attacks and guard mitigation measured without cheats")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
