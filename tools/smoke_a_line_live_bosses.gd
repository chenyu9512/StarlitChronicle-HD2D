extends SceneTree
## True battle-loop replay, with chapter-level fixtures, real HP loss and three difficulty modes.
## Never enables invincibility, directly calls _finish(), skips enemy turns or forges quest flags.
## This is a future integration gate, not proof of current Godot success.
const Battle = preload("res://scripts/first_act_battle.gd")
const Core = preload("res://scripts/rpg_core.gd")
const Save = preload("res://scripts/first_act_state.gd")
const Encounters = preload("res://scripts/encounter_registry.gd")
const MAX_ACTIONS: int = 160
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var encounters = Encounters.new()
    for spec in _read("res://data/gameplay/boss_mechanics.json").get("entries",[]):
        var chapter: int = int(spec.get("chapter",0))
        var target: Dictionary = encounters.progression(chapter)
        for difficulty in ["休闲","标准","挑战"]:
            var state = Save.new()
            state.chapter = chapter
            state.rpg["settings"] = {"difficulty":difficulty}
            state.recruit_sailor()
            # Two-person and three-person parties are both sampled across the roster.
            if chapter % 2 == 0:
                state.actors.pop_back()
            var level: int = int(target.get("recommended_level",1))
            for i in range(state.actors.size()):
                var actor: Dictionary = state.actors[i]
                actor["level"] = level
                actor["xp"] = 0
                actor["max_hp"] = int(target.get("player_hp",112))
                actor["hp"] = actor["max_hp"]
                actor["max_mp"] = int(target.get("player_mp",32))
                actor["mp"] = actor["max_mp"]
                actor["attack"] = int(target.get("player_attack",21))
                actor["defense"] = int(target.get("player_defense",9))
                state.actors[i] = actor
            var core = Core.new()
            core.bind(state)
            var battle = Battle.new()
            root.add_child(battle)
            battle.game_core = core
            battle.dice.seed = 11000+chapter*3
            var settled: Dictionary = {"done":false,"victory":false,"calls":0}
            battle.completed.connect(func(won: bool,_xp: int,_gold: int) -> void:
                settled["done"] = true
                settled["victory"] = won
                settled["calls"] = int(settled["calls"])+1
            )
            battle.start(state,chapter,true)
            for _tick in range(MAX_ACTIONS):
                if bool(settled["done"]):
                    break
                if battle.hero_turn < 0 or battle.hero_turn >= state.actors.size():
                    errors.append("No valid turn: "+str(chapter)+"/"+difficulty)
                    break
                var actor: Dictionary = state.actors[battle.hero_turn]
                var hp_ratio: float = float(actor.get("hp",0))/float(maxi(1,int(actor.get("max_hp",1))))
                # Consumables are only used when actually available and beneficial.
                if hp_ratio < 0.3 and int(state.potions) > 0:
                    battle._act("potion")
                elif str(spec.get("goal","")) == "survive" and battle.current_round % 3 == 0:
                    battle._act("guard")
                else:
                    battle._act("special")
            if not bool(settled["done"]) or not bool(settled["victory"]) or int(settled["calls"]) != 1:
                errors.append("Boss not truly cleared with live commands: "+str(spec.get("boss_id",""))+
                    " / "+difficulty+" / round "+str(battle.current_round))
            elif str(spec.get("goal","")) == "pacify" and battle.last_boss_settlement != "nonlethal":
                errors.append("Nonlethal ending lost: "+str(spec.get("boss_id","")))
            battle.free()
    if errors.is_empty():
        print("PASS: live no-cheat Boss encounters with difficulty and party-size coverage")
        quit(0)
    else:
        for item in errors:
            push_error(item)
        quit(1)

func _read(path: String) -> Dictionary:
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}
