extends Node
const AVRegistry = preload("res://scripts/av_asset_registry.gd")
const AudioBusRuntime = preload("res://scripts/audio_bus_runtime.gd")
## Small original procedural leitmotifs and transition stingers.
## No external music licenses or network streams required.
var player: AudioStreamPlayer
var enabled: bool = true
var volume_db: float = -14.0
var transition: Tween

func _ready() -> void:
    AudioBusRuntime.restore_mix()
    player = AudioStreamPlayer.new()
    player.bus = "Music"
    player.volume_db=volume_db
    add_child(player)

func cue(mood: String) -> void:
    if not enabled or player==null:
        return
    _cancel_transition()
    var authored: AudioStream = AVRegistry.audio_stream("cue.story." + mood)
    if authored != null:
        player.stop()
        player.stream = authored
        player.volume_db = volume_db
        player.play()
        return
    var notes: Array[float] = []
    match mood:
        "danger": notes=[130.81,123.47,87.31,82.41]
        "grief": notes=[293.66,246.94,196.0,174.61]
        "mystery": notes=[220.0,329.63,293.66,261.63]
        "festival": notes=[392.0,440.0,523.25,659.25]
        "victory": notes=[392.0,493.88,587.33,783.99]
        "warm": notes=[261.63,329.63,392.0,329.63]
        _: notes=[293.66,392.0,440.0,587.33]
    var rate: int=22050
    var note_length: float=0.22
    var total: int=int(rate*note_length*float(notes.size()))
    var pcm := PackedByteArray()
    pcm.resize(total*2)
    for sample in range(total):
        var time_value: float=float(sample)/float(rate)
        var index: int=mini(notes.size()-1,int(time_value/note_length))
        var local: float=fmod(time_value,note_length)
        var envelope: float=minf(1.0,local*26.0)*minf(1.0,(note_length-local)*9.0)
        var freq: float=notes[index]
        var wave: float=sin(TAU*freq*time_value)+0.19*sin(TAU*freq*2.0*time_value)
        pcm.encode_s16(sample*2,clampi(roundi(wave*envelope*8200.0),-32767,32767))
    var stream := AudioStreamWAV.new()
    stream.format=AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate=rate
    stream.stereo=false
    stream.data=pcm
    player.stop()
    player.volume_db = volume_db
    player.stream=stream
    player.play()

## Use for shared integration later; missing media fades to silence (no crash).
func transition_to(audio_id: String, fade_seconds: float = 0.35) -> void:
    if player == null or not enabled:
        return
    _cancel_transition()
    var target: AudioStream = AVRegistry.audio_stream(audio_id)
    var half: float = maxf(0.01, fade_seconds * 0.5)
    transition = create_tween()
    transition.tween_property(player, "volume_db", -60.0, half)
    transition.tween_callback(func() -> void:
        if not is_instance_valid(player):
            return
        player.stop()
        player.stream = target
        if target != null:
            player.volume_db = -60.0
            player.play()
    )
    if target != null:
        transition.tween_property(player, "volume_db", volume_db, half)

func _cancel_transition() -> void:
    if transition != null and transition.is_running():
        transition.kill()

func stop() -> void:
    _cancel_transition()
    if player!=null:
        player.stop()
