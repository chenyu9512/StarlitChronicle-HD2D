extends SceneTree
## C2.1 salt-slime authored action atlas validation; no combat state mutation.
const Art = preload("res://scripts/c_coast_monster_motion.gd")
const Foes = preload("res://scripts/battle_enemies.gd")
var errors: Array[String] = []
func check(ok: bool, message: String) -> void:
    if not ok:
        errors.append(message)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var sheets: Dictionary = Art.sheets("salt_slime")
    check(sheets.size() == 4, "Four real action sheets not imported")
    check(Art.sheets("unknown_coastal_enemy").is_empty(), "Unregistered monsters must remain on original fallback")
    if sheets.size() == 4:
        for pose in ["idle", "attack", "hit", "defeat"]:
            var tex: Texture2D = sheets[pose]
            check(tex.get_width() == Art.frame_count(pose) * 128, pose + ": sprite sheet wrong width")
            check(tex.get_height() == 128, pose + ": sprite sheet wrong height")
            var image: Image = tex.get_image()
            check(image != null, pose + ": cannot decode SVG")
            if image != null:
                var first: PackedByteArray = image.get_region(Rect2i(0,0,128,128)).get_data()
                var last_x: int = (Art.frame_count(pose) - 1) * 128
                var last: PackedByteArray = image.get_region(Rect2i(last_x,0,128,128)).get_data()
                check(first != last, pose + ": first and last action poses identical")
        var stage := Foes.new()
        stage.size = Vector2(1280, 720)
        root.add_child(stage)
        stage.configure([{"art":"salt_slime","hp":30}], 1, false)
        check(stage.slots.has(0), "Monster slot did not spawn")
        if stage.slots.has(0):
            var slot: Dictionary = stage.slots[0]
            check((slot.get("action_sheets", {}) as Dictionary).size() == 4, "Action sheets not bound to battle")
            stage.attack(0)
            stage._process(0.06)
            var attack_atlas: AtlasTexture = stage.slots[0]["atlas"]
            check(attack_atlas.atlas == sheets["attack"], "Attack did not select independent action image")
            stage.hit(0, true)
            stage._process(0.07)
            var defeat_atlas: AtlasTexture = stage.slots[0]["atlas"]
            check(defeat_atlas.atlas == sheets["defeat"], "Defeat did not select independent death image")
        stage.queue_free()
    if errors.is_empty():
        print("PASS: salt slime 4 state sheets, 20 poses, real battle bindings, no fallback regression")
        quit(0)
    else:
        for err in errors:
            push_error(err)
        quit(1)
