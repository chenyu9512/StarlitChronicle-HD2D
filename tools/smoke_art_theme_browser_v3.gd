extends SceneTree
## Actual Godot UI regression for V3's semantic theme browser.
const Themes = preload("res://scripts/c_art_theme_v2.gd")
const Manager = preload("res://scripts/c_art_manager_ui.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var canonical: Array[Dictionary] = Themes.list_slots()
    if canonical.size() != 109:
        push_error("Semantic registry expected exactly 109 authoritative slots")
        quit(1)
        return
    var unique: Dictionary = {}
    for slot in canonical:
        var name: String = str(slot.get("id", ""))
        if name.is_empty() or unique.has(name):
            push_error("Duplicate or empty semantic identity: " + name)
            quit(1)
            return
        unique[name] = true
    var manager = Manager.new()
    root.add_child(manager)
    if not manager.showing_theme_slots or manager.legacy_pack_panel.visible:
        push_error("Official gallery must be visible; legacy DLC controls should start collapsed")
        manager.queue_free()
        quit(1)
        return
    if manager.filtered.size() != 109 or manager.cards.get_child_count() != 18:
        push_error("UI must show 109 canonical slots in 18-thumbnail pages")
        manager.queue_free()
        quit(1)
        return
    manager.search_box.text = "interior.tavern."
    manager._refilter()
    if manager.filtered.size() != 15:
        push_error("Search did not find 15 explicit tavern theme slots")
        manager.queue_free()
        quit(1)
        return
    manager._select_theme_slot("interior.tavern.tavern_counter")
    if not manager.import_button.disabled or not manager.status_label.text.contains("实机截图签收"):
        push_error("Semantic-only preview must be readonly and non-misleading")
        manager.queue_free()
        quit(1)
        return
    manager._toggle_theme_gallery()
    if manager.showing_theme_slots or manager.tier_filter.disabled:
        push_error("Legacy asset gallery state was not restored")
        manager.queue_free()
        quit(1)
        return
    manager._toggle_legacy_pack_tools()
    if not manager.legacy_pack_panel.visible or manager.pack_options == null:
        push_error("Legacy DLC controls must remain accessible by an explicit toggle")
        manager.queue_free()
        quit(1)
        return
    manager._toggle_legacy_pack_tools()
    if manager.legacy_pack_panel.visible:
        push_error("Legacy DLC controls did not collapse")
        manager.queue_free()
        quit(1)
        return
    # Regression from the real screenshot: horizontal actions may not become
    # 300px tall columns, and the details panel must never crush gallery labels.
    manager.open_manager()
    var background: ColorRect = manager.get_node("ManagerBackdrop") as ColorRect
    if background == null or background.color.a < 0.99:
        push_error("Art manager must completely cover the underlying game")
        manager.queue_free()
        quit(1)
        return
    for resolution in [Vector2i(1440, 900), Vector2i(900, 700), Vector2i(640, 640), Vector2i(1440, 900)]:
        root.size = resolution
        for frame in range(4):
            await process_frame
        manager._update_responsive_layout()
        for frame in range(3):
            await process_frame
        var compact: bool = resolution.x < 1050
        if (manager.main_layout is VBoxContainer) != compact:
            push_error("Art layout did not reflow for resolution " + str(resolution)
                + " (window=" + str(root.size) + ", control=" + str(manager.size)
                + ", stacked=" + str(manager.main_layout is VBoxContainer) + ")")
            manager.queue_free()
            quit(1)
            return
        # Human-visible regression: the help sentence must never become a
        # one-glyph-wide, full-height vertical text column.
        if manager.theme_note_label.size.x < 180.0 or manager.theme_note_label.size.y > 72.0:
            push_error("Official theme description collapsed into a vertical column at "
                + str(resolution) + ": " + str(manager.theme_note_label.size))
            manager.queue_free()
            quit(1)
            return
        if manager.cards.columns < 1 or manager.cards.columns > 5:
            push_error("Invalid adaptive gallery columns")
            manager.queue_free()
            quit(1)
            return
        if background.size.x + 2.0 < manager.size.x:
            push_error("Opaque manager backdrop does not cover viewport")
            manager.queue_free()
            quit(1)
            return
        var panel_a: Rect2 = manager.browser_panel.get_global_rect()
        var panel_b: Rect2 = manager.detail_panel.get_global_rect()
        if compact and panel_b.position.y < panel_a.end.y - 8:
            push_error("Compact sidebar overlaps gallery")
            manager.queue_free()
            quit(1)
            return
        if not compact and panel_b.position.x < panel_a.end.x - 8:
            push_error("Wide sidebar overlaps gallery")
            manager.queue_free()
            quit(1)
            return
    manager.search_box.text = ""
    manager._toggle_theme_gallery()
    if not manager.showing_theme_slots or manager.filtered.size() != 109:
        push_error("Returning to official themes must restore all registered entries")
        manager.queue_free()
        quit(1)
        return
    manager.close_manager()
    manager.queue_free()
    print("PASS: 109 theme slots, 15 tavern entries, 1440/900/640/1440 physical-window reflow, opaque overlay and safe legacy return.")
    quit(0)
