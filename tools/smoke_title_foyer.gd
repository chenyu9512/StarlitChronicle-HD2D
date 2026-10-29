extends SceneTree
## Real D title foyer / C art-manager UI wiring. No save edits or menu cheats.
## CI previously referenced this file without shipping the test itself.
const GameUI = preload("res://scripts/first_act_ui.gd")
const Foyer = preload("res://scripts/d_title_screen.gd")
var issues: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,reason: String) -> void:
    if not ok:
        issues.append(reason)

func _run() -> void:
    var ui = GameUI.new()
    root.add_child(ui)
    var foyer = ui.title_overlay
    check(foyer is Foyer,"Official title is not the D-owned cinematic foyer")
    check(foyer != null and foyer.visible,"Launch foyer must be visible before gameplay")
    if foyer == null:
        quit(1)
        return
    check(foyer.illustration != null and foyer.illustration.texture != null,
        "Official title has no real illustrated backdrop")
    check(foyer.stars != null and foyer.prompt != null,
        "Cinematic starfield or explicit invitation to open menu is missing")
    check(foyer.new_game_button != null and foyer.continue_button != null,
        "New game and Continue buttons missing")
    check(ui.art_manager != null and ui.art_manager.name=="CArtManager",
        "Installed art manager is not accessible from title")

    var starts: Array[bool] = []
    ui.started.connect(func(continue_game: bool) -> void: starts.append(continue_game))
    ui.show_title(false)
    check(foyer.continue_button.disabled,"Continue enabled with no saved game")
    check(not foyer.menu_open,"Title incorrectly opens with immediate menu stack")
    foyer._reveal_menu()
    check(foyer.menu_open and foyer.menu_left.visible and foyer.menu_right.visible,
        "Player input does not reveal authored title navigation")
    foyer._request_launch(true)
    check(starts.is_empty(),"Continue without save launched gameplay")
    foyer.new_game_button.pressed.emit()
    check(starts==[false] and not ui.title_overlay.visible,
        "New game button did not request actual new-game flow")

    # A valid save must require explicit confirmation before overwriting it.
    ui.show_title(true)
    check(not foyer.continue_button.disabled,
        "Continue disabled despite an available save")
    var count_before: int=starts.size()
    foyer.new_game_button.pressed.emit()
    check(foyer.confirmation.visible and starts.size()==count_before,
        "New game overwrote a saved journey without confirmation")
    if foyer.confirmation.visible:
        var confirm_button: Button = foyer.confirmation.get_child(0).get_child(2).get_child(1) as Button
        check(confirm_button != null,"Missing irreversible-new-game confirmation")
        if confirm_button != null:
            confirm_button.pressed.emit()
            check(starts.size()==count_before+1 and starts.back()==false,
                "Explicit new-game confirmation did not launch")
    ui.show_title(true)
    foyer.continue_button.pressed.emit()
    check(not starts.is_empty() and starts.back()==true,
        "Continue did not request the previous journey")
    if issues.is_empty():
        print("PASS: cinematic title foyer, intentional menu reveal, continue gating, new-game confirmation and C art manager")
        quit(0)
        return
    for issue in issues:
        push_error(issue)
    quit(1)
