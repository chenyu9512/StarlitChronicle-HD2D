extends RefCounted
## 72章遭遇层：63种地区怪物、66场剧情Boss与12幕基础Boss数值模板。
## 没有特制动作的Boss保留美术回退，但敌人ID、数值、掉落都来自统一目录。
const COAST_ART: Array[String] = ["salt_slime","fog_crab","shell_hermit","tide_ghost","sand_lizard","salt_wolf","white_seabird","star_ray","tide_guardian"]
var monsters: Array = []
var story_bosses: Dictionary = {}
var act_bosses: Dictionary = {}
var regions: Dictionary = {}
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
    rng.randomize()

func _read(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func region_for(chapter: int) -> String:
    return str(regions.get(chapter,"region_coast"))

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
    var id: String = str(source.get("id",""))
    var art: String = ""
    if id.begins_with("mon_coast_"):
        var n: int = int(id.trim_prefix("mon_coast_")) - 1
        if n >= 0 and n < COAST_ART.size():
            art = COAST_ART[n]
    return {
        "name":str(source.get("name",id)),
        "monster_id":id, "region_id":region,
        "hp":maxi(1,int(source.get("hp",40))),"max_hp":maxi(1,int(source.get("hp",40))),
        "atk":maxi(1,int(source.get("attack",10))),"def":maxi(0,int(source.get("defense",3))),
        "xp":maxi(1,int(source.get("xp",10))),"gold":maxi(0,int(source.get("gold",5))),
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
    var base_hp: int = maxi(1,int(fallback.get("max_hp",180)))
    var hp: int = base_hp if chapter <= 6 else maxi(base_hp,int(template.get("hp",220))+chapter*19)
    var atk: int = int(fallback.get("atk",15)) if chapter <= 6 else maxi(int(fallback.get("atk",15)),int(template.get("attack",15))+chapter*2)
    var defense: int = int(fallback.get("def",5)) if chapter <= 6 else maxi(int(fallback.get("def",5)),int(template.get("defense",5))+int(chapter/2))
    var result: Dictionary = fallback.duplicate(true)
    result["name"] = str(encounter.get("display_name",story.get("name",id)))
    result["boss_id"] = id
    result["chapter_id"] = str(story.get("chapter_id",""))
    result["hp"] = hp
    result["max_hp"] = hp
    result["atk"] = atk
    result["def"] = defense
    result["xp"] = maxi(int(result.get("xp",0)),int(chapter*34+120))
    result["gold"] = maxi(int(result.get("gold",0)),int(chapter*14+55))
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
    for chapter in range(1,73):
        if not regions.has(chapter):
            mistakes.append("第%d章缺少地区映射" % chapter)
    return mistakes
