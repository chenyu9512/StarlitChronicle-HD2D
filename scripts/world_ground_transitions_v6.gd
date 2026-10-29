extends Node2D
## Material-aware transition veil over an actual 32px TileMapLayer.
## This view-only component samples the active TileSet textures. It neither
## creates collision nor edits V3 tile coordinates, NPC positions or saves.
const TILE: int = 32
const PASS_COUNT: int = 3
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN]
var _seams: Array[Dictionary] = []
var _row_colors: Dictionary = {}
var _quality: int = 2

static func _key(source_id: int, atlas: Vector2i) -> String:
    return "%d:%d" % [source_id, atlas.y]

func _sample(tilemap: TileMapLayer, source_id: int, atlas: Vector2i) -> Color:
    var key: String = _key(source_id, atlas)
    if _row_colors.has(key):
        return _row_colors[key] as Color
    var source: TileSetAtlasSource = tilemap.tile_set.get_source(source_id) as TileSetAtlasSource
    if source == null or source.texture == null:
        _row_colors[key] = Color.TRANSPARENT
        return Color.TRANSPARENT
    var image: Image = source.texture.get_image()
    if image == null or image.is_empty():
        _row_colors[key] = Color.TRANSPARENT
        return Color.TRANSPARENT
    var base_x: int = clampi(atlas.x * TILE, 0, maxi(0, image.get_width()-TILE))
    var base_y: int = clampi(atlas.y * TILE, 0, maxi(0, image.get_height()-TILE))
    var color: Color = Color(0.0,0.0,0.0,0.0)
    for sy in [8,16,24]:
        for sx in [8,16,24]:
            color += image.get_pixel(base_x+sx,base_y+sy)
    color /= 9.0
    color.a = 1.0
    _row_colors[key] = color
    return color

func configure(tilemap: TileMapLayer, quality: int = 2) -> void:
    _quality = clampi(quality,0,2)
    _seams.clear()
    _row_colors.clear()
    if tilemap == null or tilemap.tile_set == null:
        queue_redraw()
        return
    for cell in tilemap.get_used_cells():
        var source_id: int = tilemap.get_cell_source_id(cell)
        if source_id < 0:
            continue
        var atlas: Vector2i = tilemap.get_cell_atlas_coords(cell)
        var color_a: Color = _sample(tilemap,source_id,atlas)
        if color_a.a < 0.01:
            continue
        for direction in DIRECTIONS:
            var adjacent: Vector2i = cell + direction
            var next_source: int = tilemap.get_cell_source_id(adjacent)
            if next_source < 0:
                continue
            var neighbor_atlas: Vector2i = tilemap.get_cell_atlas_coords(adjacent)
            # Ignore identical material families: slight column variations
            # within grass must not be mistaken for terrain boundaries.
            if _key(source_id,atlas) == _key(next_source,neighbor_atlas):
                continue
            var color_b: Color = _sample(tilemap,next_source,neighbor_atlas)
            if color_b.a < 0.01:
                continue
            var difference: float = absf(color_a.r-color_b.r) + absf(color_a.g-color_b.g) + absf(color_a.b-color_b.b)
            # Material identity still matters, but near-identical neighbors
            # need no contrasting transition stripe.
            if difference < 0.09 and source_id == next_source:
                continue
            _seams.append({"cell":cell,"direction":direction,"color_a":color_a,"color_b":color_b,
                "difference":difference})
    queue_redraw()

func set_visual_quality(value: int) -> void:
    _quality = clampi(value,0,2)
    queue_redraw()

func seam_count() -> int:
    return _seams.size()

func _draw() -> void:
    if _quality == 0:
        return
    # Paint both sides of every material boundary, falling off into their own
    # original textures. The deterministic eight-pixel subsegments prevent
    # long ruler-straight seams. Draw commands are static and collision-free.
    var passes: int = PASS_COUNT if _quality >= 2 else 2
    for seam in _seams:
        var cell: Vector2i = seam["cell"]
        var dir: Vector2i = seam["direction"]
        var a: Color = seam["color_a"]
        var b: Color = seam["color_b"]
        var contrast: float = clampf(float(seam["difference"]),0.22,1.0)
        var origin: Vector2 = Vector2(cell*TILE)
        var vertical: bool = dir == Vector2i.RIGHT
        var boundary: float = origin.x+TILE if vertical else origin.y+TILE
        for segment in range(4):
            var jitter: int = posmod(cell.x*13+cell.y*31+segment*17,3)-1
            for pass_index in range(passes):
                var thickness: float = 2.0 if pass_index < 2 else 3.0
                var reach: float = float(pass_index*3 + jitter)
                var strength: float = (0.34 if pass_index == 0 else (0.20 if pass_index == 1 else 0.09)) * clampf(contrast*1.1,0.55,1.0)
                var tint_b: Color = b
                var tint_a: Color = a
                tint_b.a = strength
                tint_a.a = strength
                var offset: float = float(segment*8)
                if vertical:
                    draw_rect(Rect2(boundary - reach - thickness,origin.y+offset,thickness,8.0),tint_b)
                    draw_rect(Rect2(boundary + reach,origin.y+offset,thickness,8.0),tint_a)
                else:
                    draw_rect(Rect2(origin.x+offset,boundary - reach - thickness,8.0,thickness),tint_b)
                    draw_rect(Rect2(origin.x+offset,boundary + reach,8.0,thickness),tint_a)
