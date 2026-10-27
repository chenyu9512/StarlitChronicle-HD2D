extends SceneTree
const Registry = preload("res://scripts/c_act01_global_art_v14.gd")
const Art = preload("res://scripts/c_art_overrides.gd")

func _initialize() -> void:
    var info: Dictionary = Registry.data()
    if str(info.get("schema", "")) != "starlit.c.act01_global_distribution.v14":
        push_error("Act I v14 art registry missing")
        quit(1)
        return
    for section in ["props","scenery","monsters"]:
        var assets: Dictionary = info.get("runtime",{}).get(section,{})
        for key in assets.keys():
            var path: String = str(assets[key])
            var image: Texture2D = Art.texture(path)
            if image == null or image.get_width()<1 or image.get_height()<1:
                push_error("Missing real imported art: "+section+"/"+str(key)+": "+path)
                quit(1)
                return
    if Registry.texture_for_scenery("tide_lighthouse_landmark","map_coast_05") == null:
        push_error("Commercial lighthouse landmark missing")
        quit(1)
        return
    if Registry.battle_path("mon_coast_02").is_empty():
        push_error("Coastal crab battle slot unresolved")
        quit(1)
        return
    print("Act I v14 imported art texture smoke PASS")
    quit(0)
