extends SceneTree
## C line: visual-only door & room feedback, original synth soundscapes, fallback records.
const Structure = preload("res://scripts/world_structure.gd")
const Interior = preload("res://scripts/world_interior_art.gd")
const Soundscape = preload("res://scripts/c_town_soundscape.gd")
const FX = preload("res://scripts/c_interaction_fx.gd")
var issues: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, msg: String) -> void:
    if not ok:
        issues.append(msg)

func _run() -> void:
    var town := Node2D.new()
    root.add_child(town)
    var structure := Structure.new()
    town.add_child(structure)
    structure.setup("inn", "Sample inn", Vector2i(8, 6), "coastal", "map_coast_01")
    structure.play_door(true)
    check(structure.door_target == 1.0, "Door visual state missing")
    structure.set_reduced_motion(true)
    check(structure.reduced_motion, "Building low-motion mode missing")
    var sound := Soundscape.new()
    root.add_child(sound)
    sound.configure("map_coast_01", "inn", true)
    check(sound.active_key == "room:inn", "Interior soundscape key missing")
    check(sound.ambient_players[0].stream is AudioStreamWAV, "Original room tone not generated")
    sound.configure("map_coast_01", "shop", true)
    check(sound.active_key == "room:shop", "Crossfade did not change room profile")
    sound.play_foley("door_open")
    check(sound.cue_player.stream is AudioStreamWAV, "Original door foley missing")
    var fx := FX.new()
    root.add_child(fx)
    check(fx.trigger("chest_open", Vector2(22, 10)), "Chest overlay missing")
    check(not fx.trigger("unknown", Vector2.ZERO), "Unknown visual event accepted")
    var stage := Node2D.new()
    root.add_child(stage)
    var room := Interior.new()
    stage.add_child(room)
    var layout: Dictionary = {
        "art_profile":"coast_inn_v1", "map_id":"map_coast_01", "building_id":"inn",
        "visuals":[{"id":"test_lantern", "asset":"lantern", "cell":[5,4], "offset":[0, -32]}],
        "light_sources":[], "tiles":{}, "blocked":{}, "solid_regions":[]
    }
    room.install(stage, layout, 480)
    check(room.play_prop_action("test_lantern", "light"), "Live prop interaction pulse missing")
    check(not room.play_prop_action("missing", "open"), "Unbound prop event must fail safely")
    room.set_reduced_motion(true)
    check(room.reduced_motion, "Interior low-motion mode missing")
    if issues.is_empty():
        print("PASS C town: door state, interior art pulse, room crossfade, original foley, safe missing paths")
        quit(0)
    for reason in issues:
        push_error(reason)
    quit(1)
