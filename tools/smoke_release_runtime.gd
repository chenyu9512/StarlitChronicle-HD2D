extends SceneTree
## Actual imported runtime art and bootable world verification; no source pack dependency.
const GameArt = preload("res://scripts/c_act01_global_art_v14.gd")
const World = preload("res://scripts/first_act_world.gd")
const TextureResolver = preload("res://scripts/c_art_overrides.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var info: Dictionary = GameArt.data()
    if str(info.get("packaging", "")) != "runtime_only":
        push_error("Slim runtime manifest missing")
        quit(1)
        return
    var count: int = 0
    var entries: Dictionary = info.get("runtime", {})
    for category in ["props", "scenery", "monsters"]:
        var listing: Dictionary = entries.get(category, {})
        for ident in listing.keys():
            var path: String = str(listing[ident])
            var image: Texture2D = TextureResolver.texture(path)
            if image == null or image.get_width() <= 0 or image.get_height() <= 0:
                push_error("Missing runtime art: " + path)
                quit(1)
                return
            count += 1
    if count != 25:
        push_error("Expected 25 active imported textures, found " + str(count))
        quit(1)
        return
    var game: PackedScene = load("res://scenes/first_act.tscn") as PackedScene
    if game == null or game.instantiate() == null:
        push_error("First-act main scene cannot load")
        quit(1)
        return
    var world = World.new()
    root.add_child(world)
    for chapter in range(1, 7):
        world.build(chapter, 2)
        if world.layer == null or world.hero == null:
            push_error("World build failed for chapter " + str(chapter))
            quit(1)
            return
    print("PASS: slim runtime: 25 live imported images, game scene, six chapter worlds")
    quit(0)
