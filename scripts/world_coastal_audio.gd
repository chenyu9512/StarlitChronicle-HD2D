extends Node
const AudioBusRuntime = preload("res://scripts/audio_bus_runtime.gd")
const AVRegistry = preload("res://scripts/av_asset_registry.gd")
## A11: original, deterministic generated 16-bit coastal atmosphere.
## No external copyrighted music, engine-global bus edits or network services.
var player: AudioStreamPlayer
var environment_id: String = ""
var samples: int = 8000
var sample_rate: int = 8000

func configure(map_key: String,indoors: bool=false) -> void:
    environment_id=map_key
    if player != null and is_instance_valid(player):
        player.stop()
    if indoors or not map_key in ["map_coast_01","map_coast_02","map_coast_03","map_coast_04"]:
        return
    AudioBusRuntime.restore_mix()
    var authored: AudioStream = AVRegistry.audio_stream("ambience.waves")
    if authored != null:
        if player == null or not is_instance_valid(player):
            player = AudioStreamPlayer.new()
            player.name = "CoastalEnvironmentPlayer"
            add_child(player)
        player.bus = "Ambience"
        player.volume_db = -30.0
        player.stream = authored
        player.play()
        return
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = sample_rate
    wav.stereo = false
    wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    var content := PackedByteArray()
    content.resize(samples*2)
    var seed: int = {"map_coast_01":1,"map_coast_02":2,"map_coast_03":3,"map_coast_04":4}.get(map_key,1)
    for i in range(samples):
        var t: float=float(i)/float(sample_rate)
        # Periodic basis: no sharp discontinuity at the one-second seam.
        var sea: float=0.45*sin(TAU*t*2.0)+0.18*sin(TAU*t*7.0)
        var surf: float=0.16*sin(TAU*t*13.0)+0.09*sin(TAU*t*31.0)
        var tone: float = 0.0
        if seed==2:
            tone=0.18*sin(TAU*t*220.0)
        elif seed==3:
            tone=0.12*sin(TAU*t*176.0)
        elif seed==4:
            sea*=0.35
            surf*=0.3
            tone=0.27*sin(TAU*t*88.0)+0.11*sin(TAU*t*132.0)
        var env: float=0.76+0.22*sin(TAU*t)
        var value: int=clampi(int((sea+surf+tone)*env*6200.0),-32760,32760)
        content[i*2]=value&255
        content[i*2+1]=(value>>8)&255
    wav.data=content
    if player == null or not is_instance_valid(player):
        player = AudioStreamPlayer.new()
        player.name = "CoastalEnvironmentPlayer"
        add_child(player)
    player.bus = "Ambience"
    player.stream = wav
    player.volume_db = -30.0
    player.play()
