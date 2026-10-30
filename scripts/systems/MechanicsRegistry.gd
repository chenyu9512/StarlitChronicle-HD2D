extends RefCounted
## Fail-closed chapter-mechanics registry. 'pending' never becomes gameplay.
const MANIFEST: String = "res://story/runtime/mechanics_registry.json"
var bindings: Dictionary = {}
var errors: Array[String] = []

func load_all() -> bool:
    bindings.clear()
    errors.clear()
    var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
    if file == null:
        errors.append("mechanics registry is missing")
        return false
    var payload: Variant = JSON.parse_string(file.get_as_text())
    if not (payload is Dictionary):
        errors.append("mechanics registry is not a JSON object")
        return false
    if not (payload.get("chapter_mechanics_bindings") is Dictionary):
        errors.append("mechanics registry has no chapter bindings")
        return false
    var entries: Dictionary = payload["chapter_mechanics_bindings"]
    for key in entries.keys():
        var chapter_id: String = str(key)
        var row: Variant = entries[key]
        if not (row is Dictionary):
            errors.append("invalid binding: " + chapter_id)
            continue
        if chapter_id.length() != 5 or not chapter_id.begins_with("ch") or not chapter_id.substr(2).is_valid_int():
            errors.append("invalid chapter key: " + chapter_id)
            continue
        var status: String = str(row.get("status", ""))
        if status not in ["active", "pending"]:
            errors.append("invalid binding status: " + chapter_id)
            continue
        if status == "active":
            var controller: String = str(row.get("controller", ""))
            if not controller.begins_with("res://scripts/") or not controller.ends_with(".gd"):
                errors.append("invalid active controller: " + chapter_id)
                continue
            if not ResourceLoader.exists(controller):
                errors.append("active controller missing: " + controller)
                continue
        bindings[chapter_id] = (row as Dictionary).duplicate(true)
    return errors.is_empty()

func binding_for(chapter_id: String) -> Dictionary:
    return (bindings.get(chapter_id, {}) as Dictionary).duplicate(true)

func create_controller(chapter_id: String) -> Node:
    var row: Dictionary = binding_for(chapter_id)
    if str(row.get("status", "")) != "active":
        return null
    var path: String = str(row.get("controller", ""))
    if not ResourceLoader.exists(path):
        return null
    var resource: Resource = load(path)
    if not (resource is Script):
        return null
    var instance: Variant = (resource as Script).new()
    if not (instance is Node):
        return null
    return instance as Node
