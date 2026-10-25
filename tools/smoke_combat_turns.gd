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
    var targeting = Battle.new()
    root.add_child(targeting)
    targeting.game_core = core
    targeting.invincible = true
    targeting.start(state,4,false)
    if targeting.formation.alive_indices().size() < 2:
        var extra_enemy: Dictionary = targeting.formation.units[0].duplicate(true)
        extra_enemy["name"] = "测试敌人二号"
        targeting.formation.units.append(extra_enemy)
    targeting.hero_turn = 0
    var target_hp_before: int = int(targeting.formation.units[1].get("hp",0))
    targeting._act("skill:skill_wayfarer_01")
    check(is_instance_valid(targeting.skill_picker),"Multi-enemy single-target skill must open the target chooser")
    targeting._act("skill:skill_wayfarer_01#1")
    check(not is_instance_valid(targeting.skill_picker),"Skill target picker reopened after selecting the second enemy")
    check(int(targeting.formation.units[1].get("hp",0)) < target_hp_before,"Manual skill did not affect selected enemy")
    targeting.queue_free()
    var rival: Dictionary = {"name":"快攻海兽","hp":100,"max_hp":100,"speed":25,"atk":22,"def":5,"element":"水"}
    var foe_queue: Array[Dictionary] = rules.turn_timeline(actors,[rival])
    check(str(foe_queue[0].get("team","")) == "enemy","Fast enemies must take priority over both slow player actors")
    check(int(foe_queue[0].get("index",-1)) == 0,"Fast enemy index mismatch")
    var equal_queue: Array[Dictionary] = rules.turn_timeline([{"id":"a","hp":10,"speed":10}],[{"hp":10,"speed":10}])
    check(str(equal_queue[0].get("team","")) == "ally","Equal-speed ties must be stable and favor the party")
    var boss_profile: Dictionary = {"is_boss":true,"status_immunities":["stun","sleep"],"status_resistances":{"poison":0.5},"max_hp":300}
    check(rules.enemy_immune(boss_profile,"stun"),"Bosses should ignore instant stun lock")
    check(not rules.apply_enemy_negative(0,boss_profile,"sleep",4),"Boss sleep immunity was bypassed")
    check(rules.enemy_status_chance(boss_profile,"poison",1.0) == 0.5,"Boss poison resistance should halve proc rate")
    check(rules.apply_enemy_negative(0,boss_profile,"poison",2),"Boss should remain vulnerable to resisted DOT")
    check(int(rules.resolve_enemy_turn(0,300).get("damage",-1)) == 15,"Enemy DOT should drain five percent max HP")
    check(rules.has_enemy_negative(0,"poison"),"Enemy DOT expired before the second turn")
    check(not bool(rules.resolve_enemy_turn(0,300).get("skip",true)),"Enemy poison must not skip attacks")
    check(not rules.has_enemy_negative(0,"poison"),"Enemy DOT did not expire")
    check(rules.apply_enemy_negative(1,rival,"freeze",1),"Non-boss enemy should be freezable")
    check(bool(rules.resolve_enemy_turn(1,100).get("skip",false)),"Frozen enemy must lose a single action")
    check(not rules.has_enemy_negative(1,"freeze"),"Enemy freeze did not expire")
    var guardian = Battle.new()
    root.add_child(guardian)
    guardian.game_core = core
    guardian.invincible = true
    guardian.start(state,2,false)
    guardian.formation.units[0]["speed"] = 25
    guardian._begin_round()
    check(str(guardian.turn_queue[0].get("team","")) == "enemy","Battle mixed timeline did not start with high-speed monster")
    guardian._start_actor()
    check(not guardian.last_enemy_action.is_empty(),"High-speed enemy never actually acted before the player")
    check(guardian.turn_cursor == 1,"High-speed enemy must consume exactly one action slot")
    check(guardian.hero_turn == 1,"Mixed timeline did not resume on the fastest ally")
    guardian._act("guard")
    check(guardian.hero_turn == 0,"Second ally must follow first ally after monster preemptive attack")
    guardian._act("guard")
    check(guardian.current_round == 2,"Mixed timeline must advance the round only once")
    guardian.queue_free()
    if failures.is_empty():
        print("PASS: seven ailments, DOT, stun, silence, cure, slow, initiative, mixed enemy/ally preemptive actions, boss immunity, enemy DOT and multi-foe targeting")
        quit(0)
    else:
        for message in failures:
            push_error(message)
        quit(1)
