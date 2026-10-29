extends Control
## 独立剧情检查器（F6运行 scenes/story_preview.tscn）。
## 只展示JSON中真实存在的对话，不模拟任务战斗和正式存档。

const CatalogScript = preload("res://scripts/story_catalog.gd")
var catalog  # 动态脚本实例：访问StoryCatalog公开方法
var chapter_index: int = -1  # -1 = 童年序章
var scene_index: int = 0
var line_index: int = 0
var title_label: Label
var chapter_label: Label
var scene_label: Label
var dialogue_label: RichTextLabel
var hint_label: Label

func _ready() -> void:
    catalog = CatalogScript.new()
    _build_ui()
    if not catalog.load_all():
        dialogue_label.text = "剧情资源加载失败：\n" + catalog.get_errors_text()
        return
    _render()

func _build_ui() -> void:
    var background := ColorRect.new()
    background.color = Color(0.035, 0.055, 0.10, 1.0)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var container := VBoxContainer.new()
    container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    container.offset_left = 36.0
    container.offset_top = 24.0
    container.offset_right = -36.0
    container.offset_bottom = -20.0
    container.add_theme_constant_override("separation", 12)
    add_child(container)
    title_label = Label.new()
    title_label.text = "星灯纪行｜剧情预览"
    title_label.add_theme_font_size_override("font_size", 30)
    container.add_child(title_label)
    chapter_label = Label.new()
    chapter_label.add_theme_font_size_override("font_size", 20)
    container.add_child(chapter_label)
    scene_label = Label.new()
    scene_label.add_theme_font_size_override("font_size", 17)
    container.add_child(scene_label)
    dialogue_label = RichTextLabel.new()
    dialogue_label.bbcode_enabled = false
    dialogue_label.scroll_active = true
    dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dialogue_label.add_theme_font_size_override("normal_font_size", 24)
    container.add_child(dialogue_label)
    hint_label = Label.new()
    hint_label.text = "此处为编剧预览，不会自动传送地图或触发Boss。"
    container.add_child(hint_label)
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 12)
    container.add_child(buttons)
    _add_button(buttons, "上一章", Callable(self, "_previous_chapter"))
    _add_button(buttons, "下一句 / 场景", Callable(self, "_next_line"))
    _add_button(buttons, "下一章", Callable(self, "_next_chapter"))
    _add_button(buttons, "重新开始本章", Callable(self, "_restart_chapter"))

func _add_button(parent: HBoxContainer, title: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size = Vector2(145, 52)
    button.pressed.connect(callback)
    parent.add_child(button)

func _get_current_chapter() -> Dictionary:
    if chapter_index == -1:
        return catalog.prologue
    return catalog.get_chapter("ch%03d" % (chapter_index + 1))

func _render() -> void:
    var chapter: Dictionary = _get_current_chapter()
    var scenes: Array = chapter.get("scenes", [])
    if scenes.is_empty():
        dialogue_label.text = "此章节无可读场景。"
        return
    scene_index = clampi(scene_index, 0, scenes.size() - 1)
    var scene: Dictionary = scenes[scene_index]
    var lines: Array = scene.get("dialogue", [])
    line_index = clampi(line_index, 0, maxi(0, lines.size() - 1))
    chapter_label.text = ("序章" if chapter_index == -1 else "第 %02d 章" % (chapter_index + 1)) + "｜" + str(chapter.get("title", ""))
    scene_label.text = str(scene.get("title", "")) + "  ·  场景 %d/%d  ·  对白 %d/%d" % [scene_index + 1, scenes.size(), line_index + 1, lines.size()]
    if lines.is_empty():
        dialogue_label.text = "[暂无对白]"
        return
    var line: Dictionary = lines[line_index]
    dialogue_label.text = str(line.get("speaker", "")) + "\n\n" + str(line.get("text", ""))
    if scene.has("objective"):
        hint_label.text = "任务：" + str(scene.get("objective", ""))
    else:
        var objectives: Array = scene.get("objectives", [])
        hint_label.text = "任务：" + (str(objectives[0]) if not objectives.is_empty() else "继续主线")

func _next_line() -> void:
    var scenes: Array = _get_current_chapter().get("scenes", [])
    if scenes.is_empty():
        return
    var lines: Array = scenes[scene_index].get("dialogue", [])
    if line_index + 1 < lines.size():
        line_index += 1
    elif scene_index + 1 < scenes.size():
        scene_index += 1
        line_index = 0
    elif chapter_index < 71:
        _next_chapter()
        return
    _render()

func _next_chapter() -> void:
    chapter_index = mini(chapter_index + 1, 71)
    scene_index = 0
    line_index = 0
    _render()

func _previous_chapter() -> void:
    chapter_index = maxi(chapter_index - 1, -1)
    scene_index = 0
    line_index = 0
    _render()

func _restart_chapter() -> void:
    scene_index = 0
    line_index = 0
    _render()
