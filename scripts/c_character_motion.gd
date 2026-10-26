extends RefCounted
## C-line 8-heading visual motion state. Existing collision/input and 4x3 art stay authoritative.
## Atlas uses four REAL directions; odd headings select a neighboring existing row.
const ROWS: Array[int] = [0, 1, 1, 2, 2, 3, 3, 0]
const LABELS: Array[String] = ["down", "down_left", "left", "up_left", "up", "up_right", "right", "down_right"]
var heading8: int = 0
var state: String = "idle"
var phase: float = 0.0
var move_blend: float = 0.0
var idle_time: float = 0.0
var turn_time: float = 0.0
var gesture_time: float = 0.0
var footfall_index: int = 0
var reduced_motion: bool = false

static func index_for(vector: Vector2) -> int:
    if vector.length_squared() < 0.0001:
        return 0
    return posmod(roundi(atan2(-vector.x, vector.y) / (PI / 4.0)), 8)

func atlas_row() -> int:
    return ROWS[heading8]

func facing_name() -> String:
    return LABELS[heading8]

func face_vector(vector: Vector2) -> void:
    if vector.length_squared() < 0.0001:
        return
    var target: int = index_for(vector)
    if target != heading8:
        heading8 = target
        turn_time = 0.16
        if move_blend < 0.1:
            state = "turn"

func start_talking(relative_target: Vector2) -> void:
    face_vector(relative_target)
    gesture_time = 0.28
    state = "talk"

func gesture() -> void:
    gesture_time = maxf(gesture_time, 0.22)
    state = "gesture"

func advance(delta: float, input_velocity: Vector2) -> void:
    var dt: float = clampf(delta, 0.0, 0.12)
    var is_moving: bool = input_velocity.length_squared() > 0.0025
    var previous: float = move_blend
    if is_moving:
        face_vector(input_velocity)
    move_blend = move_toward(move_blend, 1.0 if is_moving else 0.0, dt * (7.0 if is_moving else 10.0))
    idle_time += dt
    turn_time = maxf(0.0, turn_time - dt)
    gesture_time = maxf(0.0, gesture_time - dt)
    if is_moving:
        state = "start" if previous < 0.72 else "walk"
        phase += dt * (5.0 + move_blend * 3.0)
        footfall_index = floori(phase / 2.0)
        idle_time = 0.0
    elif gesture_time > 0.0:
        if state != "talk":
            state = "gesture"
    elif turn_time > 0.0:
        state = "turn"
    elif previous > 0.04:
        state = "stop"
    else:
        state = "idle"
    if state == "talk" and gesture_time <= 0.0:
        state = "idle"

func atlas_column() -> int:
    if move_blend < 0.12:
        return 1
    return posmod(floori(phase), 3)

func visual_offset() -> Vector2:
    if reduced_motion:
        return Vector2.ZERO
    var bob: float = 0.6 * sin(idle_time * 2.0) if move_blend < 0.12 else 0.45 * sin(phase * TAU / 3.0)
    var turn_shift: float = sin(PI * clampf(turn_time / 0.16, 0.0, 1.0)) * 1.4
    return Vector2(turn_shift * (-1.0 if heading8 in [1,2,3] else 1.0), bob)
