extends Node
## Subtle authored JRPG camera blocking. Restores camera state on scene exit.
var active: Tween
var watched: Camera2D
var initial_zoom: Vector2=Vector2.ONE
var initial_offset: Vector2=Vector2.ZERO

func shot(camera: Camera2D, world_point: Vector2, style: String = "focus") -> void:
    if not is_instance_valid(camera):
        return
    restore()
    watched=camera
    initial_zoom=camera.zoom
    initial_offset=camera.offset
    var target_offset: Vector2=world_point-camera.position
    target_offset=target_offset.limit_length(170.0)
    var target_zoom: Vector2=initial_zoom*(1.08 if style=="reveal" else 1.04)
    active=create_tween().set_parallel(true)
    active.tween_property(camera,"offset",target_offset,0.65).set_trans(Tween.TRANS_SINE)
    active.tween_property(camera,"zoom",target_zoom,0.65).set_trans(Tween.TRANS_SINE)

func restore() -> void:
    if active!=null and active.is_running():
        active.kill()
    if is_instance_valid(watched):
        watched.zoom=initial_zoom
        watched.offset=initial_offset
    watched=null

func battle_pulse(camera: Camera2D) -> void:
    if not is_instance_valid(camera):
        return
    restore()
    watched=camera
    initial_zoom=camera.zoom
    initial_offset=camera.offset
    active=create_tween()
    active.tween_property(camera,"zoom",initial_zoom*1.06,0.14)
    active.tween_property(camera,"zoom",initial_zoom,0.21)
    active.tween_callback(restore)
