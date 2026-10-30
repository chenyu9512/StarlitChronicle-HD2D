extends Node
## iOS CJK bootstrap. Godot imports .otf into .godot/imported/, so
## FileAccess on the original .otf works in the editor but may FAIL in IPA.
## Release builds copy the hash-verified font as a nonimported *.fontbytes
## file and VERIFY that raw payload inside the FINAL iPhone .app / IPA PCK.
## For editor/desktops which have not run export preparation, use ResourceLoader
## (which correctly resolves imported OTFs) instead of relying on source bytes.
const FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
const EXPORTED_FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.fontbytes"
const MIN_FONT_BYTES := 10000000
var cjk_font: FontFile
var font_source: String = ""
var font_error: String = ""

func _enter_tree() -> void:
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(EXPORTED_FONT_PATH)
    if bytes.size() >= MIN_FONT_BYTES:
        var raw := FontFile.new()
        raw.data = bytes
        if _is_font_valid(raw):
            cjk_font = raw
            font_source = "verified raw export payload"
    if cjk_font == null:
        # This path works with *imported* fonts in PCK; FileAccess(OTF) does not.
        # Do not require the source OTF file to exist in an exported game.
        var imported: Resource = ResourceLoader.load(FONT_PATH, "FontFile")
        if imported is FontFile and _is_font_valid(imported):
            cjk_font = imported as FontFile
            font_source = "Godot imported FontFile"
    if cjk_font == null:
        # Editor/source fallback only. Release/CI must have one of the above.
        bytes = FileAccess.get_file_as_bytes(FONT_PATH)
        if bytes.size() >= MIN_FONT_BYTES:
            var raw_source := FontFile.new()
            raw_source.data = bytes
            if _is_font_valid(raw_source):
                cjk_font = raw_source
                font_source = "editor source OpenType"
    if cjk_font == null:
        font_error = "CJK font missing from iOS PCK: " + EXPORTED_FONT_PATH
        push_error("FATAL: " + font_error)
        _log_font_diagnostic("FATAL " + font_error)
        return
    # The bitmap/outline rasterizer is the same font actually used by Controls.
    ThemeDB.fallback_font = cjk_font
    get_tree().node_added.connect(_apply_cjk_font)
    _apply_existing(get_tree().root)
    _log_font_diagnostic("OK " + font_source + " | glyphs=星灯纪行中文あアA9")
    print("CJK_FONT_READY source=", font_source)

func _is_font_valid(font: FontFile) -> bool:
    if font == null:
        return false
    for letter in ["星", "灯", "纪", "行", "中", "文", "あ", "ア", "A", "9"]:
        if not font.has_char(letter.unicode_at(0)):
            return false
    return true

func _log_font_diagnostic(message: String) -> void:
    # The iPhone sandbox persists the source/error for device-log collection.
    var file := FileAccess.open("user://cjk_font_diagnostic.txt", FileAccess.WRITE)
    if file != null:
        file.store_string(message + "\n")

func _apply_existing(parent: Node) -> void:
    for child in parent.get_children():
        _apply_cjk_font(child)
        _apply_existing(child)

func _apply_cjk_font(node: Node) -> void:
    if cjk_font == null or not node is Control:
        return
    var control: Control = node as Control
    control.add_theme_font_override("font", cjk_font)
    if node is RichTextLabel:
        for kind in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
            control.add_theme_font_override(kind, cjk_font)
