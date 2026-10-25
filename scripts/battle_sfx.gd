extends Node
## Tiny cached procedural battle stingers; no licensed audio, no runtime downloads.
const SAMPLE_RATE: int = 22050
const CHANNELS: int = 3
var enabled: bool = true
var volume_db: float = -22.0
var players: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var cursor: int = 0

func _ready() -> void:
    for i in range(CHANNELS):
        var player := AudioStreamPlayer.new()
        player.bus = "Master"
        player.volume_db = volume_db
        add_child(player)
        players.append(player)

func play_event(kind: String, element: String = "") -> void:
    if not enabled or players.is_empty():
        return
    var key: String = kind + ":" + element
    if not clips.has(key):
        clips[key] = _synthesize(kind,element)
    var player: AudioStreamPlayer = players[cursor % players.size()]
    cursor += 1
    player.stop()
    player.volume_db = volume_db
    player.stream = clips[key]
    player.play()

func _synthesize(kind: String, element: String) -> AudioStreamWAV:
    var duration: float = 0.16
    var start_pitch: float = 390.0
    var end_pitch: float = 170.0
    var noise_mix: float = 0.18
    match kind:
        "attack": start_pitch=580.0; end_pitch=195.0; duration=0.16; noise_mix=0.32
        "hit": start_pitch=180.0; end_pitch=75.0; duration=0.20; noise_mix=0.34
        "enemy_hit": start_pitch=130.0; end_pitch=85.0; duration=0.22; noise_mix=0.38
        "cast": start_pitch=380.0; end_pitch=780.0; duration=0.31; noise_mix=0.08
        "heal": start_pitch=510.0; end_pitch=880.0; duration=0.32; noise_mix=0.03
        "guard": start_pitch=290.0; end_pitch=220.0; duration=0.24; noise_mix=0.12
        "charge": start_pitch=360.0; end_pitch=660.0; duration=0.29; noise_mix=0.05
        "phase": start_pitch=90.0; end_pitch=340.0; duration=0.48; noise_mix=0.30
        "victory": start_pitch=523.0; end_pitch=784.0; duration=0.42; noise_mix=0.04
    var note: Dictionary = {"火":1.12,"冰":1.25,"雷":1.43,"水":0.90,"风":1.07,"光":1.32,"影":0.72,"自然":0.96,"圣":1.50}
    var multiplier: float = float(note.get(element,1.0))
    var frames: int = maxi(1,roundi(float(SAMPLE_RATE)*duration))
    var pcm := PackedByteArray()
    pcm.resize(frames*2)
    var last_phase: float = 0.0
    for i in range(frames):
        var t: float = float(i)/float(SAMPLE_RATE)
        var progress: float = float(i)/float(frames)
        var frequency: float = lerpf(start_pitch,end_pitch,progress)*multiplier
        last_phase += TAU*frequency/float(SAMPLE_RATE)
        var body: float = sin(last_phase) + 0.20*sin(last_phase*1.96)
        var grit: float = sin(t*11289.0)*sin(t*3711.0)
        var envelope: float = minf(1.0,t*70.0)*pow(1.0-progress,1.8)
        var value: int = clampi(roundi((body+grit*noise_mix)*envelope*11000.0),-32767,32767)
        pcm.encode_s16(i*2,value)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = pcm
    return stream
