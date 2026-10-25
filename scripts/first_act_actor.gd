extends Node2D
## 第一幕角色：正式 Batch-1 96×192 四方向行走图集。
var sprite: Sprite2D
var walk_clock: float = 0.0
var facing: int = 0  # down, left, up, right
var idle_elapsed: float = 0.0
var reacting: bool = false

func _draw() -> void:
    # Ground contact shadow underneath the untouched walking sprite.
    var ellipse:=PackedVector2Array()
    for i in range(16):
        var angle: float=TAU*float(i)/16.0
        ellipse.append(Vector2(cos(angle)*11.0,8.0+sin(angle)*4.0))
    draw_colored_polygon(ellipse,Color(0.02,0.08,0.11,0.28))

func setup(image: String) -> void:
    sprite = Sprite2D.new()
    sprite.texture = load(image)
    sprite.hframes = 3
    sprite.vframes = 4
    sprite.frame_coords = Vector2i(1, 0)
    sprite.position = Vector2(0, -19)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)

func set_motion(delta: float, velocity: Vector2) -> void:
    if sprite==null:
        return
    if velocity.length_squared() < 0.001:
        walk_clock = 0.0
        idle_elapsed+=delta
        sprite.frame_coords = Vector2i(1, facing)
        # Sprite pixels remain nearest-filtered. Only a subpixel silhouette
        # shift breathes during idle; original four-direction frames stay intact.
        if not reacting:
            sprite.position.y=-19.0+0.7*sin(idle_elapsed*2.15)
        return
    sprite.position.y=-19.0
    idle_elapsed=0.0
    if absf(velocity.x) > absf(velocity.y):
        facing = 3 if velocity.x > 0.0 else 1
    else:
        facing = 0 if velocity.y > 0.0 else 2
    walk_clock += delta * 8.0
    sprite.frame_coords = Vector2i(int(walk_clock) % 3, facing)

func react() -> void:
    if sprite==null or reacting:
        return
    reacting=true
    var pulse:=create_tween()
    pulse.tween_property(sprite,"scale",Vector2(1.08,0.94),0.08)
    pulse.tween_property(sprite,"scale",Vector2.ONE,0.14)
    pulse.finished.connect(func() -> void: reacting=false)
