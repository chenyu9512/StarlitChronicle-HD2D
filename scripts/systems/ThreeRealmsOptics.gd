extends CanvasLayer
## Screen-space presentation adapter for hd2d_three_realms.gdshader.
## No story flag or world/save mutation. Existing HD2D scenery, collisions,
## world lighting and all cheat settings remain authoritative.
const REALM_SHADER = preload("res://shaders/hd2d_three_realms.gdshader")
var film: ColorRect
var material_instance: ShaderMaterial

func _ready() -> void:
    layer = 8 # The adventure/menu/secret panels stay readable above this.
    film = ColorRect.new()
    film.name = "ThreeRealmsScreenOptics"
    film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    film.mouse_filter = Control.MOUSE_FILTER_IGNORE
    film.color = Color.WHITE
    material_instance = ShaderMaterial.new()
    material_instance.shader = REALM_SHADER
    film.material = material_instance
    add_child(film)
    visible = false

func update_realm(epoch: String, flags: Dictionary, rpg: Dictionary,
        visual_quality: int, weather: String, clock_minutes: int) -> void:
    if film == null or material_instance == null:
        return
    var modes: Dictionary = {"present":0,"mirror":1,"chronicle_corridor":2}
    var mode: int = int(modes.get(epoch,0))
    var quality: int = clampi(visual_quality,0,2)
    # No visual-filter effects on the low-quality/reduced-motion setting.
    visible = quality > 0 and epoch in modes
    var effect: float = 0.27 if quality==1 else 0.42
    var time_of_day: float = float(posmod(clock_minutes,1440))/1440.0
    var sun_strength: float = clampf(0.5+0.5*cos((time_of_day-0.50)*TAU),0.05,1.0)
    material_instance.set_shader_parameter("realm_mode",mode)
    material_instance.set_shader_parameter("effect_strength",effect)
    material_instance.set_shader_parameter("sea_fog_density",
        0.37 if weather in ["fog","mist","rain"] else 0.18)
    material_instance.set_shader_parameter("lantern_radius",
        0.44 if sun_strength<0.45 else 0.72)
    var stages: Variant = rpg.get("chapter_mechanics_v2",{})
    var ch36: Dictionary = stages.get("ch036",{}) if stages is Dictionary else {}
    var shadow_ready: bool = bool(flags.get("mirror_shadow_unlocked",false)) or (
        bool(flags.get("mechanic.ch036.ready",false)) and
        bool(ch36.get("mirror_lamp_rekindled",false)) and
        bool(ch36.get("done",false)))
    material_instance.set_shader_parameter("mirror_shadow_unlocked",
        mode==1 and shadow_ready)
    material_instance.set_shader_parameter("mirror_sun_angle_deg",
        24.0 if shadow_ready else 0.0)
    material_instance.set_shader_parameter("mirror_prismatic_aberration",
        0.0015 if quality==1 else 0.0025)
    material_instance.set_shader_parameter("chronicle_dual_echo_blend",
        0.38 if quality==1 else 0.57)
    material_instance.set_shader_parameter("vignette_intensity",
        0.23 if quality==1 else 0.31)
