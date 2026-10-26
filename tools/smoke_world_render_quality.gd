extends SceneTree
## Three visual budgets must affect actual running scenes without touching
## weather identity, authored collisions, story flags, or save data.
const State = preload("res://scripts/first_act_state.gd")
const World = preload("res://scripts/first_act_world.gd")
const Registry = preload("res://scripts/world_registry.gd")
var failures: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failures.append(reason)

func _run() -> void:
    var state=State.new()
    state.new_game()
    var router=Registry.new()
    router.bind(state)
    var world=World.new()
    world.map_profile=router.profile("map_coast_01")
    root.add_child(world)
    var flags_before: Dictionary=state.flags.duplicate(true)
    var gold_before: int=state.gold
    world.set_visual_quality(0)
    world.build(1,2)
    check(world.visual_quality==0,"Low quality not stored by world")
    check(world.ambience!=null and world.ambience.visual_quality==0,
        "Low quality not applied to weather")
    var current_weather: String=str(world.ambience.weather)
    if world.coastal_scene!=null:
        for wave in world.coastal_scene.tidal_sprites:
            check(not wave.visible,"Low quality retained animated shore wave")
        for reflection in world.coastal_scene.reflections:
            check(not reflection.visible,"Low quality retained water reflection")
    world.set_visual_quality(2)
    check(world.ambience.visual_quality==2,"High quality failed to update weather")
    check(str(world.ambience.weather)==current_weather,
        "Graphics setting illegally changed actual weather")
    if world.coastal_scene!=null:
        for reflection in world.coastal_scene.reflections:
            check(reflection.visible,"High quality failed to restore reflection")
    world.set_visual_quality(0)
    check(world.enter_building("inn"),"Failed to enter actual inn")
    check(world.interior_art!=null,"V4 interior has no live art stage")
    if world.interior_art!=null:
        check(world.interior_art.visual_quality==0,"Indoor settings lost on map load")
        var low_lights: int=0
        for lamp in world.interior_art.active_lights:
            if lamp.visible:
                low_lights+=1
            check(not lamp.shadow_enabled,"Low quality cast an expensive indoor shadow")
        check(low_lights<=1,"Low quality exceeded one indoor light")
        world.set_visual_quality(2)
        var high_lights: int=0
        var shadow_count: int=0
        for lamp in world.interior_art.active_lights:
            if lamp.visible:
                high_lights+=1
            if lamp.shadow_enabled:
                shadow_count+=1
        check(high_lights>=low_lights,"High quality lost indoor lights")
        check(shadow_count<=2,"Too many indoor real-time shadow casters")
    check(world.leave_building(),"Failed to restore coast exterior")
    check(world.ambience.visual_quality==2,"High quality not restored outdoors")
    check(state.flags==flags_before and state.gold==gold_before,
        "Graphics settings altered story state or player economy")
    if failures.is_empty():
        print("PASS visual quality: low/high maps, water, weather and indoor shadow budgets; no gameplay mutation")
        quit(0)
        return
    for issue in failures:
        push_error(issue)
    quit(1)
