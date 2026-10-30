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
    # Feather the *actual* material boundary with an irregular contour,
    # not ruler-straight horizontal/vertical lines. The underlying TileSet,
    # its collision and all path coordinates remain the sole gameplay truth.
    # Each boundary is emitted exactly once (RIGHT and DOWN neighbors only).
    var passes: int = PASS_COUNT if _quality >= 2 else 2
    for seam in _seams:
        var cell: Vector2i = seam["cell"]
        var direction: Vector2i = seam["direction"]
        var neighbor_a: Color = seam["color_a"]
        var neighbor_b: Color = seam["color_b"]
        var contrast: float = clampf(float(seam["difference"]),0.20,1.0)
        var normal: Vector2 = Vector2.RIGHT if direction == Vector2i.RIGHT else Vector2.DOWN
        var tangent: Vector2 = Vector2.DOWN if direction == Vector2i.RIGHT else Vector2.RIGHT
        var origin: Vector2 = Vector2(cell*TILE) + normal*float(TILE)
        var influence: float = clampf(contrast*1.2,0.45,1.0)
        for segment in range(4):
            var start: Vector2 = origin + tangent*float(segment*8)
            var finish: Vector2 = start + tangent*8.0
            # Neighbouring 8px strokes share their boundary endpoints. The
            # 3px noise variation breaks up square silhouette seams.
            var hash0: int = posmod(cell.x*31+cell.y*17+segment*19,7)-3
            var hash1: int = posmod(cell.x*31+cell.y*17+(segment+1)*19,7)-3
            var mid0: Vector2 = start + normal*float(hash0)
            var mid1: Vector2 = finish + normal*float(hash1)
            for band in range(passes):
                var reach: float = 10.0 if band==0 else (6.0 if band==1 else 3.0)
                var opacity: float = (0.10 if band==0 else (0.16 if band==1 else 0.26))*influence
                var blend_b: Color = neighbor_b
                var blend_a: Color = neighbor_a
                blend_b.a = opacity
                blend_a.a = opacity
                # Two interlocking tapered masks hide the original square
                # boundary while respecting the authored map footprint.
                var inside: PackedVector2Array = PackedVector2Array([
                    start-normal*reach, finish-normal*reach, mid1, mid0])
                var outside: PackedVector2Array = PackedVector2Array([
                    mid0, mid1, finish+normal*reach, start+normal*reach])
                draw_colored_polygon(inside,blend_b)
                draw_colored_polygon(outside,blend_a)
