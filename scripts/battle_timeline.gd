extends Node
## Presentation-only timing; combat outcomes and turn order remain synchronous.
const MAX_PENDING: int = 48
var fx
var audio
var camera
var pending: Array[Dictionary] = []
var reduced_motion: bool = false

func bind_layers(effect_layer, audio_layer, camera_layer) -> void:
    fx = effect_layer
    audio = audio_layer
    camera = camera_layer
    set_process(true)

func queue_actor(kind: String, origin: Vector2, target: Vector2, damage: int, skill: Dictionary = {}, area: bool = false) -> void:
    if fx == null:
        return
    if not reduced_motion:
        fx.play_windup(origin,str(skill.get("element","")))
    var delay: float = 0.0 if reduced_motion else (0.20 if kind == "skill" else 0.12)
    _schedule(delay,{"kind":kind,"origin":origin,"target":target,"damage":damage,"skill":skill.duplicate(true),"area":area})

func queue_enemy(origin: Vector2, target: Vector2, damage: int) -> void:
    if fx == null:
        return
    if not reduced_motion:
        fx.play_windup(origin,"影")
    _schedule(0.0 if reduced_motion else 0.13,{"kind":"enemy","origin":origin,"target":target,"damage":damage})

func _schedule(delay: float, event: Dictionary) -> void:
    if pending.size() >= MAX_PENDING:
        pending.pop_front()
    event["remaining"] = delay
    if delay <= 0.0:
        _dispatch(event)
    else:
        pending.append(event)

func _process(delta: float) -> void:
    var step: float = clampf(delta,0.0,0.1)
    for i in range(pending.size() - 1,-1,-1):
        var event: Dictionary = pending[i]
        event["remaining"] = float(event["remaining"])-step
        if float(event["remaining"]) <= 0.0:
            pending.remove_at(i)
            _dispatch(event)
        else:
            pending[i] = event

func _dispatch(event: Dictionary) -> void:
    if not is_instance_valid(fx):
        return
    var kind: String = str(event.get("kind","attack"))
    var origin: Vector2 = event.get("origin",Vector2.ZERO)
    var target: Vector2 = event.get("target",Vector2.ZERO)
    var damage: int = int(event.get("damage",0))
    match kind:
        "skill":
            fx.play_skill(origin,target,event.get("skill",{}),damage,bool(event.get("area",false)))
        "special":
            fx.play_special(target,damage)
        "enemy":
            fx.play_enemy_attack(origin,target,damage)
        _:
            fx.play_attack(target,damage)
    fx.play_impact_feedback(0.35 if kind == "enemy" else (0.55 if kind == "skill" else 0.42))
    if is_instance_valid(camera):
        camera.impulse(5.0 if kind == "enemy" else 3.8)
    if is_instance_valid(audio):
        audio.play_event("enemy_hit" if kind == "enemy" else "hit")
