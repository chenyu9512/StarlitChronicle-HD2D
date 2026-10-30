extends RefCounted
## Exact semantic aliases for historical missing art paths. The old image files
## were deleted; only project-generated runtime images can be loaded here.
const Generated = preload("res://scripts/global_generated_art_v3.gd")
const GAP: String = "res://assets/art/runtime/generated_gaps_v10/"
static var _effects: Dictionary = {}

static func _generated(role: String) -> Texture2D:
    var uri: String = GAP + role.replace(".", "__").replace("-", "_") + ".png"
    return ResourceLoader.load(uri) as Texture2D if ResourceLoader.exists(uri) else null

static func _radial(effect: String) -> Texture2D:
    if _effects.has(effect):
        return _effects[effect]
    var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    for y in range(64):
        for x in range(64):
            var delta := Vector2(float(x)-31.5,float(y)-31.5)
            var radius: float = delta.length()/31.5
            var alpha: float = pow(maxf(0.0,1.0-radius),2.0)
            var color: Color = Color(1.0,0.83,0.44,alpha*0.72) if effect == "glow" else Color(0.48,0.72,0.80,alpha*0.45)
            image.set_pixel(x,y,color)
    var result: Texture2D = ImageTexture.create_from_image(image)
    _effects[effect] = result
    return result

static func texture(path: String) -> Texture2D:
    # Stable historical logical IDs; preserve gameplay/script references while
    # routing visuals to newly generated semantic identities, not third-party.
    match path:
        "res://assets/art/tilesets/coast_ground.png":
            return Generated.texture("terrain","region_coast_ground")
        "res://assets/art/tilesets/coast_water.png":
            return Generated.texture("terrain","region_coast_water")
        "res://assets/art/interiors/morning_dew_inn/inn_tileset.svg":
            return Generated.texture("interiors","map_coast_01__inn")
        "res://assets/art/backdrops/coast/tide_lighthouse.png":
            return Generated.texture("maps","map_coast_05")
        "res://assets/art/backdrops/coast/white_sand_port.png":
            return Generated.texture("maps","map_coast_01")
        "res://assets/fx/glow.png":
            return _radial("glow")
        "res://assets/art/battle/a15/boss_footing.svg", "res://assets/art/battle/a15/enemy_footing.svg":
            return _radial("footing")
        "res://assets/art/props/coast/rock.png", "res://assets/art/external/cc0_named_v1/props/pixelkensei_nature/base/prop_pixelkensei_nature_03_rock_cluster_32_x_32.png":
            return _generated("prop.hd2d.rock-bank")
        "res://assets/art/props/coast/well.png", "res://assets/props/well.png", "res://assets/art/runtime/act01_global_v14/props/prop_well.png":
            return _generated("prop.coast.well")
        "res://assets/art/props/coast/barrel.png":
            return _generated("prop.coast.barrel")
        "res://assets/art/props/coast/star_lantern.png", "res://assets/props/lamp.png":
            return Generated.texture("props","region_coast_lantern")
        "res://assets/art/runtime/act01_global_v14/props/prop_cottage.png":
            return _generated("prop.coast.cottage")
        "res://assets/art/runtime/act01_global_v14/props/prop_fish_stall.png":
            return _generated("prop.coast.fish_stall")
        "res://assets/art/runtime/act01_global_v14/scenery/scenery_tide_lighthouse_landmark.png":
            return _generated("landmark.coast.tide_lighthouse_landmark")
        "res://assets/art/runtime/act01_semantic_v17/harbor_crane.png":
            return _generated("scene.coast.harbor_crane")
        "res://assets/art/runtime/act01_hd2d_v18/props/market-stall.png":
            return _generated("prop.hd2d.market-stall")
        "res://assets/art/external/cc0_named_v1/icons/owlish_icons/base/icon_owlish_icons_book.png":
            return _generated("ui.extra.book")
        "res://assets/art/external/cc0_named_v1/icons/owlish_icons/base/icon_owlish_icons_medicine.png":
            return _generated("ui.extra.medicine")
        "res://assets/art/external/cc0_named_v1/icons/owlish_icons/base/icon_owlish_icons_paper.png":
            return _generated("ui.extra.paper")
    return null
