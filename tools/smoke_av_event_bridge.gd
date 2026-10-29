extends SceneTree
## Execution belongs to the shared Godot integration QA batch.
const Router = preload("res://scripts/av_event_router.gd")
var received_audio: Array[String] = []
var received_visual: Array[String] = []
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var router := Router.new()
    get_root().add_child(router)
    router.audio_requested.connect(func(id: String, _ctx: Dictionary) -> void:
        received_audio.append(id)
    )
    router.visual_requested.connect(func(id: String, _ctx: Dictionary) -> void:
        received_visual.append(id)
    )
    if not router.dispatch("combat.attack"):
        failures.append("Combat event not accepted")
    if not router.dispatch("story.mood", {"mood":"mystery"}):
        failures.append("Story event not accepted")
    if not router.dispatch("world.region_enter", {"region_id":"region_coast"}):
        failures.append("Region event not accepted")
    if not router.dispatch("combat.cast", {"skill_id":"skill_wayfarer_01"}):
        failures.append("Skill event not accepted")
    if received_audio != ["sfx.combat.attack", "cue.story.mystery",
            "bgm.region.region_coast", "sfx.combat.cast"]:
        failures.append("Unexpected audio ID sequence: " + str(received_audio))
    if received_visual != ["fx.combat.slash", "fx.story.mystery",
            "fx.world.region_coast", "fx.skill.skill_wayfarer_01"]:
        failures.append("Unexpected visual ID sequence: " + str(received_visual))
    if router.dispatch("nonexistent.event"):
        failures.append("Unknown event must not dispatch")
    if failures.is_empty():
        print("PASS: A/B event envelopes expand to C audiovisual IDs")
        quit(0)
        return
    for reason in failures:
        push_error(reason)
    quit(1)
