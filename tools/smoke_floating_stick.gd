extends SceneTree
## Headless regression test of the actual FirstActUI floating joystick in Godot 4.7.2.
const TouchFixture = preload("res://tools/tests/floating_stick_fixture.gd")
var failures: Array[String] = []
var movement: Vector2 = Vector2.ZERO

func _initialize() -> void:
    call_deferred("_run")

func _assert(condition: bool, description: String) -> void:
    if condition:
        print("PASS: ", description)
    else:
        failures.append(description)
        push_error("FAIL: " + description)

func _near(a: Vector2, b: Vector2, tolerance: float = 0.015) -> bool:
    return a.distance_to(b) < tolerance

func _touch(finger: int, down: bool, pos: Vector2) -> InputEventScreenTouch:
    var event := InputEventScreenTouch.new()
    event.index = finger
    event.pressed = down
    event.position = pos
    return event

func _drag(finger: int, pos: Vector2) -> InputEventScreenDrag:
    var event := InputEventScreenDrag.new()
    event.index = finger
    event.position = pos
    return event

func _run() -> void:
    print("FLOATING STICK SMOKE: starting")
    var ui = TouchFixture.new()
    root.add_child(ui)
    await process_frame
    ui.move_changed.connect(func(direction: Vector2) -> void: movement = direction)

    var size: Vector2 = ui.get_viewport().get_visible_rect().size
    ui._unhandled_input(_touch(2, true, Vector2(size.x * 0.83, size.y * 0.55)))
    _assert(ui.stick_touch_id == -1, "Right-thumb taps never create movement")
    ui._unhandled_input(_touch(2, true, Vector2(size.x * 0.40, size.y * 0.08)))
    _assert(ui.stick_touch_id == -1, "Top HUD taps never create movement")

    var start := Vector2(415, 330)
    ui._unhandled_input(_touch(3, true, start))
    _assert(ui.stick_touch_id == 3, "First touch owns the floating stick")
    _assert(ui.floating_stick.visible, "Stick appears at touch location")
    _assert(_near(ui.floating_stick.position + ui.floating_stick.size * 0.5, start), "Ring is centered at first touch")
    _assert(_near(movement, Vector2.ZERO), "Initial touch does not move character")

    ui._input(_drag(3, start + Vector2(100, 0)))
    _assert(_near(movement, Vector2.RIGHT), "Swipe right moves right at full speed")
    _assert(_near(ui.floating_knob.position, Vector2(101, 47)), "Knob travel is clamped to radius")

    ui._input(_drag(3, start + Vector2(100, -100)))
    _assert(_near(movement, Vector2(1, -1).normalized()), "Diagonal swipe moves diagonally")
    ui._input(_drag(3, start + Vector2(5, 0)))
    _assert(_near(movement, Vector2.ZERO), "Small swipe is inside deadzone")
    ui._input(_drag(3, start + Vector2(32, 0)))
    _assert(_near(movement, Vector2(0.5, 0)), "Partial swipe produces analog half speed")

    ui._input(_drag(7, start + Vector2(0, 100)))
    _assert(_near(movement, Vector2(0.5, 0)), "Another finger cannot hijack the stick")
    ui._unhandled_input(_touch(7, true, Vector2(550, 400)))
    _assert(ui.stick_touch_id == 3, "Second touch does not re-center active stick")
    ui._input(_touch(7, false, Vector2(550, 400)))
    _assert(ui.stick_touch_id == 3, "Non-owner release does not stop movement")

    ui._input(_touch(3, false, start))
    _assert(ui.stick_touch_id == -1 and not ui.floating_stick.visible, "Owner release hides stick")
    _assert(_near(movement, Vector2.ZERO), "Owner release stops movement")

    var dpad_button: Button = ui.dpad.get_child(0)
    dpad_button.button_down.emit()
    _assert(_near(movement, Vector2.RIGHT), "Legacy D-pad still moves the character")
    ui._unhandled_input(_touch(9, true, Vector2(400, 300)))
    ui._input(_drag(9, Vector2(400, 200)))
    _assert(_near(movement, Vector2(1, -1).normalized()), "D-pad and stick can be used together")
    dpad_button.button_up.emit()
    _assert(_near(movement, Vector2.UP), "Releasing D-pad retains stick input")
    ui.clear_movement()
    _assert(_near(movement, Vector2.ZERO) and ui.stick_touch_id == -1, "Clear movement resets both controls")

    for button in [ui.act_button, ui.menu_button, ui.shortcut_button, ui.status_toggle, dpad_button]:
        ui._unhandled_input(_touch(11, true, button.get_global_rect().get_center()))
        _assert(ui.stick_touch_id == -1, "Tapping an existing button does not start stick: " + str(button.get_path()).get_file())

    var modal := Control.new()
    modal.visible = true
    ui.root.add_child(modal)
    ui.dialog_layer = modal
    ui._unhandled_input(_touch(12, true, Vector2(460, 280)))
    _assert(ui.stick_touch_id == -1, "Dialogue overlay blocks new stick")
    modal.hide()

    ui._unhandled_input(_touch(13, true, Vector2(430, 260)))
    _assert(ui.stick_touch_id == 13, "Floating stick can restart at another position")
    modal.show()
    ui._input(_drag(13, Vector2(470, 260)))
    _assert(ui.stick_touch_id == -1 and _near(movement, Vector2.ZERO), "Opening dialogue cancels held stick")
    modal.hide()

    ui._unhandled_input(_touch(14, true, Vector2(410, 280)))
    ui._touch_mode = false
    ui._update_explore_controls()
    _assert(ui.stick_touch_id == -1 and _near(movement, Vector2.ZERO), "Switching from touch to desktop cancels stick")
    ui._unhandled_input(_touch(15, true, Vector2(420, 300)))
    _assert(ui.stick_touch_id == -1, "Desktop layout does not spawn a touch stick")
    ui._touch_mode = true
    ui._update_explore_controls()
    ui._unhandled_input(_touch(16, true, Vector2(410, 280)))
    ui.set_play_visible(false)
    _assert(ui.stick_touch_id == -1 and _near(movement, Vector2.ZERO), "Hiding gameplay clears stick input")

    if failures.is_empty():
        print("FLOATING STICK SMOKE: ALL PASS")
        quit(0)
    else:
        print("FLOATING STICK SMOKE: ", failures.size(), " failures")
        quit(1)
