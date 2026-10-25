extends Sprite2D
const ArtAssets = preload("res://scripts/art_assets.gd")
## Small original top-down citizen silhouette; role palette conveys information.
var role: String = "lore"
var citizen_name: String = ""
var tone: Color = Color("749eab")
var base_hour: int = 8
var label: Label
var artwork: Sprite2D
var idle_elapsed: float = 0.0
var base_art_offset: float = -21.0

func _process(delta: float) -> void:
    idle_elapsed+=delta
    if is_instance_valid(artwork):
        # Distinct but small idle motion keeps authored still portraits legible.
        artwork.position.y=base_art_offset+0.8*sin(idle_elapsed*1.6+float(role.hash()%8))

func setup(info: Dictionary) -> void:
    role=str(info.get("role","lore"))
    citizen_name=str(info.get("name","旅人"))
    match role:
        "shop": tone=Color("ca9568")
        "craft": tone=Color("9a8dac")
        "quest": tone=Color("d4bd72")
        "rumor": tone=Color("b59079")
        _: tone=Color("70aa9b")
    if label==null:
        label=Label.new()
        label.position=Vector2(-46,-55)
        label.custom_minimum_size.x=94
        label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size",12)
        label.add_theme_color_override("font_color",Color("fff1d2"))
        label.add_theme_color_override("font_shadow_color",Color("0a1d2d"))
        label.add_theme_constant_override("shadow_offset_x",1)
        label.add_theme_constant_override("shadow_offset_y",2)
        add_child(label)
    label.text=citizen_name
    # Only the 35 approved B02 NPC fullbody sheets are used as still overworld figures.
    # Coast residents without authored B02 art keep their silhouette fallback.
    var art_path: String = ArtAssets.npc_fullbody(str(info.get("id", "")))
    if not art_path.is_empty() and ResourceLoader.exists(art_path):
        artwork = Sprite2D.new()
        artwork.texture = load(art_path)
        var dimensions: Vector2 = artwork.texture.get_size()
        var factor: float = minf(56.0 / maxf(dimensions.y, 1.0), 38.0 / maxf(dimensions.x, 1.0))
        artwork.scale = Vector2(factor, factor)
        artwork.position = Vector2(0, -21)
        artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        add_child(artwork)
    queue_redraw()

func _draw() -> void:
    draw_circle(Vector2(0,8),10.0,Color(0.01,0.03,0.05,0.35))
    if artwork != null:
        if role == "quest":
            draw_colored_polygon(PackedVector2Array([Vector2(-6,-51),Vector2(0,-57),Vector2(6,-51),Vector2(0,-45)]),Color("ffe38f"))
        return
    draw_rect(Rect2(-7,-7,6,17),tone.darkened(0.35),true)
    draw_rect(Rect2(1,-7,6,17),tone.darkened(0.36),true)
    draw_colored_polygon(PackedVector2Array([Vector2(-12,-20),Vector2(12,-20),Vector2(10,-5),Vector2(-10,-5)]),tone)
    draw_line(Vector2(-12,-17),Vector2(-16,-7),tone.lightened(0.11),5)
    draw_line(Vector2(12,-17),Vector2(16,-7),tone.lightened(0.11),5)
    draw_circle(Vector2(0,-26),9.0,Color("e5b796"))
    draw_rect(Rect2(-9,-36,18,6),Color("3d4b57"),true)
    draw_circle(Vector2(-3,-27),1.0,Color("253747"))
    draw_circle(Vector2(3,-27),1.0,Color("253747"))
    if role=="quest":
        draw_colored_polygon(PackedVector2Array([Vector2(-6,-48),Vector2(0,-54),Vector2(6,-48),Vector2(0,-42)]),Color("ffe38f"))
