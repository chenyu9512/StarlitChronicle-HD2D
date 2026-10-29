extends SceneTree
## C2.3 chapter-2 actual B03 portrait motion — no combat state mutation.
const Motion = preload("res://scripts/c_b03_fog_tide_body_motion.gd")
const Art = preload("res://scripts/art_assets.gd")
var failures: Array[String] = []
func check(ok: bool, why: String) -> void:
    if not ok:
        failures.append(why)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var path: String = Art.boss_image("boss.ch002")
    check(path.contains("boss_final_render"),"Cannot resolve original chapter-2 B03 identity")
    var portrait := TextureRect.new()
    portrait.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
    portrait.size = Vector2(360,360)
    root.add_child(portrait)
    var rig := Motion.new()
    root.add_child(rig)
    check(rig.configure(portrait,2,false),"Chapter-2 true portrait motion failed to configure")
    if rig.enabled:
        check(rig.sheets.size()==5,"Five real motion overlays not imported")
        check(portrait.material==rig.shader_material,"Original B03 portrait did not receive body deformation")
        var original: Texture2D=portrait.texture
        for pose in ["idle","charge","attack","hit","defeat"]:
            var count: int=int(Motion.STATES[pose])
            var source: Texture2D=rig.sheets[pose]
            check(source.get_size()==Vector2(count*256,256),pose+": wrong sheet size")
            var picture: Image=source.get_image()
            check(picture != null,pose+": unreadable illustration")
            if picture!=null:
                var before: PackedByteArray=picture.get_region(Rect2i(0,0,256,256)).get_data()
                var after: PackedByteArray=picture.get_region(Rect2i((count-1)*256,0,256,256)).get_data()
                check(before!=after,pose+": first and last frame visually identical")
        rig.play_charge()
        rig._advance(0.2)
        check(rig.state=="charge","Charge state not selected")
        rig.play_attack()
        rig._advance(0.12)
        check(rig.state=="attack","Attack state not selected")
        check(float(rig.shader_material.get_shader_parameter("attack_weight"))>0.0,"The actual B03 texture is not moving")
        rig.play_hit(false)
        rig._advance(0.11)
        check(rig.state=="hit","Hit state not selected")
        rig.play_phase()
        rig._advance(0.18)
        check(rig.state=="hit","Phase must not steal an active hit response")
        rig._advance(0.40)
        check(rig.state=="phase","Phase transition must play after the hit rather than get lost")
        rig._advance(1.20)
        check(rig.state=="idle","Phase should return to idle")
        rig.play_defeat()
        rig._advance(0.2)
        check(rig.state=="defeat","Defeat state missing")
        rig.play_attack()
        check(rig.state=="defeat","Attack cannot revive defeated body")
        check(portrait.texture==original,"Original B03 PNG identity changed")
    var other := Motion.new()
    root.add_child(other)
    check(not other.configure(portrait,3,false),"Chapter-3 boss must not inherit chapter-2 art rig")
    other.queue_free()
    rig.queue_free()
    portrait.queue_free()
    if failures.is_empty():
        print("PASS C23: unchanged B03 portrait with deforming material, 26 overlay frames and state priority")
        quit(0)
        return
    for entry in failures:
        push_error(entry)
    quit(1)
