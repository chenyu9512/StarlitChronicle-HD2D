extends "res://scripts/first_act_ui.gd"
## Minimal on-tree UI fixture: exercise the real joystick handlers without building the title screen.

func _ready() -> void:
    layer = 15
    # Main2 hides its D-pad on desktop: explicitly emulate an active touch device.
    _touch_mode = true
    _playing = true
    _interaction_hint = "调查"
    root = Control.new()
    root.name = "TouchTestRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    dpad = Control.new()
    dpad.position = Vector2(20, 380)
    dpad.size = Vector2(190, 200)
    dpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(dpad)
    _direction("→", "right", Vector2.RIGHT, Vector2(128, 61))
    _build_floating_stick()

    act_button = _test_button(Vector2(900, 480))
    menu_button = _test_button(Vector2(900, 400))
    shortcut_button = _test_button(Vector2(760, 400))
    status_toggle = _test_button(Vector2(10, 60))
    interaction_label = Label.new()
    root.add_child(interaction_label)
    hud = PanelContainer.new()
    root.add_child(hud)
    status_frame = PanelContainer.new()
    root.add_child(status_frame)

func _test_button(at: Vector2) -> Button:
    var button := Button.new()
    button.position = at
    button.size = Vector2(120, 64)
    root.add_child(button)
    return button
