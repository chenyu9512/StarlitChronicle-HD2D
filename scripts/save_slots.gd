extends RefCounted
## 手动存档槽位，与旧 user://first_act_v3.json 自动存档共存；写入临时文件再替换。
const SLOT_COUNT: int = 3
const FOLDER: String = "user://slots"
const StateScript = preload("res://scripts/first_act_state.gd")
# Tests can use an isolated folder; game saves continue to use user://slots.
var folder: String = FOLDER

func _file(slot: int) -> String:
    return "%s/slot_%02d.json" % [folder,slot]

func _valid_slot(slot: int) -> bool:
    return slot >= 1 and slot <= SLOT_COUNT

func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return data if data is Dictionary else {}

func save_slot(progress, slot: int) -> bool:
    if not _valid_slot(slot):
        return false
    var content: Dictionary = progress._pack()
    if not progress._valid_payload(content):
        return false
    var directory: String = ProjectSettings.globalize_path(folder)
    if DirAccess.make_dir_recursive_absolute(directory) != OK:
        return false
    var path: String = _file(slot)
    var temp: String = path + ".tmp"
    var backup: String = path + ".bak"
    var opened: FileAccess = FileAccess.open(temp,FileAccess.WRITE)
    if opened == null:
        return false
    opened.store_string(JSON.stringify(content))
    opened.flush()
    opened.close()
    if not progress._valid_payload(_read(temp)):
        return false
    if FileAccess.file_exists(path):
        var existing: Dictionary = _read(path)
        if progress._valid_payload(existing):
            var backup_temp: String = backup + ".tmp"
            var out: FileAccess = FileAccess.open(backup_temp, FileAccess.WRITE)
            if out == null:
                return false
            out.store_string(JSON.stringify(existing))
            out.flush()
            out.close()
            if not progress._valid_payload(_read(backup_temp)):
                return false
            if DirAccess.rename_absolute(
                    ProjectSettings.globalize_path(backup_temp),
                    ProjectSettings.globalize_path(backup)) != OK:
                return false
    return DirAccess.rename_absolute(
            ProjectSettings.globalize_path(temp),
            ProjectSettings.globalize_path(path)) == OK

func load_slot(progress,slot: int) -> bool:
    if not _valid_slot(slot):
        return false
    for path in [_file(slot),_file(slot)+".bak"]:
        var payload: Dictionary = _read(path)
        if progress.restore_snapshot(payload):
            return true
    return false

func summary(slot: int) -> Dictionary:
    if not _valid_slot(slot):
        return {}
    var validator = StateScript.new()
    for path in [_file(slot), _file(slot) + ".bak"]:
        var item: Dictionary = _read(path)
        if validator._valid_payload(item):
            return {"slot":slot,"exists":true,"chapter":int(item.get("chapter",0)),"gold":int(item.get("gold",0)),"version":int(item.get("version",0)),"play_seconds":float(item.get("play_seconds",0))}
    return {"slot":slot,"exists":false}
