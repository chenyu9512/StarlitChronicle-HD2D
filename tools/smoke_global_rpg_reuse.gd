extends SceneTree
## One full-batch smoke for reusable RPG rules across the 72-chapter game.
## No player save, cheat flags, simulated Boss kills or production files touched.
const Save = preload("res://scripts/first_act_state.gd")
const Core = preload("res://scripts/rpg_core.gd")
const Routes = preload("res://scripts/world_registry.gd")
const Encounters = preload("res://scripts/encounter_registry.gd")
var problems: Array[String] = []

func ck(ok: bool, message: String) -> void:
    if not ok:
        problems.append(message)

func _initialize() -> void:
    call_deferred("_verify")

func contains_skill(skills: Array, id: String) -> bool:
    for skill in skills:
        if str(skill.get("id","")) == id:
            return true
    return false

func _verify() -> void:
    var state = Save.new()
    state.save_path = "user://smoke_global_rules_%d.json" % OS.get_process_id()
    state.backup_path = state.save_path + ".bak"
    var core = Core.new()
    core.bind(state)
    var routes = Routes.new()
    routes.bind(state)
    var encounters = Encounters.new()
    ck(core.jobs.size() == 20 and core.vocation_profiles.size() == 20,
        "The 20 shared career profiles are not all registered")
    ck(core.records("skills").size() == 63, "63 canonical skill definitions missing")
    ck(core.records("story_bosses").size() == 66, "66 original story Bosses missing")
    ck(core.records("monsters").size() == 63, "63 regional monster definitions missing")
    ck(encounters.validate().is_empty(), "Canonical encounter registry invalid")

    var previous_tier: int = 1
    for chapter in range(1,73):
        state.chapter = chapter
        core.register_chapter(chapter)
        routes.sync_chapter(chapter)
        ck(not core.chapter_data(chapter).is_empty(),"Chapter %d is not playable" % chapter)
        ck(not routes.current_info().is_empty(),"Chapter %d has no world route" % chapter)
        var region: String = encounters.region_for(chapter)
        ck(not region.is_empty(),"Chapter %d has no encounter region" % chapter)
        var foe: Dictionary = encounters.roll_monster(chapter)
        ck(not foe.is_empty() and not str(foe.get("monster_id","")).is_empty(),
            "Chapter %d cannot load a world encounter" % chapter)
        var tier: int = core.market_tier()
        ck(tier >= previous_tier and tier >= 1 and tier <= 10,
            "Chapter %d has an invalid merchandise tier" % chapter)
        previous_tier = tier
    ck(core.market_tier() == 10, "Chapter 72 did not unlock the last merchandise tier")
    state.chapter = 1
    ck(core.market_tier() == 1, "Opening chapter exposes endgame merchandise")

    var late_item: String = ""
    for row in core.records("weapons"):
        if int(row.get("tier",0)) == 9:
            late_item = str(row.get("id",""))
            break
    ck(not late_item.is_empty(),"No ninth-tier weapon to validate merchandise gate")
    state.gold = 100000
    if not late_item.is_empty():
        ck(not core.shop_available(core.entry("weapons",late_item)),
            "Endgame weapon exposed at chapter one")
        ck(not core.buy(late_item).begins_with("购买了"),
            "Early-game shop illegally sold ninth-tier equipment")
        state.chapter = 72
        ck(core.shop_available(core.entry("weapons",late_item)),
            "Final act did not unlock the ninth-tier weapon")

    var hero: String = "char_wayfarer"
    state.rpg["equipment"][hero] = {}
    var base_attack: int = int(state.actors[0]["attack"])
    var base_speed: int = int(state.actors[0]["speed"])
    for job_id in core.jobs.keys():
        var job: String = str(job_id)
        ck(core.vocation_profiles.has(job),"Missing shared profile "+job)
        state.rpg["jobs"][hero] = job
        var roster: Dictionary = state.rpg["mastery"][hero]
        roster[job] = {"rank":1,"xp":0}
        state.rpg["mastery"][hero] = roster
        var profile: Dictionary = core.vocation_profiles.get(job,{})
        var stats: Dictionary = core.gear_stats(hero)
        ck(int(stats.get("attack",-1)) == base_attack + int(profile.get("attack",0)),
            "Missing attack profile for "+job)
        ck(int(stats.get("speed",-1)) == base_speed + int(profile.get("speed",0)),
            "Missing speed profile for "+job)
    ck(int(state.actors[0]["attack"]) == base_attack and
        int(state.actors[0]["speed"]) == base_speed,
        "Changing vocations mutated permanent base attributes")

    state.rpg["jobs"][hero] = "swordsman"
    state.chapter = 1
    core.add_item("wpn_sword_01",1)
    ck(core.equip(hero,"weapon","wpn_sword_01").begins_with("装备成功"),
        "Starter sword could not be equipped")
    ck(core.change_job(hero,"guardian").begins_with("已转职"),
        "Switching to an incompatible basic job failed")
    ck(str(state.rpg["equipment"][hero].get("weapon","")).is_empty(),
        "Changing jobs retained an illegal weapon")
    ck(core.count("wpn_sword_01") >= 1,
        "Automatically removed sword vanished instead of returning to bag")

    state.actors[0]["level"] = 30
    state.rpg["mastery"][hero]["swordsman"] = {"rank":1,"xp":0}
    ck(not contains_skill(core.skills(hero),"skill_wayfarer_01"),
        "Unmastered old-job skill leaked after switch")
    state.rpg["mastery"][hero]["swordsman"] = {"rank":8,"xp":0}
    var learned: Array = core.skills(hero)
    for tier in range(1,4):
        ck(contains_skill(learned,"skill_wayfarer_%02d" % tier),
            "Fully mastered vocation did not retain its first three techniques")
    ck(not contains_skill(learned,"skill_wayfarer_04"),
        "A high-tier skill was incorrectly inherited from another vocation")
    state.actors[0]["level"] = 1
    ck(not contains_skill(core.skills(hero),"skill_wayfarer_02"),
        "Inherited skill bypassed the character level requirement")

    ck(core.codex_record("monsters","mon_coast_01").is_empty(),
        "Unencountered monster is visible in a new save")
    core.record_enemy_seen("monsters","mon_coast_01")
    ck(bool(core.codex_record("monsters","mon_coast_01").get("seen",false)),
        "Seeing a normal monster did not unlock the global codex")
    core.record_enemy_resolution("monsters","mon_coast_01")
    ck(int(core.codex_record("monsters","mon_coast_01").get("resolved",0)) == 1,
        "Normal-monster settlement was not recorded once")
    for id in encounters.story_bosses.keys():
        ck(not core.entry("story_bosses",str(id)).is_empty(),
            "Story Boss ID not indexed in RPG core: "+str(id))
    core.record_enemy_seen("story_bosses","boss.ch002")
    core.record_enemy_resolution("story_bosses","boss.ch002")
    ck(int(core.codex_record("story_bosses","boss.ch002").get("resolved",0)) == 1,
        "Nonlethal story Boss resolution missing")
    ck(state.save(), "New global rule fields were not saved")
    ck(state.load_saved(), "V3 save with global vocation/codex fields would not load")
    core.bind(state)
    ck(int(core.codex_record("monsters","mon_coast_01").get("resolved",0)) == 1,
        "World monster discovery lost after save/reload")
    ck(int(core.codex_record("story_bosses","boss.ch002").get("resolved",0)) == 1,
        "Story Boss discovery lost after save/reload")
    ck(int(state.rpg["mastery"][hero]["swordsman"].get("rank",0)) == 8,
        "Mastered vocation rank not preserved in V3 save")
    for filepath in [state.save_path,state.backup_path,
        state.save_path + ".tmp",state.backup_path + ".tmp"]:
        if FileAccess.file_exists(filepath):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(filepath))
    if problems.is_empty():
        print("PASS: 72 chapters, 20 roles, 63 skills, 63 monsters, 66 Bosses, 10 market tiers, safe job change, inherited techniques and V3 codex")
        quit(0)
    else:
        for fault in problems:
            push_error(fault)
        quit(1)
