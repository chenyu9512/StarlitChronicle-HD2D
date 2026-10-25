extends Sprite2D
## Small original top-down citizen silhouette; role palette conveys information.
var role: String = "lore"
var citizen_name: String = ""
var tone: Color = Color("749eab")
var base_hour: int = 8
var label: Label

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
    queue_redraw()

func _draw() -> void:
    draw_ellipse(Vector2(0,9),Vector2(13,4),Color(0.01,0.03,0.05,0.35))
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
