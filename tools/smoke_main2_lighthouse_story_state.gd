extends SceneTree
## Visual outcome regression: no lighthouse completion light before the
## durable story flag, real glow after completion, stable across map builds.
const State = preload("res://scripts/first_act_state.gd")
const Registry = preload("res://scripts/world_registry.gd")
const World = preload("res://scripts/first_act_world.gd")
var failures: Array[String] = []

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var state := State.new()
    state.new_game()
    var router := Registry.new()
    router.bind(state)
    var world := World.new()
    world.map_profile = router.profile("map_coast_05")
    root.add_child(world)
    world.build(6,2)
    check(world.coastal_scene != null,"Lighthouse has no rendered coastal scene")
    if world.coastal_scene != null:
        var beam: PointLight2D = world.coastal_scene.lighthouse_beacon_light
        check(is_instance_valid(beam),"Missing physical lighthouse story beacon")
        if is_instance_valid(beam):
            world.set_lighthouse_rekindled(false)
            check(not beam.visible,"Uncompleted chapter lit the main lighthouse")
            world.set_lighthouse_rekindled(true)
            check(beam.visible,"Committed lighthouse state did not create a visible beacon")
            world.coastal_scene.set_clock(720)
            var day_energy: float = beam.energy
            world.coastal_scene.set_clock(1320)
            check(beam.visible and beam.energy > day_energy,
                "Rekindled lighthouse should be brighter at night")
            world.build(6,2)
            check(world.coastal_scene != null and world.coastal_scene.lighthouse_beacon_light != null,
                "Beacon lost after legitimate world map rebuild")
            if world.coastal_scene != null and world.coastal_scene.lighthouse_beacon_light != null:
                check(world.coastal_scene.lighthouse_beacon_light.visible,
                    "Saved lighthouse state not preserved during rebuild")
    world.queue_free()
    if failures.is_empty():
        print("PASS Main2 lighthouse: dark before save, light after story completion, night/day budget and rebuild")
        quit(0)
        return
    for err in failures:
        push_error(err)
    quit(1)
