extends SceneTree
## C-line integration smoke: event-ID expansion, missing audio fallback, cancelled fades.
## Run only in the agreed C batch; does not modify story, battles, saves, or public D APIs.
const Router = preload("res://scripts/av_event_router.gd")
const Registry = preload("res://scripts/av_asset_registry.gd")
const TownSoundscape = preload("res://scripts/c_town_soundscape.gd")
var failures: Array[String] = []
var audio_ids: Array[String] = []
var visual_ids: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, reason: String) -> void:
    if not condition:
        failures.append(reason)

func _on_audio(asset_id: String, _context: Dictionary) -> void:
    audio_ids.append(asset_id)

func _on_visual(asset_id: String, _context: Dictionary) -> void:
    visual_ids.append(asset_id)

func _run() -> void:
    var router := Router.new()
    root.add_child(router)
    router.audio_requested.connect(_on_audio)
    router.visual_requested.connect(_on_visual)
    check(router.dispatch("world.region_enter", {"region_id": "region_coast"}), "Region event not handled")
    check(audio_ids.size() == 1 and audio_ids.back() == "bgm.region.region_coast", "Region cue resolved using wrong context field")
    check(visual_ids.size() == 1 and visual_ids.back() == "fx.world.region_coast", "Region visual cue mismatch")
    check(Registry.audio_stream("bgm.region.region_coast") == null, "Unproduced BGM must remain silent")
    check(router.dispatch("combat.cast", {"skill_id": "skill_001"}), "Skill cue event not handled")
    check(visual_ids.back() == "fx.skill.skill_001", "Skill_ID expansion regressed")
    check(router.dispatch("story.mood", {"mood": "danger"}), "Story mood not handled")
    check(audio_ids.back() == "cue.story.danger", "Story mood cue mismatch")
    check(router.dispatch("world.ambient_changed", {"weather": "rain"}), "Weather cue not handled")
    check(audio_ids.back() == "ambience.rain", "Weather cue mismatch")
    var prior_count: int = audio_ids.size()
    check(router.dispatch("world.region_enter", {"region_id": "../unsafe"}), "Mapped unsafe event should still be handled")
    check(audio_ids.size() == prior_count, "Unsafe dynamic suffix produced an audio request")
    check(not router.dispatch("unknown.event"), "Unknown event unexpectedly handled")
    var sound := TownSoundscape.new()
    root.add_child(sound)
    sound.configure("map_coast_01", "inn", true)
    sound.configure("map_coast_01", "shop", true)
    sound.stop_scene(0.05)
    check(sound.active_key.is_empty(), "Stop did not clear active scene key")
    check(not sound.ambient_players[1 - sound.current_slot].playing, "Cancelled transition left a hidden source playing")
    sound.configure("map_coast_01", "smith", true)
    check(sound.active_key == "room:smith", "New scene did not recover from interrupted fade")
    check(not sound.ambient_players[1 - sound.current_slot].playing, "Scene restart left an old source playing")
    sound.play_foley("door_open")
    sound.stop_scene(0.05)
    check(not sound.cue_player.playing, "Scene stop left a one-shot cue playing")
    await create_timer(0.12).timeout
    for player in sound.ambient_players:
        check(not player.playing, "Ambient audio continued after stop fade")
    sound.queue_free()
    router.queue_free()
    if failures.is_empty():
        print("PASS C AV: region/music IDs, skill/mood/weather IDs, silent missing assets, no abandoned channels")
        quit(0)
    for failure in failures:
        push_error(failure)
    quit(1)
