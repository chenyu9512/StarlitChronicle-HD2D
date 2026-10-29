extends Node2D
## Procedural C-line animated feedback: overlays only; never changes chest/inventory/quest state.
var kind: String = ""
var elapsed: float = 0.0
var duration: float = 0.4
var reduced_motion: bool = false
var active: bool = false

func trigger(event_kind: String, local_point: Vector2, low_motion: bool = false) -> bool:
    if event_kind not in ["door_open", "door_close", "chest_open", "lantern_on", "inspect"]:
        return false
    kind = event_kind
    position = local_point
    reduced_motion = low_motion
    elapsed = 0.0
    duration = 0.24 if low_motion else 0.43
    active = true
    set_process(true)
    queue_redraw()
    return true

func _process(delta: float) -> void:
    if not active:
        set_process(false)
        return
    elapsed += minf(delta, 0.1)
    if elapsed >= duration:
        active = false
        set_process(false)
    queue_redraw()

func _draw() -> void:
    if not active:
        return
    var p: float = clampf(elapsed / duration, 0.0, 1.0)
    var fade: float = 1.0 - p
    match kind:
        "door_open", "door_close":
            var open_amount: float = p if kind == "door_open" else 1.0 - p
            draw_rect(Rect2(-13, -28, 26, 28), Color(0.08, 0.10, 0.14, 0.30 * fade), true)
            draw_rect(Rect2(-12, -27, 23.0 * (1.0 - open_amount), 26), Color(0.42, 0.27, 0.18, 0.75 * fade), true)
        "chest_open":
            draw_rect(Rect2(-12, -9, 24, 12), Color(0.43, 0.27, 0.17, fade), true)
            draw_line(Vector2(-13, -10 - p * 10.0), Vector2(13, -10 - p * 10.0), Color(0.91, 0.76, 0.42, fade), 4.0)
        "lantern_on":
            draw_circle(Vector2.ZERO, 6.0 + p * 18.0, Color(1.0, 0.82, 0.44, 0.19 * fade))
            draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.94, 0.69, fade))
        "inspect":
            for idx in range(4):
                var angle: float = TAU * float(idx) / 4.0
                var direction: Vector2 = Vector2(cos(angle), sin(angle))
                draw_line(direction * (5.0 + p * 13.0), direction * (13.0 + p * 13.0), Color(0.85, 0.95, 1.0, fade), 2.0)
