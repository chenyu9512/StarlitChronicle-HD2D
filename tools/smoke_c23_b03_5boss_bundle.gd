extends SceneTree
## All five Act-I bosses: genuine imported identity and the deployed
## chapter-specific live shader or complete authored strips (when present).
const Ch2=preload("res://scripts/c_b03_fog_tide_body_motion.gd")
const Others=preload("res://scripts/c_b03_other_boss_motion.gd")
const Art=preload("res://scripts/art_assets.gd")
const Overrides=preload("res://scripts/c_art_overrides.gd")
var errors: Array[String]=[]
func check(ok: bool,msg: String) -> void:
    if not ok: errors.append(msg)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
    var sources: Dictionary={}
    for ch in range(2,7):
        var id: String="boss.ch%03d" % ch
        var path: String=Art.boss_image(id)
        check(not path.is_empty() and Overrides.exists(path),id+": missing playable portrait")
        if path.is_empty() or not Overrides.exists(path): continue
        check(not sources.has(path),id+": boss portrait reused across chapters")
        sources[path]=true
        var portrait:=TextureRect.new()
        portrait.texture=Overrides.texture(path)
        portrait.size=Vector2(360,360)
        root.add_child(portrait)
        check(portrait.texture!=null,id+": real portrait failed to decode")
        if portrait.texture==null:
            portrait.queue_free()
            continue
        var original: Texture2D=portrait.texture
        var rig=Ch2.new() if ch==2 else Others.new()
        root.add_child(rig)
        check(rig.configure(portrait,ch,false),id+": chapter motion shader cannot configure")
        if rig.enabled:
            check(rig.shader_material!=null and portrait.material==rig.shader_material,
                id+": actual portrait lacks animated material")
            check(rig.motion_source in ["authored_sheets","live_portrait_shader"],
                id+": unrecognized motion renderer")
            if rig.motion_source=="authored_sheets":
                check(rig.sheets.size()==5 and rig.atlas!=null and rig.effect!=null,
                    id+": authored pose strips incomplete")
            else:
                check(rig.sheets.is_empty() and rig.atlas==null,
                    id+": shader-only renderer pretends old strips exist")
            rig.play_attack()
            rig._advance(0.12)
            check(rig.state=="attack" and
                float(rig.shader_material.get_shader_parameter("attack_weight"))>0.0,
                id+": live attack did not move the portrait")
            rig.play_hit()
            rig._advance(0.11)
            check(rig.state=="hit",id+": live hit feedback missing")
            rig.play_phase()
            rig._advance(0.40)
            check(rig.state=="phase",id+": queued phase disappeared")
            rig.play_defeat()
            check(rig.state=="defeat",id+": defeat lock missing")
        check(portrait.texture==original,id+": original boss identity was swapped")
        rig.queue_free()
        portrait.queue_free()
    if errors.is_empty():
        print("PASS: five chapter-specific imported boss portraits, actual shader/strip and live combat states")
        quit(0)
        return
    for item in errors: push_error(item)
    quit(1)
