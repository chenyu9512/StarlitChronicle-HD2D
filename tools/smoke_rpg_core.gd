extends SceneTree
## 核心系统动态回归：背包、装备、职业、技能、出战、锻造、商店和扩展栏目UI。
const State = preload("res://scripts/first_act_state.gd")
const Core = preload("res://scripts/rpg_core.gd")
const Menu = preload("res://scripts/rpg_menu.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, message: String) -> void:
    if not value:
        failures.append(message)

func _run() -> void:
    var state = State.new()
    state.new_game()
    var core = Core.new()
    core.bind(state)
    _check(core.records("weapons").size() >= 81, "Weapon DB missing")
    _check(core.records("armor").size() >= 54, "Armor DB missing")
    _check(core.records("skills").size() >= 63, "Skills DB missing")
    _check(core.jobs.size() == 20, "All 20 career jobs missing")
    _check(core.chapter_data(72).get("number",-1) == 72, "All 72 chapters unavailable")
    _check(core.skills("char_wayfarer").size() > 0, "Default swordsman skill missing")
    _check(core.skills("char_tidecaller").size() > 0, "Default healer skill missing")
    var hero: String = "char_wayfarer"
    var baseline: int = int(core.gear_stats(hero).get("attack",0))
    _check(core.buy("wpn_sword_01").begins_with("购买"), "Weapon purchase failed")
    _check(core.count("wpn_sword_01") == 1, "Weapon did not enter inventory")
    _check(core.equip(hero,"weapon","wpn_sword_01").begins_with("装备成功"), "Equipping failed")
    _check(core.gear_stats(hero).get("attack",0) > baseline, "Weapon bonus not applied")
    _check(core.count("wpn_sword_01") == 0, "Equipped weapon still in bag")
    _check(core.unequip(hero,"weapon").begins_with("装备已"), "Unequipping failed")
    _check(core.gear_stats(hero).get("attack",0) == baseline, "Weapon bonus stayed after removal")
    _check(not core.change_job(hero,"guardian").begins_with("已转职"), "Ch15 vocation gate bypassed")
    state.chapter = 16
    state.flags["story.ch015.done"] = true
    _check(core.change_job(hero,"guardian").begins_with("已转职"), "Career switching after ch015 failed")
    _check(core.skills(hero).size() > 0, "Career skill mapping invalid")
    _check(core.toggle_party("char_tidecaller") == "阵容已经更新。", "Party configuration failed")
    _check(not core.is_active("char_tidecaller"), "Removed party member still active")
    _check(core.toggle_party("char_tidecaller") == "阵容已经更新。", "Party restore failed")
    var start_herbs: int = state.potions
    core.add_item("item_herb_01",2)
    _check(state.potions == start_herbs + 2, "Herbs and inventory out of sync")
    state.actors[0]["hp"] = maxi(1,int(state.actors[0]["hp"]) - 35)
    _check(core.use_item("item_herb_01",hero).begins_with("使用了"), "Consumable action failed")
    _check(state.potions == start_herbs + 1, "Potion was not consumed")
    core.register_chapter(72)
    _check(core.chapter_name(72).length() > 2, "Chapter 72 title missing")
    state.rpg["test_key"] = {"checkpoint":"OK"}
    var old_gold: int = state.gold
    _check(state.save(), "Full progression save failed")
    _check(state.load_saved(), "Full progression reload failed")
    _check(state.rpg.get("test_key",{}).get("checkpoint","") == "OK" and state.gold == old_gold, "RPG fields did not persist")
    _check(core.narrative_side_quests.size() >= 120, "Expected 120 chapter, companion and region story quests")
    state.chapter = 72
    state.flags["story.ch003.done"] = true
    var companion_available: bool = false
    for task in core.available_story_side_list(72):
        if str(task.get("type","")) == "companion":
            companion_available = true
            _check(core.select_story_side(str(task.get("id",""))).begins_with("已追踪"),"Selecting companion quest failed")
            break
    _check(companion_available,"Unlocked companion quests missing")
    _check(Menu.SECTIONS.size() >= 14, "Expanded gameplay menu missing panels")
    var menu = Menu.new()
    root.add_child(menu)
    menu.show_menu(core,state)
    for section in Menu.SECTIONS:
        menu.render(section)
    _check(menu.root.visible, "The expanded menu did not open")
    menu.close_menu()
    _check(not menu.root.visible, "The menu did not close")
    if not failures.is_empty():
        for error in failures:
            push_error(error)
        quit(1)
    else:
        print("PASS: 81 weapons, 54 armor, 63 skills, 20 jobs, equipment stats, bag, shop, jobs, 4-party, consumables, save and expanded menu sections")
        quit(0)
