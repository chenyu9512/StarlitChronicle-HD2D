extends SceneTree
## Runtime compatibility smoke: removed manual/third-party PNGs are never needed.
const Art = preload("res://scripts/c_art_overrides.gd")
const Runtime = preload("res://scripts/c_art_runtime.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var names: Array[String] = [
        "res://assets/art/tilesets/coast_ground.png",
        "res://assets/art/tilesets/coast_water.png",
        "res://assets/art/interiors/morning_dew_inn/inn_tileset.svg",
        "res://assets/art/backdrops/coast/tide_lighthouse.png",
        "res://assets/art/backdrops/coast/white_sand_port.png",
        "res://assets/fx/glow.png",
        "res://assets/art/battle/a15/boss_footing.svg",
        "res://assets/art/battle/a15/enemy_footing.svg",
        "res://assets/art/props/coast/rock.png",
        "res://assets/art/props/coast/well.png",
        "res://assets/art/props/coast/barrel.png",
        "res://assets/art/props/coast/star_lantern.png",
        "res://assets/art/runtime/act01_global_v14/props/prop_cottage.png",
        "res://assets/art/runtime/act01_global_v14/props/prop_well.png",
        "res://assets/art/runtime/act01_global_v14/props/prop_fish_stall.png",
        "res://assets/art/runtime/act01_global_v14/scenery/scenery_tide_lighthouse_landmark.png",
        "res://assets/art/runtime/act01_semantic_v17/harbor_crane.png",
        "res://assets/art/runtime/act01_hd2d_v18/props/market-stall.png",
    ]
    for alias in names:
        var texture: Texture2D = Art.texture(alias)
        if texture == null or texture.get_width() < 1:
            failures.append(alias)
    for label in ["book","paper","medicine"]:
        if Runtime.ui_texture(label) == null:
            failures.append("ui:"+label)
    if failures.is_empty():
        print("PASS V10 exact generated-art compatibility: ",names.size()," old paths and three scene icons")
        quit(0)
    else:
        for name in failures:
            push_error("Missing generated replacement: " + name)
        quit(1)
