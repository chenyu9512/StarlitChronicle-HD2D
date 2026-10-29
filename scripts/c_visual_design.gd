extends RefCounted
## C-line shared visual language. Presentation only; no save, NPC or battle mutations.
const INK: Color = Color("081626")
const NAVY: Color = Color("10283b")
const GOLD: Color = Color("e8c687")
const RIM: Color = Color("ad9568")
const PAPER: Color = Color("f6efde")
const SEAFOAM: Color = Color("86c8cb")
const MUTED: Color = Color("b8cbd1")
static func frame(fill: Color = NAVY, border: Color = RIM, radius: int = 12, margin: int = 13) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.set_content_margin_all(margin)
    style.anti_aliasing = true
    style.shadow_color = Color(0.01, 0.02, 0.04, 0.35)
    style.shadow_size = 4
    return style
static func style_button(button: Button, primary: bool = false) -> void:
    var fill: Color = Color(0.34, 0.27, 0.16, 0.95) if primary else Color(0.055, 0.135, 0.20, 0.96)
    button.add_theme_stylebox_override("normal", frame(fill, GOLD if primary else RIM, 10, 10))
    button.add_theme_stylebox_override("hover", frame(Color(0.12, 0.27, 0.33, 0.98), GOLD, 10, 10))
    button.add_theme_stylebox_override("pressed", frame(Color(0.08, 0.19, 0.28, 1.0), SEAFOAM, 10, 10))
    button.add_theme_stylebox_override("disabled", frame(Color(0.09, 0.12, 0.17, 0.65), RIM.darkened(0.55), 10, 10))
    var focus := frame(Color(0, 0, 0, 0), SEAFOAM, 10, 10)
    focus.shadow_size = 0
    button.add_theme_stylebox_override("focus", focus)
    button.add_theme_color_override("font_color", PAPER)
    button.add_theme_color_override("font_hover_color", Color("fff9e7"))
    button.add_theme_color_override("font_pressed_color", PAPER)
    button.add_theme_color_override("font_disabled_color", MUTED)
