extends Control
## C-line home art manager. Paginated 18 thumbnails; only user:// PNG overrides change.
signal closed
signal asset_changed(path: String)
const Overrides = preload("res://scripts/c_art_overrides.gd")
const ThemeV2 = preload("res://scripts/c_art_theme_v2.gd")
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
var theme_v2_options: OptionButton
var theme_v2_ids: Array[String] = []
var theme_v2_picker: FileDialog
var theme_gallery_button: Button
var showing_theme_slots: bool = false
var active_theme_slot: String = ""
var main_layout: BoxContainer
var browser_panel: PanelContainer
var detail_panel: PanelContainer
var compact_layout: bool = false
var legacy_pack_panel: PanelContainer
var legacy_toggle_button: Button
var theme_status_label: Label
var theme_feedback_label: Label
var theme_note_label: Label

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    all_assets = Overrides.list_assets()
    _build()
    resized.connect(_on_manager_resized)
    # canvas_items stretching can keep a stable logical control width even when
    # the physical window becomes narrow. Listen to the window as well.
    get_window().size_changed.connect(_on_manager_resized)
    call_deferred("_update_responsive_layout")
    hide()

func _button(label_text: String) -> Button:
    var b := Button.new()
    b.text = label_text
    b.custom_minimum_size.y = 43
    b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    b.add_theme_font_size_override("font_size", 14)
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
    preview.custom_minimum_size = Vector2(120, 116)
    preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return preview

## Layout is driven by available viewport width, not a single overfull HBox.
## The header is fixed, the actions wrap, and the gallery/detail panels reflow.
func _build() -> void:
    var cover := ColorRect.new()
    cover.name = "ManagerBackdrop"
    cover.color = Color("07121f")
    cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(cover)

    var margin := MarginContainer.new()
    margin.name = "ManagerMargins"
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    add_child(margin)

    var shell := VBoxContainer.new()
    shell.add_theme_constant_override("separation", 10)
    margin.add_child(shell)
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 14)
    shell.add_child(header)
    var title := _text("✦ 星灯纪行  /  美术资源中心", 23)
    title.autowrap_mode = TextServer.AUTOWRAP_OFF
    title.clip_text = true
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_color_override("font_color", GOLD)
    header.add_child(title)
    var close_button := _button("返回首页")
    close_button.custom_minimum_size.x = 120
    close_button.pressed.connect(close_manager)
    header.add_child(close_button)

    var hint := _text("浏览与管理素材  ·  预检主题包  ·  原图对比  ·  本地替换不覆盖游戏文件及存档", 13)
    hint.add_theme_color_override("font_color", Visual.MUTED)
    shell.add_child(hint)

    var viewport_scroll := ScrollContainer.new()
    viewport_scroll.name = "ManagerPageScroll"
    viewport_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    viewport_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    viewport_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    shell.add_child(viewport_scroll)
    var body := VBoxContainer.new()
    body.name = "ManagerPageBody"
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 14)
    viewport_scroll.add_child(body)

    legacy_pack_panel = PanelContainer.new()
    legacy_pack_panel.name = "LegacyDlcTools"
    legacy_pack_panel.add_theme_stylebox_override("panel", Visual.frame(Color("0d2334"), Visual.RIM, 11, 13))
    body.add_child(legacy_pack_panel)
    var pack_column := VBoxContainer.new()
    pack_column.add_theme_constant_override("separation", 9)
    legacy_pack_panel.add_child(pack_column)
    var pack_heading := _text("高级设置  /  旧版 DLC", 16)
    pack_heading.add_theme_color_override("font_color", GOLD)
    pack_column.add_child(pack_heading)
    var pack_row := HFlowContainer.new()
    pack_row.add_theme_constant_override("h_separation", 10)
    pack_row.add_theme_constant_override("v_separation", 9)
    pack_column.add_child(pack_row)
    pack_options = OptionButton.new()
    pack_options.custom_minimum_size = Vector2(275, 44)
    pack_options.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    pack_row.add_child(pack_options)
    var apply_pack := _button("应用所选画风")
    apply_pack.pressed.connect(_apply_pack)
    pack_row.add_child(apply_pack)
    var reset_pack := _button("恢复全部原始美术")
    reset_pack.pressed.connect(_reset_pack)
    pack_row.add_child(reset_pack)
    var install_pack := _button("导入DLC")
    install_pack.pressed.connect(func() -> void: pack_picker.popup_centered_ratio(0.8))
    pack_row.add_child(install_pack)
    var remove_pack := _button("卸载所选DLC")
    remove_pack.pressed.connect(_uninstall_pack)
    pack_row.add_child(remove_pack)
    pack_feedback = _text("仅卸载用户导入的DLC；内置素材与个人备注不会被删除。", 12)
    pack_feedback.add_theme_color_override("font_color", Color("b1d2ba"))
    pack_column.add_child(pack_feedback)

    var semantic_panel := PanelContainer.new()
    semantic_panel.add_theme_stylebox_override("panel", Visual.frame(Color("0d2334"), Visual.RIM, 11, 13))
    body.add_child(semantic_panel)
    body.move_child(semantic_panel, 0)
    legacy_toggle_button = _button("旧版 DLC 管理（展开）  ▾")
    legacy_toggle_button.name = "LegacyDlcToggle"
    legacy_toggle_button.tooltip_text = "旧版主题存在历史语义错配；已隔离的主题不会允许应用。"
    legacy_toggle_button.pressed.connect(_toggle_legacy_pack_tools)
    body.add_child(legacy_toggle_button)
    body.move_child(legacy_toggle_button, 1)
    legacy_pack_panel.hide()
    var semantic_column := VBoxContainer.new()
    semantic_column.add_theme_constant_override("separation", 9)
    semantic_panel.add_child(semantic_column)
    var semantic_heading := _text("01   正式高清2D主题", 18)
    semantic_heading.add_theme_color_override("font_color", GOLD)
    semantic_column.add_child(semantic_heading)
    theme_status_label = _text("", 12)
    theme_status_label.name = "ActiveThemeStatus"
    theme_status_label.add_theme_color_override("font_color", Visual.MUTED)
    semantic_column.add_child(theme_status_label)
    theme_feedback_label = _text("请选择一套完整主题，预检通过后再应用。", 12)
    theme_feedback_label.name = "ThemeActionFeedback"
    theme_feedback_label.add_theme_color_override("font_color", Visual.MUTED)
    semantic_column.add_child(theme_feedback_label)
    var semantic_row := HFlowContainer.new()
    semantic_row.add_theme_constant_override("h_separation", 10)
    semantic_row.add_theme_constant_override("v_separation", 9)
    semantic_column.add_child(semantic_row)
    theme_v2_options = OptionButton.new()
    theme_v2_options.custom_minimum_size = Vector2(275, 44)
    theme_v2_options.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    semantic_row.add_child(theme_v2_options)
    var preview_theme := _button("预检并应用完整主题")
    preview_theme.pressed.connect(_apply_theme_v2)
    semantic_row.add_child(preview_theme)
    var restore_theme := _button("恢复基础美术")
    restore_theme.pressed.connect(_restore_theme_v2)
    semantic_row.add_child(restore_theme)
    var import_theme := _button("导入完整V2主题")
    import_theme.pressed.connect(func() -> void: theme_v2_picker.popup_centered_ratio(0.8))
    semantic_row.add_child(import_theme)
    var gallery_controls := HFlowContainer.new()
    gallery_controls.add_theme_constant_override("h_separation", 12)
    gallery_controls.add_theme_constant_override("v_separation", 8)
    semantic_column.add_child(gallery_controls)
    theme_gallery_button = _button("浏览正式主题槽位（%d）" % ThemeV2.list_slots().size())
    theme_gallery_button.pressed.connect(_toggle_theme_gallery)
    gallery_controls.add_child(theme_gallery_button)
    # Never put a wrapped Label in HFlow: Godot may allocate it only one
    # character's width and stretch the entire page to an absurd height.
    theme_note_label = _text("只读语义检索与原图对比；候选素材不等于已在场景中使用。", 12)
    theme_note_label.name = "SemanticHelpText"
    theme_note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    theme_note_label.add_theme_color_override("font_color", Visual.MUTED)
    semantic_column.add_child(theme_note_label)
    _refresh_theme_v2()
    _refresh_pack_list()
    _refresh_theme_status()

    var browser_heading := _text("02   素材图库与原图对比", 17)
    browser_heading.add_theme_color_override("font_color", GOLD)
    body.add_child(browser_heading)
    var filters := HFlowContainer.new()
    filters.add_theme_constant_override("h_separation", 10)
    filters.add_theme_constant_override("v_separation", 9)
    body.add_child(filters)
    category_filter = OptionButton.new()
    category_filter.custom_minimum_size = Vector2(185, 42)
    category_filter.add_item("全部分类")
    for category in Overrides.categories():
        category_filter.add_item(str(category))
    category_filter.item_selected.connect(func(_index: int) -> void: _refilter())
    filters.add_child(category_filter)
    tier_filter = OptionButton.new()
    tier_filter.custom_minimum_size = Vector2(160, 42)
    for label in ["全部用途", "晨露村优先", "核心备用", "外部候选"]:
        tier_filter.add_item(label)
    tier_filter.item_selected.connect(func(_index: int) -> void: _refilter())
    filters.add_child(tier_filter)
    search_box = LineEdit.new()
    search_box.custom_minimum_size = Vector2(260, 42)
    search_box.placeholder_text = "搜索名称 / 资源ID / 路径 / 备注"
    search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    search_box.text_changed.connect(func(_text_value: String) -> void: _refilter())
    filters.add_child(search_box)
    count_label = _text("", 13)
    count_label.custom_minimum_size.x = 160
    filters.add_child(count_label)

    main_layout = HBoxContainer.new()
    main_layout.name = "ManagerContentColumns"
    main_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_layout.add_theme_constant_override("separation", 14)
    body.add_child(main_layout)
    browser_panel = PanelContainer.new()
    browser_panel.name = "ManagerGallery"
    browser_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    browser_panel.add_theme_stylebox_override("panel", Visual.frame(Color("0b1c2b"), Color("496173"), 10, 13))
    main_layout.add_child(browser_panel)
    var browser := VBoxContainer.new()
    browser.add_theme_constant_override("separation", 10)
    browser_panel.add_child(browser)
    var gallery_hint := _text("资源缩略图  /  单击查看详细信息", 13)
    gallery_hint.add_theme_color_override("font_color", Visual.MUTED)
    browser.add_child(gallery_hint)
    var scroller := ScrollContainer.new()
    scroller.custom_minimum_size.y = 388
    scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    browser.add_child(scroller)
    cards = GridContainer.new()
    cards.columns = 3
    cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cards.add_theme_constant_override("h_separation", 10)
    cards.add_theme_constant_override("v_separation", 10)
    scroller.add_child(cards)
    var paging := HBoxContainer.new()
    paging.alignment = BoxContainer.ALIGNMENT_CENTER
    paging.add_theme_constant_override("separation", 12)
    browser.add_child(paging)
    var prev := _button("◀ 上一页")
    prev.pressed.connect(func() -> void:
        page = maxi(0, page - 1)
        _render_page()
    )
    paging.add_child(prev)
    location_label = _text("", 14)
    location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    location_label.custom_minimum_size.x = 85
    paging.add_child(location_label)
    var next := _button("下一页 ▶")
    next.pressed.connect(func() -> void:
        page += 1
        _render_page()
    )
    paging.add_child(next)

    detail_panel = PanelContainer.new()
    detail_panel.name = "ManagerDetails"
    detail_panel.custom_minimum_size.x = 366
    detail_panel.add_theme_stylebox_override("panel", Visual.frame(Visual.NAVY, Visual.RIM, 10, 13))
    main_layout.add_child(detail_panel)
    var details := VBoxContainer.new()
    details.add_theme_constant_override("separation", 9)
    detail_panel.add_child(details)
    var detail_heading := _text("资源详情  /  替换前后对比", 17)
    detail_heading.add_theme_color_override("font_color", GOLD)
    details.add_child(detail_heading)
    var images := HBoxContainer.new()
    images.add_theme_constant_override("separation", 8)
    details.add_child(images)
    var original := VBoxContainer.new()
    original.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    images.add_child(original)
    original.add_child(_text("原始图片", 12))
    original_preview = _preview()
    original.add_child(original_preview)
    var active := VBoxContainer.new()
    active.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    images.add_child(active)
    active.add_child(_text("当前应用", 12))
    active_preview = _preview()
    active.add_child(active_preview)
    selection_label = _text("请选择图片", 14)
    selection_label.add_theme_color_override("font_color", GOLD)
    details.add_child(selection_label)
    usage_label = _text("", 12)
    details.add_child(usage_label)
    dimensions_label = _text("", 12)
    details.add_child(dimensions_label)
    status_label = _text("", 12)
    details.add_child(status_label)
    details.add_child(_text("资源备注（仅保存在本机）", 12))
    note_edit = LineEdit.new()
    note_edit.placeholder_text = "填写场景用途 / 替换版本"
    note_edit.max_length = 180
    details.add_child(note_edit)
    var save_note := _button("保存备注")
    save_note.pressed.connect(_save_note)
    details.add_child(save_note)
    prompt_button = _button("生成美术制作提示词")
    prompt_button.pressed.connect(_open_prompt)
    details.add_child(prompt_button)
    import_button = _button("导入图片并替换")
    import_button.pressed.connect(_choose_file)
    details.add_child(import_button)
    restore_button = _button("恢复此资源的原图")
    restore_button.pressed.connect(_restore)
    details.add_child(restore_button)
    last_status = _text("动态图集需保持原尺寸；普通图片保持长宽比。重新进入场景生效。", 12)
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
    theme_v2_picker = FileDialog.new()
    theme_v2_picker.title = "导入V2整套美术主题 art_theme.json"
    theme_v2_picker.access = FileDialog.ACCESS_FILESYSTEM
    theme_v2_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    theme_v2_picker.filters = PackedStringArray(["*.json ; V2完整主题包"])
    theme_v2_picker.file_selected.connect(_install_theme_v2)
    add_child(theme_v2_picker)
    _build_prompt_overlay()
    # Show actual official slots first; slim builds may have no legacy assets.
    showing_theme_slots = true
    theme_gallery_button.text = "切换到旧素材目录"
    category_filter.disabled = true
    tier_filter.disabled = true
    _refilter()


func _toggle_legacy_pack_tools() -> void:
    legacy_pack_panel.visible = not legacy_pack_panel.visible
    legacy_toggle_button.text = "收起旧版 DLC 管理  ▴" if legacy_pack_panel.visible else "旧版 DLC 管理（展开）  ▾"


func _refresh_theme_status() -> void:
    if not is_instance_valid(theme_status_label):
        return
    var active_id: String = ThemeV2.active_id()
    var count: int = ThemeV2.list_slots().size()
    var prefix: String = "当前：原始兼容画风" if active_id == "original" else "当前主题：" + active_id
    theme_status_label.text = prefix + "  ·  正式注册 %d 项  ·  画面人工验收待签收" % count


func _on_manager_resized() -> void:
    if is_node_ready():
        call_deferred("_update_responsive_layout")


func _update_responsive_layout() -> void:
    if not is_instance_valid(main_layout) or not is_instance_valid(cards):
        return
    if size.x <= 0:
        return
    # Use the physical window for breakpoint decisions: under canvas_items
    # stretch the Control may still report the project's 1152px logical width.
    var window_width: float = float(get_window().size.x)
    if window_width <= 0.0:
        return
    var compact: bool = window_width < 1050.0
    if compact != compact_layout:
        var host: Node = main_layout.get_parent()
        var at: int = main_layout.get_index()
        var replacement: BoxContainer
        if compact:
            replacement = VBoxContainer.new()
        else:
            replacement = HBoxContainer.new()
        replacement.name = "ManagerContentColumns"
        replacement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        replacement.add_theme_constant_override("separation", 14)
        host.add_child(replacement)
        host.move_child(replacement, at)
        browser_panel.reparent(replacement)
        detail_panel.reparent(replacement)
        main_layout.queue_free()
        main_layout = replacement
        compact_layout = compact
    detail_panel.custom_minimum_size.x = 0 if compact else 366
    var usable_width: float = minf(size.x, window_width)
    var available: float = maxf(320.0, usable_width - 92.0 - (0.0 if compact else 380.0))
    cards.columns = clampi(int(floor(available / 177.0)), 1, 5)

func open_manager() -> void:
    show()
    _refilter()
    call_deferred("_update_responsive_layout")
    # The root Control is not focusable; focus the real search field instead.
    search_box.call_deferred("grab_focus")

func close_manager() -> void:
    if is_instance_valid(prompt_panel):
        prompt_panel.hide()
    hide()
    closed.emit()

func _refilter() -> void:
    filtered.clear()
    if showing_theme_slots:
        var query: String = search_box.text.strip_edges().to_lower()
        for row in ThemeV2.list_slots():
            var ident: String = str(row.get("id", ""))
            var source: String = str(row.get("source", ""))
            var category: String = str(row.get("category", ""))
            if not query.is_empty() and not (ident + " " + source + " " + category).to_lower().contains(query):
                continue
            filtered.append({"slot": ident, "path": source, "name": ident,
                "category": category, "stage": str(row.get("stage", "unreviewed")),
                "required": bool(row.get("required", false))})
        page = 0
        if filtered.is_empty():
            active_theme_slot = ""
        elif not filtered.any(func(item: Dictionary) -> bool: return str(item.get("slot", "")) == active_theme_slot):
            active_theme_slot = str((filtered[0] as Dictionary).get("slot", ""))
        _render_page()
        _show_detail()
        return
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
    count_label.text = "主题槽位 %d 项" % filtered.size() if showing_theme_slots else "素材 %d / %d" % [filtered.size(), all_assets.size()]
    location_label.text = "%d / %d" % [page + 1, pages]
    var from_index: int = page * PAGE_SIZE
    for idx in range(from_index, mini(filtered.size(), from_index + PAGE_SIZE)):
        var entry: Dictionary = filtered[idx]
        var target: String = str(entry.get("path", ""))
        var card := Button.new()
        card.custom_minimum_size = Vector2(154, 115)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.tooltip_text = target
        var semantic_slot: String = str(entry.get("slot", ""))
        Visual.style_button(card, (semantic_slot == active_theme_slot) if showing_theme_slots else (target == current_path))
        if showing_theme_slots:
            card.pressed.connect(func() -> void: _select_theme_slot(semantic_slot))
        else:
            card.pressed.connect(func() -> void: _select(target))
        cards.add_child(card)
        var contents := VBoxContainer.new()
        contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
        contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        card.add_child(contents)
        var image := TextureRect.new()
        if showing_theme_slots:
            image.texture = ThemeV2.texture(semantic_slot) if ThemeV2.is_active() else Overrides.original_texture(target)
        else:
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
        if not showing_theme_slots and Overrides.has_override(target):
            card.modulate = Color("aee8ba")

func _select(target: String) -> void:
    current_path = target
    _highlight_selected_card()
    _show_detail()

func _show_detail() -> void:
    if showing_theme_slots:
        _show_theme_detail()
        return
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
    selection_label.text = str(entry.get("name", "")).substr(0, 42) + "\n" + current_path.get_file()
    selection_label.tooltip_text = current_path
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

func _select_theme_slot(semantic_id: String) -> void:
    active_theme_slot = semantic_id
    _highlight_selected_card()
    _show_detail()


func _highlight_selected_card() -> void:
    # Refresh only button emphasis: preserve gallery scroll and loaded textures.
    var start: int = page * PAGE_SIZE
    for idx in range(cards.get_child_count()):
        var card: Button = cards.get_child(idx) as Button
        var row_index: int = start + idx
        if card == null or row_index >= filtered.size():
            continue
        var row: Dictionary = filtered[row_index]
        var selected: bool = str(row.get("slot", "")) == active_theme_slot if showing_theme_slots else str(row.get("path", "")) == current_path
        Visual.style_button(card, selected)

func _toggle_theme_gallery() -> void:
    showing_theme_slots = not showing_theme_slots
    active_theme_slot = ""
    theme_gallery_button.text = "切换到旧素材目录" if showing_theme_slots else "浏览正式主题槽位（%d）" % ThemeV2.list_slots().size()
    category_filter.disabled = showing_theme_slots
    tier_filter.disabled = showing_theme_slots
    _refilter()

## Never use legacy gallery import APIs on semantic-only runtime slots.
func _show_theme_detail() -> void:
    import_button.disabled = true
    restore_button.disabled = true
    prompt_button.disabled = true
    note_edit.editable = false
    note_edit.text = ""
    var selected: Dictionary = {}
    for row in filtered:
        if str(row.get("slot", "")) == active_theme_slot:
            selected = row
            break
    if selected.is_empty():
        selection_label.text = "无匹配的正式主题槽位"
        usage_label.text = ""
        status_label.text = ""
        dimensions_label.text = ""
        original_preview.texture = null
        active_preview.texture = null
        return
    var source: String = str(selected.get("path", ""))
    var baseline: Texture2D = Overrides.original_texture(source)
    var active: Texture2D = ThemeV2.texture(active_theme_slot) if ThemeV2.is_active() else baseline
    original_preview.texture = baseline
    active_preview.texture = active
    selection_label.text = active_theme_slot.substr(0, 44) + "\n" + source.get_file()
    selection_label.tooltip_text = active_theme_slot + "  /  " + source
    usage_label.text = "语义分类：" + str(selected.get("category", "unknown"))
    var size: Vector2 = baseline.get_size() if baseline != null else Vector2.ZERO
    dimensions_label.text = "原始画布 %d×%d · %s" % [
        roundi(size.x), roundi(size.y),
        "关键素材" if bool(selected.get("required", false)) else "扩展素材"]
    status_label.text = "当前主题：" + ThemeV2.active_id() + "\n资源状态：" + (
        "可加载" if active != null else "缺失（需要修复）") + "\n审核阶段：" + str(selected.get("stage", "unreviewed")) + "\n画面效果需实机截图签收。"

func _install_theme_v2(path: String) -> void:
    var result: Dictionary = ThemeV2.install_pack(path)
    pack_feedback.text = str(result.get("message","主题导入失败。"))
    theme_feedback_label.text = pack_feedback.text
    if bool(result.get("ok",false)):
        _refresh_theme_v2()
        _refresh_theme_status()
        var selected: int = theme_v2_ids.find(str(result.get("id","")))
        if selected >= 0:
            theme_v2_options.select(selected)

func _refresh_theme_v2() -> void:
    theme_v2_options.clear()
    theme_v2_ids.clear()
    var active: String = ThemeV2.active_id()
    for entry in ThemeV2.list_themes():
        var id: String = str(entry.get("id",""))
        theme_v2_ids.append(id)
        theme_v2_options.add_item(str(entry.get("name",id)))
        if active == id:
            theme_v2_options.select(theme_v2_ids.size()-1)

func _apply_theme_v2() -> void:
    var index: int = theme_v2_options.selected
    if index < 0 or index >= theme_v2_ids.size():
        return
    var selected: String = theme_v2_ids[index]
    var report: Dictionary = ThemeV2.report(selected)
    if not bool(report.get("ok",false)):
        pack_feedback.text = "V2预检失败，保持原主题：" + JSON.stringify(report.get("missing",[]))
        theme_feedback_label.text = "应用失败：主题不完整。原主题保持不变；详情见旧DLC记录。"
        return
    if not ThemeV2.activate(selected):
        pack_feedback.text = "V2配置写入失败，原主题没有改变。"
        theme_feedback_label.text = pack_feedback.text
        return
    _refresh_theme_status()
    pack_feedback.text = "V2已应用：%d/%d资源可加载。视觉验收仍需截图签收；重进地图刷新。" % [int(report.get("present",0)),int(report.get("total",0))]
    theme_feedback_label.text = pack_feedback.text
    asset_changed.emit("res://assets/art/backdrops/coast/tide_lighthouse.png")
    _render_page()
    _show_detail()

func _restore_theme_v2() -> void:
    if ThemeV2.activate("original"):
        _refresh_theme_v2()
        _refresh_theme_status()
        pack_feedback.text = "已恢复原始兼容美术，旧DLC及个人素材未删除。重新进入地图刷新。"
        theme_feedback_label.text = pack_feedback.text
        asset_changed.emit("res://assets/art/backdrops/coast/tide_lighthouse.png")
        _render_page()
        _show_detail()

func _refresh_pack_list() -> void:
    pack_options.clear()
    pack_ids.clear()
    var current: String = Overrides.active_pack()
    var active_index: int = 0
    for pack in Overrides.list_packs():
        var id: String = str(pack.get("id", "original"))
        var index: int = pack_ids.size()
        pack_ids.append(id)
        var quarantined: bool = bool(pack.get("disabled",false))
        pack_options.add_item(str(pack.get("name", id)) + " (" + str(pack.get("count", 0)) + "项)" + (" · 错配已隔离" if quarantined else ""))
        pack_options.set_item_disabled(index, quarantined)
        if id == current:
            active_index = index
    pack_options.select(active_index)

func _apply_pack() -> void:
    if pack_options.selected < 0 or pack_options.selected >= pack_ids.size():
        return
    var chosen: String = pack_ids[pack_options.selected]
    var report: Dictionary = Overrides.pack_report(chosen)
    var ok: bool = bool(report.get("ok", false)) and Overrides.activate_pack(chosen)
    if ok:
        pack_feedback.text = "主题已切换：%d项可替换，%d项保持原图；%d项仍优先使用个人替换。重新进入地图后更新。" % [
            int(report.get("usable", 0)), int(report.get("fallback", 0)), int(report.get("personal_overrides", 0))]
    else:
        pack_feedback.text = str(report.get("message","启用失败：原主题仍生效。"))
    if ok:
        asset_changed.emit("res://assets/art/backdrops/coast/tide_lighthouse.png")
        _render_page()
        _show_detail()

func _reset_pack() -> void:
    var ok: bool = Overrides.restore_everything()
    pack_feedback.text = "全部美术已恢复游戏原版；DLC安装记录和个人备注保留。" if ok else "恢复失败，当前配置未改变。"
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
