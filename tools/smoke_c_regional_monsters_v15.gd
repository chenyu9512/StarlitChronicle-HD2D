extends SceneTree
## Live Godot smoke: imported pixels + real battle loader for 7 distinct region IDs.
const Art = preload("res://scripts/c_art_overrides.gd")
const Atlas = preload("res://scripts/c_art_regional_monsters_v15.gd")
const Battle = preload("res://scripts/art_assets.gd")
func _initialize() -> void:
    for id in Atlas.MONSTERS.keys():
        var path: String = Atlas.battle_path(str(id))
        if path.is_empty():
            push_error("Missing curated regional image: " + str(id))
            quit(1)
            return
        var image: Texture2D = Art.texture(path)
        if image == null or image.get_width() < 8 or image.get_height() < 8:
            push_error("Regional image failed Godot import: " + str(id))
            quit(1)
            return
        var from_battle: String = Battle.battle_image({"monster_id":id},false,9)
        if from_battle != path:
            push_error("Live battle path did not select curated region art: " + str(id))
            quit(1)
            return
    print("PASS: seven region-monster actual Texture2D assets and battle loader mappings")
    quit(0)
