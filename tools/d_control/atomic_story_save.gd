extends RefCounted
## D-line standalone safe story IO. Integration is opt-in after A/B/C freeze.
## Preserves flat v1/v2 JSON and never overwrites the last valid backup with invalid primary.

static func valid_payload(value: Variant) -> bool:
    if not (value is Dictionary):
        return false
    var data: Dictionary = value
    if typeof(data.get("version", null)) not in [TYPE_INT, TYPE_FLOAT]:
        return false
    var version: int = int(data["version"])
    if version != 1 and version != 2:
        return false
    if not (data.get("current_chapter_id", null) is String):
        return false
    if str(data["current_chapter_id"]).is_empty():
        return false
    if not (data.get("flags", null) is Dictionary):
        return false
    for field in ["current_scene_index", "line_index"]:
        if data.has(field):
            if typeof(data[field]) not in [TYPE_INT, TYPE_FLOAT] or int(data[field]) < 0:
                return false
    for field in ["objective_progress", "side_quest_progress"]:
        if data.has(field) and not (data[field] is Dictionary):
            return false
    if data.has("pending_branch_dialogue") and not (data["pending_branch_dialogue"] is Array):
        return false
    if version == 2:
        for field in ["dialogue_ended", "waiting_battle", "choice_made"]:
            if data.has(field) and not (data[field] is bool):
                return false
    return true


static func _read_valid(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if valid_payload(parsed):
        return parsed
    return {}


static func read_verified(path: String) -> Dictionary:
    var primary: Dictionary = _read_valid(path)
    if not primary.is_empty():
        return primary
    return _read_valid(path + ".bak")


static func write_verified(path: String, data: Dictionary) -> bool:
    if not valid_payload(data):
        return false
    var temp: String = path + ".tmp"
    var target: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
    if target == null:
        return false
    target.store_string(JSON.stringify(data, "  "))
    target.flush()
    target.close()
    if _read_valid(temp).is_empty():
        return false

    var prior: Dictionary = _read_valid(path)
    if not prior.is_empty():
        var backup_temp: String = path + ".bak.tmp"
        var copy: FileAccess = FileAccess.open(backup_temp, FileAccess.WRITE)
        if copy == null:
            return false
        copy.store_string(JSON.stringify(prior, "  "))
        copy.flush()
        copy.close()
        if _read_valid(backup_temp).is_empty():
            return false
        if DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_temp),
                ProjectSettings.globalize_path(path + ".bak")) != OK:
            return false

    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),
            ProjectSettings.globalize_path(path)) == OK
