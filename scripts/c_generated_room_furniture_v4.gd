extends RefCounted
## Runtime 2D furniture silhouettes, built for the 12 legacy coastal rooms.
## Separate semantically correct icons; never map a bed or an altar to a crate.
## These are provisional generated art, NOT a hand-painted visual approval.
static var _textures: Dictionary = {}

## Finishing pass for the existing per-role furnishings: subdued bevel highlights
## and sparse woodgrain make the different 64px assets share one HD2D lighting
## language without changing their occupancy, quest IDs or actor hit boxes.
static func _finish_surface(image: Image, kind: String) -> void:
    var source: Image = image.duplicate() as Image
    var oak: Color = Color("71503e")
    var light: Color = Color("be9166")
    for y in range(5, 59):
        for x in range(5, 59):
            var sample: Color = source.get_pixel(x, y)
            if sample.a < 0.95:
                continue
            var upper: Color = source.get_pixel(x, y - 1)
            var lower: Color = source.get_pixel(x, y + 1)
            if upper.a < 0.35:
                image.set_pixel(x, y, sample.lightened(0.15))
            elif lower.a < 0.35:
                image.set_pixel(x, y, sample.darkened(0.14))
            elif (sample.is_equal_approx(oak) or sample.is_equal_approx(light)) and posmod(x * 11 + y * 7 + kind.hash(), 29) == 0:
                image.set_pixel(x, y, sample.lightened(0.12))

static func texture(kind: String) -> Texture2D:
    if _textures.has(kind):
        return _textures[kind] as Texture2D
    var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    var oak: Color = Color("71503e")
    var light: Color = Color("be9166")
    var dark: Color = Color("382d35")
    var sea: Color = Color("3e7784")
    var gold: Color = Color("e4bc77")
    # World foot contact at image centre; shadow belongs to the prop only.
    image.fill_rect(Rect2i(9, 53, 46, 5), Color(0.09,0.10,0.14,0.24))
    match kind:
        "counter", "merchant_counter", "provisions_shelves":
            image.fill_rect(Rect2i(7, 20, 50, 32), oak)
            image.fill_rect(Rect2i(4, 16, 56, 11), light)
            image.fill_rect(Rect2i(11, 31, 42, 2), gold.darkened(0.25))
            if kind == "provisions_shelves":
                for x in [13, 27, 41]:
                    image.fill_rect(Rect2i(x, 8, 9, 11), Color("a97e50"))
                    image.fill_rect(Rect2i(x+2, 11, 5, 6), gold)
        "bed", "harbor_guest_bed":
            image.fill_rect(Rect2i(7, 21, 50, 33), oak)
            image.fill_rect(Rect2i(10, 18, 44, 31), sea.lightened(0.17))
            image.fill_rect(Rect2i(13, 21, 38, 10), Color("e6dbba"))
            image.fill_rect(Rect2i(10, 46, 44, 5), gold.darkened(0.24))
        "table":
            image.fill_rect(Rect2i(15, 31, 7, 22), dark)
            image.fill_rect(Rect2i(43, 31, 7, 22), dark)
            image.fill_rect(Rect2i(7, 22, 50, 18), oak)
            image.fill_rect(Rect2i(10, 18, 44, 8), light)
            image.fill_rect(Rect2i(15, 20, 35, 2), gold.darkened(0.28))
        "bookshelf", "travelers_shelf", "home_hutch":
            image.fill_rect(Rect2i(8, 8, 48, 46), oak)
            for y in [17, 30, 43]:
                image.fill_rect(Rect2i(11, y, 42, 4), light)
                for x in [14, 21, 29, 37, 45]:
                    image.fill_rect(Rect2i(x, y-9, 4, 9), [gold,sea,Color("ad6b68")][(x+y)%3])
            image.fill_rect(Rect2i(6, 6, 5, 47), dark)
            image.fill_rect(Rect2i(53, 6, 5, 47), dark)
        "fireplace", "smith_forge":
            image.fill_rect(Rect2i(7, 19, 50, 37), Color("5e5656"))
            image.fill_rect(Rect2i(14, 24, 36, 31), dark)
            image.fill_rect(Rect2i(20, 35, 24, 16), Color("a85032"))
            image.fill_rect(Rect2i(25, 26, 15, 24), Color("f3af58"))
            image.fill_rect(Rect2i(29, 33, 7, 14), Color("fff3ae"))
            image.fill_rect(Rect2i(7, 15, 50, 8), light)
        "window", "curtain", "window_sunshafts":
            image.fill_rect(Rect2i(14, 7, 36, 48), oak)
            image.fill_rect(Rect2i(19, 12, 26, 37), Color("8cb6ad"))
            image.fill_rect(Rect2i(30, 12, 4, 37), light)
            image.fill_rect(Rect2i(19, 29, 26, 4), light)
            if kind == "curtain":
                image.fill_rect(Rect2i(11, 9, 8, 39), Color("b66e61"))
                image.fill_rect(Rect2i(45, 9, 8, 39), Color("b66e61"))
        "rug", "shrine_starseal", "guild_emblem":
            image.fill_rect(Rect2i(7, 20, 50, 28), dark)
            image.fill_rect(Rect2i(10, 23, 44, 22), sea)
            image.fill_rect(Rect2i(24, 26, 16, 16), gold.darkened(0.12))
            image.fill_rect(Rect2i(27, 29, 10, 10), dark)
        "barrels", "bread_basket":
            for x in [7, 30]:
                image.fill_rect(Rect2i(x+3, 24, 20, 29), oak)
                image.fill_rect(Rect2i(x+2, 19, 22, 9), light)
                image.fill_rect(Rect2i(x+3, 38, 20, 4), dark)
        "lantern", "shrine_incense":
            image.fill_rect(Rect2i(29, 9, 6, 45), oak)
            image.fill_rect(Rect2i(19, 20, 26, 22), gold)
            image.fill_rect(Rect2i(24, 23, 16, 15), Color("ffe4a1"))
            image.fill_rect(Rect2i(17, 18, 30, 4), dark)
        "smith_anvil", "smith_toolwall":
            image.fill_rect(Rect2i(8, 23, 48, 12), Color("7b8791"))
            image.fill_rect(Rect2i(23, 34, 18, 20), dark)
            image.fill_rect(Rect2i(17, 48, 30, 7), Color("64717a"))
            if kind == "smith_toolwall":
                for x in [12, 30, 47]:
                    image.fill_rect(Rect2i(x, 7, 4, 15), gold)
        "shrine_altar":
            image.fill_rect(Rect2i(9, 25, 46, 30), oak)
            image.fill_rect(Rect2i(6, 21, 52, 10), gold)
            image.fill_rect(Rect2i(24, 7, 16, 16), sea)
            image.fill_rect(Rect2i(30, 9, 4, 12), gold)
        "guild_noticeboard", "tideway_chart":
            image.fill_rect(Rect2i(10, 7, 44, 48), oak)
            image.fill_rect(Rect2i(15, 12, 34, 37), Color("d9c69e"))
            for y in [18, 25, 33, 40]:
                image.fill_rect(Rect2i(20, y, 23, 2), sea.darkened(0.19))
        "saltgrass_planter":
            image.fill_rect(Rect2i(16, 36, 32, 18), oak)
            image.fill_rect(Rect2i(14, 33, 36, 7), light)
            for x in [22, 30, 38, 43]:
                image.fill_rect(Rect2i(x, 12+(x%3)*4, 4, 25), Color("6b976b"))
        _:
            # Distinct missing roles remain detectable in logs instead of
            # silently drawing a semantically incorrect substitute.
            return null
    _finish_surface(image, kind)
    var result: Texture2D = ImageTexture.create_from_image(image)
    _textures[kind] = result
    return result
