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
var class_coverage: Dictionary = {}
const JOBS: Array[String] = [
    "swordsman","guardian","monk","ranger","healer","mage","engineer","bard",
    "star_knight","shadow_blade","high_priest","element_archmage","beast_keeper",
    "arc_gunner","war_singer","star_smith","oath_keeper","time_scholar",
    "celestial_sailor","allmaker"
]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var encounters = Encounters.new()
    for spec in _read("res://data/gameplay/boss_mechanics.json").get("entries",[]):
        var chapter: int = int(spec.get("chapter",0))
        var target: Dictionary = encounters.progression(chapter)
        for difficulty_index in range(3):
            var difficulty: String = ["休闲","标准","挑战"][difficulty_index]
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
            # Rotate all 20 vocations through live turns, without changing their unlock rules
            # in the production core; assignments here are isolated encounter fixtures.
            for i in range(state.actors.size()):
                var id: String = str(state.actors[i].get("id",""))
                var job: String = JOBS[((chapter-1)*3+difficulty_index+i)%JOBS.size()]
                state.rpg["jobs"][id] = job
                class_coverage[job] = true
            var battle = Battle.new()
            root.add_child(battle)
            battle.game_core = core
            battle.encounter_registry = encounters
            encounters.rng.seed = 22000+chapter*3+difficulty_index
            battle.dice.seed = 11000+chapter*3+difficulty_index
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
                    " / "+difficulty+" / round "+str(battle.current_round)+
                    " / victory="+str(settled.get("victory",false))+
                    " / callback_count="+str(settled.get("calls",0))+
                    " / enemy_hp="+str(battle.enemy.get("hp",0))+
                    " / party_hp="+str(state.actors.map(func(member: Dictionary) -> int:
                        return int(member.get("hp",0)))))
            elif str(spec.get("goal","")) == "pacify" and battle.last_boss_settlement != "nonlethal":
                errors.append("Nonlethal ending lost: "+str(spec.get("boss_id","")))
            battle.free()
    if class_coverage.size() != JOBS.size():
        errors.append("Not every vocation entered a real Boss encounter: "+str(class_coverage.size()))
    if errors.is_empty():
        print("PASS: live no-cheat Boss encounters, 20 rotating jobs, all difficulties and party sizes")
        quit(0)
    else:
        for item in errors:
            push_error(item)
        quit(1)

func _read(path: String) -> Dictionary:
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}
