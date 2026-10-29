extends SceneTree
## Presence and dimensions of all 5 chapter rigs, without touching mutable combat data.
const Ch2 = preload("res://scripts/c_b03_fog_tide_body_motion.gd")
const Others = preload("res://scripts/c_b03_other_boss_motion.gd")
const Art = preload("res://scripts/art_assets.gd")
var errors: Array[String] = []
func check(ok: bool, msg: String) -> void:
    if not ok:
        errors.append(msg)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    for ch in range(2,7):
        var id: String = "boss.ch%03d" % ch
        var path: String = Art.boss_image(id)
        check(not path.is_empty(),id+": missing original B03 portrait")
        if not ResourceLoader.exists(path):
            check(false,id+": image not importable")
            continue
        var portrait := TextureRect.new()
        portrait.texture = load(path)
        portrait.size = Vector2(360,360)
        root.add_child(portrait)
        var original: Texture2D = portrait.texture
        var rig = Ch2.new() if ch == 2 else Others.new()
        root.add_child(rig)
        check(rig.configure(portrait,ch,false),id+": failed to configure")
        check(portrait.texture==original,id+": replaced the source portrait")
        if rig.enabled:
            check(rig.sheets.size()==5,id+": incomplete motion sheets")
            check(rig.atlas!=null and rig.effect!=null,id+": missing real action image")
        rig.queue_free()
        portrait.queue_free()
    if errors.is_empty():
        print("PASS: C2.3 all five B03 portrait rigs installed without replacing canonical PNG")
        quit(0)
        return
    for item in errors:
        push_error(item)
    quit(1)
