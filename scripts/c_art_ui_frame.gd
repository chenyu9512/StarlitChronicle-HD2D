extends RefCounted
## One consistent Kenney Fantasy 9-slice border on RPG menus, rather than
## displaying 228 arbitrary border variants simultaneously.
const Art = preload("res://scripts/c_art_overrides.gd")
const BORDER: String = "res://assets/art/external/cc0_named_v1/ui/kenney_fantasy_ui/default/border/ui_kenney_fantasy_ui_panel_border_008.png"

static func panel_frame() -> StyleBox:
    var texture: Texture2D = Art.texture(BORDER)
    if texture == null or Vector2i(texture.get_size()) != Vector2i(48, 48):
        var fallback := StyleBoxFlat.new()
        fallback.bg_color = Color("0b1c32")
        fallback.border_color = Color("e6c47d")
        fallback.set_border_width_all(2)
        fallback.set_corner_radius_all(9)
        fallback.set_content_margin_all(14)
        return fallback
    var panel := StyleBoxTexture.new()
    panel.texture = texture
    panel.texture_margin_left = 12.0
    panel.texture_margin_right = 12.0
    panel.texture_margin_top = 12.0
    panel.texture_margin_bottom = 12.0
    panel.set_content_margin_all(14.0)
    panel.modulate_color = Color("e6c47d")
    panel.draw_center = false
    return panel
