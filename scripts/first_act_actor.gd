extends Node2D
const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
## C-line actor: eight logical headings with honest four-direction sprite atlas fallback.
const CharacterMotion = preload("res://scripts/c_character_motion.gd")
const AudioBusRuntime = preload("res://scripts/audio_bus_runtime.gd")
static var footstep_wave: AudioStreamWAV
var sprite: Sprite2D
var walk_clock: float = 0.0
var facing: int = 0
var idle_elapsed: float = 0.0
var reacting: bool = false
var reduced_motion: bool = false
var motion = CharacterMotion.new()
var footsteps: AudioStreamPlayer2D
var step_index: int = 0
var footstep_enabled: bool = true

func _draw() -> void:
    var ellipse := PackedVector2Array()
    for i in range(16):
        var angle: float = TAU * float(i) / 16.0
        ellipse.append(Vector2(cos(angle) * 11.0, 8.0 + sin(angle) * 4.0))
    draw_colored_polygon(ellipse, Color(0.02, 0.08, 0.11, 0.29))

func setup(image: String) -> void:
    add_to_group("c_visual_actor")
    if is_instance_valid(sprite):
        sprite.queue_free()
    sprite = Sprite2D.new()
    # Use the authored C2.1 four-facing atlas only when no local PNG override exists.
    # Existing 96x192 PNG remains the safe fallback, unchanged on disk.
    var authored: String = image.get_basename() + "_c21.svg" if image.ends_with("/walk_4dir_3frames.png") else ""
    if not authored.is_empty() and not ArtOverrides.has_override(image) and ArtOverrides.exists(authored):
        var upgrade: Texture2D = ArtOverrides.texture(authored)
        if upgrade != null and upgrade.get_size() == Vector2(96, 192):
            sprite.texture = upgrade
            sprite.set_meta("c21_walk_source", authored)
    if sprite.texture == null and ArtOverrides.exists(image):
        sprite.texture = ArtOverrides.texture(image)
    # Third-party migration may resolve a historical 96x192 walk atlas to
    # one directional PNG. Never slice that single frame into 12 random pieces.
    if sprite.texture != null and sprite.texture.get_size() == Vector2(96, 192):
        sprite.hframes = 3
        sprite.vframes = 4
        sprite.frame_coords = Vector2i(1, 0)
    else:
        sprite.hframes = 1
        sprite.vframes = 1
        sprite.frame = 0
        if sprite.texture != null:
            var bounds: Vector2 = sprite.texture.get_size()
            var fit: float = minf(1.0, minf(32.0 / maxf(bounds.x, 1.0), 48.0 / maxf(bounds.y, 1.0)))
            sprite.scale = Vector2(fit, fit)
        else:
            sprite.visible = false
            push_warning("No third-party actor texture for " + image)
    sprite.position = Vector2(0, -19)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    if footstep_wave == null:
        footstep_wave = _build_original_footstep()
    if not is_instance_valid(footsteps):
        AudioBusRuntime.ensure_buses()
        footsteps = AudioStreamPlayer2D.new()
        footsteps.name = "OriginalFootfall"
        footsteps.bus = "SFX"
        footsteps.volume_db = -32.0
        footsteps.max_distance = 190.0
        footsteps.stream = footstep_wave
        add_child(footsteps)

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    motion.reduced_motion = value
    if is_instance_valid(sprite) and value:
        sprite.position = Vector2(0, -19)
        sprite.rotation = 0.0

func set_motion(delta: float, velocity: Vector2) -> void:
    if not is_instance_valid(sprite):
        return
    var was_step: int = step_index
    motion.reduced_motion = reduced_motion
    motion.advance(delta, velocity)
    walk_clock = motion.phase
    facing = motion.atlas_row()
    idle_elapsed = motion.idle_time
    if sprite.hframes == 3 and sprite.vframes == 4:
        sprite.frame_coords = Vector2i(motion.atlas_column(), facing)
    sprite.position = Vector2(0, -19) + motion.visual_offset()
    if not reduced_motion:
        sprite.rotation = 0.012 * sin(motion.phase * 2.2) if motion.move_blend > 0.1 else 0.0
    step_index = motion.footfall_index
    if footstep_enabled and step_index > was_step and is_instance_valid(footsteps):
        footsteps.pitch_scale = 0.96 if step_index % 2 == 0 else 1.04
        footsteps.play()

func face_position(world_point: Vector2) -> void:
    motion.face_vector(to_local(world_point))
    facing = motion.atlas_row()
    if is_instance_valid(sprite):
        if sprite.hframes == 3 and sprite.vframes == 4:
            sprite.frame_coords = Vector2i(1, facing)

func begin_conversation(world_point: Vector2) -> void:
    motion.start_talking(to_local(world_point))
    facing = motion.atlas_row()
    if is_instance_valid(sprite):
        if sprite.hframes == 3 and sprite.vframes == 4:
            sprite.frame_coords = Vector2i(1, facing)

func react() -> void:
    if not is_instance_valid(sprite) or reacting:
        return
    reacting = true
    motion.gesture()
    var pulse := create_tween()
    pulse.tween_property(sprite, "scale", Vector2(1.08, 0.94), 0.08)
    pulse.tween_property(sprite, "scale", Vector2.ONE, 0.14)
    pulse.finished.connect(func() -> void:
        reacting = false
    )

static func _build_original_footstep() -> AudioStreamWAV:
    ## Original deterministic 70ms granular contact sound; no external sample.
    var rate: int = 11025
    var count: int = 770
    var pcm := PackedByteArray()
    pcm.resize(count * 2)
    for i in range(count):
        var progress: float = float(i) / float(count)
        var time_value: float = float(i) / float(rate)
        var grain: float = sin(time_value * 3790.0) * sin(time_value * 7400.0)
        var low: float = sin(TAU * 112.0 * time_value) * 0.35
        var envelope: float = (1.0 - progress) * (1.0 - progress) * minf(1.0, progress * 42.0)
        pcm.encode_s16(i * 2, clampi(roundi((grain * 0.48 + low) * envelope * 7800.0), -32767, 32767))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.stereo = false
    stream.data = pcm
    return stream
