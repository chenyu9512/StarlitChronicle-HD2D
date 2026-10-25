extends SceneTree
## P1 deterministic rules: timed ailments, cures, stable speed order and live-battle turns.
const Combat = preload("res://scripts/combat_rules.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _run() -> void:
    var rules = Combat.new()
    rules.start({"difficulty":"标准"})
    var actors: Array[Dictionary] = [
        {"id":"slowman","hp":100,"speed":11},
        {"id":"fastman","hp":100,"speed":16},
        {"id":"midman","hp":100,"speed":14}
    ]
    check(rules.initiative_order(actors) == [1,2,0],"Initiative must be highest-speed-first")
    check(rules.apply_negative("fastman","slow",2),"Slow could not be applied")
    check(rules.initiative_order(actors) == [2,0,1],"Slow did not change initiative")
    check(not rules.apply_negative("fastman","invalid",2),"Unknown negative status should be rejected")
    check(rules.apply_negative("fastman","poison",3),"Poison missing")
    check(rules.apply_negative("fastman","stun",1),"Stun missing")
    var first: Dictionary = rules.resolve_actor_turn("fastman",120)
    check(int(first.get("damage",0)) == 6,"Poison must drain 5 percent maximum HP")
    check(bool(first.get("skip",false)),"Stun must prevent one actor action")
    check(not rules.has_negative("fastman","stun"),"One-turn stun did not expire")
    check(rules.has_negative("fastman","poison"),"Multi-round poison expired too soon")
    check(rules.apply_negative("midman","burn",2),"Burn missing")
    check(int(rules.resolve_actor_turn("midman",100).get("damage",-1)) == 7,"Burn should inflict 7 percent max HP")
    check(rules.has_negative("midman","burn"),"Burn expired too early")
    rules.resolve_actor_turn("midman",100)
    check(not rules.has_negative("midman","burn"),"Burn never expired")
    check(rules.apply_negative("slowman","silence",2),"Silence missing")
    check(rules.status_report("slowman").contains("沉默"),"Status HUD label missing")
    rules.cure_negative("slowman")
    check(rules.status_report("slowman").is_empty(),"Cure did not clear statuses")
    var state = State.new()
    var core = RPG.new()
    core.bind(state)
    var battle = Battle.new()
    root.add_child(battle)
    battle.game_core = core
    battle.invincible = true
    battle.start(state,2,false)
    check(battle.party_order.size() == 2,"Two active party actors should appear")
    check(battle.hero_turn == 1,"Faster tidecaller should take first command")
    check(battle.party_order == [1,0],"Speed-sorted battle party order not applied")
    battle._act("guard")
    check(battle.hero_turn == 0,"Guard command should advance to the next fighter")
    battle._act("guard")
    check(battle.current_round == 2,"One complete party turn should advance battle round")
    check(battle.hero_turn == 1,"Battle initiative should recalculate for the next round")
    battle.combat_rules.apply_negative("char_tidecaller","silence",1)
    battle._act("skill")
    check(not is_instance_valid(battle.skill_picker),"Silenced fighter must not open skill selection")
    battle.queue_free()
    if failures.is_empty():
        print("PASS: seven ailments, DOT, stun, silence, cure, slow, deterministic initiative and live round rotation")
        quit(0)
    else:
        for message in failures:
            push_error(message)
        quit(1)
