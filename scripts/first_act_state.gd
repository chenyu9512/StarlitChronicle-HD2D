extends RefCounted
## 第一幕独立的可迁移游戏进度：原 v1 存档永不覆盖。
const SAVE_PATH: String = "user://first_act_v3.json"
const BACKUP_PATH: String = "user://first_act_v3.backup.json"
const VERSION: int = 3
var chapter: int = 0
var scene_index: int = 0
var task_index: int = 0
var dialogue_seen: bool = false
var gold: int = 80
var potions: int = 6
var flags: Dictionary = {}
var actors: Array[Dictionary] = []
var inventory: Dictionary = {"item_herb_01": 6}
var level_cap: int = 40
var play_seconds: float = 0.0

func _init() -> void:
    new_game()

func new_game() -> void:
    chapter = 0
    scene_index = 0
    task_index = 0
    dialogue_seen = false
    gold = 80
    potions = 6
    flags = {}
    inventory = {"item_herb_01": 6}
    play_seconds = 0.0
    actors = [
        {"id": "char_wayfarer", "name": "黎昂", "level": 1, "xp": 0, "hp": 112, "max_hp": 112, "mp": 32, "max_mp": 32, "attack": 21, "defense": 9, "speed": 11, "skill": "星火斩"},
        {"id": "char_tidecaller", "name": "岚音", "level": 1, "xp": 0, "hp": 88, "max_hp": 88, "mp": 56, "max_mp": 56, "attack": 15, "defense": 7, "speed": 13, "skill": "潮愈术"}
    ]

func recruit_sailor() -> void:
    for member in actors:
        if str(member.get("id", "")) == "char_seeker":
            return
    actors.append({"id": "char_seeker", "name": "朔弦", "level": 8, "xp": 0, "hp": 136, "max_hp": 136, "mp": 35, "max_mp": 35, "attack": 30, "defense": 15, "speed": 16, "skill": "破雾击"})

func heal_all() -> void:
    for i in range(actors.size()):
        var person: Dictionary = actors[i]
        person["hp"] = int(person["max_hp"])
        person["mp"] = int(person["max_mp"])
        actors[i] = person

func heal_member(index: int, amount: int) -> bool:
    if index < 0 or index >= actors.size():
        return false
    var person: Dictionary = actors[index]
    if int(person["hp"]) >= int(person["max_hp"]):
        return false
    person["hp"] = mini(int(person["max_hp"]), int(person["hp"]) + amount)
    actors[index] = person
    return true

func give_rewards(xp: int, money: int) -> Array[String]:
    gold += maxi(0, money)
    var messages: Array[String] = []
    for i in range(actors.size()):
        var a: Dictionary = actors[i]
        a["xp"] = int(a["xp"]) + maxi(0, xp)
        while int(a["level"]) < level_cap and int(a["xp"]) >= _next_level_xp(int(a["level"])):
            a["xp"] = int(a["xp"]) - _next_level_xp(int(a["level"]))
            a["level"] = int(a["level"]) + 1
            a["max_hp"] = int(a["max_hp"]) + 15
            a["max_mp"] = int(a["max_mp"]) + 6
            a["attack"] = int(a["attack"]) + 4
            a["defense"] = int(a["defense"]) + 2
            a["hp"] = int(a["max_hp"])
            a["mp"] = int(a["max_mp"])
            messages.append("%s 升至 Lv.%d" % [str(a["name"]), int(a["level"])])
        actors[i] = a
    return messages

func _next_level_xp(lvl: int) -> int:
    return 38 + lvl * 17

func _pack() -> Dictionary:
    return {"version": VERSION, "chapter": chapter, "scene": scene_index, "task": task_index, "dialogue_seen": dialogue_seen, "gold": gold, "potions": potions, "actors": actors, "flags": flags, "inventory": inventory, "play_seconds": play_seconds}

func save() -> bool:
    var payload: String = JSON.stringify(_pack())
    # 写入新存档之前，将上一份有效的存档备份。
    if FileAccess.file_exists(SAVE_PATH):
        var previous: String = FileAccess.get_file_as_string(SAVE_PATH)
        if _valid_payload(JSON.parse_string(previous)):
            var backup: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
            if backup != null:
                backup.store_string(previous)
                backup.close()
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(payload)
    file.close()
    return true

func load_saved() -> bool:
    for path in [SAVE_PATH, BACKUP_PATH]:
        if not FileAccess.file_exists(path):
            continue
        var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if not _valid_payload(payload):
            continue
        var d: Dictionary = payload
        chapter = clampi(int(d["chapter"]), 0, 6)
        scene_index = maxi(0, int(d["scene"]))
        task_index = maxi(0, int(d["task"]))
        dialogue_seen = bool(d["dialogue_seen"])
        gold = maxi(0, int(d["gold"]))
        potions = clampi(int(d["potions"]), 0, 999)
        flags = d["flags"].duplicate(true)
        inventory = d["inventory"].duplicate(true)
        actors.clear()
        for record in d["actors"]:
            actors.append(record.duplicate(true))
        play_seconds = float(d.get("play_seconds", 0.0))
        return true
    return false

func _valid_payload(value: Variant) -> bool:
    if not (value is Dictionary):
        return false
    var obj: Dictionary = value
    if int(obj.get("version", -1)) != VERSION:
        return false
    if not (obj.get("actors") is Array) or not (obj.get("flags") is Dictionary) or not (obj.get("inventory") is Dictionary):
        return false
    if obj["actors"].size() < 2 or obj["actors"].size() > 3:
        return false
    for entry in obj["actors"]:
        if not (entry is Dictionary):
            return false
        for key in ["name", "hp", "max_hp", "mp", "max_mp", "attack", "defense", "level", "xp", "skill"]:
            if not entry.has(key):
                return false
    return int(obj.get("chapter", -1)) >= 0 and int(obj.get("chapter", 99)) <= 6 and int(obj.get("scene", -1)) >= 0 and int(obj.get("task", -1)) >= 0
