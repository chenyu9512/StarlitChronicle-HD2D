extends Control
## Development-only C line V12 inventory gallery. Never mutates or promotes art.
## Run res://scenes/c_art_distribution_gallery.tscn in Godot.
const SOURCE_MANIFEST: String = "res://data/assets/c_art_usage_source_v12.json"
const EXTERNAL_MANIFEST: String = "res://data/assets/c_art_usage_external_v12.json"
const OTHER_MANIFEST: String = "res://data/assets/c_art_nonimage_groups_v12.json"
const GROUP_MANIFEST: String = "res://data/assets/c_art_group_contracts_v12.json"
const PAGE_SIZE: int = 18
const EXTERNAL_PREFIX: String = "res://assets/art/external/cc0_named_v1/"
var entries: Array = []
var group_ids: Array[String] = []
var filtered: Array = []
var page: int = 0
var group_selector: OptionButton
var grid: GridContainer
var current_status: Label
var current_page: Label
var prev_page: Button
var next_page: Button

func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_warning("V12 art distribution file missing: " + path)
        return {}
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var group_data: Dictionary = _read(GROUP_MANIFEST)
    var unique: Dictionary = {}
    for group in group_data.get("groups", []):
        if group is Dictionary:
            var id: String = str(group.get("id", ""))
            if not id.is_empty():
                unique[id] = true
    for path in [SOURCE_MANIFEST, EXTERNAL_MANIFEST]:
        for item in _read(path).get("rows", []):
            if item is Dictionary:
                entries.append(item)
    for item in _read(OTHER_MANIFEST).get("records", []):
        if item is Dictionary:
            entries.append(item)
    group_ids.assign(unique.keys())
    group_ids.sort()
    _build()
    group_selector.item_selected.connect(_change_group)
    _change_group(0)

func _new_label(value: String, font_size: int = 13) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    return label

func _build() -> void:
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("101b2b")
    add_child(bg)
    var outer := MarginContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right"]:
        outer.add_theme_constant_override("margin_" + side, 20)
    for side in ["top", "bottom"]:
        outer.add_theme_constant_override("margin_" + side, 16)
    add_child(outer)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    outer.add_child(column)
    column.add_child(_new_label("星灯纪行 · 第三方素材组 · V12全集审查", 22))
    column.add_child(_new_label("共1,413张PNG与104项源工程/压缩档。候选分配不代表Godot已正式采用。原档在.gdignore目录内不显示缩略图。"))
    var header := HBoxContainer.new()
    column.add_child(header)
    group_selector = OptionButton.new()
    group_selector.custom_minimum_size = Vector2(320, 40)
    group_selector.add_item("全部素材组")
    for id in group_ids:
        group_selector.add_item(id)
    header.add_child(group_selector)
    current_status = _new_label("")
    current_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(current_status)
    var navigation := HBoxContainer.new()
    column.add_child(navigation)
    prev_page = Button.new()
    prev_page.text = "上一页"
    prev_page.pressed.connect(_previous)
    navigation.add_child(prev_page)
    current_page = _new_label("页数")
    current_page.custom_minimum_size.x = 110
    current_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    navigation.add_child(current_page)
    next_page = Button.new()
    next_page.text = "下一页"
    next_page.pressed.connect(_next)
    navigation.add_child(next_page)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(scroll)
    grid = GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 14)
    grid.add_theme_constant_override("v_separation", 14)
    scroll.add_child(grid)

func _change_group(index: int) -> void:
    filtered.clear()
    var group: String = "" if index == 0 else group_ids[index - 1]
    for item in entries:
        if group.is_empty() or str(item.get("group_id", "")) == group:
            filtered.append(item)
    page = 0
    _render()

func _previous() -> void:
    page = maxi(0, page - 1)
    _render()

func _next() -> void:
    page = mini(maxi(0, ceili(float(filtered.size()) / PAGE_SIZE) - 1), page + 1)
    _render()

func _render() -> void:
    for child in grid.get_children():
        grid.remove_child(child)
        child.queue_free()
    var pages: int = maxi(1, ceili(float(filtered.size()) / PAGE_SIZE))
    page = clampi(page, 0, pages - 1)
    current_page.text = "%d / %d" % [page + 1, pages]
    current_status.text = "此组 %d 项 / 全部 %d 项" % [filtered.size(), entries.size()]
    prev_page.disabled = page <= 0
    next_page.disabled = page >= pages - 1
    var from_index: int = page * PAGE_SIZE
    for j in range(from_index, mini(from_index + PAGE_SIZE, filtered.size())):
        var item: Dictionary = filtered[j]
        var cell := PanelContainer.new()
        cell.custom_minimum_size = Vector2(245, 240)
        grid.add_child(cell)
        var content := VBoxContainer.new()
        cell.add_child(content)
        var path: String = str(item.get("source", ""))
        var status: String = str(item.get("status", item.get("state", item.get("allocation_intent", "source_only"))))
        var role: String = str(item.get("intended_role", item.get("asset_type", item.get("kind", "source"))))
        if path.begins_with(EXTERNAL_PREFIX) and ResourceLoader.exists(path):
            var tex: Texture2D = ResourceLoader.load(path) as Texture2D
            if tex != null:
                var image := TextureRect.new()
                image.custom_minimum_size.y = 115
                image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                image.texture = tex
                content.add_child(image)
        else:
            content.add_child(_new_label("制作原档 / 不能直接运行预览", 12))
        content.add_child(_new_label(path.get_file(), 14))
        content.add_child(_new_label("用途: " + role))
        content.add_child(_new_label("地区: " + str(item.get("region_id", "")) + " / " + str(item.get("map_id", ""))))
        content.add_child(_new_label("阶段: " + status))
