extends SceneTree
## Five first-act live boss identities: real six-row generated motion
## atlases, visibly state-responsive boss shaders and recoverable base portraits.
## Authored B03 multi-frame overlay production is a SEPARATE failing art gate.
const Art = preload("res://scripts/art_assets.gd")
const Ch2 = preload("res://scripts/c_b03_fog_tide_body_motion.gd")
const Others = preload("res://scripts/c_b03_other_boss_motion.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, reason: String) -> void:
    if not ok:
        errors.append(reason)

func _run() -> void:
    var ids: Dictionary = {}
    for chapter in range(2,7):
        var boss_id: String = "boss.ch%03d" % chapter
        var path: String = Art.boss_image(boss_id)
        verify(not path.is_empty() and ResourceLoader.exists(path),boss_id+" lacks live portrait")
        if path.is_empty() or not ResourceLoader.exists(path):
            continue
        verify(not ids.has(path),boss_id+" reused another boss identity")
        ids[path] = true
        var portrait := TextureRect.new()
        portrait.size = Vector2(360,360)
        portrait.texture = load(path) as Texture2D
        root.add_child(portrait)
        var untouched: Texture2D = portrait.texture
        var rig = Ch2.new() if chapter == 2 else Others.new()
        root.add_child(rig)
        verify(rig.configure(portrait,chapter,false),boss_id+" boss shader did not configure")
        if rig.enabled:
            verify(rig.motion_source in ["generated_six_state_atlas","live_portrait_shader","authored_sheets"],
                boss_id+" recorded no real runtime motion source")
            verify(portrait.material == rig.shader_material,
                boss_id+" has no working original-identity shader")
            if rig.motion_source == "generated_six_state_atlas":
                # A REAL 512x768 six-row sheet intentionally replaces the
                # portrait with an AtlasTexture at runtime. Identity is proved
                # by its original portrait handoff and chapter-specific source,
                # not by demanding that the rendering texture never change.
                var sheet_source: String = "res://assets/art/runtime/boss_motion_v1/boss_ch%03d.png" % chapter
                verify(ResourceLoader.exists(sheet_source)
                    and rig.generated_texture != null
                    and rig.generated_texture.get_size() == Vector2(512,768)
                    and rig.generated_atlas != null
                    and rig.generated_atlas.atlas == rig.generated_texture
                    and portrait.texture == rig.generated_atlas
                    and rig.previous_portrait_texture == untouched,
                    boss_id+" six-state animation did not preserve chapter portrait identity")
            else:
                verify(untouched == portrait.texture,
                    boss_id+" fallback portrait identity was changed")
            verify(str(rig.motion_source) in ["generated_six_state_atlas","authored_sheets"] or
                (rig.sheets.is_empty() and rig.effect == null),
                boss_id+" claims missing authored illustrations as real")
            if chapter >= 3:
                verify(int(rig.shader_material.get_shader_parameter("chapter_style")) == chapter,
                    boss_id+" lost its chapter-specific style")
            rig.play_charge()
            rig._advance(0.18)
            verify(rig.state == "charge" and
                float(rig.shader_material.get_shader_parameter("charge_weight")) > 0.0,
                boss_id+" cannot animate boss charging")
            rig.play_attack()
            rig._advance(0.12)
            verify(rig.state == "attack" and
                float(rig.shader_material.get_shader_parameter("attack_weight")) > 0.0,
                boss_id+" cannot animate boss attack")
            rig.play_hit(false)
            rig._advance(0.1)
            verify(rig.state == "hit" and
                float(rig.shader_material.get_shader_parameter("hit_weight")) > 0.0,
                boss_id+" has no hit feedback")
            rig.play_phase()
            rig._advance(0.36)
            verify(rig.state == "phase",boss_id+" lost phase cue after hit")
            rig._advance(1.2)
            verify(rig.state == "idle",boss_id+" phase did not settle")
            rig.reduced_motion = true
            rig.play_charge()
            rig._advance(0.1)
            verify(float(rig.shader_material.get_shader_parameter("reduced_motion")) == 1.0,
                boss_id+" accessibility toggle not sent to shader")
            rig.play_defeat()
            rig._advance(0.2)
            verify(rig.state == "defeat",boss_id+" lacks ending/release visual state")
            rig.play_attack()
            verify(rig.state == "defeat",boss_id+" defeated body revived on attack")
        rig.queue_free()
        portrait.queue_free()
    verify(ids.size() == 5,"Five distinct true first-act boss art paths required")
    if errors.is_empty():
        print("PASS Main2: five distinct boss sources, real 6-state animation or safe shader fallback, charge/strike/hit/phase/end, reduced motion and preserved portrait identity; human art approval pending")
        quit(0)
        return
    for problem in errors:
        push_error(problem)
    quit(1)
