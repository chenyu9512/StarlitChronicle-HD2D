extends SceneTree
const Registry = preload("res://scripts/c_act01_global_art_v14.gd")
const Art = preload("res://scripts/c_art_overrides.gd")
const Coastal = preload("res://scripts/world_coastal_scene.gd")

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
    # Test the actual scene sprite loader, not just the resource registry.
    var coast := Coastal.new()
    coast.map_id = "map_coast_05"
    root.add_child(coast)
    var landmark: Sprite2D = coast.call("_sprite", "tide_lighthouse_landmark", Vector2i(6, 6)) as Sprite2D
    if landmark == null or landmark.texture == null or not landmark.has_meta("global_art_fit"):
        push_error("Real lighthouse sprite did not select its curated imported image")
        quit(1)
        return
    coast.add_child(landmark)
    coast.authored_sprites["lighthouse_landmark"] = landmark
    coast.call("_install_lighthouse_light")
    if coast.lighthouse_light == null or coast.lighthouse_beacon_light == null:
        push_error("Lighthouse lights depend on an obsolete legacy SVG")
        quit(1)
        return
    if coast.lighthouse_light.texture == null or coast.lighthouse_beacon_light.texture == null:
        push_error("Procedural lighthouse falloff did not generate a texture")
        quit(1)
        return
    coast.set_lighthouse_rekindled(false)
    if coast.lighthouse_beacon_light.visible:
        push_error("Story lighthouse beacon incorrectly illuminated before relight")
        quit(1)
        return
    coast.set_lighthouse_rekindled(true)
    if coast.light_quality > 0 and not coast.lighthouse_beacon_light.visible:
        push_error("Story lighthouse beacon failed to illuminate after relight")
        quit(1)
        return
    var cavern := Coastal.new()
    cavern.map_id = "map_coast_04"
    root.add_child(cavern)
    var relic := Sprite2D.new()
    cavern.add_child(relic)
    cavern.authored_sprites["cave_relic"] = relic
    cavern.call("_make_cavern_lighting")
    if cavern.cavern_lights.size() != 1 or cavern.cavern_lights[0].texture == null:
        push_error("Actual cave light is still dependent on missing third-party SVG redirect")
        quit(1)
        return
    print("Act I v14 imported art and coast/cave real scene lighting smoke PASS")
    quit(0)
