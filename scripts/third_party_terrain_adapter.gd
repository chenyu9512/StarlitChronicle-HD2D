extends RefCounted
## Compatibility-only: third-party tile source -> legacy 32px x 8x8 terrain atlas.
## Never uses removed original artwork, and does not change collision or map cells.
const TILE: int = 32
const GRID: int = 8
const WATER_SHEET: String = "res://assets/art/external/cc0_named_v1/tilesets/kenney_roguelike/spritesheet/tile_kenney_roguelike_roguelike_sheet_transparent.png"

static func supports(path: String) -> bool:
    if not path.begins_with("res://assets/art/tilesets/"):
        return false
    var name: String = path.get_file()
    return name.ends_with("_ground.png") or name.ends_with("_water.png")

static func assemble(path: String, source_texture: Texture2D) -> Texture2D:
    if not supports(path) or source_texture == null:
        return source_texture
    var texture: Texture2D = source_texture
    if path.get_file().ends_with("_water.png"):
        texture = ResourceLoader.load(WATER_SHEET) as Texture2D
    if texture == null:
        return null
    var pixels: Image = texture.get_image()
    if pixels == null or pixels.is_empty():
        return null
    if pixels.get_width() < TILE or pixels.get_height() < TILE:
        pixels.resize(maxi(TILE,pixels.get_width()),maxi(TILE,pixels.get_height()),Image.INTERPOLATE_NEAREST)
    if pixels.get_format() != Image.FORMAT_RGBA8:
        pixels.convert(Image.FORMAT_RGBA8)
    var atlas: Image = Image.create(TILE*GRID,TILE*GRID,false,Image.FORMAT_RGBA8)
    # Repeat one nonlegacy third-party tile into every logical slot so references
    # to existing terrain coords stay safe; final art still requires semantic remap.
    for y in range(GRID):
        for x in range(GRID):
            atlas.blit_rect(pixels,Rect2i(0,0,TILE,TILE),Vector2i(x*TILE,y*TILE))
    return ImageTexture.create_from_image(atlas)
