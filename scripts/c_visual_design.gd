extends RefCounted
## 《星灯纪行》统一二维视觉语言。只涉及外观，不读取/修改剧情、背包或存档。
## 符号原则：午夜海蓝背景 / 旧纸白文本 / 磨砂金属边 / 各幕专属窄色带。
const INK: Color = Color("081626")
const NAVY: Color = Color("10283b")
const GOLD: Color = Color("e8c687")
const RIM: Color = Color("ad9568")
const PAPER: Color = Color("f6efde")
const SEAFOAM: Color = Color("86c8cb")
const MUTED: Color = Color("b8cbd1")
const SHADOW: Color = Color(0.012,0.025,0.044,0.43)
const DANGER: Color = Color("ef8b85")
const PALETTE_BY_ACT: Array[Color] = [
    Color("9bd4ce"), # 1 晨露、白砂：海玻璃
    Color("d6ac75"), # 2 三誓王都：砂金
    Color("e49870"), # 3 赤炉：温铜
    Color("9ca5de"), # 4 旧时档案：银蓝
    Color("7ec8dd"), # 5 群岛：海天青
    Color("d6b5dd"), # 6 映世：镜紫
    Color("b9b6e6"), # 7 失落大洲：薄雾
    Color("e2bd92"), # 8 战火与撤离：琥珀
    Color("85bdb3"), # 9 十二年后：苔青
    Color("c8b58c"), # 10 群灯之城：居民金
    Color("a6c3e7"), # 11 天轨圣域：星银蓝
    Color("dfc3a8"), # 12 永昼与终章：晨曦白金
]

static func act_accent(chapter: int) -> Color:
    if chapter <= 0:
        return GOLD
    var act: int = clampi((chapter - 1) / 6, 0, PALETTE_BY_ACT.size() - 1)
    return PALETTE_BY_ACT[act]


static func frame(fill: Color = NAVY, border: Color = RIM, radius: int = 12, margin: int = 13) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.set_content_margin_all(margin)
    style.anti_aliasing = true
    style.shadow_color = SHADOW
    style.shadow_size = 5
    style.shadow_offset = Vector2(0, 3)
    return style


static func surface(emphasis: bool = false, chapter: int = 0) -> StyleBoxFlat:
    var border: Color = act_accent(chapter) if emphasis else RIM
    var fill: Color = Color(0.032,0.078,0.115,0.97) if emphasis else Color(0.035,0.09,0.14,0.94)
    var style: StyleBoxFlat = frame(fill, border, 10, 15)
    style.border_width_top = 2 if emphasis else 1
    return style


static func style_button(button: Button, primary: bool = false) -> void:
    var fill: Color = Color(0.26,0.21,0.14,0.97) if primary else Color(0.065,0.15,0.205,0.96)
    button.add_theme_stylebox_override("normal", frame(fill, GOLD if primary else RIM, 8, 11))
    button.add_theme_stylebox_override("hover", frame(Color(0.115,0.255,0.32,0.98), GOLD, 8, 11))
    button.add_theme_stylebox_override("pressed", frame(Color(0.075,0.18,0.255,1.0), SEAFOAM, 8, 11))
    button.add_theme_stylebox_override("disabled", frame(Color(0.065,0.08,0.105,0.75), RIM.darkened(0.60), 8, 11))
    var focus: StyleBoxFlat = frame(Color(0,0,0,0), SEAFOAM, 8, 4)
    focus.shadow_size = 0
    focus.set_border_width_all(2)
    button.add_theme_stylebox_override("focus", focus)
    button.add_theme_color_override("font_color", PAPER)
    button.add_theme_color_override("font_hover_color", Color("fffaf0"))
    button.add_theme_color_override("font_pressed_color", PAPER)
    button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.22))
    button.add_theme_color_override("font_focus_color", PAPER)
    button.add_theme_constant_override("h_separation", 9)


static func style_caption(label: Label, chapter: int = 0, large: bool = false) -> void:
    label.add_theme_color_override("font_color", act_accent(chapter))
    label.add_theme_font_size_override("font_size", 23 if large else 16)
    label.add_theme_color_override("font_shadow_color", SHADOW)
    label.add_theme_constant_override("shadow_offset_y", 2)


static func clamp_readable_size(viewport: Vector2i, normal: int, minimum: int) -> int:
    if viewport.y < 585 or viewport.x < 940:
        return maxi(minimum, normal - 3)
    return normal
