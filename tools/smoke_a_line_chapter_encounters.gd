extends SceneTree
## A-line real normal-monster regression: 72 chapters x three difficulties.
## Uses encounter registry's seeded RNG and actual party HP/MP/commands; no cheats.
const Battle = preload("res://scripts/first_act_battle.gd")
const Core = preload("res://scripts/rpg_core.gd")
const Save = preload("res://scripts/first_act_state.gd")
const Encounters = preload("res://scripts/encounter_registry.gd")
const MAX_ACTIONS: int = 120
const JOBS: Array[String] = [
    "swordsman","guardian","monk","ranger","healer","mage","engineer","bard",
    "star_knight","shadow_blade","high_priest","element_archmage","beast_keeper",
    "arc_gunner","war_singer","star_smith","oath_keeper","time_scholar",
    "celestial_sailor","allmaker"
]
var errors: Array[String] = []
var jobs_exercised: Dictionary = {}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var registry = Encounters.new()
    for chapter in range(1,73):
        var target: Dictionary = registry.progression(chapter)
        for difficulty_index in range(3):
            var difficulty: String = ["休闲","标准","挑战"][difficulty_index]
            var state = Save.new()
            state.chapter = chapter
            state.rpg["settings"] = {"difficulty":difficulty}
            state.recruit_sailor()
            if (chapter+difficulty_index)%2 == 0:
                state.actors.pop_back()
            for index in range(state.actors.size()):
                var member: Dictionary = state.actors[index]
                member["level"] = int(target.get("recommended_level",1))
                member["xp"] = 0
                member["max_hp"] = int(target.get("player_hp",112))
                member["hp"] = member["max_hp"]
                member["max_mp"] = int(target.get("player_mp",32))
                member["mp"] = member["max_mp"]
                member["attack"] = int(target.get("player_attack",21))
                member["defense"] = int(target.get("player_defense",9))
                state.actors[index] = member
            var core = Core.new()
            core.bind(state)
            for index in range(state.actors.size()):
                var actor_id: String = str(state.actors[index].get("id",""))
                var job: String = JOBS[(chapter*3+difficulty_index*7+index*4)%JOBS.size()]
                state.rpg["jobs"][actor_id] = job
                jobs_exercised[job] = true
            registry.rng.seed = 600000+chapter*7+difficulty_index
            var battle = Battle.new()
            root.add_child(battle)
            battle.encounter_registry = registry
            battle.game_core = core
            battle.dice.seed = 500000+chapter*7+difficulty_index
            var result: Dictionary = {"done":false,"win":false,"signals":0}
            battle.completed.connect(func(won: bool, _xp: int, _gold: int) -> void:
                result["done"] = true
                result["win"] = won
                result["signals"] = int(result["signals"])+1
            )
            battle.start(state,chapter,false)
            for _turn in range(MAX_ACTIONS):
                if bool(result["done"]):
                    break
                if battle.hero_turn < 0 or battle.hero_turn >= state.actors.size():
                    errors.append("No active actor chapter "+str(chapter)+" / "+difficulty)
                    break
                var actor: Dictionary = state.actors[battle.hero_turn]
                var ratio: float = float(actor.get("hp",0))/float(maxi(1,int(actor.get("max_hp",1))))
                if ratio < 0.30 and state.potions > 0:
                    battle._act("potion")
                else:
                    # Explicit target token is a real target selection, not direct HP editing.
                    var choices: Array[int] = battle.formation.alive_indices()
                    if choices.is_empty():
                        errors.append("No legal target chapter "+str(chapter))
                        break
                    battle._act("special#"+str(choices[0]))
            if not bool(result["done"]) or not bool(result["win"]) or int(result["signals"]) != 1:
                errors.append("Normal fight failed: chapter "+str(chapter)+
                    " / "+difficulty+" / turn "+str(battle.current_round))
            battle.free()
    if jobs_exercised.size() != JOBS.size():
        errors.append("Missing jobs in normal encounters: "+str(jobs_exercised.size()))
    if errors.is_empty():
        print("PASS: 216 seeded, live normal encounters, 72 chapters, 20 jobs, three difficulties")
        quit(0)
    else:
        for problem in errors:
            push_error(problem)
        quit(1)
