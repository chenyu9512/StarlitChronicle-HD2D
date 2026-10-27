extends Control
## C-line home art manager. Paginated 18 thumbnails; only user:// PNG overrides change.
signal closed
signal asset_changed(path: String)
const Overrides = preload("res://scripts/c_art_overrides.gd")
const Visual = preload("res://scripts/c_visual_design.gd")
const VisualPrompts = preload("res://scripts/c_visual_prompts.gd")
const PAGE_SIZE: int = 18
const INK: Color = Color("0b1c32")
const GOLD: Color = Color("e6c47d")
var all_assets: Array = []
var filtered: Array = []
var current_path: String = ""
var page: int = 0
var category_filter: OptionButton
var tier_filter: OptionButton
var search_box: LineEdit
var cards: GridContainer
var count_label: Label
var location_label: Label
var original_preview: TextureRect
var active_preview: TextureRect
var selection_label: Label
var dimensions_label: Label
var usage_label: Label
var status_label: Label
var note_edit: LineEdit
var restore_button: Button
var import_button: Button
var file_picker: FileDialog
var last_status: Label
var prompt_button: Button
var prompt_panel: PanelContainer
var prompt_text: TextEdit
var pack_options: OptionButton
var pack_picker: FileDialog
var pack_feedback: Label
var pack_ids: Array[String] = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    all_assets = Overrides.list_assets()
    _build()
    hide()

func _button(label_text: String) -> Button:
    var b := Button.new()
    b.text = label_text
    b.custom_minimum_size.y = 39
    b.add_theme_font_size_override("font_size", 15)
    Visual.style_button(b)
    return b

func _text(content: String, size: int = 14) -> Label:
    var item := Label.new()
    item.text = content
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    item.add_theme_font_size_override("font_size", size)
    return item

func _preview() -> TextureRect:
    var preview := TextureRect.new()
    preview.custom_minimum_size = Vector2(148, 140)
    preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return preview

func _build() -> void:
    var cover := ColorRect.new()
    cover.color = Color(0.014, 0.038, 0.071, 0.98)
    cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(cover)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for edge in ["left", "right"]:
        margin.add_theme_constant_override("margin_" + edge, 24)
    for edge in ["top", "bottom"]:
        margin.add_theme_constant_override("margin_" + edge, 15)
    add_child(margin)
    var flow := VBoxContainer.new()
    flow.add_theme_constant_override("separation", 9)
    margin.add_child(flow)
    var header := HBoxContainer.new()
    flow.add_child(header)
    var title := _text("✦ 星灯纪行 · 美术资源管理与替换", 24)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_color_override("font_color", GOLD)
    header.add_child(title)
    var close_button := _button("返回首页")
    close_button.pressed.connect(close_manager)
    header.add_child(close_button)
    var hint := _text("按分类查看原始素材、预览缩略图、保存备注或导入本机图片。原文件与游戏存档不会被覆盖。", 15)
    hint.add_theme_color_override("font_color", Color("b5c6d9"))
    flow.add_child(hint)
    var pack_row := HBoxContainer.new()
    pack_row.add_theme_constant_override("separation", 8)
    flow.add_child(pack_row)
    pack_row.add_child(_text("全局主题包 / DLC", 15))
    pack_options = OptionButton.new()
    pack_options.custom_minimum_size.x = 220
    pack_row.add_child(pack_options)
    var apply_pack := _button("一键应用全局画风")
    apply_pack.pressed.connect(_apply_pack)
    pack_row.add_child(apply_pack)
    var reset_pack := _button("切换回游戏原版")
    reset_pack.pressed.connect(_reset_pack)
    pack_row.add_child(reset_pack)
    var install_pack := _button("导入DLC包")
    install_pack.pressed.connect(func() -> void: pack_picker.popup_centered_ratio(0.8))
    pack_row.add_child(install_pack)
    var remove_pack := _button("卸载所选DLC")
    remove_pack.pressed.connect(_uninstall_pack)
    pack_row.add_child(remove_pack)
    pack_feedback = _text("主题切换后重新进入地图即可更新已创建的场景图集。", 12)
    pack_feedback.add_theme_color_override("font_color", Color("b1d2ba"))
    flow.add_child(pack_feedback)
    _refresh_pack_list()
    var filters := HBoxContainer.new()
    flow.add_child(filters)
    category_filter = OptionButton.new()
    category_filter.custom_minimum_size.x = 210
    category_filter.add_item("全部分类")
    for category in Overrides.categories():
        category_filter.add_item(str(category))
    category_filter.item_selected.connect(func(_index: int) -> void: _refilter())
    filters.add_child(category_filter)
    tier_filter = OptionButton.new()
    tier_filter.custom_minimum_size.x = 166
    for label in ["全部用途", "晨露村优先", "核心备用", "外部候选"]:
        tier_filter.add_item(label)
    tier_filter.item_selected.connect(func(_index: int) -> void: _refilter())
    filters.add_child(tier_filter)
    search_box = LineEdit.new()
    search_box.placeholder_text = "搜索名称、路径、资源ID或备注"
    search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    search_box.text_changed.connect(func(_text_value: String) -> void: _refilter())
    filters.add_child(search_box)
    count_label = _text("", 14)
    count_label.custom_minimum_size.x = 160
    filters.add_child(count_label)
    var main := HBoxContainer.new()
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_theme_constant_override("separation", 14)
    flow.add_child(main)
    var browser := VBoxContainer.new()
    browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main.add_child(browser)
    var scroller := ScrollContainer.new()
    scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    browser.add_child(scroller)
    cards = GridContainer.new()
    cards.columns = 3
    cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cards.add_theme_constant_override("h_separation", 9)
    cards.add_theme_constant_override("v_separation", 9)
    scroller.add_child(cards)
    var paging := HBoxContainer.new()
    paging.alignment = BoxContainer.ALIGNMENT_CENTER
    browser.add_child(paging)
    var prev := _button("◀ 上一页")
    prev.pressed.connect(func() -> void:
        page = maxi(0, page - 1)
        _render_page()
    )
    paging.add_child(prev)
    location_label = _text("", 14)
    location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    location_label.custom_minimum_size.x = 110
    paging.add_child(location_label)
    var next := _button("下一页 ▶")
    next.pressed.connect(func() -> void:
        page += 1
        _render_page()
    )
    paging.add_child(next)
    var sidebar := PanelContainer.new()
    sidebar.custom_minimum_size.x = 348
    main.add_child(sidebar)
    var panel_style: StyleBoxFlat = Visual.frame(Visual.NAVY, Visual.RIM, 12, 13)
    sidebar.add_theme_stylebox_override("panel", panel_style)
    var details := VBoxContainer.new()
    details.add_theme_constant_override("separation", 9)
    sidebar.add_child(details)
    details.add_child(_text("选中资源 · 替换前后对比", 19))
    var images := HBoxContainer.new()
    details.add_child(images)
    var original := VBoxContainer.new()
    original.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    images.add_child(original)
    original.add_child(_text("游戏原图"))
    original_preview = _preview()
    original.add_child(original_preview)
    var active := VBoxContainer.new()
    active.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    images.add_child(active)
    active.add_child(_text("本机当前图"))
    active_preview = _preview()
    active.add_child(active_preview)
    selection_label = _text("请选择图片", 15)
    selection_label.add_theme_color_override("font_color", GOLD)
    details.add_child(selection_label)
    usage_label = _text("", 12)
    details.add_child(usage_label)
    dimensions_label = _text("", 13)
    details.add_child(dimensions_label)
    status_label = _text("", 13)
    details.add_child(status_label)
    details.add_child(_text("自定义中文备注（存储在本机）", 13))
    note_edit = LineEdit.new()
    note_edit.placeholder_text = "例：晨露村街道旗帜 / 已替换版本2"
    note_edit.max_length = 180
    details.add_child(note_edit)
    var save_note := _button("保存备注")
    save_note.pressed.connect(_save_note)
    details.add_child(save_note)
    prompt_button = _button("✦ 生成这张素材的美化提示词")
    prompt_button.pressed.connect(_open_prompt)
    details.add_child(prompt_button)
    import_button = _button("导入图片并替换")
    import_button.pressed.connect(_choose_file)
    details.add_child(import_button)
    restore_button = _button("恢复游戏原图")
    restore_button.pressed.connect(_restore)
    details.add_child(restore_button)
    last_status = _text("动态图集必须保持原尺寸；普通图片要保持原长宽比。修改后重新进入场景生效。", 13)
    last_status.add_theme_color_override("font_color", Color("b1d2ba"))
    details.add_child(last_status)
    file_picker = FileDialog.new()
    file_picker.title = "选择本机 PNG / JPEG / WebP 图片"
    file_picker.access = FileDialog.ACCESS_FILESYSTEM
    file_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    file_picker.filters = PackedStringArray(["*.png ; PNG 图片", "*.jpg, *.jpeg ; JPEG 图片", "*.webp ; WebP 图片"])
    file_picker.file_selected.connect(_file_chosen)
    add_child(file_picker)
    pack_picker = FileDialog.new()
    pack_picker.title = "选择 DLC 素材包 manifest.json"
    pack_picker.access = FileDialog.ACCESS_FILESYSTEM
    pack_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    pack_picker.filters = PackedStringArray(["*.json ; 美术DLC清单"])
    pack_picker.file_selected.connect(_install_pack)
    add_child(pack_picker)
    _build_prompt_overlay()
    _refilter()

func open_manager() -> void:
    show()
    _refilter()
    grab_focus()

func close_manager() -> void:
    if is_instance_valid(prompt_panel):
        prompt_panel.hide()
    hide()
    closed.emit()

func _refilter() -> void:
    filtered.clear()
    var category: String = category_filter.get_item_text(category_filter.selected) if category_filter.selected > 0 else ""
    var tier_names: Array[String] = ["", "primary", "reserve_core", "reserve_external"]
    var required_tier: String = tier_names[clampi(tier_filter.selected, 0, 3)]
    var term: String = search_box.text.strip_edges().to_lower()
    for raw in all_assets:
        if not raw is Dictionary:
            continue
        var entry: Dictionary = raw
        if not category.is_empty() and str(entry.get("category", "")) != category:
            continue
        if not required_tier.is_empty() and str(entry.get("curation_tier", "")) != required_tier:
            continue
        var path: String = str(entry.get("path", ""))
        var haystack: String = str(entry.get("name", "")) + " " + path + " " + str(entry.get("entry_id", "")) + " " + Overrides.user_note(path)
        if not term.is_empty() and not haystack.to_lower().contains(term):
            continue
        filtered.append(entry)
    page = 0
    if filtered.is_empty():
        current_path = ""
    elif not filtered.any(func(row: Dictionary) -> bool: return str(row.get("path", "")) == current_path):
        current_path = str((filtered[0] as Dictionary).get("path", ""))
    _render_page()
    _show_detail()

func _render_page() -> void:
    for item in cards.get_children():
        cards.remove_child(item)
        item.queue_free()
    var pages: int = maxi(1, ceili(float(filtered.size()) / float(PAGE_SIZE)))
    page = clampi(page, 0, pages - 1)
    count_label.text = "找到 %d / %d 项" % [filtered.size(), all_assets.size()]
    location_label.text = "%d / %d" % [page + 1, pages]
    var from_index: int = page * PAGE_SIZE
    for idx in range(from_index, mini(filtered.size(), from_index + PAGE_SIZE)):
        var entry: Dictionary = filtered[idx]
        var target: String = str(entry.get("path", ""))
        var card := Button.new()
        Visual.style_button(card)
        card.custom_minimum_size = Vector2(154, 115)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.tooltip_text = target
        card.pressed.connect(func() -> void: _select(target))
        cards.add_child(card)
        var contents := VBoxContainer.new()
        contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
        contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        card.add_child(contents)
        var image := TextureRect.new()
        image.texture = Overrides.texture(target)
        image.custom_minimum_size = Vector2(138, 76)
        image.size_flags_vertical = Control.SIZE_EXPAND_FILL
        image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        image.mouse_filter = Control.MOUSE_FILTER_IGNORE
        contents.add_child(image)
        var caption := _text(str(entry.get("name", target.get_file())).substr(0, 17), 12)
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
        contents.add_child(caption)
        if Overrides.has_override(target):
            card.modulate = Color("aee8ba")

func _select(target: String) -> void:
    current_path = target
    _show_detail()

func _show_detail() -> void:
    var entry: Dictionary = Overrides.info(current_path)
    var valid: bool = not entry.is_empty()
    import_button.disabled = not valid
    prompt_button.disabled = not valid
    restore_button.disabled = not valid or not Overrides.has_override(current_path)
    note_edit.editable = valid
    if not valid:
        selection_label.text = "没有匹配的资源"
        usage_label.text = ""
        dimensions_label.text = ""
        status_label.text = ""
        original_preview.texture = null
        active_preview.texture = null
        note_edit.text = ""
        return
    var original: Texture2D = Overrides.original_texture(current_path)
    var active: Texture2D = Overrides.texture(current_path)
    original_preview.texture = original
    active_preview.texture = active
    selection_label.text = str(entry.get("name", "")) + "\n" + current_path.trim_prefix("res://")
    usage_label.text = str(entry.get("description", ""))
    var dims: Vector2 = original.get_size() if original != null else Vector2.ZERO
    dimensions_label.text = "分类：%s · 原尺寸：%d×%d · %s" % [str(entry.get("category", "")), roundi(dims.x), roundi(dims.y), "需要完全一致" if bool(entry.get("atlas", false)) else "保持长宽比"]
    var tier_key: String = str(entry.get("curation_tier", ""))
    var tier_text: String = {"primary": "晨露村优先资源", "reserve_core": "核心备用", "reserve_external": "外部候选未绑定"}.get(tier_key, "尚未分类")
    var state_text: String = "已设置单张本机替换" if Overrides.has_override(current_path) else ("使用全局DLC主题" if Overrides.pack_has_slot(current_path) else "使用原始资源")
    status_label.text = "分组：" + tier_text + "\n状态：" + str(entry.get("status", "未验收")) + "\n" + state_text
    if tier_key == "reserve_external":
        status_label.text += "\n外部候选尚未绑定场景；替换这里的图片不会自动替换游戏角色或地图。"
    note_edit.text = Overrides.user_note(current_path)

func _refresh_pack_list() -> void:
    pack_options.clear()
    pack_ids.clear()
    var current: String = Overrides.active_pack()
    var active_index: int = 0
    for pack in Overrides.list_packs():
        var id: String = str(pack.get("id", "original"))
        var index: int = pack_ids.size()
        pack_ids.append(id)
        pack_options.add_item(str(pack.get("name", id)) + " (" + str(pack.get("count", 0)) + "项)")
        if id == current:
            active_index = index
    pack_options.select(active_index)

func _apply_pack() -> void:
    if pack_options.selected < 0 or pack_options.selected >= pack_ids.size():
        return
    var chosen: String = pack_ids[pack_options.selected]
    var ok: bool = Overrides.activate_pack(chosen)
    pack_feedback.text = ("已启用整套主题："+pack_options.get_item_text(pack_options.selected)+"。重新进入地图生效。" if ok else "启用失败：原主题仍生效。")
    if ok:
        asset_changed.emit("res://assets/art/backdrops/coast/tide_lighthouse.png")
        _render_page()
        _show_detail()

func _reset_pack() -> void:
    var ok: bool = Overrides.activate_pack("original")
    pack_feedback.text = "已切换回游戏原版；单张手工覆盖仍保留。" if ok else "恢复失败，当前配置未改变。"
    if ok:
        _refresh_pack_list()
        asset_changed.emit("res://assets/art/backdrops/coast/tide_lighthouse.png")
        _render_page()
        _show_detail()

func _uninstall_pack() -> void:
    if pack_options.selected < 0 or pack_options.selected >= pack_ids.size():
        return
    var id: String = pack_ids[pack_options.selected]
    var result: bool = Overrides.uninstall_pack(id)
    pack_feedback.text = "已卸载本机DLC，原始游戏素材保留。" if result else "只能卸载用户导入的DLC，内置资源不会删除。"
    if result:
        _refresh_pack_list()
        asset_changed.emit("res://assets/art/backdrops/coast/tide_lighthouse.png")
        _render_page()
        _show_detail()

func _install_pack(path: String) -> void:
    var report: Dictionary = Overrides.install_pack(path)
    pack_feedback.text = str(report.get("message", "未知DLC导入结果。"))
    if bool(report.get("ok", false)):
        _refresh_pack_list()
        var installed_id: String = str(report.get("pack_id", ""))
        var selected: int = pack_ids.find(installed_id)
        if selected >= 0:
            pack_options.select(selected)

func _save_note() -> void:
    if current_path.is_empty():
        return
    var ok: bool = Overrides.set_note(current_path, note_edit.text)
    last_status.text = "备注已保存。" if ok else "备注保存失败，请检查设备空间。"

func _choose_file() -> void:
    if current_path.is_empty():
        return
    file_picker.popup_centered_ratio(0.83)

func _file_chosen(path: String) -> void:
    if current_path.is_empty():
        return
    var result: Dictionary = Overrides.import_image(current_path, path)
    last_status.text = str(result.get("message", "未知导入结果。"))
    if bool(result.get("ok", false)):
        asset_changed.emit(current_path)
        _render_page()
        _show_detail()

func _restore() -> void:
    if current_path.is_empty():
        return
    var ok: bool = Overrides.restore(current_path)
    last_status.text = "已恢复原图，重新进入场景生效。" if ok else "恢复失败，原配置仍保留。"
    if ok:
        asset_changed.emit(current_path)
        _render_page()
        _show_detail()


func _build_prompt_overlay() -> void:
    prompt_panel = PanelContainer.new()
    prompt_panel.name = "CArtPromptOverlay"
    prompt_panel.anchor_left = 0.13
    prompt_panel.anchor_right = 0.87
    prompt_panel.anchor_top = 0.08
    prompt_panel.anchor_bottom = 0.92
    prompt_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    prompt_panel.add_theme_stylebox_override("panel", Visual.frame(Visual.INK, Visual.GOLD, 12, 16))
    add_child(prompt_panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    prompt_panel.add_child(column)
    var heading := _text("✦ 原创高清2D美术 · 当前素材制作提示词", 20)
    heading.add_theme_color_override("font_color", Visual.GOLD)
    column.add_child(heading)
    var explanation := _text("根据素材真实用途与尺寸生成。这里只展示与复制提示词，不自动替换原图。", 13)
    column.add_child(explanation)
    prompt_text = TextEdit.new()
    prompt_text.editable = false
    prompt_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    prompt_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    prompt_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    prompt_text.add_theme_color_override("font_color", Visual.PAPER)
    column.add_child(prompt_text)
    var controls := HBoxContainer.new()
    column.add_child(controls)
    var copy := _button("复制提示词")
    copy.pressed.connect(_copy_prompt)
    controls.add_child(copy)
    var close := _button("返回素材浏览")
    close.pressed.connect(func() -> void: prompt_panel.hide())
    controls.add_child(close)
    prompt_panel.hide()

func _open_prompt() -> void:
    var entry: Dictionary = Overrides.info(current_path)
    if entry.is_empty():
        return
    prompt_text.text = VisualPrompts.for_asset(entry)
    prompt_panel.show()
    prompt_text.scroll_vertical = 0

func _copy_prompt() -> void:
    if not is_instance_valid(prompt_text) or prompt_text.text.is_empty():
        return
    DisplayServer.clipboard_set(prompt_text.text)
    last_status.text = "美化提示词已复制；请先制作和验收，再通过导入按钮替换。"
