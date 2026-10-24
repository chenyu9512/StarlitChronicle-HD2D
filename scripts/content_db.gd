extends RefCounted
## Read-only, versioned content catalog. Never mutates old saved games.
const BASE = "res://data/content/"
const CATEGORIES = ["regions", "characters", "npcs", "maps", "items", "weapons", "armor", "skills", "monsters", "bosses", "quests"]

static func load_entries(category: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if not CATEGORIES.has(category):
        push_warning("Unknown catalog: " + category)
        return result
    var path: String = BASE + category + ".json"
    if not FileAccess.file_exists(path):
        push_warning("Missing catalog: " + path)
        return result
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return result
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not (parsed is Dictionary):
        push_warning("Broken catalog: " + path)
        return result
    var records: Variant = parsed.get("entries", [])
    if records is Array:
        for entry in records:
            if entry is Dictionary and entry.has("id") and entry.has("name"):
                result.append(entry)
    return result

static func lookup(category: String, entry_id: String) -> Dictionary:
    for row in load_entries(category):
        if str(row.get("id", "")) == entry_id:
            return row
    return {}

static func count(category: String) -> int:
    return load_entries(category).size()
