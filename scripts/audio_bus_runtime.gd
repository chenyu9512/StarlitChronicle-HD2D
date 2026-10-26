extends RefCounted
## Runtime-only bus groups; no changes to project.godot or audio layout required.
## Persist volumes under user:// instead of editing A/B save state.
const MIX_CONFIG: String = "user://av_audio_mix.cfg"

static func ensure_buses() -> void:
    for bus_name in ["Music", "SFX", "Ambience", "Voice"]:
        if AudioServer.get_bus_index(bus_name) < 0:
            AudioServer.add_bus()
            var idx: int = AudioServer.get_bus_count() - 1
            AudioServer.set_bus_name(idx, bus_name)
            AudioServer.set_bus_send(idx, "Master")

static func restore_mix() -> void:
    ensure_buses()
    var cfg := ConfigFile.new()
    if cfg.load(MIX_CONFIG) != OK:
        return
    for group in ["Master", "Music", "SFX", "Ambience", "Voice"]:
        if cfg.has_section_key("volume", group):
            _apply_volume(group, float(cfg.get_value("volume", group, 1.0)))

static func set_group_volume(group: String, normalized: float) -> void:
    ensure_buses()
    if not group in ["Master", "Music", "SFX", "Ambience", "Voice"]:
        return
    var level: float = clampf(normalized, 0.0, 1.0)
    _apply_volume(group, level)
    var cfg := ConfigFile.new()
    cfg.load(MIX_CONFIG)
    cfg.set_value("volume", group, level)
    cfg.save(MIX_CONFIG)

static func get_group_volume(group: String) -> float:
    var idx: int = AudioServer.get_bus_index(group)
    if idx < 0 or AudioServer.is_bus_mute(idx):
        return 0.0
    return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)

static func _apply_volume(group: String, level: float) -> void:
    var idx: int = AudioServer.get_bus_index(group)
    if idx < 0:
        return
    AudioServer.set_bus_mute(idx, level <= 0.0)
    AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(level, 0.001)))
