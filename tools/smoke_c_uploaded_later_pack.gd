extends SceneTree
## C-line later-upload artwork migration: engine check, not a visual QA substitute.
## Run with a disposable Godot user:// profile; this smoke restores the chosen pack.
const Art = preload("res://scripts/c_art_overrides.gd")
const PACK_INDEX: String = "res://data/assets/c_art_packs.json"
const PACK_ID: String = "uploaded_later_v1"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACK_INDEX))
    if not raw is Dictionary:
        _fail("Art pack manifest unavailable or malformed")
        return
    var entries: Array = []
    for item in raw.get("packs", []):
        if item is Dictionary and str(item.get("id", "")) == PACK_ID:
            entries = item.get("mappings", [])
            break
    if entries.size() != 6:
        _fail("Expected exactly six approved initial source-to-slot mappings")
        return
    var inspection: Dictionary = Art.pack_report(PACK_ID)
    if not bool(inspection.get("ok", false)) or int(inspection.get("mapped", 0)) != entries.size() or int(inspection.get("fallback", -1)) != 0:
        _fail("Pack not fully registered or some source images cannot load: " + str(inspection))
        return
    var former: String = Art.active_pack()
    if not Art.activate_pack(PACK_ID):
        _fail("Could not activate later-upload pack")
        return
    var errors: Array[String] = []
    for entry in entries:
        if not entry is Dictionary:
            errors.append("Mapping has wrong type")
            continue
        var target: String = str(entry.get("target", ""))
        var source: String = str(entry.get("source", ""))
        if not source.begins_with("res://assets/art/external/cc0_named_v1/"):
            errors.append("Source is not a later-uploaded art file: " + source)
            continue
        var baseline: Texture2D = Art.original_texture(target)
        var current: Texture2D = Art.texture(target)
        if baseline == null or current == null or Vector2i(current.get_size()) != Vector2i(baseline.get_size()):
            errors.append("Failed target load or exact footprint matching: " + target)
    if not Art.activate_pack(former):
        errors.append("Cannot restore previously selected art pack")
    if not errors.is_empty():
        _fail("; ".join(errors))
        return
    print("SUCCESS: C later-upload pack has 6 loadable sources, effective targets and preserved texture footprints")
    quit(0)

func _fail(message: String) -> void:
    push_error("FAILED: " + message)
    quit(1)
