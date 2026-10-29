extends SceneTree
## Captures the actual Godot art manager framebuffer; no AI mockups.
const Manager = preload("res://scripts/c_art_manager_ui.gd")
const OUTPUT: String = "res://build/art-manager-ui-v4/"
const FRAMES: Array[Dictionary] = [
    {"file": "01_desktop_1440", "size": Vector2i(1440, 900), "themes": true},
    {"file": "02_laptop_900", "size": Vector2i(900, 700), "themes": true},
    {"file": "03_small_640", "size": Vector2i(640, 640), "themes": true},
    {"file": "04_legacy_dlc_expanded_1440", "size": Vector2i(1440, 900), "themes": false},
]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var cjk_font := SystemFont.new()
    cjk_font.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans CJK JP", "Noto Sans"])
    ThemeDB.fallback_font = cjk_font
    ThemeDB.get_default_theme().default_font = cjk_font
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
    var manager = Manager.new()
    root.add_child(manager)
    manager.open_manager()
    var evidence: Array[Dictionary] = []
    for entry in FRAMES:
        var target: Vector2i = entry["size"]
        root.size = target
        if bool(entry["themes"]) != manager.showing_theme_slots:
            manager._toggle_theme_gallery()
        if not bool(entry["themes"]):
            manager.legacy_pack_panel.show()
        for i in range(8):
            await process_frame
        manager._update_responsive_layout()
        for i in range(4):
            await process_frame
        await RenderingServer.frame_post_draw
        var img: Image = root.get_texture().get_image()
        var name: String = str(entry["file"]) + ".png"
        if img == null or img.is_empty() or img.get_width() < target.x or img.get_height() < target.y:
            push_error("Art manager framebuffer missing: " + name)
            quit(1)
            return
        var output: String = ProjectSettings.globalize_path(OUTPUT + name)
        if img.save_png(output) != OK:
            push_error("Cannot write actual Godot art manager image: " + output)
            quit(1)
            return
        evidence.append({"name": name, "size": [img.get_width(), img.get_height()],
            "gallery_columns": manager.cards.columns,
            "stacked_details": manager.main_layout is VBoxContainer,
            "semantic_gallery": manager.showing_theme_slots})
        print("CAPTURED REAL GODOT ART UI: " + name)
    var output := FileAccess.open(OUTPUT + "manifest.json", FileAccess.WRITE)
    if output == null:
        push_error("Cannot write UI capture manifest")
        quit(1)
        return
    output.store_string(JSON.stringify({"schema": "starlit.art_manager.actual_ui.v4",
        "kind": "real_godot_framebuffer",
        "source_sha": OS.get_environment("GITHUB_SHA"),
        "images": evidence, "human_approved": false}, "  ") + "\n")
    output.close()
    manager.queue_free()
    print("PASS: four actual Godot UI captures at three widths, no visual approval implied")
    quit(0)
