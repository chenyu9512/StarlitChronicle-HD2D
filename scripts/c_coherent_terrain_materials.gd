extends RefCounted
## Authoritative Main2 fallback for migrated third-party terrain families.
## The historical maps encode SEMANTIC ROLES as atlas rows (0..7). A random
## tile from a desert/roguelike sheet is not interchangeable with road/water.
## Rebuild fully opaque terrain materials and sparse transparent overlays using
## the color/grain of the uploaded pixels without changing any collision cells.
const TILE: int = 32
const GRID: int = 8
const ArtTheme = preload("res://scripts/c_art_theme_v2.gd")
static var _theme_revision: int = -1

static func supports(path: String) -> bool:
    if not path.begins_with("res://assets/art/"):
        return false
    var name: String = path.get_file()
    # Canonical V10 per-map source sheets have correct 8x8 dimensions but
    # are procedural color candidates, not yet organized by gameplay's
    # semantic sand/road/cliff rows. Re-atlas them without changing V3 tiles.
    if path.begins_with("res://assets/art/runtime/generated_gaps_v10/terrain__coast__"):
        return name.ends_with("_ground.png") or name.ends_with("_water.png")
    if path.contains("/tilesets/story_v1/") and name.ends_with("_decals.svg"):
        return true
    if path.contains("/tilesets/") and (name.ends_with("_ground.png") or name.ends_with("_water.png")):
        return true
    # The live V14 coastal water sprites are high-resolution source imagery,
    # not 8x8 ground atlases. Adapt the approved image and V18 water materials
    # into the exact 256px terrain atlas rather than stretching it directly.
    if path.contains("/runtime/act01_global_v14/surfaces/") and name.ends_with("_water.png"):
        return true
    if path.contains("/exteriors/coast_final_pass/"):
        return name in ["saltwind_route_tileset.svg", "tide_cavern_tileset.svg", "cavern_water_atlas.svg"] or name.ends_with("_detail_atlas.svg") or name.ends_with("_ground_glaze.svg") or name.ends_with("_road_material_8x8.svg")
    if path.contains("/interiors/") and name.ends_with("_tileset.svg"):
        return true
    return false

static func _overlay(path: String) -> bool:
    var name: String = path.get_file()
    return name.ends_with("_decals.svg") or name.ends_with("_detail_atlas.svg") or name.ends_with("_ground_glaze.svg") or name.ends_with("_road_material_8x8.svg")

static func _water(path: String) -> bool:
    return path.get_file().contains("water")

const HD2D_MATERIAL_ROOT: String="res://assets/art/runtime/generated_gaps_v10/"
static var _hd2d_cache: Dictionary={}

static func _real_material(path: String,row: int) -> Image:
    if _theme_revision != ArtTheme.revision():
        _hd2d_cache.clear()
        _theme_revision = ArtTheme.revision()
    var types: Array[String]=["beach-sand","town-grass","cliff-rock","cobbles",
        "harbor-ground","planks","cliff-rock","marsh"]
    if _water(path):
        types=["water-sea","water-shallow","water-sea","water-foam",
            "water-brine","water-shallow","water-sea","water-foam"]
    if not _water(path):
        if path.contains("forge") or path.contains("oldland") or path.contains("mirror") or path.contains("cavern"):
            types=["cliff-rock","cliff-rock","cobbles","cobbles","cliff-rock","planks","cliff-rock","marsh"]
        elif path.contains("city") or path.contains("sanctum"):
            types=["cobbles","cobbles","cliff-rock","cobbles","harbor-ground","planks","cliff-rock","marsh"]
        elif path.contains("isles"):
            types=["beach-sand","beach-sand","cliff-rock","cobbles","beach-sand","planks","cliff-rock","marsh"]
    var name: String=types[clampi(row,0,7)]
    if not _hd2d_cache.has(name):
        var file: String=HD2D_MATERIAL_ROOT+"material__coast__"+name.replace("-","_")+".png"
        if not ResourceLoader.exists(file):
            return null
        var texture: Texture2D=ArtTheme.texture("material.coast."+name)
        if texture==null:
            texture=load(file) as Texture2D
        if texture==null:
            return null
        var bitmap: Image=texture.get_image()
        if bitmap==null or bitmap.is_empty():
            return null
        if bitmap.get_format()!=Image.FORMAT_RGBA8:
            bitmap.convert(Image.FORMAT_RGBA8)
        _hd2d_cache[name]=bitmap
    return _hd2d_cache.get(name) as Image

static func _hash(x: int, y: int, seed: int) -> int:
    return ((x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)) & 0x7fffffff

static func _colors(path: String) -> Array[Color]:
    if _water(path):
        return [Color("326d7b"), Color("418492"), Color("4b929e"), Color("377887"),
            Color("2d6378"), Color("42828d"), Color("2d6171"), Color("387784")]
    if path.contains("forge") or path.contains("lava"):
        return [Color("66625c"), Color("736a59"), Color("554a47"), Color("8a6753"),
            Color("594e47"), Color("75655b"), Color("493d3e"), Color("6a5850")]
    if path.contains("oldland") or path.contains("mirror") or path.contains("cavern"):
        return [Color("777465"), Color("6f766d"), Color("545850"), Color("7c7567"),
            Color("777569"), Color("68695f"), Color("444a49"), Color("79796b")]
    if path.contains("oaths") or path.contains("sanctum"):
        return [Color("a0a38b"), Color("899a7a"), Color("777c72"), Color("877f6f"),
            Color("b0a58e"), Color("8c8a7b"), Color("61665d"), Color("aa9f86")]
    if path.contains("region_city"):
        return [Color("a39d83"), Color("929781"), Color("7c7d73"), Color("8e806e"),
            Color("aaa189"), Color("999486"), Color("706f6b"), Color("aaa18c")]
    if path.contains("isles"):
        return [Color("b7b095"), Color("9aab88"), Color("88867d"), Color("958473"),
            Color("c0b099"), Color("ab9e8d"), Color("736d65"), Color("b5ae94")]
    if path.contains("/interiors/"):
        return [Color("a69b84"), Color("a49b85"), Color("837b6f"), Color("887964"),
            Color("c0aa8e"), Color("a99883"), Color("5d564d"), Color("b2a28c")]
    # First-act morning village and white-sand harbour palette.
    return [Color("c1b093"), Color("a8b299"), Color("968c7a"), Color("94836e"),
        Color("c4b39a"), Color("a99c84"), Color("676257"), Color("bdac90")]

static func _overlay_texture(path: String) -> Texture2D:
    var img: Image = Image.create(TILE * GRID, TILE * GRID, false, Image.FORMAT_RGBA8)
    var shore: bool = path.contains("shore") or path.contains("coastal") or path.contains("harbor")
    for row in range(GRID):
        for col in range(GRID):
            var seed: int = 31 + row * 59 + col * 23
            for y in range(TILE):
                for x in range(TILE):
                    var h: int = _hash(x, y, seed) % 211
                    var put: bool = false
                    var c: Color = Color("8d8270", 0.23)
                    if shore and row == 4:
                        put = (y == 15 or y == 16) and x >= 3 and x < 28 and x % 4 != 0
                        c = Color("a4c0b1", 0.22)
                    elif row == 1:
                        put = h <= 2
                        c = Color("6b8069", 0.27)
                    elif row == 2:
                        put = h <= 3 and y % 3 == 0
                        c = Color("d9c6ad", 0.26)
                    elif row in [3, 6]:
                        put = h <= 3 and (y % 5 == 0 or x % 7 == 0)
                        c = Color("766d60", 0.22)
                    else:
                        put = h <= 1
                    if put:
                        img.set_pixel(col * TILE + x, row * TILE + y, c)
    return ImageTexture.create_from_image(img)

static func assemble(path: String, texture: Texture2D) -> Texture2D:
    if not supports(path) or texture == null:
        return texture
    if _overlay(path):
        return _overlay_texture(path)
    var source: Image = texture.get_image()
    if source == null or source.is_empty():
        return null
    if source.get_format() != Image.FORMAT_RGBA8:
        source.convert(Image.FORMAT_RGBA8)
    var width: int = source.get_width()
    var height: int = source.get_height()
    var palette: Array[Color] = _colors(path)
    var water: bool = _water(path)
    var atlas: Image = Image.create(TILE * GRID, TILE * GRID, false, Image.FORMAT_RGBA8)
    for row in range(GRID):
        var material: Image=_real_material(path,row)
        var base: Color = palette[row]
        for col in range(GRID):
            var salt: int = 71 + row * 137 + col * 19
            for y in range(TILE):
                for x in range(TILE):
                    var r: int = _hash(x, y, salt) % 101
                    var grain: float = float(r - 50) / 2500.0
                    # Actual imported art contributes subdued color grain.
                    # Ignore transparent or dark samples instead of turning
                    # map background cells black or transparent.
                    var pixel: Color = source.get_pixel((col * TILE + x) % width,
                        (row * TILE + y) % height)
                    if pixel.a > 0.95:
                        var luminance: float = (pixel.r + pixel.g + pixel.b) / 3.0
                        grain += (luminance - 0.5) * 0.028
                    var c: Color = base.lightened(grain) if grain >= 0 else base.darkened(-grain)
                    if water:
                        var wave: int = posmod(x + int(y / 8) * 5 + salt, 21)
                        if y % 8 == 2 and wave >= 2 and wave <= 9:
                            c = c.lerp(Color("77b0b2"), 0.40)
                        elif y % 8 == 3 and wave >= 3 and wave <= 8:
                            c = c.lerp(Color("77b0b2"), 0.18)
                    elif row == 3:
                        if y % 11 == 0 or (x + (int(y / 11) % 2) * 11) % 23 == 0:
                            c = c.darkened(0.15)
                        elif r % 17 == 0:
                            c = c.lightened(0.10)
                    elif row in [2, 6]:
                        if y % 13 == 0 or (x + (int(y / 13) % 2) * 13) % 28 == 0:
                            c = c.darkened(0.18)
                        elif r % 29 == 0:
                            c = c.lightened(0.10)
                    elif row == 1 and r % 37 == 0:
                        c = c.lerp(Color("637b65"), 0.32)
                    elif row == 5 and y % 16 == 0:
                        c = c.darkened(0.07)
                    elif r % 43 == 0:
                        c = c.lightened(0.08)
                    if material!=null and material.get_width()>80 and material.get_height()>80:
                        var mx: int=32+posmod(col*73+x*3+row*17,material.get_width()-64)
                        var my: int=32+posmod(row*67+y*3+col*19,material.get_height()-64)
                        var sample: Color=material.get_pixel(mx,my)
                        if sample.a>0.94:
                            c=c.lerp(sample,0.70 if path.contains("coast") or path.contains("cavern") or path.contains("saltwind") else 0.24)
                    # V18 cliff/cobbles photo textures have overlapping
                    # luminance. A cave corridor must remain visibly distinct
                    # from blocking rock even when both source photos are grey.
                    # Distinguish authored tile roles, never their collision.
                    if path.get_file() == "tide_cavern_tileset.svg" or path.contains("terrain__coast__map_4_"):
                        if row == 3: # Safe carved route, warm navigational tone.
                            c=c.lerp(Color("c8b593"),0.56)
                        elif row == 6: # Rough solid escarpment / blocked rim.
                            c=c.lerp(Color("46535f"),0.60)
                    c.a=1.0
                    atlas.set_pixel(col * TILE + x, row * TILE + y, c)
    return ImageTexture.create_from_image(atlas)
