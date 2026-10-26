extends SceneTree
## Deterministic Boss/career/72-chapter contract checks. One consolidated future Godot batch.
const BossMechanics = preload("res://scripts/battle_boss_mechanics.gd")
const Rules = preload("res://scripts/combat_rules.gd")
const Encounters = preload("res://scripts/encounter_registry.gd")
var problems: Array[String] = []

func ck(ok: bool, why: String) -> void:
    if not ok:
        problems.append(why)

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var encounters = Encounters.new()
    for problem in encounters.validate():
        problems.append(problem)
    var careers: Dictionary = _read("res://data/gameplay/vocation_profiles.json").get("jobs",{})
    var skills: Array = _read("res://data/content/skills.json").get("entries",[])
    var passives: Dictionary = {}
    ck(careers.size() == 20,"Expected 20 career profiles")
    ck(skills.size() == 63,"Canonical 63-skill catalog changed")
    var weapons: Array = _read("res://data/content/weapons.json").get("entries",[])
    for job in careers:
        var available_tiers: Dictionary = {}
        for weapon in weapons:
            if str(job) in weapon.get("job_tags",[]):
                available_tiers[int(weapon.get("tier",0))] = true
        for tier in range(1,10):
            ck(available_tiers.has(tier),"Career "+str(job)+" has no legal weapon at tier "+str(tier))
    for key in careers:
        var passive: String = str(careers[key].get("passive",""))
        ck(not passive.is_empty(),"Missing career passive: "+str(key))
        ck(not passives.has(passive),"Duplicate passive: "+passive)
        passives[passive] = true
    for skill in skills:
        var effect: Dictionary = skill.get("effect",{})
        ck(not (str(effect.get("kind","")) == "heal" and str(skill.get("target","")) in ["all_enemies","single_enemy"]),
            "Hostile-target heal skill: "+str(skill.get("id","")))
    var last_level: int = 0
    var last_hp: int = 0
    var last_price: int = 0
    for chapter in range(1,73):
        var target: Dictionary = encounters.progression(chapter)
        ck(not target.is_empty(),"Missing growth targets for chapter "+str(chapter))
        var level: int = int(target.get("recommended_level",0))
        var hp: int = int(target.get("player_hp",0))
        var price: int = int(target.get("equipment_price",0))
        ck(level >= last_level and level <= 99,"Nonmonotonic level "+str(chapter))
        ck(hp >= last_hp and hp > 0,"Nonmonotonic HP "+str(chapter))
        ck(price >= last_price and price > 0,"Nonmonotonic equipment price "+str(chapter))
        ck(int(target.get("monster_hp",0)) > 0 and int(target.get("boss_hp",0)) > 0,
            "Nonpositive enemy HP in chapter "+str(chapter))
        ck(float(target.get("rare_drop_chance",-1.0)) >= 0.0 and float(target.get("rare_drop_chance",2.0)) <= 1.0,
            "Invalid rare drop probability "+str(chapter))
        last_level = level
        last_hp = hp
        last_price = price
    var table: Array = _read("res://data/gameplay/boss_mechanics.json").get("entries",[])
    ck(table.size() == 66,"Expected 66 Boss execution profiles")
    var found: Dictionary = {}
    var type_count: Dictionary = {}
    for row in table:
        var entry: Dictionary = row
        var id: String = str(entry.get("boss_id",""))
        ck(not found.has(id) and not id.is_empty(),"Duplicated Boss runtime id: "+id)
        found[id] = true
        var goal: String = str(entry.get("goal",""))
        type_count[goal] = int(type_count.get(goal,0))+1
        var story: Dictionary = encounters.story_bosses.get(id,{})
        ck(not story.is_empty(),"Boss runtime has no authored story: "+id)
        var mech = BossMechanics.new()
        mech.start(entry)
        ck(int(mech.report().get("ward",-1)) >= 0,"Negative ward: "+id)
        if goal == "legacy":
            ck(not mech.enabled(),"Legacy Boss was overridden: "+id)
            continue
        ck(mech.enabled(),"Missing executable Boss mechanics: "+id)
        ck(mech.objective_label() != "","Missing Boss win objective: "+id)
        var intent: Dictionary = mech.intent(2)
        ck(float(intent.get("multiplier",0.0)) > 0.0,"No Boss attack: "+id)
        var start_value: float = mech.damage_factor()
        var first: Dictionary = mech.record_action("special",{}, "ally_A",1)
        var retry: Dictionary = mech.record_action("special",{}, "ally_A",1)
        ck(int(mech.report().get("progress",0)) == int(first.get("victory",false)) * 0 + 1,
            "Actor could farm progress in one round: "+id)
        ck(not bool(retry.get("victory",false)),"Duplicate turn granted a victory: "+id)
        ck(mech.damage_factor() >= start_value or int(mech.report().get("ward",0)) > 0,
            "Ward break reduced damage: "+id)
        mech.set_phase_two()
        ck(bool(mech.report().get("phase_two",false)),"Phase did not advance: "+id)
        var finished: Dictionary = {}
        for turn in range(2,12):
            finished = mech.record_action("special",{}, "ally_A",turn)
        if goal == "defeat":
            ck(not bool(finished.get("victory",false)),"Lethal Boss escaped by command-only win: "+id)
        elif goal in ["pacify","survive"]:
            ck(bool(finished.get("victory",false)),"Nonlethal objective has no reachable terminal condition: "+id)
            ck(mech.protect_from_lethal(),"Nonlethal Boss can be killed before its objective: "+id)
    ck(type_count.get("defeat",0) > 0 and type_count.get("pacify",0) > 0 and type_count.get("survive",0) == 1,
        "Boss outcomes lost their diversity")
    var rules = Rules.new()
    for difficulty in ["休闲","标准","挑战"]:
        rules.start({"difficulty":difficulty})
        for damage in [0,1,200,1000000]:
            ck(rules.mitigated_damage(damage,"ally",true) >= 0,"Negative damage in "+difficulty)
            ck(rules.mitigated_damage(damage,"ally",false) <= 1500000,"Overflowed damage in "+difficulty)
    if problems.is_empty():
        print("PASS: 66 Boss runtime contracts, 20 distinct vocation hooks, 72 progression targets and safe damage bounds")
        quit(0)
    else:
        for issue in problems:
            push_error(issue)
        quit(1)

func _read(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}
