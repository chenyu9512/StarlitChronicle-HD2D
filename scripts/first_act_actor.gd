extends Node2D
## 第一幕角色：正式 Batch-1 96×192 四方向行走图集。
var sprite: Sprite2D
var walk_clock: float = 0.0
var facing: int = 0  # down, left, up, right

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
    if velocity.length_squared() < 0.001:
        walk_clock = 0.0
        sprite.frame_coords = Vector2i(1, facing)
        return
    if absf(velocity.x) > absf(velocity.y):
        facing = 3 if velocity.x > 0.0 else 1
    else:
        facing = 0 if velocity.y > 0.0 else 2
    walk_clock += delta * 8.0
    sprite.frame_coords = Vector2i(int(walk_clock) % 3, facing)
