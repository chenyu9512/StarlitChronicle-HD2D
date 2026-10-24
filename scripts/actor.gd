extends Node2D
## One Y-sorted world actor with a 3-column × 4-direction sprite sheet.

var character_id := "hero"
var direction := 0 # down/right/up/left, atlas rows
var walk_timer := 0.0
var sprite: Sprite2D

func setup(id: String) -> void:
    character_id = id
    sprite = Sprite2D.new()
    sprite.texture = load("res://assets/characters/%s.png" % id)
    sprite.hframes = 3
    sprite.vframes = 4
    sprite.centered = true
    sprite.position = Vector2(0, -21)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite)
    _update_sprite(1)

func set_motion(delta: float, velocity: Vector2) -> void:
    if velocity.length_squared() < 0.02:
        walk_timer = 0.0
        _update_sprite(1)
        return
    if absf(velocity.x) > absf(velocity.y):
        direction = 1 if velocity.x > 0 else 3
    else:
        direction = 0 if velocity.y > 0 else 2
    walk_timer += delta * 7.0
    _update_sprite(int(walk_timer) % 3)

func _update_sprite(frame_column: int) -> void:
    if sprite != null:
        sprite.frame_coords = Vector2i(frame_column, direction)
