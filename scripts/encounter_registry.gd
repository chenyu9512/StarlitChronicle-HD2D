extends RefCounted
## 72章遭遇层：63种地区怪物、66场剧情Boss与12幕基础Boss数值模板。
## 没有特制动作的Boss保留美术回退，但敌人ID、数值、掉落都来自统一目录。
const BattleWorldHandoff = preload("res://scripts/battle_world_handoff.gd")
## Exact order is the canonical mon_coast_01..09 content registry, not the
## old hand-entered sprite-sheet order: wrong aliases showed a hermit crab
## for the sand lizard and a lizard for the coastal white seabird.
const COAST_ART: Array[String] = ["salt_slime","fog_crab","sand_lizard","tide_ghost","white_seabird","shell_hermit","salt_wolf","star_ray","tide_guardian"]
var monsters: Array = []
var story_bosses: Dictionary = {}
var act_bosses: Dictionary = {}
var regions: Dictionary = {}
var boss_profiles: Dictionary = {}
var chapter_curves: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
    monsters = _read("res://data/content/monsters.json").get("entries", [])
    var r: Dictionary = _read("res://data/content/bosses.json")
    for b in r.get("entries",[]):
        if b is Dictionary:
            act_bosses[int(b.get("act",0))] = b
    for b in _read("res://story/data/bosses.json").get("bosses",[]):
        if b is Dictionary:
            story_bosses[str(b.get("id",""))] = b
    for entry in _read("res://data/content/quests.json").get("entries",[]):
        if entry is Dictionary and str(entry.get("kind","")) == "main":
            regions[int(entry.get("chapter",0))] = str(entry.get("region_id","region_coast"))
    for row in _read("res://data/gameplay/boss_mechanics.json").get("entries",[]):
        if row is Dictionary:
            boss_profiles[str(row.get("boss_id",""))] = row
    for row in _read("res://data/gameplay/combat_progression.json").get("chapters",[]):
        if row is Dictionary:
            chapter_curves[int(row.get("chapter",0))] = row
    rng.randomize()

func _read(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func progression(chapter: int) -> Dictionary:
    return chapter_curves.get(clampi(chapter,1,72),{})

func boss_profile(id: String) -> Dictionary:
    return boss_profiles.get(id,{})

func region_for(chapter: int) -> String:
    return str(regions.get(chapter,"region_coast"))

## Read-only world encounter gate for D-line controller integration.
func world_encounter_gate(mode: String, context: Dictionary) -> Dictionary:
    return BattleWorldHandoff.eligible(mode,context)

func roll_monster(chapter: int) -> Dictionary:
    var region: String = region_for(chapter)
    var pool: Array = []
    for monster in monsters:
        if str(monster.get("region_id","")) == region and int(monster.get("level",0)) <= chapter + 5:
            pool.append(monster)
    if pool.is_empty():
        for monster in monsters:
            if str(monster.get("region_id","")) == region:
                pool.append(monster)
    if pool.is_empty():
        pool = monsters
    if pool.is_empty():
        return {}
    var source: Dictionary = pool[rng.randi_range(0,pool.size()-1)]
    var growth: Dictionary = progression(chapter)
    var recommended: int = maxi(1,int(growth.get("recommended_level",chapter)))
    var enemy_level: int = maxi(1,int(source.get("level",recommended)))
    var level_weight: float = clampf(float(enemy_level+8)/float(recommended+8),0.80,1.20)
    var scaled_hp: int = maxi(1,roundi(float(growth.get("monster_hp",source.get("hp",40)))*level_weight))
    var scaled_attack: int = maxi(1,roundi(float(growth.get("monster_attack",source.get("attack",10)))*level_weight))
    var scaled_xp: int = maxi(1,roundi(float(growth.get("normal_xp",source.get("xp",10)))*level_weight))
    var scaled_gold: int = maxi(0,roundi(float(growth.get("normal_gold",source.get("gold",5)))*level_weight))
    var id: String = str(source.get("id",""))
    var art: String = ""
    if id.begins_with("mon_coast_"):
        var n: int = int(id.trim_prefix("mon_coast_")) - 1
        if n >= 0 and n < COAST_ART.size():
            art = COAST_ART[n]
    return {
        "name":str(source.get("name",id)),
        "monster_id":id, "region_id":region,
        "hp":scaled_hp,"max_hp":scaled_hp,
        "atk":scaled_attack,"def":maxi(0,int(source.get("defense",3))),
        "speed":maxi(1,int(source.get("speed",8))),
        "ai_pattern":str(source.get("ai_pattern","基本攻击")),
        "status_immunities":source.get("status_immunities",[]),
        "status_resistances":source.get("status_resistances",{}),
        "xp":scaled_xp,"gold":scaled_gold,
        "element":str(source.get("element","")),"weakness":str(source.get("weakness","")),
        "art":art
    }

func story_boss(chapter: int, encounter: Dictionary, fallback: Dictionary) -> Dictionary:
    var id: String = str(encounter.get("enemy_id","boss.ch%03d" % chapter))
    var story: Dictionary = story_bosses.get(id,{})
    if story.is_empty():
        return fallback
    var act: int = int((chapter-1)/6) + 1
    var template: Dictionary = act_bosses.get(act,{})
    var progression_target: Dictionary = progression(chapter)
    var base_hp: int = maxi(1,int(fallback.get("max_hp",180)))
    var hp: int = base_hp if chapter <= 6 else maxi(base_hp,int(progression_target.get("boss_hp",int(template.get("hp",220))+chapter*19)))
    var atk: int = int(fallback.get("atk",15)) if chapter <= 6 else maxi(int(fallback.get("atk",15)),int(progression_target.get("boss_attack",int(template.get("attack",15))+chapter*2)))
    var defense: int = int(fallback.get("def",5)) if chapter <= 6 else maxi(int(fallback.get("def",5)),int(progression_target.get("boss_defense",int(template.get("defense",5))+int(chapter/2))))
    var result: Dictionary = fallback.duplicate(true)
    result["is_boss"] = true
    result["speed"] = maxi(1,int(story.get("speed",min(18,7+int(chapter/4)))))
    result["ai_pattern"] = str(story.get("ai_pattern","阶段压迫"))
    result["status_immunities"] = story.get("status_immunities",["sleep","stun","freeze"])
    result["status_resistances"] = story.get("status_resistances",{"poison":0.5,"burn":0.35,"slow":0.4})
    result["name"] = str(encounter.get("display_name",story.get("name",id)))
    result["boss_id"] = id
    result["chapter_id"] = str(story.get("chapter_id",""))
    result["hp"] = hp
    result["max_hp"] = hp
    result["atk"] = atk
    result["def"] = defense
    # First-act authored XP must override the high legacy fallback. Later
    # chapters retain their existing growth and reward floor.
    if chapter <= 6 and progression_target.has("boss_xp"):
        result["xp"] = maxi(0,int(progression_target["boss_xp"]))
    else:
        result["xp"] = maxi(maxi(int(result.get("xp",0)),int(chapter*34+120)),
            int(progression_target.get("boss_xp",chapter*34+120)))
    result["gold"] = maxi(int(result.get("gold",0)),int(progression_target.get("boss_gold",chapter*14+55)))
    var mechanism: Dictionary = boss_profile(id)
    result["boss_mechanics"] = mechanism.duplicate(true)
    if not mechanism.is_empty():
        result["status_resistances"] = mechanism.get("status_resistances",result["status_resistances"])
        result["status_immunities"] = ["sleep","stun","freeze"]
    result["phase_design"] = story.get("phase_design",[])
    result["art_status"] = "fallback" if chapter > 6 else "first_act_art"
    return result

func validate() -> Array[String]:
    var mistakes: Array[String] = []
    if monsters.size() != 63:
        mistakes.append("怪物应有63条")
    if act_bosses.size() != 12:
        mistakes.append("幕Boss规划应有12条")
    if story_bosses.size() != 66:
        mistakes.append("剧情Boss应有66场")
    if boss_profiles.size() != 66:
        mistakes.append("Boss战斗执行配置应有66条")
    if chapter_curves.size() != 72:
        mistakes.append("成长曲线应覆盖72章")
    for id in story_bosses.keys():
        if not boss_profiles.has(id):
            mistakes.append("Boss缺少执行配置："+str(id))
    for chapter in range(1,73):
        if not regions.has(chapter):
            mistakes.append("第%d章缺少地区映射" % chapter)
    return mistakes
