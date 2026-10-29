extends SceneTree
## Independent Godot 4.7.2 import and UI route test for all 288 new runtime PNGs.
## Resource existence alone is not enough: each registered ID must decode into
## a real 64x64 Texture2D through the production CArtItemIcons entrypoint.
const Icons = preload("res://scripts/c_art_item_icons.gd")
var issues: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var path: String = "res://data/assets/c_art_content_icons_v6.json"
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not raw is Dictionary:
        push_error("Cannot parse canonical content IDs")
        quit(1)
        return
    var records: Array = raw.get("records", [])
    var seen: Dictionary = {}
    for item in records:
        if not item is Dictionary:
            continue
        var id: String = str(item.get("id", ""))
        var source: String = Icons.icon_path(id)
        var expected: String = "res://assets/art/runtime/content_icons_v1/icons/" + id + ".png"
        if source != expected or seen.has(source):
            issues.append("Broken/duplicate generated source binding: " + id)
            continue
        seen[source] = true
        var art: Texture2D = Icons.texture_for(id)
        if art == null or art.get_size() != Vector2(64, 64):
            issues.append("Generated content icon did not import: " + id)
    if records.size() != 288 or Icons.allocated_count() != 288 or seen.size() != 288:
        issues.append("All 288 independent item/equipment/skill IDs were not loaded")
    if issues.is_empty():
        print("PASS: 288 unique canonical content IDs draw real 64x64 Godot Texture2D art; human visual QA pending")
        quit(0)
        return
    for issue in issues:
        push_error(issue)
    quit(1)
