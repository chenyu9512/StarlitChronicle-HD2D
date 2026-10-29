extends SceneTree
## Standard difficulty, fresh level-one party, no stat boosts or invincibility.
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const Core = preload("res://scripts/rpg_core.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for chapter in [2,3]:
        for seed_value in range(12):
            var state = State.new()
            state.chapter = chapter
            var core = Core.new()
            core.bind(state)
            var battle = Battle.new()
            root.add_child(battle)
            battle.game_core = core
            battle.dice.seed = seed_value
            var outcome: Dictionary = {"count":0,"won":false}
            battle.completed.connect(func(won: bool, _xp: int, _gold: int) -> void:
                outcome["count"] = int(outcome["count"])+1
                outcome["won"] = won
            )
            battle.start(state,chapter,true)
            for command in range(100):
                if battle.win_locked:
                    break
                var member: Dictionary = state.actors[battle.hero_turn]
                if int(member["hp"]) < int(member["max_hp"])/2 and state.potions > 0:
                    battle._act("potion")
                elif float(battle.round_boss_intent.get("multiplier",1.0)) > 1.5:
                    battle._act("guard")
                else:
                    battle._act("special")
            if not bool(outcome["won"]) or int(outcome["count"]) != 1:
                failures.append("Chapter %d seed %d: fresh-party tactical victory failed" % [chapter,seed_value])
            if battle.current_round < 3 or battle.current_round > 20:
                failures.append("Chapter %d seed %d outside 3-20 round opening budget" % [chapter,seed_value])
            print("BALANCE chapter=%d seed=%d rounds=%d herbs_used=%d won=%s" % [chapter,seed_value,battle.current_round,6-state.potions,str(outcome["won"])])
            battle.free()
    # Crossing phase/HP thresholds cannot change an already announced action.
    var state = State.new()
    var battle = Battle.new()
    root.add_child(battle)
    battle.start(state,12,true)
    var announced: Dictionary = battle.round_boss_intent.duplicate(true)
    battle.phase_two = true
    battle.enemy["hp"] = 1
    battle._telegraph_next_boss_action()
    if battle.round_boss_intent != announced:
        failures.append("Boss intent changed after phase transition")
    battle.free()
    for failure in failures:
        push_error(failure)
    quit(0 if failures.is_empty() else 1)
