extends SceneTree
## D-line title acceptance: no gameplay mutation, no save deletion, no fake victory.
const Title = preload("res://scripts/d_title_screen.gd")
const FirstActUI = preload("res://scripts/first_act_ui.gd")
var failures: Array[String] = []
var starts: Array[bool] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, why: String) -> void:
    if not ok:
        failures.append(why)

func _run() -> void:
    var ui = FirstActUI.new()
    root.add_child(ui)
    ui.started.connect(func(continue_game: bool) -> void:
        starts.append(continue_game)
    )
    ui.set_play_visible(false)
    ui.show_title(false)
    var screen: Control = ui.title_overlay
    verify(screen.get_script()==Title,"actual game UI not connected to D title")
    verify(screen.visible,"opening page hidden")
    verify(not screen.get("menu_open"),"boot bypasses atmospheric opening and shows menu")
    verify(screen.get("prompt").visible,"opening invitation missing")
    verify(not screen.get("menu_left").visible,"menu visible immediately at boot")
    verify(ui.title_continue.disabled,"Continue active with no local save")
    verify(ui.title_illustration!=null,"original replaceable backdrop lost")
    verify(ui.art_manager!=null,"C-line art manager not preserved")
    screen.call("_reveal_menu")
    verify(screen.get("menu_open") and screen.get("menu_left").visible and screen.get("menu_right").visible,
        "title portal does not expose adventure lobby")
    screen.call("_set_page","controls")
    verify("WASD" in str(screen.get("detail_body").text),"help page lacks real controls")
    screen.call("_set_page","archive")
    verify(not str(screen.get("detail_body").text).is_empty(),"archive page is empty")
    screen.call("_set_page","settings")
    verify(screen.get("prefs_actions").visible and screen.get("motion_button")!=null
        and screen.get("audio_button")!=null,"opening preferences missing")
    screen.call("_request_launch",true)
    verify(starts.is_empty(),"disabled Continue emitted a false start")
    screen.call("_request_launch",false)
    verify(starts.size()==1 and not starts[0],"New Game did not emit existing started signal")
    screen.show()
    screen.call("configure",true,"")
    starts.clear()
    screen.call("_request_launch",false)
    verify(screen.get("confirmation").visible and starts.is_empty(),
        "New Game overwrote existing auto save without warning")
    (screen.get("confirmation") as Control).hide()
    screen.call("_request_launch",true)
    verify(starts.size()==1 and starts[0],"Continue did not preserve game load callback")
    if failures.is_empty():
        print("PASS: cinematic foyer, guided menu, C art bridge, safe continue/new-game signals")
        quit(0)
    else:
        for item in failures:
            push_error(item)
        quit(1)
