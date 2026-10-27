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
            # Canonical chapter roster, not the old arbitrary even/odd
            # two-person fixture that lacked all later story companions.
            if chapter >= 4:
                state.recruit_sailor()
            var core = Core.new()
            core.bind(state)
            if chapter >= 9:
                core.recruit_from_story(9)
            var expected_party: int = 2 if chapter < 4 else (3 if chapter < 9 else 4)
            if state.actors.size() != expected_party:
                errors.append("Wrong story roster at chapter %d: got %d, expected %d" %
                    [chapter,state.actors.size(),expected_party])
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
            # An actual support role is needed for late, long boss battles.
            # Rotate all 20 other roles; the production skill/MP rules remain.
            for i in range(state.actors.size()):
                var id: String = str(state.actors[i].get("id",""))
                var job: String = "healer" if id == "char_tidecaller" else JOBS[
                    ((chapter-1)*3+difficulty_index+i)%JOBS.size()]
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
                # Let the living, recruited healer use learned and affordable
                # real skills. No free heal, forged victory, invulnerability,
                # skipped hostile turn or manual change to boss HP.
                var did_cast: bool=false
                if str(actor.get("id","")) == "char_tidecaller":
                    var wounded: int=0
                    var weakest: int=-1
                    var lowest_ratio: float=1.0
                    for ally_index in range(state.actors.size()):
                        var ally: Dictionary=state.actors[ally_index]
                        if int(ally.get("hp",0)) <= 0 or not core.is_active(str(ally.get("id",""))):
                            continue
                        var ratio: float=float(ally.get("hp",0))/float(maxi(1,int(ally.get("max_hp",1))))
                        if ratio < 0.70:
                            wounded+=1
                        if ratio < lowest_ratio:
                            lowest_ratio=ratio
                            weakest=ally_index
                    if weakest>=0 and lowest_ratio<0.65:
                        var heals: Array=core.skills(str(actor.get("id","")))
                        heals.reverse()
                        for skill in heals:
                            var effect: Dictionary=skill.get("effect",{})
                            if str(effect.get("kind",""))!="heal" or int(skill.get("mp_cost",999))>int(actor.get("mp",0)):
                                continue
                            var skill_id: String=str(skill.get("id",""))
                            var target_type: String=str(skill.get("target",""))
                            if target_type=="all_allies" and wounded>=2:
                                battle._act("skill:"+skill_id)
                            elif target_type=="single_ally":
                                battle._act("skill:"+skill_id+"@"+str(weakest))
                            else:
                                continue
                            did_cast=true
                            break
                if did_cast:
                    continue
                if hp_ratio<0.45 and int(state.potions)>0 and core.count("item_herb_01")>0:
                    battle._act("potion")
                elif str(spec.get("goal",""))=="survive" and battle.current_round%3==0:
                    battle._act("guard")
                elif float(battle.round_boss_intent.get("multiplier",1.0))>=1.5 and hp_ratio<0.65:
                    battle._act("guard")
                else:
                    battle._act("special")
            if not bool(settled["done"]) or not bool(settled["victory"]) or int(settled["calls"]) != 1:
                var remaining_party_hp: Array[int]=[]
                for member in state.actors:
                    remaining_party_hp.append(int(member.get("hp",0)))
                errors.append("Boss not truly cleared with live commands: "+str(spec.get("boss_id",""))+
                    " / "+difficulty+" / round "+str(battle.current_round)+
                    " / victory="+str(settled.get("victory",false))+
                    " / callback_count="+str(settled.get("calls",0))+
                    " / enemy_hp="+str(battle.enemy.get("hp",0))+
                    " / party_hp="+str(remaining_party_hp))
            elif str(spec.get("goal","")) == "pacify" and battle.last_boss_settlement != "nonlethal":
                errors.append("Nonlethal ending lost: "+str(spec.get("boss_id","")))
            battle.free()
    if class_coverage.size() != JOBS.size():
        errors.append("Not every vocation entered a real Boss encounter: "+str(class_coverage.size()))
    if errors.is_empty():
        print("PASS: live no-cheat Boss encounters, canonical story rosters, 20 jobs, real MP healing, all difficulties")
        quit(0)
        return
    else:
        for item in errors:
            push_error(item)
        quit(1)

func _read(path: String) -> Dictionary:
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}
