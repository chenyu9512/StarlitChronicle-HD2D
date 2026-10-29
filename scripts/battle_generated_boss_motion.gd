extends Node
## Player-visible six-state chapter Boss animation for the full campaign.
## Uses the canonical generated 4x6 atlas; no reward, turn or save mutations.
## Chapters 2-6 retain their more specialized C2.3 rendering controller.
const Generated = preload("res://scripts/global_generated_art_v3.gd")
const MANIFEST: String = "res://assets/art/runtime/boss_motion_v1/manifest.json"
const ROOT: String = "res://assets/art/runtime/boss_motion_v1/"
const FRAME: int = 128
const COLUMNS: int = 4
const ROWS: Array[String] = ["idle", "attack", "hit", "status", "down", "phase_change"]
const DURATIONS: Dictionary = {
    "charge": 0.72, "attack": 0.38, "hit": 0.34,
    "phase": 1.08, "defeat": 0.75
}

var portrait: TextureRect
var original_texture: Texture2D
var atlas: AtlasTexture
var sheet: Texture2D
var enabled: bool = false
var reduced_motion: bool = false
var state: String = "idle"
var elapsed: float = 0.0
var clock: float = 0.0
var queued_phase: bool = false
var frame_index: int = 0

func configure(target: TextureRect, chapter: int, motion_reduced: bool = false) -> bool:
    enabled = false
    if not is_instance_valid(target) or chapter < 7 or chapter > 72:
        return false
    if not FileAccess.file_exists(MANIFEST):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    if not (parsed is Dictionary) or str(parsed.get("schema", "")) != "starlit.boss_motion.runtime.v1":
        return false
    var id: String = "boss_ch%03d" % chapter
    var info: Dictionary = (parsed.get("assets", {}) as Dictionary).get(id, {})
    var source: String = ROOT + id + ".png"
    var actual_identity: String = Generated.boss_path("boss.ch%03d" % chapter)
    if actual_identity.is_empty() or str(info.get("source_identity", "")) != actual_identity:
        return false
    if str(info.get("source", "")) != source or not ResourceLoader.exists(source):
        return false
    var candidate: Texture2D = ResourceLoader.load(source) as Texture2D
    if candidate == null or candidate.get_size() != Vector2(FRAME * COLUMNS, FRAME * ROWS.size()):
        return false
    portrait = target
    original_texture = portrait.texture
    sheet = candidate
    reduced_motion = motion_reduced
    atlas = AtlasTexture.new()
    atlas.atlas = sheet
    atlas.region = Rect2(0, 0, FRAME, FRAME)
    portrait.texture = atlas
    state = "idle"
    elapsed = 0.0
    clock = 0.0
    queued_phase = false
    frame_index = 0
    enabled = true
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
    if not enabled or pose not in ["charge", "attack", "hit", "phase", "defeat"]:
        return
    if state != "idle" and _priority(state) > _priority(pose):
        if pose == "phase" and state != "defeat":
            queued_phase = true
        return
    state = pose
    elapsed = 0.0
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
    _advance(clampf(delta, 0.0, 0.12))

func _advance(delta: float) -> void:
    if not enabled or not is_instance_valid(portrait) or atlas == null:
        return
    var dt: float = maxf(0.0, delta)
    clock += dt
    elapsed += dt
    var duration: float = float(DURATIONS.get(state, 0.0))
    if duration > 0.0 and elapsed >= duration and state != "defeat":
        state = "phase" if queued_phase else "idle"
        queued_phase = false
        elapsed = 0.0
        duration = float(DURATIONS.get(state, 0.0))
    var progress: float = clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0) if duration > 0.0 else 0.0
    var visible_state: String = state
    match state:
        "charge": visible_state = "status"
        "phase": visible_state = "phase_change"
        "defeat": visible_state = "down"
    var row: int = ROWS.find(visible_state)
    if row < 0:
        return
    frame_index = 0 if reduced_motion else (
        int(clock / 0.18) % COLUMNS if state == "idle" else mini(int(progress * float(COLUMNS)), COLUMNS - 1)
    )
    atlas.region = Rect2(
        FRAME * frame_index, FRAME * row,
        FRAME, FRAME
    )

func _exit_tree() -> void:
    if is_instance_valid(portrait) and atlas != null and portrait.texture == atlas:
        portrait.texture = original_texture
