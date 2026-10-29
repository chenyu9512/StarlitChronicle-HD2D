extends SceneTree
## Real-command boss integration across all twelve acts, plus the two scripted endings.
## Fixed boosted party stats isolate turn/target/win mechanics from long-term balance.
## This intentionally never invokes _finish(true) to forge victory.
const Battle = preload("res://scripts/first_act_battle.gd")
const SaveState = preload("res://scripts/first_act_state.gd")
const Core = preload("res://scripts/rpg_core.gd")

const BOSS_CHAPTERS: Array[int] = [5,6,12,18,24,30,36,42,48,54,60,66,72]
const MAX_PLAYER_ACTIONS: int = 180
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for chapter in BOSS_CHAPTERS:
        var state = SaveState.new()
        state.chapter = chapter
        for i in range(state.actors.size()):
            var actor: Dictionary = state.actors[i]
            actor["attack"] = 195
            actor["level"] = 99
            actor["hp"] = actor["max_hp"]
            state.actors[i] = actor
        var core = Core.new()
        core.bind(state)
        var battle = Battle.new()
        root.add_child(battle)
        battle.game_core = core
        battle.invincible = true
        var outcome: Dictionary = {"done":false,"victory":false,"count":0,"xp":0}
        battle.completed.connect(func(won: bool, xp: int, _gold: int) -> void:
            outcome["done"] = true
            outcome["victory"] = won
            outcome["count"] = int(outcome["count"])+1
            outcome["xp"] = xp
        )
        battle.start(state,chapter,true)
        var initial_max_hp: int = int(battle.enemy.get("max_hp",0))
        for turn in range(MAX_PLAYER_ACTIONS):
            if bool(outcome["done"]):
                break
            battle._act("special")
        if not bool(outcome["done"]):
            failures.append("Chapter %d Boss did not resolve within %d live commands" %
                [chapter,MAX_PLAYER_ACTIONS])
        elif not bool(outcome["victory"]):
            failures.append("Chapter %d Boss was defeated despite invincibility" % chapter)
        elif int(outcome["count"]) != 1:
            failures.append("Chapter %d emitted completed more than once" % chapter)
        elif int(outcome["xp"]) <= 0:
            failures.append("Chapter %d Boss awarded no XP" % chapter)
        if chapter == 5 and int(battle.chain_hp) > 0:
            failures.append("Chapter 5 star chains were not removed by real actions")
        elif chapter == 6 and int(battle.resonance) < 4:
            failures.append("Chapter 6 resonance was not completed by real actions")
        elif chapter > 6 and initial_max_hp > 0:
            var remaining: int = int(battle.enemy.get("hp",0))
            if battle.last_boss_settlement in ["nonlethal","rescued"]:
                # Pacification is a true victory with the enemy deliberately alive.
                if remaining <= 0:
                    failures.append("Chapter %d nonlethal Boss was killed" % chapter)
            elif remaining > 0:
                failures.append("Chapter %d lethal Boss HP remained after declared victory" % chapter)
        battle.free()
    if not failures.is_empty():
        for fault in failures:
            push_error(fault)
        quit(1)
        return
    print("PASS: 13 story Boss encounters cleared by live player commands, "
        + "unique battle settlement, scripted chain/resonance, and reward callbacks")
    quit(0)
