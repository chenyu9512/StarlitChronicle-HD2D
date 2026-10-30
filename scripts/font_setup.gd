extends Node
## Always create a real FontFile from source bytes embedded in the iOS PCK.
## Avoid Godot's first-run imported-font loader ordering and any reliance on
## iPhone proprietary SystemFont naming. Called before game scenes are built.
const FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
const MIN_FONT_BYTES := 10000000

func _enter_tree() -> void:
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(FONT_PATH)
    if bytes.size() < MIN_FONT_BYTES:
        push_error("FATAL: packaged Noto CJK font missing; text cannot be rendered: " + FONT_PATH)
        return
    var embedded := FontFile.new()
    embedded.data = bytes
    ThemeDB.fallback_font = embedded
    if not embedded.has_char("星".unicode_at(0)):
        push_error("FATAL: packaged CJK font has no Chinese glyphs")
