extends Node
## Two genuinely compatible source-original three-frame idle sheets, copied by
## Git blob ID from .gdignore archives into exportable PNG runtime paths.
## Art selection is an explicit boss-ID match; never recycle across 66 bosses.
const Art = preload("res://scripts/c_art_overrides.gd")
const SELECTION: Dictionary = {
    "boss.ch017": {"path":"res://assets/art/runtime/imported/librarium/dynamo_3frame.png", "frame":Vector2i(95,107)},
    "boss.ch051": {"path":"res://assets/art/runtime/imported/librarium/skoll_3frame.png", "frame":Vector2i(48,48)}
}
var target: TextureRect
var atlas: AtlasTexture
var current_boss: String = ""
var frame_size: Vector2i = Vector2i.ZERO
var elapsed: float = 0.0
var frame: int = 0
var enabled: bool = false
var reduced_motion: bool = false

static func accepts(id: String) -> bool:
    return SELECTION.has(id)

func configure(view: TextureRect, details: Dictionary, reduce: bool = false) -> bool:
    enabled = false
    var id: String = str(details.get("boss_id", ""))
    if not SELECTION.has(id) or not is_instance_valid(view):
        return false
    var spec: Dictionary = SELECTION[id]
    var resource: String = str(spec["path"])
    var unit: Vector2i = spec["frame"]
    var texture: Texture2D = Art.texture(resource)
    if texture == null or Vector2i(texture.get_size()) != Vector2i(unit.x * 3, unit.y * 4):
        push_warning("Rejected incompatible three-frame boss sheet: " + resource)
        return false
    target = view
    current_boss = id
    frame_size = unit
    atlas = AtlasTexture.new()
    atlas.atlas = texture
    atlas.region = Rect2(0,0,unit.x,unit.y)
    target.texture = atlas
    target.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    elapsed = 0.0
    frame = 0
    reduced_motion = reduce
    enabled = true
    set_process(true)
    return true

func _process(delta: float) -> void:
    if not enabled or not is_instance_valid(target):
        return
    elapsed += clampf(delta,0.0,0.12)
    frame = 1 if reduced_motion else posmod(int(elapsed / 0.22),3)
    atlas.region = Rect2(frame * frame_size.x,0,frame_size.x,frame_size.y)
    if target.texture != atlas:
        target.texture = atlas
