extends Node2D
## P5 cinematic blocking in the actual game world; presentation-only.
## Deterministic seek() supports frame-by-frame GPU evidence.
const Actor = preload("res://scripts/first_act_actor.gd")
const Art = preload("res://scripts/c_art_overrides.gd")
var hero: Node2D
var cast: Dictionary = {}
var phase: String = "normal"
var elapsed: float = 0.0
var manual_clock: bool = false

func bind_hero(value: Node2D) -> void:
    hero = value
    for who in ["chengzhou", "lanyin"]:
        var path: String = "res://assets/art/characters/%s/walk_4dir_3frames.png" % who
        if Art.texture(path) == null:
            push_warning("Missing blocking actor: " + path)
            continue
        var performer = Actor.new()
        performer.name = "P5_" + who
        performer.setup(path)
        performer.z_index = 5
        add_child(performer)
        cast[who] = performer
    apply("normal")

func apply(next_phase: String) -> void:
    phase = next_phase
    elapsed = 0.0
    manual_clock = false
    visible = phase in ["falling", "fallen", "forgotten", "ten_years"]
    set_process(visible)
    _pose()

func seek(seconds: float) -> void:
    manual_clock = true
    elapsed = maxf(0.0, seconds)
    _pose()

func resume() -> void:
    manual_clock = false

func _process(delta: float) -> void:
    if not manual_clock:
        elapsed += minf(delta, 0.1)
        _pose()

func _pose() -> void:
    if not is_instance_valid(hero):
        return
    global_position = hero.global_position
    for performer in cast.values():
        performer.visible = false
    if not visible:
        return
    var cheng = cast.get("chengzhou")
    var lan = cast.get("lanyin")
    match phase:
        "falling":
            # Chengzhou crosses between the falling star and the other two.
            if cheng != null:
                cheng.visible = true
                var t: float = smoothstep(0.0, 1.8, elapsed)
                cheng.position = Vector2(-115.0, -15.0).lerp(Vector2(8.0, -78.0), t)
                cheng.set_motion(0.083, Vector2(1,-1) if t<1.0 else Vector2.ZERO)
            if lan != null:
                lan.visible = true
                lan.position = Vector2(-48, 23).lerp(Vector2(43, 39), smoothstep(0.9, 3.3, elapsed))
                lan.set_motion(0.083, Vector2(1,0) if elapsed<3.3 else Vector2.ZERO)
        "fallen":
            # An explicit separation: Chengzhou holds the rear, Lanyin exits.
            if cheng != null:
                cheng.visible = elapsed<3.8
                cheng.position = Vector2(12,-78)
                cheng.set_motion(0.083, Vector2(0,-1) if elapsed<3.8 else Vector2.ZERO)
            if lan != null:
                lan.visible = true
                lan.position = Vector2(42,34).lerp(Vector2(160,126), smoothstep(0.5,4.0,elapsed))
                lan.set_motion(0.083, Vector2(1,1) if elapsed<4.0 else Vector2.ZERO)
        "forgotten":
            if lan != null:
                lan.visible = true
                lan.position = Vector2(-50,20)
                lan.set_motion(0.083, Vector2.ZERO)
        "ten_years":
            if lan != null:
                lan.visible = true
                lan.position = Vector2(-50,20)
                lan.set_motion(0.083, Vector2.ZERO)
