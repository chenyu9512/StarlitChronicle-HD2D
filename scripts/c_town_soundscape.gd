extends Node
## C-line original procedural town/room soundscape. Production BGM/assets remain unmade.
## Reusable by D-line transition; no gameplay modifications or network dependency.
const AudioBusRuntime = preload("res://scripts/audio_bus_runtime.gd")
const AssetRegistry = preload("res://scripts/av_asset_registry.gd")
const SAMPLE_RATE: int = 11025
static var room_cache: Dictionary = {}
static var event_cache: Dictionary = {}
var ambient_players: Array[AudioStreamPlayer] = []
var cue_player: AudioStreamPlayer
var current_slot: int = 0
var active_key: String = ""
var transition: Tween
var reduced_audio: bool = false

func _ready() -> void:
    AudioBusRuntime.restore_mix()
    for i in range(2):
        var player := AudioStreamPlayer.new()
        player.name = "TownAmbient_%d" % i
        player.bus = "Ambience"
        player.volume_db = -60.0
        add_child(player)
        ambient_players.append(player)
    cue_player = AudioStreamPlayer.new()
    cue_player.name = "OriginalTownFoley"
    cue_player.bus = "SFX"
    cue_player.volume_db = -23.0
    add_child(cue_player)

func configure(map_id: String, location: String = "street", indoors: bool = false, seconds: float = 0.40) -> void:
    var region: String = "coast"
    for key in ["coast","oaths","forge","isles","mirror","oldland","sanctum","city"]:
        if map_id.contains(key):
            region = key
            break
    var category: String = location if indoors else region
    var key: String = ("room:" if indoors else "town:") + category
    if key == active_key or ambient_players.is_empty():
        return
    var id: String = "ambience." + (location if indoors else region)
    var authored: AudioStream = AssetRegistry.audio_stream(id)
    var stream: AudioStream = authored if authored != null else _original_loop(key)
    if transition != null and transition.is_running():
        transition.kill()
    if active_key.is_empty():
        ambient_players[0].stream = stream
        ambient_players[0].volume_db = -37.0 if indoors else -42.0
        ambient_players[0].play()
        current_slot = 0
    else:
        var old: AudioStreamPlayer = ambient_players[current_slot]
        var next_slot: int = 1 - current_slot
        var new_player: AudioStreamPlayer = ambient_players[next_slot]
        new_player.stop()
        new_player.stream = stream
        new_player.volume_db = -60.0
        new_player.play()
        transition = create_tween().set_parallel(true)
        transition.tween_property(old, "volume_db", -60.0, maxf(0.05, seconds))
        transition.tween_property(new_player, "volume_db", -37.0 if indoors else -42.0, maxf(0.05, seconds))
        transition.chain().tween_callback(func() -> void: old.stop())
        current_slot = next_slot
    active_key = key

func stop_scene(seconds: float = 0.25) -> void:
    if transition != null and transition.is_running():
        transition.kill()
    if ambient_players.is_empty():
        return
    var current: AudioStreamPlayer = ambient_players[current_slot]
    transition = create_tween()
    transition.tween_property(current, "volume_db", -60.0, maxf(0.05, seconds))
    transition.tween_callback(func() -> void: current.stop())
    active_key = ""

func play_foley(kind: String) -> void:
    if not is_instance_valid(cue_player):
        return
    var authored: AudioStream = AssetRegistry.audio_stream("sfx.town." + kind)
    cue_player.stop()
    cue_player.stream = authored if authored != null else make_foley(kind)
    cue_player.play()

static func _original_loop(key: String) -> AudioStreamWAV:
    if room_cache.has(key):
        return room_cache[key]
    var count: int = SAMPLE_RATE
    var buffer := PackedByteArray()
    buffer.resize(count * 2)
    var is_indoor: bool = key.begins_with("room:")
    var tone: float = 102.0
    if key.contains("forge") or key.contains("smith"):
        tone = 84.0
    elif key.contains("isles"):
        tone = 122.0
    elif key.contains("shrine"):
        tone = 164.0
    elif key.contains("shop"):
        tone = 140.0
    elif key.contains("inn"):
        tone = 110.0
    elif key.contains("mirror"):
        tone = 132.0
    var harmonic: int = maxi(1, roundi(tone))
    for i in range(count):
        var t: float = float(i) / float(SAMPLE_RATE)
        # Integer Hertz ensures a clean loop at one second.
        var wind: float = sin(TAU * 2.0 * t) * 0.38 + sin(TAU * 11.0 * t) * 0.20
        var detail: float = sin(TAU * float(harmonic) * t) * 0.10
        var surf: float = sin(TAU * 19.0 * t) * 0.15
        var value: float = (wind * (0.32 if is_indoor else 0.60) + detail + surf * (0.05 if is_indoor else 0.3))
        buffer.encode_s16(i * 2, clampi(roundi(value * 6500.0), -32767, 32767))
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = SAMPLE_RATE
    wav.stereo = false
    wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    wav.data = buffer
    room_cache[key] = wav
    return wav

static func make_foley(kind: String) -> AudioStreamWAV:
    if event_cache.has(kind):
        return event_cache[kind]
    var seconds: float = 0.17 if kind in ["door_open", "door_close", "chest_open"] else 0.11
    var count: int = maxi(1, roundi(seconds * float(SAMPLE_RATE)))
    var buffer := PackedByteArray()
    buffer.resize(count * 2)
    var base: float = 130.0 if kind.contains("door") else (255.0 if kind.contains("lantern") else 185.0)
    for i in range(count):
        var t: float = float(i) / float(SAMPLE_RATE)
        var p: float = float(i) / float(count)
        var grit: float = sin(t * 19377.0) * sin(t * 4830.0)
        var tone: float = sin(TAU * base * t) * 0.56
        var envelope: float = minf(1.0, p * 60.0) * pow(1.0 - p, 2.1)
        buffer.encode_s16(i * 2, clampi(roundi((grit * 0.43 + tone) * envelope * 10500.0), -32767, 32767))
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = SAMPLE_RATE
    wav.stereo = false
    wav.data = buffer
    event_cache[kind] = wav
    return wav
