extends SceneTree
## C2.3b four unique B03 source-preserving boss visual rigs, no HP or reward writes.
const Art = preload("res://scripts/art_assets.gd")
const Rig = preload("res://scripts/c_b03_other_boss_motion.gd")
const Ch2 = preload("res://scripts/c_b03_fog_tide_body_motion.gd")
var errors: Array[String] = []
func check(ok: bool, why: String) -> void:
    if not ok:
        errors.append(why)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var originals: Dictionary = {}
    for chapter in range(3,7):
        var id: String = "boss.ch%03d" % chapter
        var path: String = Art.boss_image(id)
        check(path.contains("boss_final_render"),id+": cannot resolve authoritative B03 art")
        if not ResourceLoader.exists(path):
            check(false,id+": image file not importable")
            continue
        var portrait := TextureRect.new()
        portrait.texture = load(path) as Texture2D
        portrait.size = Vector2(360,360)
        root.add_child(portrait)
        if portrait.texture == null:
            check(false,id+": B03 source was not a texture")
            portrait.queue_free()
            continue
        var original: Texture2D = portrait.texture
        var rig := Rig.new()
        root.add_child(rig)
        check(rig.configure(portrait,chapter,false),id+": rig configure failed")
        if rig.enabled:
            check(rig.sheets.size()==5,id+": missing any of the five illustrated poses")
            check(rig.shader_material!=null and portrait.material==rig.shader_material,id+": source body has no state shader")
            check(int(rig.shader_material.get_shader_parameter("chapter_style"))==chapter,id+": wrong boss motion type")
            check(not originals.has(rig.art_directory),id+": reused another boss art atlas")
            originals[rig.art_directory]=true
            for pose in ["idle","charge","attack","hit","defeat"]:
                var tex: Texture2D = rig.sheets[pose]
                var count: int = int(Ch2.STATES[pose])
                check(tex.get_size()==Vector2(256*count,256),id+": "+pose+" sheet size mismatch")
                var im: Image = tex.get_image()
                check(im!=null,id+": "+pose+" decode failed")
                if im!=null:
                    var first: PackedByteArray=im.get_region(Rect2i(0,0,256,256)).get_data()
                    var last: PackedByteArray=im.get_region(Rect2i((count-1)*256,0,256,256)).get_data()
                    check(first!=last,id+": "+pose+" identical frames")
            rig.play_charge()
            rig._advance(0.2)
            check(rig.state=="charge",id+": charge not playing")
            rig.play_attack()
            rig._advance(0.12)
            check(rig.state=="attack",id+": attack not playing")
            rig.play_hit(false)
            rig.play_phase()
            rig._advance(0.4)
            check(rig.state=="phase",id+": phase was lost after hit")
            rig._advance(1.2)
            check(rig.state=="idle",id+": phase failed to finish")
            rig.play_defeat()
            rig._advance(0.4)
            check(rig.state=="defeat",id+": settlement animation missing")
            rig.play_attack()
            check(rig.state=="defeat",id+": defeated state revived")
            check(portrait.texture==original,id+": B03 identity image was changed")
        rig.queue_free()
        portrait.queue_free()
    if errors.is_empty():
        print("PASS: four identity-specific Boss portrait rigs, 104 overlay frames and original PNG intact")
        quit(0)
        return
    for reason in errors:
        push_error(reason)
    quit(1)
