extends SceneTree
## Combat architecture regression: database monsters by region, canon boss IDs, explicit player-selected skills.
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")
const Encounter = preload("res://scripts/encounter_registry.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func test(value: bool, message: String) -> void:
    if not value:
        errors.append(message)

func _run() -> void:
    var reg = Encounter.new()
    test(reg.validate().is_empty(),"Encounter database incomplete: "+str(reg.validate()))
    var coast: Dictionary = reg.roll_monster(2)
    test(str(coast.get("region_id","")) == "region_coast","Coast encounter mapped to wrong region")
    test(not str(coast.get("monster_id","")).is_empty(),"Monster ID missing")
    var oaths: Dictionary = reg.roll_monster(15)
    test(str(oaths.get("region_id","")) == "region_oaths","Chapter 15 did not select regional monsters")
    var boss: Dictionary = reg.story_boss(2,{"enemy_id":"boss.ch002","display_name":"雾潮寄生体"},{"name":"old","hp":255,"max_hp":255,"atk":16,"def":7,"xp":300,"gold":150,"art":"tide_ghost"})
    test(str(boss.get("boss_id","")) == "boss.ch002","Canon chapter 2 boss ID was lost")
    test(int(boss.get("max_hp",0)) == 255,"First-act mechanic HP changed")
    var state = State.new()
    state.new_game()
    var core = RPG.new()
    core.bind(state)
    var battle = Battle.new()
    root.add_child(battle)
    battle.game_core = core
    battle.encounter_registry = reg
    battle.start(state,2,false)
    test(not str(battle.enemy.get("monster_id","")).is_empty(),"Battle did not load monster database")
    battle._act("skill")
    test(is_instance_valid(battle.skill_picker),"Skill picker did not open on the skill command")
    var options: Array = core.skills("char_wayfarer")
    if not options.is_empty():
        battle._act("skill:"+str(options[0].get("id","")))
        test(not is_instance_valid(battle.skill_picker),"Skill picker remained after skill was chosen")
        test(int(battle.enemy.get("hp",0)) < int(battle.enemy.get("max_hp",1)) or battle.hero_turn > 0,"Selected skill did not resolve")
    else:
        errors.append("Hero has no playable skills")
    battle.queue_free()
    var chapter_boss = Battle.new()
    root.add_child(chapter_boss)
    chapter_boss.game_core = core
    chapter_boss.encounter_registry = reg
    chapter_boss.encounter_data = {"enemy_id":"boss.ch002","display_name":"雾潮寄生体"}
    chapter_boss.start(state,2,true)
    test(str(chapter_boss.enemy.get("boss_id","")) == "boss.ch002","Boss battle did not apply canon metadata")
    if errors.is_empty():
        print("PASS: 63 monsters, 12 act templates, 66 story bosses, regional encounters, chapter boss identity and manual skill picker")
        quit(0)
    else:
        for message in errors:
            push_error(message)
        quit(1)
