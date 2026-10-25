extends SceneTree
## Headless integration: actor illustrations and nine-element skill staging.
const Actors = preload("res://scripts/battle_actors.gd")
const FX = preload("res://scripts/battle_fx.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool, details: String) -> void:
    if not ok:
        failures.append(details)

func _verify() -> void:
    var state = State.new()
    var canvas := Control.new()
    canvas.size = Vector2(1152,648)
    root.add_child(canvas)
    var actor_layer = Actors.new()
    actor_layer.size = canvas.size
    canvas.add_child(actor_layer)
    actor_layer.configure(state.actors)
    check(actor_layer.avatars.size() == 2,"Initial party must show two actor illustrations")
    var actor_id: String = "char_wayfarer"
    check(actor_layer.avatars.has(actor_id),"Lead actor was not staged")
    if actor_layer.avatars.has(actor_id):
        var entry: Dictionary = actor_layer.avatars[actor_id]
        var portrait: TextureRect = entry["node"]
        check(portrait.texture is Texture2D,"Existing art for the lead actor could not load")
        actor_layer.play_action(actor_id,"attack")
        actor_layer._process(0.10)
        check(portrait.position.x > float(entry["base"].x),"Attack did not move the actor toward target")
        actor_layer.play_action(actor_id,"skill")
        actor_layer._process(0.10)
        check(portrait.position.y < float(entry["base"].y),"Casting did not raise the actor")
        actor_layer.play_hit(actor_id,true)
        actor_layer._process(0.08)
        check(portrait.modulate.a < 0.8,"Fallen actor was not visually dimmed")
        actor_layer.reduced_motion = true
        actor_layer.play_hit(actor_id,false)
        actor_layer._process(0.08)
        check(portrait.position.distance_to(entry["base"]) < 0.01,"Reduced motion still moves actor")
    var fx = FX.new()
    fx.size = canvas.size
    canvas.add_child(fx)
    var elements: Dictionary = {
        "火":"flame","冰":"frost","雷":"lightning","水":"tide",
        "风":"gust","影":"shadow","自然":"leaf","圣":"halo","光":"star"
    }
    for element in elements.keys():
        fx.effects.clear()
        fx.play_skill(Vector2(300,330),Vector2(600,180),
            {"element":element,"job_id":"wayfarer","tier":7},34,true)
        var found: bool = false
        for effect in fx.effects:
            if str(effect.get("kind","")) == str(elements[element]):
                found = true
        check(found,"Missing elemental motif for %s" % element)
    canvas.queue_free()
    var core = RPG.new()
    core.bind(state)
    var battle = Battle.new()
    root.add_child(battle)
    battle.game_core = core
    battle.invincible = true
    battle.start(state,2,false)
    check(is_instance_valid(battle.actor_stage),"Active battle did not build actor stage")
    if is_instance_valid(battle.actor_stage):
        check(battle.actor_stage.avatars.size() >= 2,"Battle actor portraits unavailable")
    var first_index: int = battle.hero_turn
    var first_id: String = str(state.actors[first_index].get("id",""))
    battle._act("guard")
    if is_instance_valid(battle.actor_stage) and battle.actor_stage.avatars.has(first_id):
        check(str(battle.actor_stage.avatars[first_id].get("action","")) == "guard",
            "Guard command was not reflected in actor motion")
    battle.queue_free()
    if not failures.is_empty():
        for message in failures:
            push_error(message)
        quit(1)
        return
    print("PASS: actor image staging, movement, casting, hit/down, reduced motion, 9 elements, real battle wiring")
    quit(0)
