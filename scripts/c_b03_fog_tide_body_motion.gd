extends Node2D
## C2.3: first-act single-body boss visuals ONLY. B03 high-resolution art is
## never replaced. Motion UV deformation + five distinct illustrated fog strips.
const SHADER_PATH: String = "res://assets/shaders/c23_fog_tide_body_warp.gdshader"
const FRAME_SIZE: int = 256
const DIRECTORY: String = "res://assets/art/b03/boss_motion/c23_ch002/"
const Generated = preload("res://scripts/global_generated_art_v3.gd")
const GENERATED_MOTION_MANIFEST: String = "res://assets/art/runtime/boss_motion_v1/manifest.json"
const GENERATED_MOTION_ROOT: String = "res://assets/art/runtime/boss_motion_v1/"
const GENERATED_CELL: int = 128
const GENERATED_STATES: Array[String] = ["idle", "attack", "hit", "status", "down", "phase_change"]
const STATES: Dictionary = {"idle":4, "charge":6, "attack":6, "hit":4, "defeat":6}
const DURATIONS: Dictionary = {"charge":0.72, "attack":0.38, "hit":0.34, "defeat":0.75, "phase":1.08}
var portrait: TextureRect
var shader_material: ShaderMaterial
var original_material: Material
var effect: Sprite2D
var sheets: Dictionary = {}
var atlas: AtlasTexture
var generated_atlas: AtlasTexture
var generated_texture: Texture2D
var previous_portrait_texture: Texture2D
var state: String = "idle"
var state_elapsed: float = 0.0
var clock: float = 0.0
var frame_index: int = 0
var reduced_motion: bool = false
var enabled: bool = false
## Either "authored_sheets" (five genuinely imported frame sources) or
## "live_portrait_shader" (real portrait with material deformation only).
## Never represent procedural movement as authored frame art.
var motion_source: String = "unavailable"
var queued_phase: bool = false
var permitted_chapter: int = 2
var art_directory: String = DIRECTORY
var shader_path: String = SHADER_PATH
var effect_label: String = "C23AuthoredFogAppendages"

## Return only a correctly registered per-boss six-state atlas. We do not
## assume that a generated file exists just because a chapter ID is known.
func _live_generated_sheet(chapter: int) -> Texture2D:
    if chapter < 2 or chapter > 6 or not FileAccess.file_exists(GENERATED_MOTION_MANIFEST):
        return null
    var payload: Variant = JSON.parse_string(
        FileAccess.get_file_as_string(GENERATED_MOTION_MANIFEST))
    if not (payload is Dictionary) or str(payload.get("schema", "")) != "starlit.boss_motion.runtime.v1":
        return null
    var key: String = "boss_ch%03d" % chapter
    var record: Dictionary = (payload.get("assets", {}) as Dictionary).get(key, {})
    var image_path: String = GENERATED_MOTION_ROOT + key + ".png"
    if str(record.get("source", "")) != image_path:
        return null
    if str(record.get("source_identity", "")) != Generated.boss_path("boss.ch%03d" % chapter):
        return null
    if not ResourceLoader.exists(image_path):
        return null
    var loaded: Texture2D = ResourceLoader.load(image_path) as Texture2D
    if loaded == null or loaded.get_size() != Vector2(GENERATED_CELL * 4, GENERATED_CELL * GENERATED_STATES.size()):
        return null
    return loaded

func configure(target: TextureRect, chapter: int, motion_reduced: bool = false) -> bool:
    enabled = false
    motion_source = "unavailable"
    sheets.clear()
    effect = null
    atlas = null
    generated_atlas = null
    generated_texture = null
    previous_portrait_texture = null
    if chapter != permitted_chapter or not is_instance_valid(target) or target.texture == null:
        return false
    if not ResourceLoader.exists(shader_path):
        return false
    portrait = target
    reduced_motion = motion_reduced
    original_material = portrait.material
    # Respect any externally-authored material instead of overwriting a DLC effect.
    if original_material != null:
        return false
    var shader: Shader = load(shader_path) as Shader
    if shader == null:
        return false
    var imported: Dictionary = {}
    var has_authored_sheets: bool = true
    for pose in STATES.keys():
        var count: int = int(STATES[pose])
        var path: String = art_directory + pose + "_" + str(count) + "f.svg"
        if not ResourceLoader.exists(path):
            has_authored_sheets = false
            break
        var texture: Texture2D = load(path) as Texture2D
        if texture == null or texture.get_size() != Vector2(FRAME_SIZE*count, FRAME_SIZE):
            has_authored_sheets = false
            break
        imported[pose] = texture
    sheets = imported if has_authored_sheets and imported.size() == STATES.size() else {}
    shader_material = ShaderMaterial.new()
    shader_material.shader = shader
    portrait.material = shader_material
    previous_portrait_texture = portrait.texture
    generated_texture = _live_generated_sheet(chapter)
    if generated_texture != null:
        # A real 4-column x 6-row sheet is the live boss portrait, not
        # just a resource registered in an art catalog. The existing shader
        # adds subtle movement to the actual handoff/attack/hit frames.
        generated_atlas = AtlasTexture.new()
        generated_atlas.atlas = generated_texture
        generated_atlas.region = Rect2(0, 0, GENERATED_CELL, GENERATED_CELL)
        portrait.texture = generated_atlas
        motion_source = "generated_six_state_atlas"
    else:
        # Damaged or absent generated atlas: keep the current visible
        # portrait and the old shader/optional authored-sheet behavior.
        motion_source = "authored_sheets" if not sheets.is_empty() else "live_portrait_shader"
    if generated_atlas == null and not sheets.is_empty():
        effect = Sprite2D.new()
        effect.name = effect_label
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
    if generated_atlas != null:
        var generated_pose: String = state
        match state:
            "charge": generated_pose = "status"
            "phase": generated_pose = "phase_change"
            "defeat": generated_pose = "down"
        var row: int = GENERATED_STATES.find(generated_pose)
        if row >= 0:
            var generated_frame: int = 0
            if not reduced_motion:
                generated_frame = int(clock / 0.18) % 4 if state == "idle" else mini(int(progress * 4.0), 3)
            frame_index = generated_frame
            generated_atlas.region = Rect2(
                GENERATED_CELL * generated_frame, GENERATED_CELL * row,
                GENERATED_CELL, GENERATED_CELL)
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
    if is_instance_valid(portrait):
        if generated_atlas != null and portrait.texture == generated_atlas:
            portrait.texture = previous_portrait_texture
        if is_instance_valid(shader_material) and portrait.material == shader_material:
            portrait.material = original_material
