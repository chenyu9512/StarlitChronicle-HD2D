extends Node2D
## C2.3: first-act single-body boss visuals ONLY. B03 high-resolution art is
## never replaced. Motion UV deformation + five distinct illustrated fog strips.
const SHADER_PATH: String = "res://assets/shaders/c23_fog_tide_body_warp.gdshader"
const FRAME_SIZE: int = 256
const DIRECTORY: String = "res://assets/art/b03/boss_motion/c23_ch002/"
const STATES: Dictionary = {"idle":4, "charge":6, "attack":6, "hit":4, "defeat":6}
const DURATIONS: Dictionary = {"charge":0.72, "attack":0.38, "hit":0.34, "defeat":0.75, "phase":1.08}
var portrait: TextureRect
var shader_material: ShaderMaterial
var original_material: Material
var effect: Sprite2D
var sheets: Dictionary = {}
var atlas: AtlasTexture
var state: String = "idle"
var state_elapsed: float = 0.0
var clock: float = 0.0
var frame_index: int = 0
var reduced_motion: bool = false
var enabled: bool = false
var queued_phase: bool = false

func configure(target: TextureRect, chapter: int, motion_reduced: bool = false) -> bool:
    enabled = false
    if chapter != 2 or not is_instance_valid(target) or target.texture == null:
        return false
    if not ResourceLoader.exists(SHADER_PATH):
        return false
    portrait = target
    reduced_motion = motion_reduced
    original_material = portrait.material
    # Respect any externally-authored material instead of overwriting a DLC effect.
    if original_material != null:
        return false
    var shader: Shader = load(SHADER_PATH) as Shader
    if shader == null:
        return false
    var imported: Dictionary = {}
    for pose in STATES.keys():
        var count: int = int(STATES[pose])
        var path: String = DIRECTORY + pose + "_" + str(count) + "f.svg"
        if not ResourceLoader.exists(path):
            return false
        var texture: Texture2D = load(path) as Texture2D
        if texture == null or texture.get_size() != Vector2(FRAME_SIZE*count, FRAME_SIZE):
            return false
        imported[pose] = texture
    sheets = imported
    shader_material = ShaderMaterial.new()
    shader_material.shader = shader
    portrait.material = shader_material
    effect = Sprite2D.new()
    effect.name = "C23AuthoredFogAppendages"
    effect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    atlas = AtlasTexture.new()
    atlas.atlas = sheets["idle"]
    atlas.region = Rect2(0,0,FRAME_SIZE,FRAME_SIZE)
    effect.texture = atlas
    effect.modulate.a = 0.48
    add_child(effect)
    enabled = true
    state = "idle"
    state_elapsed = 0.0
    clock = 0.0
    queued_phase = false
    _advance(0.0)
    set_process(true)
    return true

func _priority(pose: String) -> int:
    match pose:
        "defeat": return 5
        "hit": return 4
        "phase": return 3
        "attack": return 2
        "charge": return 1
        _: return 0

func _set_state(pose: String) -> void:
    if not enabled or not STATES.has(pose) and pose != "phase":
        return
    if state != "idle" and _priority(state) > _priority(pose):
        # A-line raises phase-two immediately after a hit. Queue it so the
        # hit is visibly shown and the only phase transition is not lost.
        if pose == "phase" and state != "defeat":
            queued_phase = true
        return
    state = pose
    state_elapsed = 0.0
    frame_index = 0
    _advance(0.0)

func play_charge() -> void:
    _set_state("charge")
func play_attack() -> void:
    _set_state("attack")
func play_hit(defeated: bool = false) -> void:
    _set_state("defeat" if defeated else "hit")
func play_phase() -> void:
    _set_state("phase")
func play_defeat() -> void:
    _set_state("defeat")

func _process(delta: float) -> void:
    _advance(clampf(delta,0.0,0.10))

func _advance(delta: float) -> void:
    if not enabled or not is_instance_valid(portrait):
        return
    var dt: float = maxf(0.0,delta)
    clock += dt
    state_elapsed += dt
    var duration: float = float(DURATIONS.get(state,0.0))
    if duration > 0.0 and state_elapsed >= duration and state != "defeat":
        state = "phase" if queued_phase else "idle"
        queued_phase = false
        state_elapsed = 0.0
        duration = float(DURATIONS.get(state,0.0))
    var progress: float = clampf(state_elapsed/maxf(duration,0.001),0.0,1.0) if duration > 0.0 else 0.0
    var pulse: float = sin(progress*PI)
    var idling: float = 1.0 if state == "idle" else 0.34
    shader_material.set_shader_parameter("elapsed_time",clock)
    shader_material.set_shader_parameter("idle_weight",idling)
    shader_material.set_shader_parameter("charge_weight",pulse if state == "charge" else 0.0)
    shader_material.set_shader_parameter("attack_weight",pulse if state == "attack" else 0.0)
    shader_material.set_shader_parameter("hit_weight",pulse if state == "hit" else 0.0)
    shader_material.set_shader_parameter("defeat_weight",progress if state == "defeat" else 0.0)
    shader_material.set_shader_parameter("phase_weight",pulse if state == "phase" else 0.0)
    shader_material.set_shader_parameter("reduced_motion",1.0 if reduced_motion else 0.0)
    if not is_instance_valid(effect):
        return
    var visible_pose: String = "charge" if state == "phase" else state
    var count: int = int(STATES.get(visible_pose,4))
    var new_frame: int
    if reduced_motion:
        new_frame = count/2 if state == "phase" else 0
    elif state == "idle":
        new_frame = int(clock/0.18)%count
    else:
        new_frame = mini(int(progress*float(count)),count-1)
    frame_index = new_frame
    atlas.atlas = sheets[visible_pose]
    atlas.region = Rect2(FRAME_SIZE*new_frame,0,FRAME_SIZE,FRAME_SIZE)
    var global_center: Vector2 = portrait.get_global_rect().get_center()
    effect.position = to_local(global_center)
    var width: float = minf(portrait.size.x,portrait.size.y)
    effect.scale = Vector2.ONE*clampf(width/360.0,0.4,1.75)
    effect.visible = portrait.visible
    effect.modulate.a = 0.0 if state == "defeat" and progress >= 1.0 else (0.30 if reduced_motion else 0.52 + pulse*0.22)

func _exit_tree() -> void:
    if is_instance_valid(portrait) and is_instance_valid(shader_material) and portrait.material == shader_material:
        portrait.material = original_material
