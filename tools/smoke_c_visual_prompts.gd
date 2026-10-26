extends SceneTree
## Visual prompts / title art workbench smoke; engine QA, no game state mutations.
const Visual = preload("res://scripts/c_visual_design.gd")
const Prompts = preload("res://scripts/c_visual_prompts.gd")
const Overrides = preload("res://scripts/c_art_overrides.gd")
const Manager = preload("res://scripts/c_art_manager_ui.gd")
var issues: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool, message: String) -> void:
    if not ok:
        issues.append(message)
func _run() -> void:
    var entries: Array = Overrides.list_assets()
    _check(entries.size() >= 1100, "Main art catalog missing records")
    var item: Dictionary = Overrides.info("res://assets/art/characters/leon/walk_4dir_3frames.png")
    _check(not item.is_empty(), "Missing original main actor walk")
    var instructions: String = Prompts.for_asset(item)
    _check(instructions.contains("黎昂"), "Actor identity prompt missing")
    _check(instructions.contains("强制图集规则"), "Atlas safety notes missing")
    _check(instructions.contains("res://assets/art/characters/leon/"), "Prompt has no target path")
    var box: StyleBoxFlat = Visual.frame()
    _check(box != null and box.border_width_left > 0, "Shared visual frame absent")
    var button := Button.new()
    Visual.style_button(button)
    _check(button.has_theme_stylebox_override("normal"), "Unified button style missing")
    button.free()
    var manager: Control = Manager.new()
    root.add_child(manager)
    _check(manager.has_method("_open_prompt"), "Home art prompt dialog not installed")
    manager.call("_open_prompt")
    var popup: Control = manager.get_node_or_null("CArtPromptOverlay")
    _check(popup != null and popup.visible, "Prompt overlay not opened")
    manager.queue_free()
    if issues.is_empty():
        print("PASS C visual: art profile, frames, workbench prompt preview. Real visual QA still needed.")
        quit(0)
    else:
        for issue in issues:
            push_error(issue)
        quit(1)
