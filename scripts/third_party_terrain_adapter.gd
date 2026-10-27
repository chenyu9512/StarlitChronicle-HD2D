extends RefCounted
## Main2 third-party atlas assembler: map existing 8x8 logical terrain slots to
## actual varied tiles from an imported sheet. Keeps V3 collision/grid intact.
## No deleted project-created PNG/SVG is loaded or recreated.
const TILE: int = 32
const GRID: int = 8
const WATER_SHEET: String = "res://assets/art/external/cc0_named_v1/tilesets/kenney_roguelike/spritesheet/tile_kenney_roguelike_roguelike_sheet_transparent.png"

static func supports(path: String) -> bool:
    if not path.begins_with("res://assets/art/"):
        return false
    if path.contains("/tilesets/story_v1/") and path.ends_with("_decals.svg"):
        return true
    if path.contains("/interiors/") and (path.ends_with("_tileset.svg") or path.ends_with("_tileset.png")):
        return true
    if path.contains("/tilesets/"):
        var filename: String = path.get_file()
        return filename.ends_with("_ground.png") or filename.ends_with("_water.png")
    return false

static func _tile_candidates(pixels: Image, edge: int) -> Array[Vector2i]:
    var options: Array[Vector2i] = []
    var cols: int = int(pixels.get_width() / edge)
    var rows: int = int(pixels.get_height() / edge)
    for y in range(rows):
        for x in range(cols):
            var origin: Vector2i = Vector2i(x*edge,y*edge)
            var present: int = 0
            for probe in [Vector2i(edge/4,edge/4),Vector2i(edge*3/4,edge/4),
                    Vector2i(edge/2,edge/2),Vector2i(edge/4,edge*3/4),Vector2i(edge*3/4,edge*3/4)]:
                if pixels.get_pixelv(origin+probe).a > 0.15:
                    present += 1
            if present >= 3:
                options.append(origin)
    return options

static func assemble(path: String, source_texture: Texture2D) -> Texture2D:
    if not supports(path) or source_texture==null:
        return source_texture
    var texture: Texture2D = source_texture
    if path.get_file().ends_with("_water.png") and ResourceLoader.exists(WATER_SHEET):
        texture=ResourceLoader.load(WATER_SHEET) as Texture2D
    if texture==null:
        return null
    var pixels: Image=texture.get_image()
    if pixels==null or pixels.is_empty():
        return null
    if pixels.get_format()!=Image.FORMAT_RGBA8:
        pixels.convert(Image.FORMAT_RGBA8)
    var edge: int = TILE if pixels.get_width()>=TILE and pixels.get_height()>=TILE else 16
    if pixels.get_width()<edge or pixels.get_height()<edge:
        return null
    var candidates: Array[Vector2i]=_tile_candidates(pixels,edge)
    if candidates.is_empty():
        return null
    var atlas: Image=Image.create(TILE*GRID,TILE*GRID,false,Image.FORMAT_RGBA8)
    # The prior implementation repeated the top-left 32px tile into all 64
    # slots, producing flat fake roads and identical biomes. Sample multiple
    # nonempty source tiles deterministically instead; keep each game's
    # authored 0..7 atlas coords, collision and 32px cell placement unchanged.
    for y in range(GRID):
        for x in range(GRID):
            var index: int = posmod(y*11+x*7+int(y*x/3),candidates.size())
            var chosen: Vector2i=candidates[index]
            var destination: Vector2i=Vector2i(x*TILE,y*TILE)
            if edge==TILE:
                atlas.blit_rect(pixels,Rect2i(chosen,Vector2i(edge,edge)),destination)
            else:
                var crop: Image=pixels.get_region(Rect2i(chosen,Vector2i(edge,edge)))
                crop.resize(TILE,TILE,Image.INTERPOLATE_NEAREST)
                atlas.blit_rect(crop,Rect2i(Vector2i.ZERO,Vector2i(TILE,TILE)),destination)
    return ImageTexture.create_from_image(atlas)

## Five region-local marks are assembled from real third-party source tiles.
## These are presentation-only; never change the 40-map collision/quest layer.
static func signature_strip(source_texture: Texture2D) -> Texture2D:
    if source_texture==null:
        return null
    var source: Image=source_texture.get_image()
    if source==null or source.is_empty():
        return null
    if source.get_format()!=Image.FORMAT_RGBA8:
        source.convert(Image.FORMAT_RGBA8)
    var edge: int=TILE if source.get_width()>=TILE and source.get_height()>=TILE else 16
    if source.get_width()<edge or source.get_height()<edge:
        return null
    var source_cells: Array[Vector2i]=_tile_candidates(source,edge)
    if source_cells.size()<2:
        return null
    var frame_count: int=5
    var frame_width: int=5*TILE
    var total_width: int=frame_count*frame_width
    var atlas: Image=Image.create(total_width,4*TILE,false,Image.FORMAT_RGBA8)
    for scene in range(frame_count):
        for row in range(4):
            for column in range(5):
                var sample_id: int=posmod(scene*37+column*11+row*17+scene*column*3,
                    source_cells.size())
                var part: Vector2i=source_cells[sample_id]
                var target: Vector2i=Vector2i(scene*frame_width+column*TILE,row*TILE)
                if edge==TILE:
                    atlas.blit_rect(source,Rect2i(part,Vector2i(edge,edge)),target)
                else:
                    var single: Image=source.get_region(Rect2i(part,Vector2i(edge,edge)))
                    single.resize(TILE,TILE,Image.INTERPOLATE_NEAREST)
                    atlas.blit_rect(single,Rect2i(Vector2i.ZERO,Vector2i(TILE,TILE)),target)
    return ImageTexture.create_from_image(atlas)
