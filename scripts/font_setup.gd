extends Node
## Shared CJK fallback for programmatically drawn text (draw_string).
## The project default GUI font uses the same SystemFont resource.
## System fonts are available on iOS and do not require bundling proprietary fonts.

const CHINESE_FONT: Font = preload("res://assets/fonts/chinese_system_font.tres")

func _enter_tree() -> void:
    ThemeDB.fallback_font = CHINESE_FONT
