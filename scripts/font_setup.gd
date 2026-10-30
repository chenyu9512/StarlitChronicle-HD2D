extends Node
## Ship an OFL Chinese-Japanese-Latin font as raw bytes in every Godot PCK.
## ThemeDB.fallback_font alone is NOT sufficient: Godot's built-in theme
## already specifies Latin-only fonts for Label, Button and RichTextLabel.
## Install the actual FontFile as a font override on every game Control,
## including dynamically created menu/dialogue controls and future scenes.
const FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
const MIN_FONT_BYTES := 10000000
var cjk_font: FontFile

func _enter_tree() -> void:
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(FONT_PATH)
    if bytes.size() < MIN_FONT_BYTES:
        push_error("FATAL: bundled Chinese font missing from PCK: " + FONT_PATH)
        return
    cjk_font = FontFile.new()
    cjk_font.data = bytes
    if not cjk_font.has_char("星".unicode_at(0)):
        push_error("FATAL: bundled font lacks Chinese glyphs")
        return
    # For manually drawn text / code without a specified font.
    ThemeDB.fallback_font = cjk_font
    # Controls resolve the built-in theme before ThemeDB.fallback_font.
    # Apply to every Control on insertion, before its first visible frame.
    get_tree().node_added.connect(_apply_cjk_font)
    _apply_existing(get_tree().root)

func _apply_existing(parent: Node) -> void:
    for child in parent.get_children():
        _apply_cjk_font(child)
        _apply_existing(child)

func _apply_cjk_font(node: Node) -> void:
    if cjk_font == null or not node is Control:
        return
    var control: Control = node as Control
    # Label, Button, LineEdit, CheckBox, OptionButton, Tree, ItemList etc.
    control.add_theme_font_override("font", cjk_font)
    if node is RichTextLabel:
        # RichTextLabel is NOT drawn using the ordinary "font" theme item.
        # Explicitly override all text styles, including BBCode bold/italic.
        for kind in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
            control.add_theme_font_override(kind, cjk_font)
