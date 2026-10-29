extends SceneTree
## Verify real CArtRuntime resource-loader integration, not just PNG existence.
const RuntimeArt = preload("res://scripts/c_art_runtime.gd")
const INDEX: String = "res://data/assets/c_art_runtime_registry_v1.json"
var errors: Array[String] = []

func require(ok: bool, label: String) -> void:
    if not ok:
        errors.append(label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
    require(raw is Dictionary, "canonical art registry cannot load")
    if not raw is Dictionary:
        quit(1)
        return
    var registry: Dictionary = raw
    var slots: Dictionary = registry.get("canonical_slots", {})
    require(slots.size() >= 109, "canonical slot count regressed")
    var loaded: int = 0
    for id in slots.keys():
        var source: String = str((slots[id] as Dictionary).get("source", ""))
        require(source.begins_with("res://assets/art/runtime/generated_gaps_v10/"),
            "Canonical slot is not generated-only: " + str(id))
        var art: Texture2D = RuntimeArt.texture_slot(str(id))
        if art == null:
            errors.append("Unrenderable canonical slot: " + str(id))
        else:
            loaded += 1
            require(art.get_width() > 0 and art.get_height() > 0, "Zero canvas: " + str(id))
    var ui: Dictionary = registry.get("ui", {})
    for icon in ui.keys():
        require(RuntimeArt.ui_texture(str(icon)) != null, "Unrenderable UI icon: " + str(icon))
    var monster_ids: Dictionary = registry.get("monster_id_sources", {})
    for id in monster_ids.keys():
        require(not RuntimeArt.monster_source(str(id)).is_empty(), "Missing exact monster: " + str(id))
    for region_id in (registry.get("regions", {}) as Dictionary).keys():
        var region: Dictionary = (registry["regions"] as Dictionary)[region_id]
        for kind in ["ground", "water"]:
            require(RuntimeArt.texture_region(str(region_id), "material_preview", kind) != null,
                "Missing region material preview: " + str(region_id) + "/" + kind)
    if errors.is_empty():
        print("PASS V10 generated art: ", loaded, " canonical slots, ",ui.size(),
              " UI icons, ",monster_ids.size()," exact monster IDs, 8 regions")
        quit(0)
    else:
        for item in errors:
            push_error(item)
        quit(1)
