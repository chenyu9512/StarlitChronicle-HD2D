extends RefCounted
## Main2 visual-repair terrain assembler. Reconstruct the game's 8x8 logical
## 32px atlas from material ROLES, not arbitrary cells in unrelated art packs.
## Keeps existing TileMapLayer coordinates/collision/source IDs unchanged.
## Uses the later-uploaded source palette texture as restrained grain only:
## transparent pixels can NEVER leave world-map holes.
const TILE: int = 32
const GRID: int = 8
const WATER_SHEET: String = "res://assets/art/external/cc0_named_v1/tilesets/kenney_roguelike/spritesheet/tile_kenney_roguelike_roguelike_sheet_transparent.png"

static func supports(path: String) -> bool:
    if path.begins_with("res://assets/art/tilesets/"):
        var filename: String = path.get_file()
        return filename.ends_with("_ground.png") or filename.ends_with("_water.png")
    if path.begins_with("res://assets/art/exteriors/coast_final_pass/"):
        return path.get_file() in ["saltwind_route_tileset.svg", "tide_cavern_tileset.svg", "cavern_water_atlas.svg"]
    if path.begins_with("res://assets/art/interiors/"):
        return path.get_file().ends_with("_tileset.svg")
    return false

static func _water(path: String) -> bool:
    return path.get_file().contains("water")

static func _material(path: String) -> String:
    if path.contains("region_forge") or path.contains("lava"):
        return "forge"
    if path.contains("region_oldland") or path.contains("region_mirror") or path.contains("tide_cavern"):
        return "cavern"
    if path.contains("region_oaths") or path.contains("region_sanctum"):
        return "highland"
    if path.contains("region_city"):
        return "town"
    if path.contains("region_isles"):
        return "isles"
    if path.contains("region_mirror"):
        return "mystic"
    if path.contains("interiors/") or path.contains("inn_tileset"):
        return "interior"
    return "coast"

static func _colors(path: String) -> Array[Color]:
    if _water(path):
        return [Color("326d7b"), Color("418492"), Color("4b929e"),
            Color("377887"), Color("2d6378"), Color("42828d"),
            Color("2d6171"), Color("387784")]
    match _material(path):
        "forge":
            return [Color("66625c"), Color("736a59"), Color("554a47"),
                Color("8a6753"), Color("594e47"), Color("75655b"),
                Color("493d3e"), Color("6a5850")]
        "cavern":
            return [Color("777465"), Color("6f766d"), Color("545850"),
                Color("827b6d"), Color("777569"), Color("68695f"),
                Color("444a49"), Color("79796b")]
        "highland":
            return [Color("a0a38b"), Color("899a7a"), Color("777c72"),
                Color("a49c87"), Color("b0a58e"), Color("8c8a7b"),
                Color("61665d"), Color("aa9f86")]
        "town":
            return [Color("a39d83"), Color("929781"), Color("7c7d73"),
                Color("ac9b82"), Color("aaa189"), Color("999486"),
                Color("706f6b"), Color("aaa18c")]
        "isles":
            return [Color("b7b095"), Color("9aab88"), Color("88867d"),
                Color("aea18d"), Color("c0b099"), Color("ab9e8d"),
                Color("736d65"), Color("b5ae94")]
        "interior":
            return [Color("a69b84"), Color("a49b85"), Color("837b6f"),
                Color("a99883"), Color("c0aa8e"), Color("a99883"),
                Color("5d564d"), Color("b2a28c")]
        _:
            return [Color("c1b093"), Color("a8b299"), Color("968c7a"),
                Color("b7a58d"), Color("c4b39a"), Color("a99c84"),
                Color("676257"), Color("bdac90")]

static func _hash(x: int, y: int, salt: int) -> int:
    return ((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0x7fffffff

static func assemble(path: String, source_texture: Texture2D) -> Texture2D:
    if not supports(path) or source_texture == null:
        return source_texture
    var sample: Image = source_texture.get_image()
    if sample == null or sample.is_empty():
        return null
    if sample.get_format() != Image.FORMAT_RGBA8:
        sample.convert(Image.FORMAT_RGBA8)
    var atlas: Image = Image.create(TILE * GRID, TILE * GRID, false, Image.FORMAT_RGBA8)
    var colors: Array[Color] = _colors(path)
    var is_water: bool = _water(path)
    var sw: int = sample.get_width()
    var sh: int = sample.get_height()
    # Stable palettes make connected road cells read as continuous materials;
    # legacy x/y is only a tiny grain variation, never a foreign atlas UV.
    for row in range(GRID):
        var base: Color = colors[row]
        for column in range(GRID):
            var salt: int = 70 + row * 137 + column * 19
            var top: int = row * TILE
            var left: int = column * TILE
            for y in range(TILE):
                for x in range(TILE):
                    var r: int = _hash(x, y, salt) % 101
                    var grain: float = float(r - 50) / 2400.0
                    # Subtle real source noise, capped so the user-uploaded
                    # sheet cannot turn houses/stone/water into random tiles.
                    var source_pixel: Color = sample.get_pixel((left + x) % sw, (top + y) % sh)
                    if source_pixel.a > 0.95:
                        var light: float = (source_pixel.r + source_pixel.g + source_pixel.b) / 3.0
                        grain += (light - 0.5) * 0.045
                    var c: Color = base.lightened(grain) if grain >= 0.0 else base.darkened(-grain)
                    if is_water:
                        # Connected bands of water, not transparent PNG holes.
                        var wave: int = posmod(x + (y / 8) * 5 + salt, 21)
                        if y % 8 == 2 and wave >= 2 and wave <= 9:
                            c = c.lerp(Color("77b0b2"), 0.42)
                        elif y % 8 == 3 and wave >= 3 and wave <= 8:
                            c = c.lerp(Color("77b0b2"), 0.20)
                    elif row == 3:
                        # Walkable road: same joint pattern on every tile, with
                        # a warm cobblestone palette instead of a sheet fragment.
                        var joint: bool = y % 11 == 0 or (x + (y / 11 % 2) * 11) % 23 == 0
                        if joint:
                            c = c.darkened(0.15)
                        elif r % 17 == 0:
                            c = c.lightened(0.10)
                    elif row in [2, 6]:
                        # Stone wall / cliff: mark fracture joints but NEVER
                        # render arbitrary black or transparent cells.
                        if y % 13 == 0 or (x + (y / 13 % 2) * 13) % 28 == 0:
                            c = c.darkened(0.19)
                        elif r % 29 == 0:
                            c = c.lightened(0.11)
                    elif row == 1:
                        if r % 37 == 0:
                            c = c.lerp(Color("637b65"), 0.34)
                    elif row == 5:
                        if y % 16 == 0:
                            c = c.darkened(0.07)
                    elif r % 43 == 0:
                        c = c.lightened(0.09)
                    c.a = 1.0
                    atlas.set_pixel(left + x, top + y, c)
    return ImageTexture.create_from_image(atlas)
