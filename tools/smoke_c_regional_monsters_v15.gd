extends SceneTree
## Confirm seven independently named regional enemies reach real generated 2D
## portraits through the current runtime registry and live battle renderer.
## The deleted V15/Foozle source pack must never be required by Runtime.
const Art = preload("res://scripts/c_art_overrides.gd")
const Atlas = preload("res://scripts/c_art_regional_monsters_v15.gd")
const Battle = preload("res://scripts/art_assets.gd")
const INDEX: String = "res://data/assets/c_art_runtime_registry_v1.json"

func _initialize() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
    if not (raw is Dictionary) or str(raw.get("schema","")) != "starlit.c.art_runtime_registry.v1":
        push_error("Current regional enemy identity index missing")
        quit(1)
        return
    var canonical: Dictionary = raw.get("monster_id_sources",{})
    if canonical.size() != 7:
        push_error("Not seven current regional monster image identities")
        quit(1)
        return
    var unique_paths: Dictionary = {}
    for id in canonical.keys():
        var path: String = Atlas.battle_path(str(id))
        if path != str(canonical[id]) or path.is_empty() or unique_paths.has(path):
            push_error("Regional enemy identity or image was reused: " + str(id))
            quit(1)
            return
        unique_paths[path] = true
        if not path.begins_with("res://assets/art/runtime/global_factory_v3/monsters/"):
            push_error("Regional monster points to deleted third-party source: " + str(id))
            quit(1)
            return
        var image: Texture2D = Art.texture(path)
        if image == null or image.get_width() < 8 or image.get_height() < 8:
            push_error("Regional enemy image failed import: " + str(id))
            quit(1)
            return
        var from_battle: String = Battle.battle_image({"monster_id":str(id)},false,9)
        if from_battle != path:
            push_error("Live battle did not resolve correct regional monster: " + str(id))
            quit(1)
            return
    print("PASS: seven distinct generated regional monster portraits and live battle identity routing")
    quit(0)
