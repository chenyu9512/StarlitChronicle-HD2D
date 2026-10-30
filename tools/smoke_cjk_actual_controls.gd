extends SceneTree
## Detect the exact regression pictured on iOS: English is visible but every
## Chinese character is rendered as a missing-glyph square by GUI controls.
## Checking ThemeDB.fallback_font alone is not sufficient for Godot 4.
const GameUI = preload("res://scripts/first_act_ui.gd")
var issues: Array[String] = []
var checked_controls: int = 0
var checked_rich_text: int = 0
var checked_chinese: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _contains_cjk(message: String) -> bool:
    for i in range(message.length()):
        var cp: int = message.unicode_at(i)
        if cp >= 0x3400 and cp <= 0x9fff:
            return true
    return false

func _verify_actual_controls(node: Node) -> void:
    if node is Label or node is Button or node is RichTextLabel:
        var control: Control = node as Control
        var font_key: String = "normal_font" if node is RichTextLabel else "font"
        var font: Font = control.get_theme_font(font_key)
        checked_controls += 1
        if node is RichTextLabel:
            checked_rich_text += 1
        if font == null or not font.has_char("星".unicode_at(0)):
            issues.append("%s uses a GUI font without Chinese glyphs: %s" % [node.get_path(),font_key])
        var displayed: String = ""
        if node is RichTextLabel:
            displayed = (node as RichTextLabel).get_parsed_text()
            for style in ["bold_font", "italics_font", "bold_italics_font", "mono_font"]:
                var variant: Font = control.get_theme_font(style)
                if variant == null or not variant.has_char("中".unicode_at(0)):
                    issues.append("%s RichTextLabel lacks Chinese glyphs in %s" % [node.get_path(),style])
        elif node is Label:
            displayed = (node as Label).text
        elif node is Button:
            displayed = (node as Button).text
        if _contains_cjk(displayed):
            checked_chinese += 1
            if font == null or not font.has_char("中".unicode_at(0)):
                issues.append("Chinese text will render as squares: " + displayed.left(32))
    for child in node.get_children():
        _verify_actual_controls(child)

func _run() -> void:
    var ui = GameUI.new()
    root.add_child(ui)
    var foyer = ui.title_overlay
    if foyer == null:
        issues.append("Official title UI missing")
    else:
        foyer._reveal_menu()
        _verify_actual_controls(foyer)
        # Test the actual richly formatted story and controls pages, too.
        foyer._set_page("controls")
        _verify_actual_controls(foyer.detail_body)
        foyer._set_page("story")
    # Also verify the HUD/dialogue controls created under this CanvasLayer.
    if ui.root != null:
        _verify_actual_controls(ui.root)
    if checked_controls < 20 or checked_rich_text < 1 or checked_chinese < 10:
        issues.append("Insufficient real GUI font checks: %d controls, %d rich, %d Chinese" % [
            checked_controls, checked_rich_text, checked_chinese])
    if issues.is_empty():
        print("CJK REAL CONTROL SMOKE: ALL PASS; controls=%d rich=%d Chinese=%d" % [
            checked_controls, checked_rich_text, checked_chinese])
        quit(0)
    else:
        for problem in issues:
            push_error("CJK GUI FAIL: " + problem)
        quit(1)
