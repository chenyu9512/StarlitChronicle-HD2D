extends Node2D
## 《星灯纪行》72章全篇：地图、分支任务、三结局、战斗与存档协调器。
const WorldScript = preload("res://scripts/first_act_world.gd")
const UIScript = preload("res://scripts/first_act_ui.gd")
const MapScript = preload("res://scripts/map_hud.gd")
const BattleScript = preload("res://scripts/first_act_battle.gd")
const StateScript = preload("res://scripts/first_act_state.gd")
const CatalogScript = preload("res://scripts/story_catalog.gd")
const CheatScript = preload("res://scripts/cheat_panel.gd")
const RPGCore = preload("res://scripts/rpg_core.gd")
const RPGMenu = preload("res://scripts/rpg_menu.gd")
const EndingDirector = preload("res://scripts/ending_director.gd")
const ChapterAmbient = preload("res://scripts/chapter_ambient.gd")
const WorldRegistry = preload("res://scripts/world_registry.gd")
const GameEvents = preload("res://scripts/game_events.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
const HousingService = preload("res://scripts/housing_service.gd")
const HousingRoom = preload("res://scripts/housing_room.gd")
const OptionalDirector = preload("res://scripts/optional_director.gd")
var progress
var catalog
var world
var ui
var atlas
var battle
var cheat
var game_core
var adventure_menu
var ending_director
var chapter_ambient
var world_router
var game_events
var save_slots
var housing
var housing_room
var optional_director
var pending_optional: Dictionary = {}
var clock_tick: float = 0.0
var active_optional_flag: String = ""
var ending_replay_id: String = ""
var ending_replay_scene: int = 0
var busy: bool = true
var paused_for_dialogue: bool = false
var pending: String = ""
var battle_is_boss: bool = false
var invincible: bool = false
var no_encounters: bool = false
var five_xp: bool = false
var side_quests: Dictionary = {}
var active_story_side: Dictionary = {}

func _ready() -> void:
    progress = StateScript.new()
    game_core = RPGCore.new()
    ending_director = EndingDirector.new()
    chapter_ambient = ChapterAmbient.new()
    world_router = WorldRegistry.new()
    game_events = GameEvents.new()
    save_slots = SaveSlots.new()
    housing = HousingService.new()
    optional_director = OptionalDirector.new()
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
    ui.atlas_requested.connect(_open_map_from_quick_menu)
    ui.menu_dismissed.connect(_return_to_world)
    ui.save_pressed.connect(_save)
    ui.potion_pressed.connect(_use_potion)
    ui.rest_pressed.connect(_rest)
    ui.dialogue_finished.connect(_dialogue_ended)
    ui.choice_picked.connect(_choice_picked)
    atlas = MapScript.new()
    add_child(atlas)
    atlas.bind_world(world, world_router)
    atlas.opened.connect(_map_opened)
    atlas.closed.connect(_return_to_world)
    atlas.travel_requested.connect(_travel_to)
    adventure_menu = RPGMenu.new()
    add_child(adventure_menu)
    adventure_menu.closed.connect(_return_to_world)
    adventure_menu.replay_ending_requested.connect(_replay_ending)
    adventure_menu.travel_requested.connect(_travel_to)
    adventure_menu.map_requested.connect(_open_world_map_from_book)
    adventure_menu.save_slot_requested.connect(_save_slot)
    adventure_menu.load_slot_requested.connect(_load_slot)
    adventure_menu.housing_purchase_requested.connect(_purchase_house)
    adventure_menu.housing_open_requested.connect(_open_house)
    adventure_menu.world_router = world_router
    adventure_menu.game_events = game_events
    adventure_menu.slot_service = save_slots
    adventure_menu.housing = housing
    housing_room = HousingRoom.new()
    add_child(housing_room)
    housing_room.closed.connect(_return_to_world)
    housing_room.changed.connect(_housing_changed)
    cheat = CheatScript.new()
    add_child(cheat)
    cheat.opened.connect(_on_cheat_opened)
    cheat.closed.connect(_return_to_world)
    cheat.command_requested.connect(_run_cheat)
    ui.set_play_visible(false)
    ui.show_title(FileAccess.file_exists(StateScript.SAVE_PATH) or FileAccess.file_exists(StateScript.BACKUP_PATH))
    if not loaded:
        push_error("剧情资源载入失败：" + catalog.get_errors_text())

func _process(delta: float) -> void:
    if progress == null or game_events == null:
        return
    if busy:
        return
    progress.play_seconds += delta
    clock_tick += delta
    if clock_tick >= 8.0:
        var elapsed: int = int(clock_tick / 8.0)
        clock_tick = fmod(clock_tick,8.0)
        game_events.advance_time(elapsed)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_TAB, KEY_P] or (event.keycode == KEY_ESCAPE and atlas.is_open()):
            if atlas.is_open():
                atlas.close_map()
            elif not busy:
                atlas.open_map()
            get_viewport().set_input_as_handled()
            return
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
    world_router.bind(progress)
    game_events.bind(progress)
    housing.bind(progress)
    optional_director.bind(progress)
    if progress.chapter == 72 and bool(progress.flags.get("story.complete",false)) and str(progress.rpg.get("ending_id","")).is_empty():
        # v0.3旧版结算标记没有三结局记录：迁移到终局选择，保留装备、等级与支线。
        progress.flags.erase("story.complete")
        progress.flags["story.ch072.done"] = true
        progress.scene_index = 4
        progress.save()
    _enter_location()
    if progress.chapter == 72 and progress.scene_index == 4 and not bool(progress.flags.get("story.complete", false)):
        if str(progress.rpg.get("ending_id", "")).is_empty():
            _begin_ending_choice()
        else:
            _play_ending_scene()

func _enter_location() -> void:
    game_core.register_chapter(progress.chapter)
    world_router.sync_chapter(progress.chapter)
    world.map_profile = world_router.profile()
    world.custom_region = str(world.map_profile.get("name",game_core.location_name(progress.chapter)))
    world.party_ids = progress.rpg.get("party", []).duplicate()
    world.build(progress.chapter, world.party_ids.size())
    world.locked = false
    busy = false
    pending = ""
    ui.set_play_visible(true)
    atlas.show_exploration(true)
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
    if progress.chapter == 72 and bool(progress.flags.get("story.complete", false)):
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
    if progress.chapter == 72 and progress.scene_index == 4:
        return "最后的抉择 · 前往归航灯坛，见证世界的未来"
    return "探索旅途中的秘密"

func _focus() -> void:
    world.set_focus(_target() if not (progress.chapter == 72 and bool(progress.flags.get("story.complete", false))) else "")
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
    if side_target.is_empty() and progress.chapter > 0:
        var quest: Dictionary = game_core.available_story_side(progress.chapter)
        if not quest.is_empty():
            var stage: int = game_core.story_side_stage(str(quest.get("id","")))
            var stages: Array = quest.get("stages",[])
            if stage < stages.size():
                side_target = "story_stage_%d" % stage
                extra = "【世界支线】%s · %s" % [str(quest.get("title","未命名委托")),str(stages[stage].get("objective","前往支线地点"))]
    world.set_side_focus(side_target)
    if extra.is_empty() and progress.chapter > 0:
        var open_inspections: Array[String] = []
        for index in range(2):
            var item: Dictionary = chapter_ambient.inspection(progress.chapter,index,progress.flags)
            if not item.is_empty():
                open_inspections.append(str(item.get("name","区域线索")))
        if not open_inspections.is_empty():
            extra = "【地区线索】" + "、".join(open_inspections)
        elif not chapter_ambient.midpoint(progress.chapter,progress.flags).is_empty():
            extra = "【地区事件】额外证言可在地图灯坛查看"
    for slot in ["town","evidence"]:
        var point: String = "optional_"+slot
        if world.nodes.has(point):
            world.nodes[point].visible = not optional_director.offered(progress.chapter,slot,progress.scene_index).is_empty()
    ui.set_hud(progress.chapter, world.region_name(), _objective() + ("\n" + extra if not extra.is_empty() else ""), progress.actors, progress.gold, progress.potions)
    atlas.set_targets(world.focus_name,side_target)

func _interact(target: String) -> void:
    if busy:
        return
    if target.begins_with("dungeon_switch_"):
        var key: String = "map.%s.%s" % [world_router.current_map(),target]
        if bool(progress.flags.get(key,false)):
            ui.show_message("符文机关已经启动。")
        else:
            progress.flags[key] = true
            _save_progress()
            var left_a: bool = bool(progress.flags.get("map.%s.dungeon_switch_a" % world_router.current_map(),false))
            var left_b: bool = bool(progress.flags.get("map.%s.dungeon_switch_b" % world_router.current_map(),false))
            ui.show_message("古代灯纹机关发出亮光！" + (" 两座机关同时激活，秘藏已解除封印。" if left_a and left_b else " 附近还有其他机关。"))
        return
    if target == "dungeon_chest":
        var lock_prefix: String = "map.%s." % world_router.current_map()
        if not bool(progress.flags.get(lock_prefix+"dungeon_switch_a",false)) or not bool(progress.flags.get(lock_prefix+"dungeon_switch_b",false)):
            ui.show_message("宝箱受到两道灯纹封印。需要在地下城中找到两座机关。")
        elif bool(progress.flags.get(lock_prefix+"chest_claimed",false)):
            ui.show_message("秘藏宝箱已经打开。")
        else:
            progress.flags[lock_prefix+"chest_claimed"] = true
            progress.gold += 60 + 8 * maxi(1,progress.chapter)
            game_core.add_item("item_herb_01",2)
            _save_progress()
            ui.show_message("发现地下城秘藏！获得两株盐露草与旅行金币。")
        return
    if target == "wild_cache":
        var cache_flag: String = "map.%s.wild_cache" % world_router.current_map()
        if bool(progress.flags.get(cache_flag,false)):
            ui.show_message("补给箱已被取走。")
        else:
            progress.flags[cache_flag] = true
            game_core.add_item("item_herb_01",1)
            _save_progress()
            ui.show_message("从野外补给箱发现了一株盐露草。")
        return
    if target == "wild_camp":
        ui.show_message("这里是安全的野外休憩地点。可以查看地图并整理装备。")
        return
    if target.begins_with("exit:"):
        _travel_to(target.trim_prefix("exit:"))
        return
    if target.begins_with("building:"):
        var building_id: String = target.trim_prefix("building:")
        if world.enter_building(building_id):
            _focus()
            ui.show_message("进入 " + world.region_name() + "。可在室内探索，寻找出口标记返回街道。")
        return
    if target == "interior_exit":
        if world.leave_building():
            _focus()
            ui.show_message("返回 " + world.region_name() + "。")
        return
    if target == "interior_service":
        ui.show_message("室内设施已经可以调查。特殊商店、公会与NPC交易将按地区逐步开放。")
        return
    if target == "interior_storage":
        ui.show_message("储物柜与家具已经布置。家园专用仓储请从自己的房屋进入。")
        return
    if target.begins_with("optional_"):
        _optional_event_interact(target.trim_prefix("optional_"))
        return
    if target == "home_door":
        _open_house()
        return
    if target == "inn":
        _rest()
        return
    if target == "shop":
        if progress.gold < 16:
            ui.show_message("盐露草售价 16 G，金币不足。")
        else:
            progress.gold -= 16
            game_core.add_item("item_herb_01",1)
            progress.save()
            ui.show_message("购买盐露草 ×1，剩余金币 %d。" % progress.gold)
        _focus()
        return
    if target.begins_with("side_"):
        _side_interact(target)
        return
    if target.begins_with("story_stage_"):
        _story_side_interact(target)
        return
    if target.begins_with("inspect_"):
        _optional_inspection(target)
        return
    if target == "ambient_npc":
        _ambient_npc_interact()
        return
    if target == "midpoint":
        _ambient_midpoint()
        return
    if progress.chapter == 72 and bool(progress.flags.get("story.complete", false)):
        ui.show_message("结局已经完成。可从「功能手册 → 结局档案」回看后日谈。")
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
        4: _present("ending_intro")

func _optional_event_interact(slot: String) -> void:
    var event: Dictionary = optional_director.offered(progress.chapter,slot,progress.scene_index)
    if event.is_empty():
        ui.show_message("这段可选见证尚未开放，或已记录在旅行日志。")
        return
    pending_optional = event
    pending = "optional_event"
    paused_for_dialogue = true
    busy = true
    world.locked = true
    ui.show_dialogue(event.get("dialogue",[]))

func _optional_inspection(target: String) -> void:
    var index: int = 0 if target == "inspect_1" else 1
    var item: Dictionary = chapter_ambient.inspection(progress.chapter,index,progress.flags)
    if item.is_empty():
        ui.show_message("这里的线索尚未开放，或已经记录在旅行手册。")
        return
    active_optional_flag = str(item.get("investigation_flag",""))
    pending = "optional_inspect"
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.show_dialogue(chapter_ambient.inspection_lines(item))

func _ambient_npc_interact() -> void:
    var record: Dictionary = chapter_ambient.npc_state(progress.chapter,progress.scene_index,progress.flags)
    if record.is_empty():
        ui.show_message("这里的居民暂时没有新的消息。")
        return
    pending = "ambient_npc"
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.show_dialogue([{"speaker":str(record.get("speaker","旅人")),"text":str(record.get("text",""))}])

func _ambient_midpoint() -> void:
    var record: Dictionary = chapter_ambient.midpoint(progress.chapter,progress.flags)
    if record.is_empty():
        ui.show_message("尚需记录两份现场证据，或者这一段见证已经完成。")
        return
    pending = "ambient_midpoint"
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.show_dialogue(record.get("dialogue",[]))

func _story_side_interact(target: String) -> void:
    var quest: Dictionary = game_core.available_story_side(progress.chapter)
    if quest.is_empty():
        ui.show_message("当前没有可接取的世界支线。")
        return
    var step: int = game_core.story_side_stage(str(quest.get("id","")))
    if target != "story_stage_%d" % step:
        ui.show_message("请先完成本次委托的上一个目标。")
        return
    var entry: Dictionary = game_core.story_stage_record(quest)
    if entry.is_empty():
        return
    active_story_side = quest
    pending = "story_side"
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.show_dialogue(entry.get("dialogue", []))

func _finish_story_side(selected: Dictionary = {}) -> void:
    var result: String = game_core.advance_story_side(active_story_side, selected)
    if result.begins_with("委托完成"):
        game_events.record("side_quest_completed",{"id":str(active_story_side.get("id",""))})
    var branch_dialogue: Array = selected.get("branch_dialogue", [])
    _save_progress()
    if not branch_dialogue.is_empty():
        pending = "story_side_branch"
        paused_for_dialogue = true
        ui.show_dialogue(branch_dialogue)
    else:
        active_story_side = {}
        pending = ""
        _return_to_world()
    ui.show_message(result)

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
        "story_side":
            var stage: Dictionary = game_core.story_stage_record(active_story_side)
            var pick: Dictionary = stage.get("choice", {})
            if not pick.is_empty():
                pending = "story_side_choice"
                ui.show_choices(pick)
                return
            _finish_story_side()
            return
        "story_side_branch":
            active_story_side = {}
        "optional_event":
            if optional_director.mark_seen(pending_optional):
                game_events.record("optional_event",{"id":str(pending_optional.get("id",""))})
            pending_optional = {}
        "choice_reaction":
            _crisis_choice_complete()
            return
        "ambient_npc":
            pass
        "optional_inspect":
            if not active_optional_flag.is_empty():
                progress.flags[active_optional_flag] = true
                game_events.record("investigation",{"flag":active_optional_flag})
            active_optional_flag = ""
        "ambient_midpoint":
            progress.flags["explore.ch%03d.midpoint" % progress.chapter] = true
        "ending_intro":
            _begin_ending_choice()
            return
        "ending_epilogue":
            _finish_ending_scene()
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
            game_core.add_item("item_herb_01",int(reward.get("potions",0)))
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
    if pending == "ending_select":
        _choose_ending(item)
        return
    if pending == "story_side_choice":
        _finish_story_side(item)
        return
    for key in (item.get("sets", {}) as Dictionary).keys():
        progress.flags[str(key)] = (item["sets"] as Dictionary)[key]
    var scene: Dictionary = _current_scene()
    var choice: Dictionary = scene.get("choice", {})
    progress.flags[str(choice.get("id", "choice")) + ".chosen"] = true
    var followup: Dictionary = optional_director.reaction(progress.chapter,item,progress.flags)
    if not followup.is_empty() and optional_director.mark_seen(followup):
        pending = "choice_reaction"
        ui.show_dialogue(followup.get("dialogue",[]))
        return
    _crisis_choice_complete()

func _crisis_choice_complete() -> void:
    _apply_effects(_current_scene())
    if progress.chapter == 1:
        _advance_scene()
        _save_progress()
        _return_to_world()
        return
    var encounter_value: Variant = _current_scene().get("encounter", {})
    var fight: Dictionary = encounter_value if encounter_value is Dictionary else {}
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
    atlas.show_exploration(false)
    battle = BattleScript.new()
    add_child(battle)
    battle.completed.connect(_battle_finished)
    battle.invincible = invincible
    battle.game_core = game_core
    var battle_event: Variant = _current_scene().get("encounter", {}) if is_boss else {}
    battle.encounter_data = battle_event if battle_event is Dictionary else {}
    battle.start(progress, progress.chapter, is_boss)

func _random_encounter() -> void:
    if no_encounters:
        world.locked = false
        return
    _start_battle(false)

func _battle_finished(won: bool, xp: int, money: int) -> void:
    var defeated_monster: String = str(battle.enemy.get("monster_id","")) if is_instance_valid(battle) else ""
    if is_instance_valid(battle):
        battle.queue_free()
        battle = null
    if won:
        var levels: Array[String] = progress.give_rewards(xp * (5 if five_xp else 1), money)
        var job_levels: Array[String] = game_core.award_job_xp(maxi(5,int(xp / 5)),battle_is_boss)
        game_events.record("battle_victory",{"boss":battle_is_boss,"xp":xp,"gold":money})
        var loot: Array[String] = game_core.roll_monster_loot(defeated_monster)
        if battle_is_boss:
            progress.flags["ch%03d.battle_won" % progress.chapter] = true
            _advance_scene()
            if not job_levels.is_empty():
                ui.show_message("职业提升：" + "；".join(job_levels))
        else:
            ui.show_message("战斗胜利，获得 %d 经验、%d 金币。%s%s" % [xp * (5 if five_xp else 1), money, "，".join(levels)+"；".join(job_levels), (" 掉落："+ "、".join(loot) if not loot.is_empty() else "")])
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
    var quest_key: String = "quest_main_%03d" % last
    if not game_core.entry("quests",quest_key).is_empty():
        progress.rpg["quests"][quest_key] = true
    if last == 4:
        progress.recruit_sailor()
    if last == 6:
        progress.flags["world.seven_lanterns.first"] = true
    if last == 72:
        _begin_ending_choice()
        return
    game_events.record("chapter_completed",{"chapter":last})
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

func _begin_ending_choice() -> void:
    if progress.chapter != 72:
        return
    var final_scene: Dictionary = _current_scene()
    var raw_choice: Dictionary = final_scene.get("choice", {})
    if raw_choice.is_empty():
        push_error("第72章命运抉择数据缺失")
        return
    var choices: Dictionary = ending_director.choices(raw_choice, progress.flags)
    pending = "ending_select"
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.show_choices(choices)

func _choose_ending(option: Dictionary) -> void:
    var id: String = str((option.get("sets", {}) as Dictionary).get("world.ending", ""))
    if not ending_director.can_choose(id, progress.flags):
        _begin_ending_choice()
        return
    progress.flags["world.ending"] = id
    progress.rpg["ending_id"] = id
    progress.rpg["ending_scene_index"] = 0
    progress.rpg["ending_complete"] = false
    var quests: Dictionary = progress.rpg.get("quests", {})
    quests["quest_main_072"] = true
    progress.rpg["quests"] = quests
    _save_progress()
    _play_ending_scene()

func _play_ending_scene() -> void:
    var id: String = ending_replay_id if not ending_replay_id.is_empty() else str(progress.rpg.get("ending_id", ""))
    var index: int = ending_replay_scene if not ending_replay_id.is_empty() else int(progress.rpg.get("ending_scene_index", 0))
    var scene: Dictionary = ending_director.scene(id, index)
    if scene.is_empty():
        if ending_replay_id.is_empty():
            _finalize_ending()
        else:
            ending_replay_id = ""
            ending_replay_scene = 0
            pending = ""
            paused_for_dialogue = false
            _return_to_world()
            ui.show_message("结局回放完毕。")
        return
    pending = "ending_epilogue"
    busy = true
    paused_for_dialogue = true
    world.locked = true
    var lines: Array = scene.get("dialogue", [])
    ui.show_dialogue(lines)

func _finish_ending_scene() -> void:
    if not ending_replay_id.is_empty():
        ending_replay_scene += 1
        _play_ending_scene()
        return
    progress.rpg["ending_scene_index"] = int(progress.rpg.get("ending_scene_index", 0)) + 1
    _save_progress()
    _play_ending_scene()

func _finalize_ending() -> void:
    var id: String = str(progress.rpg.get("ending_id", ""))
    if ending_director.details(id).is_empty():
        push_error("不能保存无效结局：" + id)
        return
    progress.flags["story.ch072.done"] = true
    progress.flags["story.complete"] = true
    game_events.record("chapter_completed",{"chapter":72,"ending":id})
    progress.rpg["ending_complete"] = true
    var archive: Dictionary = progress.rpg.get("ending_archive", {})
    archive[id] = true
    progress.rpg["ending_archive"] = archive
    progress.scene_index = 5
    progress.task_index = 0
    pending = ""
    paused_for_dialogue = false
    _save_progress()
    _enter_location()
    ui.show_message("《%s》完成！结局已经记录于「功能手册 → 结局档案」。" % ending_director.title(id))

func _replay_ending(id: String) -> void:
    var archive: Dictionary = progress.rpg.get("ending_archive", {})
    if not bool(archive.get(id, false)) or ending_director.details(id).is_empty():
        return
    adventure_menu.close_menu()
    ending_replay_id = id
    ending_replay_scene = 0
    _play_ending_scene()

func _travel_to(map_id: String) -> void:
    if progress.chapter < 1 or is_instance_valid(battle):
        return
    if not world.interior_building.is_empty():
        ui.show_message("请先从建筑出口返回街道，再前往其他区域。")
        return
    var previous_map: String = world_router.current_map()
    if not world_router.travel(map_id):
        ui.show_message("航路尚未解锁，请先沿主线探索相邻地区。")
        return
    game_events.advance_time(45)
    game_events.record("travel",{"map_id":map_id})
    adventure_menu.close_menu()
    _enter_location()
    world.spawn_from_exit(previous_map)
    _save_progress()
    ui.show_message("已抵达：" + str(world_router.profile().get("name",map_id)))

func _house_accessible() -> bool:
    var info: Dictionary = world_router.profile()
    return housing.owned() and housing.can_access(info) and str(info.get("region_id","")) == str(housing.data().get("region_id",""))

func _purchase_house() -> void:
    var message: String = housing.purchase(world_router.profile())
    if housing.owned():
        game_events.record("house_owned",{"region_id":str(housing.data().get("region_id",""))})
    _save_progress()
    adventure_menu.render("家园")
    adventure_menu.footer.text = message

func _open_house() -> void:
    if not _house_accessible():
        ui.show_message("需在家园所属地区的城镇进入房屋；没有地契可先在功能栏购买。")
        return
    if adventure_menu.root.visible:
        adventure_menu.close_menu()
    ui.close_menu()
    busy = true
    world.locked = true
    housing_room.open_house(housing,progress,game_core)

func _housing_changed(message: String) -> void:
    game_events.record("home_activity",{"description":message})
    _save_progress()

func _save_slot(slot: int) -> void:
    var success: bool = save_slots.save_slot(progress,slot)
    adventure_menu.render("存档管理")
    adventure_menu.footer.text = "槽位 %d %s" % [slot,"已保存" if success else "保存失败"]

func _load_slot(slot: int) -> void:
    if not save_slots.load_slot(progress,slot):
        adventure_menu.footer.text = "槽位文件损坏或读取失败。"
        return
    game_core.bind(progress)
    world_router.bind(progress)
    game_events.bind(progress)
    housing.bind(progress)
    optional_director.bind(progress)
    adventure_menu.close_menu()
    _enter_location()
    _save_progress()
    if progress.chapter == 72 and progress.scene_index == 4 and not bool(progress.flags.get("story.complete",false)):
        if str(progress.rpg.get("ending_id","")).is_empty():
            _begin_ending_choice()
        else:
            _play_ending_scene()
    ui.show_message("已载入手动存档 %d。" % slot)

func _save_progress() -> void:
    if not progress.save():
        push_warning("游戏主体存档写入失败")

func _save() -> void:
    _save_progress()
    ui.show_message("旅途进度已保存。")

func _open_adventure_book() -> void:
    if is_instance_valid(battle):
        return
    atlas.show_exploration(false)
    ui.close_menu()
    busy = true
    world.locked = true
    adventure_menu.show_menu(game_core, progress)
    atlas.show_exploration(false)

func _show_menu() -> void:
    if busy:
        return
    atlas.show_exploration(false)
    busy = true
    world.locked = true
    ui.show_menu(progress.actors, progress.gold, progress.potions)

func _map_opened() -> void:
    if busy or is_instance_valid(battle):
        atlas.close_map()
        return
    ui.clear_movement()
    busy = true
    world.locked = true
    ui.set_play_visible(false)

func _open_world_map_from_book() -> void:
    if is_instance_valid(battle):
        return
    adventure_menu.close_menu()
    _return_to_world()
    atlas.show_exploration(true)
    atlas.show_world_map()

func _open_map_from_quick_menu() -> void:
    if is_instance_valid(battle):
        return
    ui.close_menu()
    atlas.open_map()

func _return_to_world() -> void:
    busy = paused_for_dialogue or is_instance_valid(battle) or ui.menu_layer.visible or adventure_menu.root.visible or housing_room.root.visible or cheat.shade.visible or atlas.is_open()
    if not busy and world.party_ids != progress.rpg.get("party",[]):
        _enter_location()
        return
    world.locked = busy
    ui.set_play_visible(not is_instance_valid(battle) and not atlas.is_open())
    atlas.show_exploration(not busy)
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
    game_events.advance_time(480)
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
                a["level"] = mini(progress.level_cap, int(a["level"]) + 10)
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
            if progress.chapter < 72:
                if progress.chapter == 0:
                    progress.flags["story.prologue_done"] = true
                else:
                    progress.flags["story.ch%03d.done" % progress.chapter] = true
                    if progress.chapter == 71:
                        progress.flags["ch071.battle_won"] = true
                progress.chapter += 1
                progress.scene_index = 0
                progress.task_index = 0
                _save_progress()
                _enter_location()
            else:
                message = "已处于第72章终章。请在命运灯坛选择结局。"
        "village":
            message = "剧情地图自动依据章节载入。"
        "ruins":
            message = "正式剧情下不可越过任务条件随意传送。"
        _:
            message = "未知指令。"
    _save_progress()
    _focus()
    cheat.report(message)
