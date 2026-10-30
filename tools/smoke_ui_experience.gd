extends SceneTree
## Real Main2 UI smoke: gameplay touch shortcuts, safe HUD, title,
## responsive dialogue controls, adventure book and map. No save mutation.
const GameUI = preload("res://scripts/first_act_ui.gd")
const RPGMenu = preload("res://scripts/rpg_menu.gd")
const MapHud = preload("res://scripts/map_hud.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
const Progress = preload("res://scripts/first_act_state.gd")
const Core = preload("res://scripts/rpg_core.gd")
var issues: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func verify(condition: bool, reason: String) -> void:
    checks += 1
    if not condition:
        issues.append(reason)
        push_error("UI EXPERIENCE FAIL: " + reason)

func touch(finger: int, pressed: bool, location: Vector2) -> InputEventScreenTouch:
    var e := InputEventScreenTouch.new()
    e.index = finger
    e.pressed = pressed
    e.position = location
    return e

func _run() -> void:
    var ui = GameUI.new()
    root.add_child(ui)
    await process_frame
    verify(ui.title_overlay != null and ui.title_overlay.visible,"Official title available")
    var foyer = ui.title_overlay
    verify(foyer.art_button != null and foyer.art_button.is_inside_tree(),"Art tool retained in title menu")
    verify(foyer.continue_button != null and foyer.new_game_button != null,"Continue and New Game available")
    verify(foyer.detail_body != null and foyer.detail_body.scroll_active,"Title help stays scrollable")
    foyer._reflow_title()
    foyer._reveal_menu()
    verify(foyer.menu_left.visible and foyer.menu_right.visible,"Title navigation reveals both panels")

    var opened: Array[int] = []
    ui.adventure_book_requested.connect(func() -> void: opened.append(1))
    ui.title_overlay.hide()
    ui._touch_mode = true
    ui.set_play_visible(true)
    ui._reflow_layout()
    verify(ui.shortcut_button.visible,"Touch adventure-book shortcut is visible")
    verify(ui.menu_button.visible and ui.dpad.visible,"Touch menu and D-pad remain visible")
    verify(ui.shortcut_button.custom_minimum_size.y >= 46.0,"Book shortcut has thumb-friendly height")
    ui.shortcut_button.pressed.emit()
    verify(opened.size() == 1,"Book shortcut opens real adventure-book signal")
    var size: Vector2 = ui.get_viewport().get_visible_rect().size
    ui._unhandled_input(touch(9,true,Vector2(size.x*0.82,size.y*0.65)))
    verify(ui.stick_touch_id == -1,"Right-thumb inputs cannot trigger movement")
    ui._unhandled_input(touch(9,true,Vector2(size.x*0.40,size.y*0.08)))
    verify(ui.stick_touch_id == -1,"Touches near top HUD cannot trigger movement")
    verify(ui._touch_hits_buttons(ui.status_frame.get_global_rect().get_center()),"HP status panel does not spawn joystick")
    verify(ui._touch_hits_buttons(ui.shortcut_button.get_global_rect().get_center()),"Quick menu touch is not stolen by joystick")
    ui._unhandled_input(touch(9,true,Vector2(size.x*0.43,size.y*0.55)))
    verify(ui.stick_touch_id == 9,"Clear left playfield starts floating movement")
    ui._input(touch(9,false,Vector2(size.x*0.43,size.y*0.55)))
    verify(ui.stick_touch_id == -1,"Release cancels movement promptly")

    ui.show_dialogue([{"speaker":"岚音","text":"探索、调查和战斗后继续前进。"}])
    verify(ui.dialog_layer.visible,"Dialogue overlay visible")
    for action in [ui.dialog_next,ui.dialog_auto_button,ui.dialog_history_button,ui.dialog_skip_button]:
        verify(action.custom_minimum_size.y >= 46.0,"Touch dialogue action has >=46 pixel height")
    verify(ui.stick_touch_id == -1,"Dialogue opening cancels lingering movement")
    ui.dialog_layer.hide()
    ui.show_menu([],30,2)
    verify(ui.menu_layer.visible,"Camp menu retains all commands")
    verify(ui.camp_commands.get_child_count() == 6,"Camp command set not lost")
    ui.close_menu()
    ui.queue_free()

    var book = RPGMenu.new()
    root.add_child(book)
    await process_frame
    verify(book.group_scroller != null and book.tab_scroller != null and book.content_scroller != null,"Adventure book has three responsive scroll areas")
    book._select_group("装备")
    verify(book.active_group == "装备" and book.section_buttons.size() == 5,"Equipment group retains five real tabs")
    book._select_group("冒险")
    verify(book.section_buttons.size() == 4,"Quest navigation retains chapter/story/route/history tabs")
    book._reflow_menu()
    verify(book.book_panel.anchor_left > 0.0 and book.book_panel.anchor_right < 1.0,"Adventure menu stays inside screen edges")
    book.queue_free()

    var atlas = MapHud.new()
    root.add_child(atlas)
    await process_frame
    atlas._reflow_map()
    verify(atlas.small_frame.offset_right <= -14.0,"Minimap has right-edge clearance")
    verify(atlas.large_frame.anchor_left > 0.0 and atlas.large_frame.anchor_right < 1.0,"Full map respects safe horizontal margins")
    verify(atlas.local_button != null and atlas.region_button != null and atlas.world_button != null,"Map travel tab controls preserved")
    atlas.queue_free()

    var progress = Progress.new()
    var core = Core.new()
    core.bind(progress)
    var fight = Battle.new()
    root.add_child(fight)
    fight.game_core = core
    fight.start(progress,2,false)
    fight._reflow_battle_controls()
    verify(fight.command_panel != null and fight.command_panel.anchor_left > 0.0,
        "Combat command panel uses inset safe margins")
    verify(fight.commands != null and fight.commands.columns == 4,
        "Landscape combat maintains two-row seven-action layout")
    verify(fight.commands.get_child_count() == 7,
        "Responsive battle did not lose any official action")
    verify(fight.special_button != null and fight.special_button.is_inside_tree(),
        "Boss/weakness special action remains accessible")
    for action in fight.commands.get_children():
        verify(action is Button and action.custom_minimum_size.y >= 40.0,
            "Real combat command retains usable tap size")
    fight.queue_free()

    if issues.is_empty():
        print("UI EXPERIENCE SMOKE: ALL PASS checks=", checks)
        quit(0)
    else:
        print("UI EXPERIENCE SMOKE: failures=", issues.size()," checks=",checks)
        quit(1)
