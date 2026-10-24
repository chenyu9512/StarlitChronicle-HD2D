extends Node2D
## 《星灯纪行》序章—第一幕六章：地图交互任务 / 剧情 / 战斗 / 存档总控制。
const WorldScript = preload("res://scripts/first_act_world.gd")
const UIScript = preload("res://scripts/first_act_ui.gd")
const BattleScript = preload("res://scripts/first_act_battle.gd")
const StateScript = preload("res://scripts/first_act_state.gd")
const CatalogScript = preload("res://scripts/story_catalog.gd")
const CheatScript = preload("res://scripts/cheat_panel.gd")
const RPGCore = preload("res://scripts/rpg_core.gd")
const RPGMenu = preload("res://scripts/rpg_menu.gd")
var progress
var catalog
var world
var ui
var battle
var cheat
var game_core
var adventure_menu
var busy: bool = true
var paused_for_dialogue: bool = false
var pending: String = ""
var battle_is_boss: bool = false
var invincible: bool = false
var no_encounters: bool = false
var five_xp: bool = false
var side_quests: Dictionary = {}

func _ready() -> void:
    progress = StateScript.new()
    game_core = RPGCore.new()
    var side_file: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/first_act_side_quests.json"))
    if side_file is Dictionary:
        for row in side_file.get("quests", []):
            if row is Dictionary:
                side_quests[int(row.get("chapter", 0))] = row
    catalog = CatalogScript.new()
    var loaded: bool = catalog.load_all()
    world = WorldScript.new()
    add_child(world)
    world.interacted.connect(_interact)
    world.encounter_requested.connect(_random_encounter)
    ui = UIScript.new()
    add_child(ui)
    ui.started.connect(_start)
    ui.move_changed.connect(func(v: Vector2) -> void: world.movement = v)
    ui.action_pressed.connect(func() -> void: world.interact())
    ui.menu_pressed.connect(_show_menu)
    ui.adventure_book_requested.connect(_open_adventure_book)
    ui.menu_dismissed.connect(_return_to_world)
    ui.save_pressed.connect(_save)
    ui.potion_pressed.connect(_use_potion)
    ui.rest_pressed.connect(_rest)
    ui.dialogue_finished.connect(_dialogue_ended)
    ui.choice_picked.connect(_choice_picked)
    adventure_menu = RPGMenu.new()
    add_child(adventure_menu)
    adventure_menu.closed.connect(_return_to_world)
    cheat = CheatScript.new()
    add_child(cheat)
    cheat.opened.connect(_on_cheat_opened)
    cheat.closed.connect(_return_to_world)
    cheat.command_requested.connect(_run_cheat)
    ui.set_play_visible(false)
    ui.show_title(FileAccess.file_exists(StateScript.SAVE_PATH) or FileAccess.file_exists(StateScript.BACKUP_PATH))
    if not loaded:
        push_error("剧情资源载入失败：" + catalog.get_errors_text())

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and not busy:
        world.interact()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("open_menu") and not busy:
        _show_menu()
        get_viewport().set_input_as_handled()

func _start(continue_game: bool) -> void:
    if not continue_game or not progress.load_saved():
        progress.new_game()
        progress.save()
    game_core.bind(progress)
    _enter_location()

func _enter_location() -> void:
    game_core.register_chapter(progress.chapter)
    world.custom_region = game_core.location_name(progress.chapter)
    world.build(progress.chapter, progress.actors.size())
    world.locked = false
    busy = false
    pending = ""
    ui.set_play_visible(true)
    _focus()

func _current_scene() -> Dictionary:
    if progress.chapter == 0:
        var prologue: Array = catalog.prologue.get("scenes", [])
        if progress.scene_index >= 0 and progress.scene_index < prologue.size():
            return prologue[progress.scene_index]
        return {}
    var current: Dictionary = catalog.get_chapter("ch%03d" % progress.chapter)
    var scenes: Array = current.get("scenes", [])
    if progress.scene_index >= 0 and progress.scene_index < scenes.size():
        return scenes[progress.scene_index]
    return {}

func _target() -> String:
    if progress.chapter == 0:
        return "prologue_%d" % progress.scene_index if progress.scene_index < 9 else ""
    match progress.scene_index:
        0: return "key_npc"
        1: return "clue" if progress.task_index == 0 else "witness"
        2: return "crisis"
        3: return "resolve"
        4: return "resolve"
    return ""

func _objective() -> String:
    if progress.chapter == 72 and bool(progress.flags.get("story.ch072.done", false)):
        return "终章已完成 · 星灯纪行迎来结局。可继续探索与保存。"
    var scene: Dictionary = _current_scene()
    var prefix: String = str(scene.get("title", "探索周围"))
    if progress.chapter == 0:
        return "前往 ✦ 光点：" + prefix
    match progress.scene_index:
        0: return prefix + " · 找到" + (WorldScript.NPC_NAMES[progress.chapter] if progress.chapter < WorldScript.NPC_NAMES.size() else "关键人物")
        1: return prefix + (" · 调查线索" if progress.task_index == 0 else " · 询问目击者")
        2: return prefix + (" · 迎战敌人" if progress.task_index == 1 else " · 前往冲突现场")
        3: return prefix + " · 返回归航点，完成本章"
    return "探索旅途中的秘密"

func _focus() -> void:
    world.set_focus(_target() if not (progress.chapter == 72 and bool(progress.flags.get("story.ch072.done", false))) else "")
    var side_step: int = _side_step()
    var extra: String = ""
    var side_target: String = ""
    if progress.chapter > 0 and side_quests.has(progress.chapter):
        var side: Dictionary = side_quests[progress.chapter]
        match side_step:
            0:
                side_target = "side_start"
                extra = "【支线委托】%s · 寻找委托人" % str(side["name"])
            1:
                side_target = "side_item"
                extra = "【支线委托】%s · 找到遗失物" % str(side["name"])
            2:
                side_target = "side_return"
                extra = "【支线委托】%s · 交还物品" % str(side["name"])
    world.set_side_focus(side_target)
    ui.set_hud(progress.chapter, world.region_name(), _objective() + ("\n" + extra if not extra.is_empty() else ""), progress.actors, progress.gold, progress.potions)

func _interact(target: String) -> void:
    if busy:
        return
    if target == "inn":
        _rest()
        return
    if target == "shop":
        if progress.gold < 16:
            ui.show_message("盐露草售价 16 G，金币不足。")
        else:
            progress.gold -= 16
            progress.potions += 1
            progress.save()
            ui.show_message("购买盐露草 ×1，剩余金币 %d。" % progress.gold)
        _focus()
        return
    if target.begins_with("side_"):
        _side_interact(target)
        return
    if progress.chapter == 72 and bool(progress.flags.get("story.ch072.done", false)):
        ui.show_message("第一幕已结束。潮歌灯仍照亮着归航之路。")
        return
    if target != _target():
        ui.show_message("当前目标：" + _objective())
        return
    if progress.chapter == 0:
        _present("prologue")
        return
    match progress.scene_index:
        0: _present("opening")
        1:
            if progress.task_index == 0:
                _present("clue")
            else:
                _advance_scene()
                ui.show_message("线索已经齐备，新的事件正在发生。")
        2:
            if progress.task_index == 1:
                _start_battle(true)
            else:
                _present("crisis")
        3: _present("resolve")
        4: _present("resolve")

func _side_flag(suffix: String) -> String:
    var side: Dictionary = side_quests.get(progress.chapter, {})
    return "side." + str(side.get("id", "unknown")) + "." + suffix

func _side_step() -> int:
    if progress.chapter == 0 or not side_quests.has(progress.chapter):
        return -1
    if bool(progress.flags.get(_side_flag("done"), false)):
        return -1
    if bool(progress.flags.get(_side_flag("found"), false)):
        return 2
    if bool(progress.flags.get(_side_flag("accepted"), false)):
        return 1
    return 0

func _side_interact(target: String) -> void:
    if progress.chapter == 0 or not side_quests.has(progress.chapter):
        return
    var step: int = _side_step()
    var quest: Dictionary = side_quests[progress.chapter]
    var phase: String = ""
    var action: String = ""
    if step == 0 and target == "side_start":
        phase = "start"
        action = "side_accept"
    elif step == 1 and target == "side_item":
        phase = "find"
        action = "side_found"
    elif step == 2 and target == "side_return":
        phase = "finish"
        action = "side_complete"
    if phase.is_empty():
        ui.show_message("支线任务：" + str(quest.get("name", "")))
        return
    pending = action
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.show_dialogue(quest.get(phase, []))

func _present(on_complete: String) -> void:
    var scene: Dictionary = _current_scene()
    if scene.is_empty():
        ui.show_message("当前章节内容缺失，请检查剧情数据。")
        return
    pending = on_complete
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.show_dialogue(scene.get("dialogue", []))

func _dialogue_ended() -> void:
    paused_for_dialogue = false
    match pending:
        "prologue":
            _apply_effects(_current_scene())
            progress.scene_index += 1
            if progress.scene_index >= 9:
                progress.chapter = 1
                progress.scene_index = 0
                progress.flags["story.prologue_done"] = true
                _save_progress()
                _enter_location()
                ui.show_message("序章完成 · 第一章《不曾寄出的信》")
                return
        "opening":
            _apply_effects(_current_scene())
            _advance_scene()
        "clue":
            _apply_effects(_current_scene())
            progress.task_index = 1
        "crisis":
            var choice: Dictionary = _current_scene().get("choice", {})
            if not choice.is_empty():
                pending = "choice"
                ui.show_choices(choice)
                return
            _crisis_choice_complete()
            return
        "side_accept":
            progress.flags[_side_flag("accepted")] = true
        "side_found":
            progress.flags[_side_flag("found")] = true
        "side_complete":
            progress.flags[_side_flag("done")] = true
            var quest: Dictionary = side_quests.get(progress.chapter, {})
            var reward: Dictionary = quest.get("reward", {})
            progress.give_rewards(int(reward.get("xp", 0)), int(reward.get("gold", 0)))
            progress.potions += int(reward.get("potions", 0))
            ui.show_message("支线完成！获得经验、金币与药草奖励。")
        "resolve":
            _apply_effects(_current_scene())
            if progress.chapter == 72 and progress.scene_index == 3:
                _advance_scene()
                _return_to_world()
                return
            _complete_chapter()
            return
    pending = ""
    _save_progress()
    _return_to_world()

func _choice_picked(item: Dictionary) -> void:
    for key in (item.get("sets", {}) as Dictionary).keys():
        progress.flags[str(key)] = (item["sets"] as Dictionary)[key]
    var scene: Dictionary = _current_scene()
    var choice: Dictionary = scene.get("choice", {})
    progress.flags[str(choice.get("id", "choice")) + ".chosen"] = true
    _crisis_choice_complete()

func _crisis_choice_complete() -> void:
    _apply_effects(_current_scene())
    if progress.chapter == 1:
        _advance_scene()
        _save_progress()
        _return_to_world()
        return
    var fight: Dictionary = _current_scene().get("encounter", {})
    if fight.is_empty():
        _advance_scene()
        _save_progress()
        _return_to_world()
        return
    progress.task_index = 1
    _save_progress()
    _start_battle(true)

func _start_battle(is_boss: bool) -> void:
    if is_instance_valid(battle):
        return
    if progress.chapter < 1:
        return
    battle_is_boss = is_boss
    world.locked = true
    busy = true
    ui.set_play_visible(false)
    battle = BattleScript.new()
    add_child(battle)
    battle.completed.connect(_battle_finished)
    battle.invincible = invincible
    battle.game_core = game_core
    battle.encounter_data = _current_scene().get("encounter", {}) if is_boss else {}
    battle.start(progress, progress.chapter, is_boss)

func _random_encounter() -> void:
    if no_encounters:
        world.locked = false
        return
    _start_battle(false)

func _battle_finished(won: bool, xp: int, money: int) -> void:
    if is_instance_valid(battle):
        battle.queue_free()
        battle = null
    if won:
        var levels: Array[String] = progress.give_rewards(xp * (5 if five_xp else 1), money)
        if battle_is_boss:
            progress.flags["ch%03d.battle_won" % progress.chapter] = true
            _advance_scene()
        else:
            ui.show_message("战斗胜利，获得 %d 经验、%d 金币。%s" % [xp * (5 if five_xp else 1), money, "，".join(levels)])
    else:
        progress.gold = maxi(0, progress.gold - 15)
        progress.heal_all()
        ui.show_message("队伍在营地苏醒，遗失了至多15 G。可再次挑战。")
    _save_progress()
    ui.set_play_visible(true)
    _return_to_world()

func _apply_effects(scene: Dictionary) -> void:
    for value in scene.get("effects", []):
        if not value is Dictionary:
            continue
        var effect: Dictionary = value
        var kind: String = str(effect.get("type", ""))
        if kind == "set_flag":
            progress.flags[str(effect.get("key", ""))] = effect.get("value", true)
        elif kind == "grant":
            progress.give_rewards(int(effect.get("xp", 0)), int(effect.get("gold", 0)))
        elif kind == "time_skip":
            progress.flags["world.years_passed"] = true

func _advance_scene() -> void:
    progress.scene_index += 1
    progress.task_index = 0
    progress.dialogue_seen = false
    _save_progress()

func _complete_chapter() -> void:
    var last: int = progress.chapter
    progress.flags["story.ch%03d.done" % last] = true
    if last == 4:
        progress.recruit_sailor()
    if last == 6:
        progress.flags["world.seven_lanterns.first"] = true
    if last == 72:
        progress.flags["story.complete"] = true
        _save_progress()
        _enter_location()
        ui.show_message("终章已完成！星灯的故事在此落幕。")
        return
    progress.chapter += 1
    progress.scene_index = 0
    progress.task_index = 0
    var newcomer: String = game_core.recruit_from_story(progress.chapter)
    progress.heal_all()
    _save_progress()
    _enter_location()
    if not newcomer.is_empty():
        ui.show_message(newcomer)
    var next_chapter: Dictionary = catalog.get_chapter("ch%03d" % progress.chapter)
    ui.show_message("第%d章 · %s" % [progress.chapter, str(next_chapter.get("title", "新的旅程"))])

func _save_progress() -> void:
    if not progress.save():
        push_warning("第一幕存档写入失败")

func _save() -> void:
    _save_progress()
    ui.show_message("已保存第一幕进度。")

func _open_adventure_book() -> void:
    if is_instance_valid(battle):
        return
    ui.close_menu()
    busy = true
    world.locked = true
    adventure_menu.show_menu(game_core, progress)

func _show_menu() -> void:
    if busy:
        return
    busy = true
    world.locked = true
    ui.show_menu(progress.actors, progress.gold, progress.potions)

func _return_to_world() -> void:
    busy = paused_for_dialogue or is_instance_valid(battle) or ui.menu_layer.visible or adventure_menu.root.visible or cheat.shade.visible
    world.locked = busy
    ui.set_play_visible(not is_instance_valid(battle))
    _focus()

func _use_potion() -> void:
    if progress.potions <= 0:
        ui.show_message("药草不足。")
        return
    var who: int = -1
    var gap: int = 0
    for i in range(progress.actors.size()):
        var person: Dictionary = progress.actors[i]
        var diff: int = int(person["max_hp"]) - int(person["hp"])
        if diff > gap:
            gap = diff
            who = i
    if who < 0:
        ui.show_message("队员生命已经全满。")
        return
    progress.heal_member(who, 65)
    game_core.take_item("item_herb_01", 1)
    _save_progress()
    ui.show_menu(progress.actors, progress.gold, progress.potions)
    _focus()

func _rest() -> void:
    if progress.gold < 30:
        ui.show_message("需要30 G才能休息。")
        return
    progress.gold -= 30
    progress.heal_all()
    _save_progress()
    ui.show_message("全队休息完毕，HP/MP完全恢复。")
    _focus()

func _on_cheat_opened() -> void:
    if is_instance_valid(battle):
        return
    busy = true
    world.locked = true

func _run_cheat(command: String) -> void:
    var message := "操作已执行。"
    match command:
        "heal": progress.heal_all()
        "gold": progress.gold += 10000
        "potions": game_core.add_item("item_herb_01", 99)
        "level":
            for i in range(progress.actors.size()):
                var a: Dictionary = progress.actors[i]
                a["level"] = mini(40, int(a["level"]) + 10)
                a["max_hp"] = int(a["max_hp"]) + 120
                a["max_mp"] = int(a["max_mp"]) + 50
                a["attack"] = int(a["attack"]) + 30
                a["defense"] = int(a["defense"]) + 12
                progress.actors[i] = a
            progress.heal_all()
        "stats":
            for i in range(progress.actors.size()):
                var a: Dictionary = progress.actors[i]
                a["attack"] = int(a["attack"]) + 50
                a["defense"] = int(a["defense"]) + 30
                progress.actors[i] = a
        "god":
            invincible = not invincible
            message = "无敌模式：" + ("开" if invincible else "关")
        "encounters":
            no_encounters = not no_encounters
            message = "随机遇敌：" + ("已禁止" if no_encounters else "开启")
        "xp":
            five_xp = not five_xp
            message = "经验5倍：" + ("开" if five_xp else "关")
        "speed":
            world.walk_speed = 141.0 if world.walk_speed > 141.0 else 240.0
            message = "移动速度：" + ("加速" if world.walk_speed > 141.0 else "正常")
        "next_chapter":
            if progress.chapter < 6:
                if progress.chapter == 0:
                    progress.flags["story.prologue_done"] = true
                else:
                    progress.flags["story.ch%03d.done" % progress.chapter] = true
                progress.chapter += 1
                progress.scene_index = 0
                progress.task_index = 0
                _save_progress()
                _enter_location()
            else:
                message = "已处于第一幕终章。"
        "village":
            message = "剧情地图自动依据章节载入。"
        "ruins":
            message = "正式剧情下不可越过任务条件随意传送。"
        _:
            message = "未知指令。"
    _save_progress()
    _focus()
    cheat.report(message)
