extends SceneTree
## C2.3 chapter-2 actual B03 portrait motion — no combat state mutation.
const Motion = preload("res://scripts/c_b03_fog_tide_body_motion.gd")
const Art = preload("res://scripts/art_assets.gd")
const Overrides = preload("res://scripts/c_art_overrides.gd")
var failures: Array[String] = []
func check(ok: bool, why: String) -> void:
    if not ok:
        failures.append(why)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var path: String = Art.boss_image("boss.ch002")
    check(not path.is_empty() and Overrides.exists(path),"Chapter-2 real candidate portrait missing")
    var portrait := TextureRect.new()
    portrait.texture = Overrides.texture(path) if not path.is_empty() else null
    portrait.size = Vector2(360,360)
    root.add_child(portrait)
    var rig := Motion.new()
    root.add_child(rig)
    check(rig.configure(portrait,2,false),"Chapter-2 true portrait motion failed to configure")
    if rig.enabled:
        check(rig.motion_source in ["authored_sheets","live_portrait_shader"],
            "No real boss portrait motion renderer")
        check(portrait.material==rig.shader_material,
            "Imported portrait did not receive body deformation")
        if rig.motion_source=="authored_sheets":
            check(rig.sheets.size()==5 and rig.atlas!=null,
                "Existing illustrated motion overlays are incomplete")
        else:
            check(rig.sheets.is_empty() and rig.atlas==null,
                "Retired illustrated motion sheets were falsely reported")
        var original: Texture2D=portrait.texture
        # Reading back huge third-party PNG pixels is not part of the live
        # Boss visual contract, and used to block CI for three minutes.
        # Check frame dimensions only if real authored strips are installed.
        if rig.motion_source=="authored_sheets":
            for pose in ["idle","charge","attack","hit","defeat"]:
                var count: int=int(Motion.STATES[pose])
                var source: Texture2D=rig.sheets.get(pose)
                check(source!=null and source.get_size()==Vector2(count*256,256),
                    pose+": actual imported strip has wrong dimensions")
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
        print("PASS C23: real portrait shader state priority, source-preserving art and optional real authored overlays")
        quit(0)
        return
    for entry in failures:
        push_error(entry)
    quit(1)
