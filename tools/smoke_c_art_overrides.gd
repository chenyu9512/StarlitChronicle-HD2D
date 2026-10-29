extends SceneTree
## C art gallery and user data persistence smoke. Run with Godot --headless during batched QA.
const Overrides = preload("res://scripts/c_art_overrides.gd")
const Interface = preload("res://scripts/first_act_ui.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_verify")

func check(value: bool, message: String) -> void:
    if not value:
        errors.append(message)

func _verify() -> void:
    var catalog: Array = Overrides.list_assets()
    check(catalog.size() >= 548, "Art inventory incomplete")
    var keys: Dictionary = {}
    for entry in catalog:
        var path: String = str(entry.get("path", ""))
        check(not keys.has(path), "Duplicate catalog path: " + path)
        keys[path] = true
        check(path.begins_with("res://assets/"), "Unexpected non-art resource path: " + path)
        check(not str(entry.get("name", "")).is_empty(), "Missing readable name: " + path)
    var original: String = "res://assets/art/backdrops/coast/tide_lighthouse.png"
    check(Overrides.has_slot(original), "Title background is not replaceable")
    check(Overrides.has_slot("res://assets/maps/village.png"), "Legacy map not registered")
    check(Overrides.has_slot("res://assets/art/interiors/morning_dew_inn/inn_tileset.svg"), "Interior tileset not registered")
    check(not Overrides.has_slot("res://scripts/first_act.gd"), "Script path must not be replaceable")
    var baseline: Texture2D = Overrides.original_texture(original)
    check(baseline != null, "Original background texture missing")
    if baseline != null and not Overrides.has_override(original):
        var size: Vector2i = Vector2i(baseline.get_size())
        var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
        image.fill(Color(0.28, 0.62, 0.81))
        var test_path: String = "user://c_art_qa_input.png"
        check(image.save_png(test_path) == OK, "Cannot create QA PNG")
        var unsupported: Dictionary = Overrides.import_image(original, "user://c_art_qa_input.gd")
        check(not bool(unsupported.get("ok", true)), "Script import must be rejected")
        var result: Dictionary = Overrides.import_image(original, test_path)
        check(bool(result.get("ok", false)), "Safe PNG override failed: " + str(result.get("message", "")))
        check(Overrides.has_override(original), "Stored PNG mapping missing")
        check(Overrides.texture(original) is Texture2D, "Replacement texture missing")
        check(Overrides.restore(original), "Restore original failed")
        check(not Overrides.has_override(original), "Restore left mapping behind")
        check(Overrides.texture(original) is Texture2D, "Default texture missing after restore")
        DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
    var ui := Interface.new()
    root.add_child(ui)
    check(ui.title_overlay != null, "Home title missing")
    check(ui.art_manager != null, "Art manager not embedded on home screen")
    if ui.art_manager != null:
        ui.art_manager.open_manager()
        check(ui.art_manager.visible, "Cannot open home gallery")
        check(ui.art_manager.all_assets.size() >= 548, "UI lost catalog")
        check(ui.art_manager.cards.get_child_count() <= 18, "Pagination is disabled")
        ui.art_manager.close_manager()
        check(not ui.art_manager.visible, "Gallery cannot return to title")
    ui.queue_free()
    if errors.is_empty():
        print("PASS C art: 548 image slots, names, GUI thumbnails, safe import, restore and original fallback")
        quit(0)
    else:
        for issue in errors:
            push_error(issue)
        quit(1)
