extends Node
## Render-time CJK font must be embedded in every IPA, not located via iOS
## system font names. The same imported FontFile backs all Control labels and
## CanvasItem.draw_string text.
const CHINESE_FONT: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

func _enter_tree() -> void:
    ThemeDB.fallback_font = CHINESE_FONT
