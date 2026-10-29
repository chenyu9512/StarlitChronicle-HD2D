extends Node
## All campaign state, including local offline saves. No external services or APIs.

const SAVE_PATH := "user://starlit_save_v1.json"
const SAVE_VERSION := 1
# Mutable only for isolated test paths; legacy release default remains unchanged.
var save_path: String = SAVE_PATH
var backup_path: String = SAVE_PATH + ".bak"

var map_id := "village"
var spawn_tile := Vector2i(12, 17)
var quest_stage := 0 # 0: see elder, 1: retrieve star core, 2: finished
var boss_defeated := false
var opened_chests: Array[String] = []
var gold := 35
var potions := 3
var party: Array[Dictionary] = []

# Canonical story progress is additional data; old v1 save files remain compatible.
var story_chapter: int = 0  # 0 = childhood prologue; 1..72 = main chapters
var story_scene: int = 0
var story_flags: Dictionary = {}
var story_ending: String = ""

# Temporary local developer switches are NEVER persisted in save files.
var cheat_god: bool = false
var cheat_no_encounters: bool = false
var cheat_xp_five: bool = false
var cheat_fast_walk: bool = false

func _ready() -> void:
    new_game()

func new_game() -> void:
    map_id = "village"
    spawn_tile = Vector2i(12, 17)
    quest_stage = 0
    boss_defeated = false
    opened_chests.clear()
    gold = 35
    potions = 3
    story_chapter = 0
    story_scene = 0
    story_flags.clear()
    story_ending = ""
    cheat_god = false
    cheat_no_encounters = false
    cheat_xp_five = false
    cheat_fast_walk = false
    party = [
        {"name":"黎昂", "level":1, "xp":0, "hp":96, "max_hp":96, "mp":20, "max_mp":20, "attack":17, "defense":5, "skill":"烈风斩"},
        {"name":"岚音", "level":1, "xp":0, "hp":71, "max_hp":71, "mp":46, "max_mp":46, "attack":11, "defense":3, "skill":"星火术"}
    ]

func save_game() -> bool:
    var payload := {
        "version": SAVE_VERSION,
        "map_id": map_id,
        "spawn_tile": [spawn_tile.x, spawn_tile.y],
        "quest_stage": quest_stage,
        "boss_defeated": boss_defeated,
        "opened_chests": opened_chests,
        "gold": gold,
        "potions": potions,
        "party": party,
        "story_chapter": story_chapter,
        "story_scene": story_scene,
        "story_flags": story_flags,
        "story_ending": story_ending
    }
    if not _valid_legacy_payload(payload):
        return false
    var temp: String = save_path + ".tmp"
    var file: FileAccess = FileAccess.open(temp,FileAccess.WRITE)
    if file == null:
        push_warning("V1存档临时写入失败：" + str(FileAccess.get_open_error()))
        return false
    file.store_string(JSON.stringify(payload,"  "))
    file.flush()
    file.close()
    if not _valid_legacy_payload(_read_legacy_payload(temp)):
        return false
    # Never destroy the previous good V1 save when temp write or verification fails.
    if FileAccess.file_exists(save_path):
        var old: Variant = _read_legacy_payload(save_path)
        if _valid_legacy_payload(old):
            var backup_temp: String = backup_path + ".tmp"
            var out: FileAccess = FileAccess.open(backup_temp,FileAccess.WRITE)
            if out == null:
                return false
            out.store_string(JSON.stringify(old,"  "))
            out.flush()
            out.close()
            if not _valid_legacy_payload(_read_legacy_payload(backup_temp)):
                return false
            if DirAccess.rename_absolute(
                    ProjectSettings.globalize_path(backup_temp),
                    ProjectSettings.globalize_path(backup_path)) != OK:
                return false
    return DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temp),
        ProjectSettings.globalize_path(save_path)) == OK

func _read_legacy_payload(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))

func _valid_legacy_payload(candidate: Variant) -> bool:
    if not (candidate is Dictionary):
        return false
    var data: Dictionary = candidate
    if typeof(data.get("version",-1)) not in [TYPE_INT,TYPE_FLOAT] or int(data["version"]) != SAVE_VERSION:
        return false
    var map_name: String = str(data.get("map_id",""))
    if map_name not in ["village","ruins"]:
        return false
    var coords: Variant = data.get("spawn_tile",null)
    if not (coords is Array) or coords.size()!=2:
        return false
    for v in coords:
        if typeof(v) not in [TYPE_INT,TYPE_FLOAT]:
            return false
    for field in ["quest_stage","gold","potions","story_chapter","story_scene"]:
        if data.has(field) and typeof(data[field]) not in [TYPE_INT,TYPE_FLOAT]:
            return false
    if int(data.get("gold",35))<0 or int(data.get("potions",3))<0:
        return false
    if not (data.get("party",null) is Array) or (data["party"] as Array).size()!=2:
        return false
    for person in data["party"]:
        if not (person is Dictionary):
            return false
        for field in ["name","hp","max_hp","mp","max_mp","level","xp"]:
            if not person.has(field):
                return false
        for field in ["hp","max_hp","mp","max_mp","level","xp"]:
            if typeof(person[field]) not in [TYPE_INT,TYPE_FLOAT]:
                return false
    if not (data.get("opened_chests",[]) is Array):
        return false
    if not (data.get("story_flags",{}) is Dictionary):
        return false
    return true

func load_game() -> bool:
    # V1 remains separate from V3; try the last known good backup before failing.
    var parsed: Variant = null
    for path in [save_path,backup_path]:
        var candidate: Variant = _read_legacy_payload(path)
        if _valid_legacy_payload(candidate):
            parsed = candidate
            break
    if not (parsed is Dictionary):
        return false
    var loaded: Dictionary = parsed
    var coords: Array = loaded.get("spawn_tile", [12, 17])
    if coords.size() != 2 or not (loaded.get("party", []) is Array):
        return false
    var new_party: Array = loaded["party"]
    if new_party.size() != 2 or not (new_party[0] is Dictionary) or not (new_party[1] is Dictionary):
        return false
    var loaded_map := str(loaded.get("map_id", "village"))
    if loaded_map != "village" and loaded_map != "ruins":
        return false
    map_id = loaded_map
    spawn_tile = Vector2i(int(coords[0]), int(coords[1]))
    quest_stage = clampi(int(loaded.get("quest_stage", 0)), 0, 2)
    boss_defeated = bool(loaded.get("boss_defeated", false))
    opened_chests.clear()
    for chest in loaded.get("opened_chests", []):
        opened_chests.append(str(chest))
    gold = maxi(0, int(loaded.get("gold", 35)))
    potions = maxi(0, int(loaded.get("potions", 3)))
    story_chapter = clampi(int(loaded.get("story_chapter", 0)), 0, 72)
    story_scene = maxi(0, int(loaded.get("story_scene", 0)))
    var imported_flags: Variant = loaded.get("story_flags", {})
    story_flags = imported_flags.duplicate(true) if imported_flags is Dictionary else {}
    story_ending = str(loaded.get("story_ending", ""))
    cheat_god = false
    cheat_no_encounters = false
    cheat_xp_five = false
    cheat_fast_walk = false
    party.clear()
    for entry in new_party:
        party.append(entry)
    return true

func grant_rewards(xp_amount: int, gold_amount: int) -> Array[String]:
    gold += gold_amount
    var level_ups: Array[String] = []
    for i in range(party.size()):
        var person: Dictionary = party[i]
        person["xp"] = int(person["xp"]) + xp_amount
        var threshold := int(person["level"]) * 42
        if int(person["xp"]) >= threshold:
            person["xp"] = int(person["xp"]) - threshold
            person["level"] = int(person["level"]) + 1
            person["max_hp"] = int(person["max_hp"]) + 12
            person["max_mp"] = int(person["max_mp"]) + 5
            person["attack"] = int(person["attack"]) + 3
            person["defense"] = int(person["defense"]) + 1
            person["hp"] = int(person["max_hp"])
            person["mp"] = int(person["max_mp"])
            level_ups.append(str(person["name"]) + " 升到了 Lv." + str(person["level"]) + "！")
        party[i] = person
    return level_ups

func fully_heal() -> void:
    for i in range(party.size()):
        var person: Dictionary = party[i]
        person["hp"] = int(person["max_hp"])
        person["mp"] = int(person["max_mp"])
        party[i] = person

func quest_title() -> String:
    if quest_stage == 0:
        return "主线：寻找村中的守灯人"
    if quest_stage == 1:
        if boss_defeated:
            return "主线：将星核交还守灯人"
        return "主线：深入星落遗迹，寻找星核"
    return "主线完成：星灯再次亮起"
