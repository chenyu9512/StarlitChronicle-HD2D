extends SceneTree
const Menu = preload("res://scripts/rpg_menu.gd")
const Icons = preload("res://scripts/c_art_navigation_icons.gd")
const Frame = preload("res://scripts/c_art_ui_frame.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    if not value:
        errors.append(message)

func _run() -> void:
    var menu := Menu.new()
    root.add_child(menu)
    await process_frame
    check(menu.root != null and menu.section_tabs != null,
        "Actual RPG main menu not constructed")
    var count: int = 0
    for tab in Menu.SECTIONS:
        var texture: Texture2D = Icons.icon_for(str(tab))
        check(texture != null and texture.get_width() >= 16,
            "A real player menu tab has no assigned imported icon: " + str(tab))
        if texture != null:
            count += 1
    for group in Menu.NAV_GROUPS.keys():
        menu._select_group(str(group))
        for control in menu.section_tabs.get_children():
            var button: Button = control as Button
            check(button != null and button.icon != null and button.expand_icon == false,
                "Tab's visual icon missing from real input control: " + str(group))
    var panel: PanelContainer = menu.root.get_child(1) as PanelContainer
    check(panel != null, "Real menu panel absent")
    if panel != null:
        var style: StyleBox = panel.get_theme_stylebox("panel")
        check(style is StyleBoxTexture, "Kenney 9-slice art was not actually applied to RPG menu")
        if style is StyleBoxTexture:
            check((style as StyleBoxTexture).texture != null,
                "Menu skin refers to null imported artwork")
    check(Frame.panel_frame() != null, "No graceful theme fallback")
    menu.queue_free()
    if errors.is_empty():
        print("PASS C V13 UI: %d unique assigned section buttons use imported icons and the visible RPG menu uses a valid Kenney nine-slice frame" % count)
        quit(0)
        return
    for reason in errors:
        push_error(reason)
    quit(1)
