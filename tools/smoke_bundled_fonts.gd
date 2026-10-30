extends SceneTree
## Verify OpenType raw bytes and the same FontSetup path used on iOS.
const FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.otf"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var problems: Array[String] = []
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(FONT_PATH)
    if bytes.size() < 10000000:
        problems.append("Bundled CJK OpenType raw bytes absent")
    else:
        var font := FontFile.new()
        font.data = bytes
        for character in ["星", "灯", "纪", "行", "中", "文", "字", "体", "菜", "单", "对", "话", "A", "9", "あ", "ア"]:
            if not font.has_char(character.unicode_at(0)):
                problems.append("No embedded glyph: " + character)
        var setup: Node = load("res://scripts/font_setup.gd").new()
        root.add_child(setup)
        if not ThemeDB.fallback_font.has_char("星".unicode_at(0)):
            problems.append("Game FontSetup did not install Chinese fallback")
        if not ThemeDB.fallback_font.has_char("A".unicode_at(0)):
            problems.append("Game FontSetup did not install Latin fallback")
        setup.queue_free()
    if not problems.is_empty():
        for error in problems:
            push_error("FONT FAIL: " + error)
        quit(1)
    else:
        print("BUNDLED CJK FONT SMOKE: ALL PASS")
        quit(0)
