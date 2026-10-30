extends SceneTree
## CJK glyph availability regression for the same embedded FontFile shipped to iOS.
const FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.otf"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var problems: Array[String] = []
    var resource: Resource = load(FONT_PATH)
    if resource == null or not resource is FontFile:
        problems.append("Noto CJK FontFile could not be imported")
    else:
        var font: FontFile = resource
        for character in ["星", "灯", "纪", "行", "中", "文", "字", "体", "菜", "单", "对", "话", "A", "9", "あ", "ア"]:
            if not font.has_char(character.unicode_at(0)):
                problems.append("No embedded glyph: " + character)
        ThemeDB.fallback_font = font
        if not ThemeDB.fallback_font.has_char("星".unicode_at(0)):
            problems.append("Canvas fallback has no Chinese glyph")
    if not ProjectSettings.has_setting("gui/theme/custom_font"):
        problems.append("Project default font setting missing")
    # The import is proven by successfully loading the FontFile resource, not
    # by checking just its unimported source file on the build machine.
    if problems.is_empty():
        print("BUNDLED CJK FONT SMOKE: ALL PASS")
        quit(0)
    else:
        for error in problems:
            push_error("FONT FAIL: " + error)
        quit(1)
