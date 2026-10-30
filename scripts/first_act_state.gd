extends RefCounted
## 第一幕独立的可迁移游戏进度：原 v1 存档永不覆盖。
const SAVE_PATH: String = "user://first_act_v3.json"
const BACKUP_PATH: String = "user://first_act_v3.backup.json"
const VERSION: int = 3
# Runtime defaults remain the V3 save contract; tests redirect to isolated paths.
var save_path: String = SAVE_PATH
var backup_path: String = BACKUP_PATH
var chapter: int = 0
var scene_index: int = 0
var task_index: int = 0
var dialogue_seen: bool = false
var gold: int = 80
var potions: int = 6
var flags: Dictionary = {}
var actors: Array[Dictionary] = []
var inventory: Dictionary = {"item_herb_01": 6}
var level_cap: int = 99
var rpg: Dictionary = {}
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
    rpg = {}
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
    return {"version": VERSION, "chapter": chapter, "scene": scene_index, "task": task_index, "dialogue_seen": dialogue_seen, "gold": gold, "potions": potions, "actors": actors, "flags": flags, "inventory": inventory, "rpg": rpg, "play_seconds": play_seconds}

func save() -> bool:
    var snapshot: Dictionary = _pack()
    if not _valid_payload(snapshot):
        return false
    var payload: String = JSON.stringify(snapshot)
    var temp_path: String = save_path + ".tmp"
    var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(payload)
    file.flush()
    file.close()
    # Never replace the last good snapshot with an unparseable or incomplete write.
    if not _valid_payload(JSON.parse_string(FileAccess.get_file_as_string(temp_path))):
        return false
    # Keep a previous valid snapshot recoverable even if the final rename fails.
    if FileAccess.file_exists(save_path):
        var previous: String = FileAccess.get_file_as_string(save_path)
        if _valid_payload(JSON.parse_string(previous)):
            var backup_temp: String = backup_path + ".tmp"
            var backup: FileAccess = FileAccess.open(backup_temp, FileAccess.WRITE)
            if backup == null:
                return false
            backup.store_string(previous)
            backup.flush()
            backup.close()
            if not _valid_payload(JSON.parse_string(FileAccess.get_file_as_string(backup_temp))):
                return false
            if DirAccess.rename_absolute(
                    ProjectSettings.globalize_path(backup_temp),
                    ProjectSettings.globalize_path(backup_path)) != OK:
                return false
    return DirAccess.rename_absolute(
            ProjectSettings.globalize_path(temp_path),
            ProjectSettings.globalize_path(save_path)) == OK

func load_saved() -> bool:
    for path in [save_path, backup_path]:
        if not FileAccess.file_exists(path):
            continue
        var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if restore_snapshot(payload):
            return true
    return false

func restore_snapshot(value: Variant) -> bool:
    if not _valid_payload(value):
        return false
    var d: Dictionary = value
    chapter = clampi(int(d["chapter"]),0,72)
    scene_index = maxi(0,int(d["scene"]))
    task_index = maxi(0,int(d["task"]))
    dialogue_seen = bool(d["dialogue_seen"])
    gold = maxi(0,int(d["gold"]))
    potions = clampi(int(d["potions"]),0,999)
    flags = d["flags"].duplicate(true)
    inventory = d["inventory"].duplicate(true)
    rpg = d.get("rpg",{}).duplicate(true)
    actors.clear()
    for record in d["actors"]:
        actors.append(record.duplicate(true))
    play_seconds = float(d.get("play_seconds",0.0))
    return true

func _valid_payload(value: Variant) -> bool:
    if not (value is Dictionary):
        return false
    var obj: Dictionary = value
    if not obj.has("version") or typeof(obj["version"]) not in [TYPE_INT, TYPE_FLOAT]:
        return false
    if int(obj["version"]) != VERSION:
        return false
    # Legacy V3 payloads may omit rpg, but any supplied rpg must be a map.
    # Reject absent or nonnumeric fields before restore_snapshot accesses them.
    for key in ["version", "chapter", "scene", "task", "gold", "potions"]:
        if not obj.has(key) or typeof(obj[key]) not in [TYPE_INT, TYPE_FLOAT]:
            return false
    if not (obj.get("dialogue_seen") is bool):
        return false
    if not (obj.get("rpg", {}) is Dictionary):
        return false
    # A syntactically valid JSON file can still contain fractional, infinite,
    # or otherwise impossible numeric state. Reject it before mutating progress.
    for key in ["version","chapter","scene","task","gold","potions"]:
        var numeric_value: float = float(obj[key])
        if is_nan(numeric_value) or is_inf(numeric_value) or numeric_value != floorf(numeric_value):
            return false
    if int(obj["gold"]) < 0 or int(obj["potions"]) < 0:
        return false
    var seconds: Variant = obj.get("play_seconds",0.0)
    if typeof(seconds) not in [TYPE_INT,TYPE_FLOAT] or is_nan(float(seconds)) or is_inf(float(seconds)) or float(seconds)<0.0:
        return false
    # A wrong numeric type or impossible checkpoint must fall back to the
    # last good backup, NOT reach gameplay as a plausible but corrupt save.
    if int(obj["chapter"]) < 0 or int(obj["chapter"]) > 72:
        return false
    if int(obj["scene"]) < 0 or int(obj["scene"]) > 9 or int(obj["task"]) < 0 or int(obj["task"]) > 9:
        return false
    if not (obj.get("actors") is Array) or not (obj.get("flags") is Dictionary) or not (obj.get("inventory") is Dictionary):
        return false
    var inventory_data: Dictionary = obj["inventory"]
    for item_id in inventory_data:
        var amount: Variant = inventory_data[item_id]
        if typeof(amount) not in [TYPE_INT,TYPE_FLOAT] or is_nan(float(amount)) or is_inf(float(amount)) or float(amount) < 0.0 or float(amount) != floorf(float(amount)):
            return false
    if obj["actors"].size() < 2 or obj["actors"].size() > 12:
        return false
    for entry in obj["actors"]:
        if not (entry is Dictionary):
            return false
        for key in ["name","hp","max_hp","mp","max_mp","attack","defense","level","xp","skill"]:
            if not entry.has(key):
                return false
        if not (entry["name"] is String) or not (entry["skill"] is String):
            return false
        for key in ["hp","max_hp","mp","max_mp","attack","defense","level","xp"]:
            if typeof(entry[key]) not in [TYPE_INT,TYPE_FLOAT]:
                return false
            if is_nan(float(entry[key])) or is_inf(float(entry[key])) or float(entry[key]) != floorf(float(entry[key])):
                return false
        if int(entry["level"]) < 1 or int(entry["max_hp"]) <= 0 or int(entry["max_mp"]) < 0:
            return false
        if int(entry["hp"]) < 0 or int(entry["hp"]) > int(entry["max_hp"]) or int(entry["mp"]) < 0 or int(entry["mp"]) > int(entry["max_mp"]) or int(entry["xp"]) < 0:
            return false
    return true
