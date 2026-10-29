extends SceneTree
## Run only during scheduled 3-line Godot integration:
## godot --headless --path . --script res://tools/smoke_av_fallback.gd
const Registry = preload("res://scripts/av_asset_registry.gd")
const BusRuntime = preload("res://scripts/audio_bus_runtime.gd")
const SFX = preload("res://scripts/battle_sfx.gd")
const Cinema = preload("res://scripts/cinematic_audio.gd")
const Coast = preload("res://scripts/world_coastal_audio.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, msg: String) -> void:
    if not ok:
        failures.append(msg)

func _run() -> void:
    BusRuntime.ensure_buses()
    for group in ["Music", "SFX", "Ambience", "Voice"]:
        verify(AudioServer.get_bus_index(group) >= 0, "Missing audio bus: " + group)
    verify(Registry.audio_stream("bgm.battle") == null, "Missing BGM must stay silent")
    verify(Registry.audio_stream("sfx.ui.confirm") == null, "Unimported UI sound must stay silent")
    verify(Registry.bridge_audio_id("combat.attack") == "sfx.combat.attack", "Event bridge mismatch")
    verify(not Registry.boss_static_art("boss.ch002").is_empty(), "First act static boss render missing")
    var sfx := SFX.new()
    get_root().add_child(sfx)
    sfx.play_event("attack", "火")
    verify(sfx.players.size() == 3, "SFX channel count changed")
    verify(sfx.clips.has("attack:火"), "Procedural fallback not cached")
    verify(sfx.players[0].stream is AudioStreamWAV, "Fallback must be PCM")
    sfx.play_asset_id("sfx.ui.confirm")  # Must not attempt to load missing audio.
    var cinema := Cinema.new()
    get_root().add_child(cinema)
    cinema.cue("mystery")
    verify(cinema.player.stream is AudioStreamWAV, "Cinematic cue fallback missing")
    cinema.stop()
    var coast := Coast.new()
    get_root().add_child(coast)
    coast.configure("map_coast_01")
    var first_player: AudioStreamPlayer = coast.player
    verify(first_player != null and first_player.stream != null, "Coast fallback missing")
    coast.configure("map_coast_01", true)
    verify(not first_player.playing, "Indoor entry must stop coastal audio")
    coast.configure("map_coast_02")
    verify(coast.player == first_player, "Coastal audio player leaked on reconfiguration")
    coast.configure("map_city_01")
    verify(not first_player.playing, "Region exit must stop coastal audio")
    sfx.queue_free()
    cinema.queue_free()
    coast.queue_free()
    if failures.is_empty():
        print("PASS: AV ID routes, bus creation, procedural fallbacks and coastal lifecycle")
        quit(0)
        return
    for reason in failures:
        push_error(reason)
    quit(1)
