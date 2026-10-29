extends Node
## Moves only gameplay scenery, never the command UI or hit-testing areas.
var targets: Array[Control] = []
var bases: Dictionary = {}
var shake_time: float = 0.0
var shake_strength: float = 0.0
var elapsed: float = 0.0
var reduced_motion: bool = false

func bind_targets(items: Array) -> void:
    _restore()
    targets.clear()
    bases.clear()
    for item in items:
        if item is Control and is_instance_valid(item):
            var node: Control = item
            targets.append(node)
            bases[node.get_instance_id()] = node.position
    set_process(true)

func impulse(strength: float = 4.0) -> void:
    if reduced_motion:
        return
    shake_time = maxf(shake_time,0.19)
    shake_strength = maxf(shake_strength,clampf(strength,0.0,9.0))

func _process(delta: float) -> void:
    var step: float = clampf(delta,0.0,0.1)
    elapsed += step
    shake_time = maxf(0.0,shake_time-step)
    var strength: float = shake_strength * clampf(shake_time/0.19,0.0,1.0)
    var displacement: Vector2 = Vector2(
        sin(elapsed*107.0)*strength,
        cos(elapsed*83.0)*strength*0.65)
    for target in targets:
        if is_instance_valid(target) and bases.has(target.get_instance_id()):
            target.position = Vector2(bases[target.get_instance_id()])+displacement
    if shake_time <= 0.0:
        shake_strength = 0.0

func _restore() -> void:
    for target in targets:
        if is_instance_valid(target) and bases.has(target.get_instance_id()):
            target.position = Vector2(bases[target.get_instance_id()])

func _exit_tree() -> void:
    _restore()
