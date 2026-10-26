extends Node2D
## 《星灯纪行》72章全篇：地图、分支任务、三结局、战斗与存档协调器。
const WorldScript = preload("res://scripts/first_act_world.gd")
const UIScript = preload("res://scripts/first_act_ui.gd")
const MapScript = preload("res://scripts/map_hud.gd")
const WorldFogV3 = preload("res://scripts/world_fog_v3.gd")
const BattleScript = preload("res://scripts/first_act_battle.gd")
const BattleRewardTransaction = preload("res://scripts/battle_reward_transaction.gd")
const BattleV3Settlement = preload("res://scripts/d_world_interaction/battle_v3_settlement.gd")
const QuestV3Settlement = preload("res://scripts/d_world_interaction/quest_v3_settlement.gd")
const V3ProgressTransition = preload("res://scripts/d_world_interaction/v3_progress_transition.gd")
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
const StoryBranchRuntime = preload("res://scripts/story_branch_runtime.gd")
const EvidencePuzzles = preload("res://scripts/story_evidence_puzzles.gd")
const StoryWorldBindings = preload("res://scripts/story_world_bindings.gd")
const RegionalServiceMenu = preload("res://scripts/world_service_menu.gd")
const CinematicDirector = preload("res://scripts/cinematic_director.gd")
const CinematicCamera = preload("res://scripts/cinematic_camera.gd")
var progress
var catalog
var world
var ui
var atlas
var map_fog
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
var branch_runtime
var evidence_puzzles = EvidencePuzzles.new()
var active_puzzle_quest: String = ""
var story_world_bindings
var service_menu
var cinematic
var cinematic_camera
var cinematic_resume: String = ""
var cinematic_force_play: bool = false
var cinematic_prologue: Dictionary = {}
var cinematic_chapters: Dictionary = {}
var cinematic_scene_blocking: Dictionary = {}
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
    branch_runtime = StoryBranchRuntime.new()
    story_world_bindings = StoryWorldBindings.new()
    if not story_world_bindings.errors.is_empty():
        push_error("地图任务定位数据错误：" + "；".join(story_world_bindings.errors))
    if not branch_runtime.load_all():
        push_error("阶段19剧情扩展读取失败：" + "；".join(branch_runtime.errors))
    var side_file: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/first_act_side_quests.json"))
    if side_file is Dictionary:
        for row in side_file.get("quests", []):
            if row is Dictionary:
                side_quests[int(row.get("chapter", 0))] = row
    catalog = CatalogScript.new()
    var loaded: bool = catalog.load_all()
    world = WorldScript.new()
    map_fog = WorldFogV3.new()
    world.fog = map_fog
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
    adventure_menu.branch_runtime = branch_runtime
    adventure_menu.branch_event_requested.connect(_start_branch_event)
    adventure_menu.branch_navigation_requested.connect(_track_branch_event)
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
    service_menu = RegionalServiceMenu.new()
    add_child(service_menu)
    service_menu.closed.connect(_return_to_world)
    service_menu.action_requested.connect(_service_action)
    cinematic_prologue = JSON.parse_string(FileAccess.get_file_as_string("res://data/cinematics/prologue.json"))
    cinematic_chapters = JSON.parse_string(FileAccess.get_file_as_string("res://data/cinematics/chapter_transitions.json"))
    cinematic_scene_blocking = JSON.parse_string(FileAccess.get_file_as_string("res://data/cinematics/scene_blocking.json"))
    cinematic = CinematicDirector.new()
    add_child(cinematic)
    cinematic.finished.connect(_cinematic_finished)
    cinematic_camera = CinematicCamera.new()
    add_child(cinematic_camera)
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
        world.sync_world_clock(int(progress.rpg.get("game_clock",{}).get("day",1)),int(progress.rpg.get("game_clock",{}).get("minutes",480)))

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
    # A failed Continue must NEVER start a new game and overwrite unreadable saves.
    # Keep both original files for recovery or inspection.
    if continue_game and not progress.load_saved():
        ui.show_title(false, "存档与备份均无法读取，已保留原文件。请先备份文件再开始新游戏。")
        return
    var fresh_game: bool = not continue_game
    if fresh_game:
        progress.new_game()
        if not progress.save():
            ui.show_title(false, "新游戏无法创建存档，请检查设备空间与存储权限。")
            return
    game_core.bind(progress)
    world_router.bind(progress)
    map_fog.bind(progress)
    game_events.bind(progress)
    housing.bind(progress)
    optional_director.bind(progress)
    branch_runtime.bind(progress)
    if progress.chapter == 72 and bool(progress.flags.get("story.complete",false)) and str(progress.rpg.get("ending_id","")).is_empty():
        # v0.3旧版结算标记没有三结局记录：迁移到终局选择，保留装备、等级与支线。
        progress.flags.erase("story.complete")
        progress.flags["story.ch072.done"] = true
        progress.scene_index = 4
        progress.save()
    _enter_location()
    var interrupted_cue: String = str(progress.rpg.get("cinematic_checkpoint",""))
    if not fresh_game and not interrupted_cue.is_empty():
        var desired_resume: String = "explore" if interrupted_cue=="cold_open" else "dialogue"
        if _play_story_cinematic(interrupted_cue,desired_resume):
            return
        progress.rpg.erase("cinematic_checkpoint")
    var resumed_branch: Dictionary = branch_runtime.resume()
    if not resumed_branch.is_empty() and str(progress.rpg.get("branch_story",{}).get("active",{}).get("source","menu")) == "menu":
        _display_branch_event(resumed_branch)
        return
    if fresh_game and progress.chapter == 0 and _play_story_cinematic("cold_open","explore"):
        return
    if progress.chapter == 72 and progress.scene_index == 4 and not bool(progress.flags.get("story.complete", false)):
        if str(progress.rpg.get("ending_id", "")).is_empty():
            _begin_ending_choice()
        else:
            _play_ending_scene()

func _play_story_cinematic(cue_id: String,resume: String) -> bool:
    # Headless game automation runs story logic without waiting for presentation.
    # Explicit cinematic smoke tests opt in to the real on-screen state machine.
    if DisplayServer.get_name() == "headless" and not cinematic_force_play:
        return false
    if bool(progress.flags.get("cinematic."+cue_id+".seen",false)):
        return false
    var cue: Dictionary = cinematic_prologue.get("beats",{}).get(cue_id,{})
    if cue.is_empty() or not cinematic.start(cue_id,cue):
        return false
    cinematic_resume=resume
    if progress.chapter==0 and cue_id.begins_with("prologue_"):
        world.set_prologue_phase(progress.scene_index,progress.chapter)
    progress.rpg["cinematic_checkpoint"]=cue_id
    _save_progress()
    busy=true
    paused_for_dialogue=true
    world.locked=true
    ui.set_play_visible(false)
    atlas.show_exploration(false)
    _mix_world_for_cinematic(true)
    return true

func _cinematic_finished(cue_id: String,_skipped: bool) -> void:
    # Completed and skipped scenes have identical canonical state effects.
    # This is presentation-only: narrative effects remain in _dialogue_ended.
    if cue_id.is_empty():
        return
    _mix_world_for_cinematic(false)
    progress.flags["cinematic."+cue_id+".seen"]=true
    progress.rpg.erase("cinematic_checkpoint")
    var resume: String=cinematic_resume
    cinematic_resume=""
    paused_for_dialogue=false
    _save_progress()
    if resume=="dialogue":
        busy=false
        _present("prologue")
    elif resume=="explore":
        _return_to_world()

func _mix_world_for_cinematic(mute_ambience: bool) -> void:
    if world==null or not is_instance_valid(world.coastal_audio):
        return
    var environment_player: AudioStreamPlayer=world.coastal_audio.player
    if environment_player==null or not is_instance_valid(environment_player):
        return
    if not environment_player.has_meta("cinematic_original_db"):
        environment_player.set_meta("cinematic_original_db",environment_player.volume_db)
    var normal_db: float=float(environment_player.get_meta("cinematic_original_db",-30.0))
    var destination: float=-44.0 if mute_ambience else normal_db
    var active_fade: Variant=environment_player.get_meta("cinematic_fade") if environment_player.has_meta("cinematic_fade") else null
    if active_fade is Tween and active_fade.is_running():
        active_fade.kill()
    var fade: Tween=create_tween()
    fade.tween_property(environment_player,"volume_db",destination,0.34)
    environment_player.set_meta("cinematic_fade",fade)

func _chapter_card(chapter_no: int) -> void:
    if chapter_no<1 or cinematic==null:
        return
    var all_chapters: Array = cinematic_chapters.get("chapters",[])
    var chosen: Dictionary={}
    for record in all_chapters:
        if int(record.get("number",0))==chapter_no:
            chosen=record
            break
    if chosen.is_empty():
        return
    var act_no: int=int(chosen.get("act",1))
    var act_title: String=""
    for record in cinematic_chapters.get("acts",[]):
        if int(record.get("act",0))==act_no:
            act_title=str(record.get("title",""))
            break
    var is_act_start: bool=(chapter_no-1)%6==0
    var heading: String=("%s · %s" % ["第%d幕" % act_no,act_title]) if is_act_start else ("第%d章 · %s" % [chapter_no,str(chosen.get("title",""))])
    var label_text: String=("第%d章 · %s" % [chapter_no,str(chosen.get("title",""))]) if is_act_start else str(chosen.get("location","洛维恩"))
    cinematic.banner_card(heading,label_text,"mystery" if is_act_start else "hope")

func _enter_location() -> void:
    game_core.register_chapter(progress.chapter)
    world_router.sync_chapter(progress.chapter)
    world.map_profile = world_router.profile()
    world.custom_region = str(world.map_profile.get("name",game_core.location_name(progress.chapter)))
    world.party_ids = progress.rpg.get("party", []).duplicate()
    world.build(progress.chapter, world.party_ids.size())
    var saved_world: Dictionary = progress.rpg.get("world",{})
    var indoor_id: String = str(saved_world.get("indoor_building",""))
    if not indoor_id.is_empty():
        var restored_room: bool = world.enter_story_submap(indoor_id.trim_prefix("quest__"),true) if indoor_id.begins_with("quest__") else world.enter_building(indoor_id)
        if restored_room:
            var outdoor: Array = saved_world.get("outdoor_return",[])
            if outdoor.size()==2:
                world.exterior_position=Vector2(float(outdoor[0]),float(outdoor[1]))
        else:
            saved_world.erase("indoor_building")
            saved_world.erase("outdoor_return")
    world.sync_world_clock(int(progress.rpg.get("game_clock",{}).get("day",1)),int(progress.rpg.get("game_clock",{}).get("minutes",480)))
    _restore_world_position()
    world.set_prologue_phase(progress.scene_index,progress.chapter)
    world.refresh_field_ecology(progress)
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
    if progress.chapter <= 3:
        var steps: Array[String] = ["与%s交谈" % WorldScript.NPC_NAMES[progress.chapter], "调查线索" if progress.task_index == 0 else "向目击者核实线索", "再次调查冲突点，开始战斗" if progress.task_index == 1 else "调查冲突点", "返回归航点，完成本章"]
        if progress.scene_index >= 0 and progress.scene_index < steps.size():
            var instruction: String = steps[progress.scene_index]
            if not world.interior_building.is_empty():
                instruction = "先从出口返回室外"
            var advice: String = "地图查看主线标记，靠近后调查"
            if progress.scene_index == 2 and progress.chapter > 1:
                advice = "可先补给；重击防御，喘息回复"
            return "【主线 %d/4】%s\n%s" % [progress.scene_index+1,instruction,advice]
    match progress.scene_index:
        0: return prefix + " · 找到" + (WorldScript.NPC_NAMES[progress.chapter] if progress.chapter < WorldScript.NPC_NAMES.size() else "关键人物")
        1: return prefix + (" · 调查线索" if progress.task_index == 0 else " · 询问目击者")
        2: return prefix + (" · 迎战敌人" if progress.task_index == 1 else " · 前往冲突现场")
        3: return prefix + " · 返回归航点，完成本章"
    if progress.chapter == 72 and progress.scene_index == 4:
        return "最后的抉择 · 前往归航灯坛，见证世界的未来"
    return "探索旅途中的秘密"

func _focus() -> void:
    # Refresh sector NPC/evidence/notice props against actual reachable terrain,
    # after each decision, loading a slot, changing map or finishing an event.
    var tracked: String = str(progress.rpg.get("tracked_branch_event",""))
    var branch_world: Dictionary = world.sync_story_world_markers(
        story_world_bindings,game_core,branch_runtime,tracked)
    world.refresh_room_evidence(progress.rpg)
    world.refresh_room_npcs(progress.flags)
    world.sync_prologue_markers(progress.scene_index,progress.chapter)
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
    if progress.chapter > 0:
        var quest: Dictionary = game_core.available_story_side(progress.chapter)
        if not quest.is_empty():
            var stage: int = game_core.story_side_stage(str(quest.get("id","")))
            var stages: Array = quest.get("stages",[])
            if stage < stages.size():
                if story_world_bindings.matches(str(quest.get("id","")),world_router.current_map()):
                    # Only the one actually tracked original quest uses this map
                    # point, and it must outrank a separate chapter-local errand.
                    var original_quest_id: String = str(quest.get("id",""))
                    if not world.quest_submaps.detail(original_quest_id).is_empty() and world.interior_building.is_empty():
                        side_target = "questdoor:"+original_quest_id
                        extra = "【调查现场入口】%s · 进入专属调查地点" % str(quest.get("title","未命名委托"))
                    else:
                        side_target = "story_stage_%d" % stage
                        extra = "【世界支线】%s · %s" % [str(quest.get("title","未命名委托")),str(stages[stage].get("objective","前往支线地点"))]
                elif side_target.is_empty():
                    extra = "【世界支线导航】" + story_world_bindings.route_summary(str(quest.get("id","")),world_router)
    var branch_choice: Dictionary = branch_world.get("chosen",{})
    if bool(branch_world.get("local",false)) and not branch_choice.is_empty():
        var step: int = int(progress.rpg.get("branch_story",{}).get("active",{}).get("line",0))
        var marker: String = "branchmap:"+str(branch_choice.get("id",""))+":"+str(step)
        if world.nodes.has(marker):
            side_target = marker
            var scene_plan: Dictionary = world.scene_director.stage(str(branch_choice.get("quest_id","")),branch_choice,step)
            extra = "【剧情实地回访】%s · %s（%d/3）" % [str(branch_choice.get("title","")),str(scene_plan.get("label","调查线索")),step+1]
    elif not tracked.is_empty() and branch_runtime.eligible(tracked):
        var destination: Dictionary = branch_runtime.get_event(tracked)
        var tracking_quest: String = str(destination.get("quest_id",""))
        if not world.quest_submaps.detail(tracking_quest).is_empty() and world.interior_building.is_empty() and world.nodes.has("questdoor:"+tracking_quest):
            side_target = "questdoor:"+tracking_quest
            extra = "【专属场景后续调查】" + world.quest_submaps.room_name(tracking_quest)
        else:
            extra = "【剧情路线】" + story_world_bindings.route_summary(tracking_quest,world_router)
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
    # The opening tracker prioritizes the main route. Optional markers remain
    # on the atlas; stacking their prose here clips the fixed-height mobile HUD.
    var show_extra: bool = progress.chapter > 3 and not extra.is_empty()
    ui.set_hud(progress.chapter, world.region_name(), _objective() + ("\n" + extra if show_extra else ""), progress.actors, progress.gold, progress.potions)
    atlas.set_targets(world.focus_name,side_target)
    var nav_event: Dictionary = branch_runtime.get_event(tracked)
    if not nav_event.is_empty() and not branch_runtime.is_seen(tracked):
        var quest_id: String = str(nav_event.get("quest_id",""))
        atlas.set_story_route(story_world_bindings.map_for(quest_id),
            story_world_bindings.route_summary(quest_id,world_router))
    else:
        atlas.set_story_route("","")

func _interact(target: String) -> void:
    if busy:
        return
    if target.begins_with("field:"):
        if not world.interior_building.is_empty():
            return
        var field_map: String=world_router.current_map()
        var field_action: String=target.trim_prefix("field:")
        var field_clock: Dictionary=progress.rpg.get("game_clock",{})
        var field_weather: String=str(world.ambience.weather) if world.ambience!=null else "clear"
        var field_result: Dictionary=world.field_ecology.interact(field_map,field_action,progress,field_weather,int(field_clock.get("minutes",480)),int(field_clock.get("day",1)))
        if bool(field_result.get("changed",false)):
            var field_reward: Dictionary=field_result.get("reward",{})
            if not field_reward.is_empty():
                var field_gold: int=maxi(0,int(field_reward.get("gold",0)))
                var field_item: String=str(field_reward.get("item_id",""))
                var field_count: int=maxi(0,int(field_reward.get("amount",0)))
                progress.gold+=field_gold
                if not field_item.is_empty() and field_count>0:
                    game_core.add_item(field_item,field_count)
            game_events.record("field_ecology_v7",{"map":field_map,"event":field_action,"weather":field_weather})
            _save_progress()
            _focus()
        world.refresh_field_ecology(progress)
        if bool(field_result.get("teleport",false)):
            world.teleport_field_secret()
        ui.show_message(str(field_result.get("message","附近没有可以操作的地形。")))
        return
    if target.begins_with("townlife:"):
        if not world.interior_building.is_empty():
            return
        var town_id: String = world_router.current_map()
        var task_id: String = target.trim_prefix("townlife:")
        var hour: int = int(float(progress.rpg.get("game_clock",{}).get("minutes",480))/60.0)
        var result: Dictionary = world.town_ecology.interact(town_id,task_id,progress,hour)
        if bool(result.get("changed",false)):
            var reward: Dictionary = result.get("reward",{})
            var message: String = str(result.get("message",""))
            if not reward.is_empty():
                var amount: int = maxi(0,int(reward.get("gold",0)))
                var item_id: String = str(reward.get("item_id",""))
                var item_count: int = maxi(0,int(reward.get("amount",0)))
                progress.gold += amount
                if item_count>0 and not item_id.is_empty():
                    game_core.add_item(item_id,item_count)
                message += "\n社区酬谢：%d G 与补给 ×%d。" % [amount,item_count]
                game_events.record("town_ecology_completed",{"map":town_id,"activity":task_id})
            else:
                game_events.record("town_ecology_activity",{"map":town_id,"activity":task_id})
            _save_progress()
            ui.show_message(message)
        else:
            ui.show_message(str(result.get("message","街区活动暂时无法办理。")))
        return
    if target.begins_with("discovery:"):
        if not world.interior_building.is_empty():
            return
        var map_id: String = world_router.current_map()
        var event_id: String = target.trim_prefix("discovery:")
        var record: Dictionary = world.discoveries.event(map_id,event_id)
        if record.is_empty():
            ui.show_message("这里尚没有可以调查的地图地标。")
            return
        var completion: String = world.discoveries.flag(map_id,event_id)
        if bool(progress.flags.get(completion,false)):
            ui.show_message("【%s】已完成调查，记录留存在旅途日志中。" % str(record.get("name","探索地点")))
            return
        var needed: String = str(record.get("require",""))
        if not needed.is_empty() and not bool(progress.flags.get(world.discoveries.flag(map_id,needed),false)):
            ui.show_message("【%s】附近还有未调查的线索，暂时无法解开此处的秘密。" % str(record.get("name","地标")))
            return
        progress.flags[completion] = true
        var narrative: String = str(record.get("text",""))
        var reward: Dictionary = record.get("reward",{}) if record.get("reward",{}) is Dictionary else {}
        var payout: String = ""
        if not reward.is_empty():
            var amount: int = maxi(0,int(reward.get("gold",0)))
            var item_id: String = str(reward.get("item_id",""))
            var item_count: int = maxi(0,int(reward.get("amount",0)))
            if not item_id.is_empty() and item_count>0:
                game_core.add_item(item_id,item_count)
            progress.gold += amount
            payout = "\n获得 %d G 与地区补给 ×%d。" % [amount,item_count]
        game_events.record("world_discovery",{"map":map_id,"site":event_id})
        _save_progress()
        ui.show_message("【%s】\n%s%s" % [str(record.get("name","地标")),narrative,payout])
        return
    if target.begins_with("puzzle:"):
        if not world.interior_building.is_empty():
            return
        var region_id: String = world_router.current_map()
        var device_id: String = target.trim_prefix("puzzle:")
        var solved: Dictionary = world.dungeon_puzzles.interact(region_id,device_id,progress)
        if bool(solved.get("changed",false)):
            var payment: Dictionary = solved.get("reward",{})
            if not payment.is_empty():
                var gold: int = maxi(0,int(payment.get("gold",0)))
                var item_id: String = str(payment.get("item_id",""))
                var count: int = maxi(0,int(payment.get("amount",0)))
                progress.gold += gold
                if count>0 and not item_id.is_empty():
                    game_core.add_item(item_id,count)
                game_events.record("dungeon_puzzle_solved",{"map":region_id,"mode":str(world.dungeon_puzzles.config(region_id).get("mode",""))})
            _save_progress()
        ui.show_message(str(solved.get("message","这里没有可操作的机关。")))
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
        var daily: Dictionary = progress.rpg.get("camp_last_day",{})
        var region_id: String = world_router.current_map()
        var calendar: Dictionary = progress.rpg.get("game_clock",{})
        var today: int = int(calendar.get("day",1))
        if int(daily.get(region_id,-1)) == today:
            ui.show_message("今天已经在这处营地休息过了。还可以整理队伍与查看地图。")
            return
        daily[region_id] = today
        progress.rpg["camp_last_day"] = daily
        for i in range(progress.actors.size()):
            var person: Dictionary = progress.actors[i]
            if int(person.get("hp",0))>0:
                person["hp"]=mini(int(person.get("max_hp",1)),int(person.get("hp",1))+maxi(12,roundi(float(person.get("max_hp",1))*0.38)))
                person["mp"]=mini(int(person.get("max_mp",1)),int(person.get("mp",0))+maxi(6,roundi(float(person.get("max_mp",1))*0.30)))
                progress.actors[i]=person
        world.encounter_meter=-380.0
        game_events.advance_time(120)
        game_events.record("camp_rest",{"map":region_id})
        world.sync_world_clock(int(progress.rpg["game_clock"].get("day",1)),int(progress.rpg["game_clock"].get("minutes",480)))
        _save_progress()
        _focus()
        ui.show_message("队伍在安全营地整备两小时，恢复部分 HP / MP；附近的怪物暂时不会接近。")
        return
    if target.begins_with("exit:"):
        _travel_to(target.trim_prefix("exit:"))
        return
    if target.begins_with("questdoor:"):
        var lost_page_id: String = target.trim_prefix("questdoor:")
        if world.enter_story_submap(lost_page_id):
            var current_world: Dictionary = progress.rpg.get("world",{})
            current_world["indoor_building"] = world.interior_building
            current_world["outdoor_return"] = [world.exterior_position.x,world.exterior_position.y]
            game_events.record("lost_page_scene_entered",{"quest_id":lost_page_id,"map":world_router.current_map()})
            _save_progress()
            _focus()
            ui.show_message("进入"+world.quest_submaps.room_name(lost_page_id)+"。现场调查、证物与离开进度均可保存。")
        return
    if target.begins_with("building:"):
        var building_id: String = target.trim_prefix("building:")
        if world.enter_building(building_id):
            var current_world: Dictionary = progress.rpg.get("world",{})
            current_world["indoor_building"] = building_id
            current_world["outdoor_return"] = [world.exterior_position.x,world.exterior_position.y]
            game_events.record("building_entered",{"building":building_id,"map":world_router.current_map()})
            _save_progress()
            _focus()
            ui.show_message("进入 " + world.region_name() + "。室内进度已自动保存。")
        return
    if target == "interior_exit":
        if world.leave_building():
            var current_world: Dictionary = progress.rpg.get("world",{})
            current_world.erase("indoor_building")
            current_world.erase("outdoor_return")
            _save_progress()
            _focus()
            ui.show_message("返回 " + world.region_name() + "。")
        return
    if target == "interior_service":
        _open_regional_service()
        return
    if target == "interior_storage":
        ui.show_message("储物柜与家具已经布置。家园专用仓储请从自己的房屋进入。")
        return
    if target.begins_with("questcase:") and world.interior_building.begins_with("quest__"):
        var quest_id: String = world.interior_building.trim_prefix("quest__")
        var step: int = int(target.trim_prefix("questcase:"))
        var details: Dictionary = world.quest_submaps.detail(quest_id)
        var titles: Array = details.get("displays",[])
        if step>=0 and step<titles.size():
            var gallery: Dictionary = progress.rpg.get("quest_gallery",{})
            var room_log: Dictionary = gallery.get(quest_id,{})
            room_log[str(step)] = true
            gallery[quest_id] = room_log
            progress.rpg["quest_gallery"] = gallery
            _save_progress()
            var dossier: Dictionary = world.scene_director.dossier(quest_id)
            var note: String = str(dossier.get("observation","")) if step==1 else (str(dossier.get("later_record","")) if step==2 else str(details.get("original_location","")))
            if step==2 and evidence_puzzles.can_attempt(progress.rpg,quest_id):
                var puzzle: Dictionary = evidence_puzzles.entry(quest_id)
                active_puzzle_quest = quest_id
                pending = "quest_puzzle_choice"
                busy = true
                paused_for_dialogue = true
                world.locked = true
                ui.show_choices({"prompt":"【%s】%s" % [str(puzzle.get("mechanic","线索比对")),str(puzzle.get("prompt",""))],
                    "options":puzzle.get("options",[])})
                return
            _focus()
            ui.show_message("【调查档案 %d/3】%s。%s" % [step+1,str(titles[step]),note])
        return
    if target.begins_with("branchmap:") or target.begins_with("questhint:"):
        _interact_world_branch(target)
        return
    if target.begins_with("citizen:"):
        var citizen_id: String = target.trim_prefix("citizen:")
        var clock: Dictionary = progress.rpg.get("game_clock",{})
        var conversation: Dictionary = world.town_life.talk(citizen_id,str(world.map_profile.get("region_id","region_coast")),clock,progress)
        var map_id: String = world_router.current_map()
        var neighborhood_gossip: String = world.town_ecology.resident_hint(map_id,progress,int(float(clock.get("minutes",480))/60.0))
        if not neighborhood_gossip.is_empty():
            conversation["text"]=str(conversation.get("text",""))+"\n"+neighborhood_gossip
        if bool(conversation.get("first",false)):
            game_events.record("resident_met",{"id":citizen_id,"region_id":str(world.map_profile.get("region_id",""))})
            _save_progress()
        pending = "resident_talk"
        busy = true
        paused_for_dialogue = true
        world.locked = true
        ui.show_dialogue([{"speaker":str(conversation.get("name","居民")),"text":str(conversation.get("text",""))}])
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
            _save_progress()
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
                if _advance_scene():
                    ui.show_message("线索已经齐备，新的事件正在发生。")
                else:
                    ui.show_message("场景进度未保存，请重新调查线索。")
        2:
            if progress.task_index == 1:
                _start_battle(true)
            else:
                _present("crisis")
        3: _present("resolve")
        4: _present("ending_intro")

func _start_branch_event(event_id: String) -> void:
    if branch_runtime == null or not branch_runtime.begin(event_id):
        ui.show_message("该支线后续尚未开放，或已经完成。")
        return
    adventure_menu.close_menu()
    _display_branch_event(branch_runtime.get_event(event_id))

func _display_branch_event(event: Dictionary) -> void:
    if event.is_empty():
        return
    var stored: Dictionary = progress.rpg.get("branch_story",{}).get("active",{})
    var current_line_index: int = maxi(0,int(stored.get("line",0)))
    var lines: Array = event.get("dialogue",[])
    if current_line_index >= lines.size():
        return
    pending = "branch_event"
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.show_dialogue(lines.slice(current_line_index))

func _track_branch_event(event_id: String) -> void:
    if not branch_runtime.eligible(event_id):
        ui.show_message("后续剧情尚未开放，或所需伙伴未加入当前队伍。")
        return
    progress.rpg["tracked_branch_event"] = event_id
    _save_progress()
    adventure_menu.close_menu()
    _return_to_world()
    _focus()
    var event: Dictionary = branch_runtime.get_event(event_id)
    ui.show_message(story_world_bindings.route_summary(str(event.get("quest_id","")),world_router))

func _interact_world_branch(target: String) -> void:
    var event_id: String = ""
    if target.begins_with("questhint:"):
        event_id = target.trim_prefix("questhint:")
    elif target.begins_with("branchmap:"):
        var suffix: String = target.trim_prefix("branchmap:")
        event_id = suffix.substr(0,suffix.rfind(":"))
    if event_id.is_empty():
        return
    var resumed: Dictionary = branch_runtime.resume()
    if resumed.is_empty():
        if not branch_runtime.begin(event_id,"field"):
            ui.show_message("此事件需要完成原任务、选择对应分支或等待后期章节。")
            return
    elif str(resumed.get("id","")) != event_id:
        ui.show_message("请先继续已经开始的调查。")
        return
    progress.rpg["tracked_branch_event"] = event_id
    _focus()
    var line: Dictionary = branch_runtime.current_line()
    if line.is_empty():
        return
    var stage_index: int = int(progress.rpg.get("branch_story",{}).get("active",{}).get("line",0))
    var plan: Dictionary = world.scene_director.stage(str(resumed.get("quest_id",event_id.split(".")[0])),branch_runtime.get_event(event_id),stage_index)
    busy = true
    paused_for_dialogue = true
    world.locked = true
    if stage_index > 0:
        # The evidence and later notice require explicit player confirmation.
        # Choosing to return leaves the same field event at its saved stage.
        pending = "branch_field_review"
        ui.show_choices({
            "prompt":str(plan.get("prompt","请仔细核对现场证物。")),
            "options":[
                {"id":"confirm","label":str(plan.get("action_label","确认调查"))},
                {"id":"defer","label":"暂时离开，稍后再查"}
            ]
        })
        return
    pending = "branch_field"
    ui.show_dialogue([line])

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
    # RPGCore.advance_story_side commits the stage, choices, rewards and nonce.
    # Do not separately save or display "completed" on a failed V3 commit.
    var result: String = game_core.advance_story_side(active_story_side, selected)
    if result.begins_with("委托存档失败") or result.begins_with("委托状态无效"):
        pending = ""
        active_story_side = {}
        paused_for_dialogue = false
        ui.show_message(result)
        _return_to_world()
        return
    if result.begins_with("委托完成"):
        game_events.record("side_quest_completed",{"id":str(active_story_side.get("id",""))})
    var branch_dialogue: Array = selected.get("branch_dialogue", [])
    _focus() # Re-position the next original stage at this quest's authored site.
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
    if on_complete == "prologue" and progress.chapter == 0:
        if _play_story_cinematic("prologue_%d" % progress.scene_index,"dialogue"):
            return
    if on_complete == "crisis" and progress.chapter > 0:
        cinematic.banner_card(str(scene.get("title","前方的危机")),"第%d章 · 事件转折" % progress.chapter,"danger")
    pending = on_complete
    busy = true
    paused_for_dialogue = true
    world.locked = true
    var blocking: Dictionary = cinematic_scene_blocking.get("scenes",{}).get(str(scene.get("id","")),{})
    var shot_focus: String=str(blocking.get("focus",_target()))
    if on_complete=="prologue":
        shot_focus=_target()
    if world.nodes.has(shot_focus) and on_complete in ["prologue","opening","clue","crisis","resolve"]:
        cinematic_camera.shot(world.camera,world.nodes[shot_focus].position,"reveal" if str(blocking.get("camera",""))=="confrontation" else "focus")
    if on_complete=="clue" and not blocking.is_empty():
        cinematic.sound.cue(str(blocking.get("mood","mystery")))
    ui.show_dialogue(scene.get("dialogue", []),bool(progress.flags.get("cinematic.dialogue."+str(scene.get("id",""))+".seen",false)))

func _dialogue_ended() -> void:
    cinematic_camera.restore()
    if pending in ["prologue","opening","clue","crisis","resolve"]:
        var scene_id: String=str(_current_scene().get("id",""))
        if not scene_id.is_empty():
            progress.flags["cinematic.dialogue."+scene_id+".seen"]=true
    paused_for_dialogue = false
    match pending:
        "prologue":
            if not _apply_effects(_current_scene()):
                _scene_effect_save_failed()
                return
            _capture_world_position()
            var prologue_tx: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
                progress.scene_index += 1
                if progress.scene_index >= 9:
                    progress.chapter = 1
                    progress.scene_index = 0
                    progress.flags["story.prologue_done"] = true
                return {"ok":true}
            )
            if not bool(prologue_tx.get("ok",false)):
                _scene_effect_save_failed()
                return
            world.set_prologue_phase(progress.scene_index,progress.chapter)
            if progress.chapter == 1:
                _enter_location()
                _chapter_card(1)
                ui.show_message("序章完成 · 第一章《不曾寄出的信》")
                return
        "opening":
            if not _apply_effects(_current_scene()):
                _scene_effect_save_failed()
                return
            if not _advance_scene():
                _scene_effect_save_failed()
                return
        "clue":
            if not _apply_effects(_current_scene()):
                _scene_effect_save_failed()
                return
            _capture_world_position()
            if not bool(V3ProgressTransition.commit(progress,func() -> Dictionary:
                progress.task_index = 1
                return {"ok":true}
            ).get("ok",false)):
                _scene_effect_save_failed()
                return
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
        "branch_field":
            var field_event: Dictionary = branch_runtime.resume()
            if not field_event.is_empty():
                if not branch_runtime.advance():
                    ui.show_message("实地调查状态未能写入存档。")
                    return
                if branch_runtime.is_seen(str(field_event.get("id",""))):
                    game_events.record("branch_world_completed",{"id":str(field_event.get("id",""))})
                    progress.rpg["tracked_branch_event"] = ""
            _focus()
        "branch_event":
            var active_branch: Dictionary = branch_runtime.resume()
            if not active_branch.is_empty():
                var current_index: int = int(progress.rpg.get("branch_story",{}).get("active",{}).get("line",0))
                var total_lines: int = (active_branch.get("dialogue",[]) as Array).size()
                for _step in range(current_index,total_lines):
                    if not branch_runtime.advance():
                        ui.show_message("支线后续存档失败，请重新保存。")
                        return
                game_events.record("branch_story_completed",{"id":str(active_branch.get("id",""))})
        "optional_event":
            if optional_director.mark_seen(pending_optional):
                game_events.record("optional_event",{"id":str(pending_optional.get("id",""))})
            pending_optional = {}
        "choice_reaction":
            _crisis_choice_complete()
            return
        "ambient_npc":
            pass
        "resident_talk":
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
        "side_accept", "side_found":
            var stage: String = "accepted" if pending == "side_accept" else "found"
            var local_quest: Dictionary = side_quests.get(progress.chapter,{})
            _capture_world_position()
            var stage_result: Dictionary = QuestV3Settlement.settle_local_stage(
                progress,progress.chapter,local_quest,stage)
            pending = ""
            if not bool(stage_result.get("ok",false)):
                ui.show_message("支线阶段未保存，进度已回滚，请重新调查。")
            _return_to_world()
            return
        "side_complete":
            var quest: Dictionary = side_quests.get(progress.chapter, {})
            _capture_world_position()
            var settlement: Dictionary = QuestV3Settlement.settle_local(
                progress,game_core,progress.chapter,quest)
            if not bool(settlement.get("ok",false)):
                # The physical completion marker remains reachable for retry.
                pending = ""
                ui.show_message("支线奖励未保存，进度已恢复，请重新与委托人交谈。")
                _return_to_world()
                return
            pending = ""
            if bool(settlement.get("repeated",false)):
                ui.show_message("该委托已经完成，奖励不会重复领取。")
            else:
                ui.show_message("支线完成！经验、金币与药草已保存。")
            _return_to_world()
            return
        "resolve":
            if not _apply_effects(_current_scene()):
                _scene_effect_save_failed()
                return
            if progress.chapter == 72 and progress.scene_index == 3:
                if not _advance_scene():
                    _scene_effect_save_failed()
                    return
                _return_to_world()
                return
            if not _complete_chapter():
                _scene_effect_save_failed()
            return
    pending = ""
    _save_progress()
    _return_to_world()

func _choice_picked(item: Dictionary) -> void:
    if pending == "quest_puzzle_choice":
        var case_id: String = active_puzzle_quest
        active_puzzle_quest = ""
        var outcome: Dictionary = evidence_puzzles.result(progress.rpg,case_id,str(item.get("id","")),progress.chapter)
        if bool(outcome.get("accepted",false)):
            _save_progress()
            if bool(outcome.get("solved",false)):
                game_events.record("lost_page_evidence_solved",{"quest_id":case_id})
        pending = ""
        paused_for_dialogue = false
        _focus()
        _return_to_world()
        ui.show_message(str(outcome.get("message","线索仍需继续核对。")))
        return
    if pending == "branch_field_review":
        if str(item.get("id","")) != "confirm":
            pending = ""
            paused_for_dialogue = false
            _return_to_world()
            return
        var current: Dictionary = branch_runtime.current_line()
        if current.is_empty():
            pending = ""
            paused_for_dialogue = false
            _return_to_world()
            return
        pending = "branch_field"
        ui.show_dialogue([current])
        return
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
    # The chosen A/B route immediately changes the conversation, while
    # existing optional reactions remain additive, not overwritten.
    var response_lines: Array = item.get("branch_dialogue", []).duplicate(true)
    var followup: Dictionary = optional_director.reaction(progress.chapter,item,progress.flags)
    if not followup.is_empty() and optional_director.mark_seen(followup):
        response_lines.append_array(followup.get("dialogue", []))
    if not response_lines.is_empty():
        pending = "choice_reaction"
        ui.show_dialogue(response_lines)
        return
    _crisis_choice_complete()

func _crisis_choice_complete() -> void:
    if not _apply_effects(_current_scene()):
        _scene_effect_save_failed()
        return
    if progress.chapter == 1:
        if not _advance_scene():
            _scene_effect_save_failed()
            return
        _return_to_world()
        return
    var encounter_value: Variant = _current_scene().get("encounter", {})
    var fight: Dictionary = encounter_value if encounter_value is Dictionary else {}
    if fight.is_empty():
        if not _advance_scene():
            _scene_effect_save_failed()
            return
        _return_to_world()
        return
    _capture_world_position()
    if not bool(V3ProgressTransition.commit(progress,func() -> Dictionary:
        progress.task_index = 1
        return {"ok":true}
    ).get("ok",false)):
        _scene_effect_save_failed()
        return
    if progress.chapter in [2,3]:
        # Persist the choice once, then allow supplies and saving before combat.
        # Returning to the crisis marker retries without replaying choice effects.
        _return_to_world()
        ui.show_message("强敌就在前方。可先补给、保存；准备好后再次调查主线冲突点。")
        return
    _start_battle(true)

func _start_battle(is_boss: bool) -> void:
    if is_instance_valid(battle):
        return
    if progress.chapter < 1:
        return
    # Older V3 saves may already have a Boss victory flag without a nonce.
    if is_boss and bool(progress.flags.get("ch%03d.battle_won" % progress.chapter,false)):
        ui.show_message("本章强敌已经解决，无需重复挑战。")
        return
    battle_is_boss = is_boss
    cinematic_camera.battle_pulse(world.camera)
    if is_boss:
        cinematic.banner_card("命运的交锋","第%d章 · 强敌登场" % progress.chapter,"danger")
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
    # A single discovery hook covers all 63 regional monsters and 66 story
    # bosses, regardless of which of the 72 chapters spawned the fight.
    if battle.formation != null:
        for foe in battle.formation.units:
            var monster_id: String = str(foe.get("monster_id",""))
            var boss_id: String = str(foe.get("boss_id",""))
            if not monster_id.is_empty():
                game_core.record_enemy_seen("monsters",monster_id)
            if not boss_id.is_empty():
                game_core.record_enemy_seen("story_bosses",boss_id)

func _random_encounter() -> void:
    if no_encounters:
        world.locked = false
        return
    _start_battle(false)

func _battle_finished(won: bool, xp: int, money: int) -> void:
    # Keep the original battle alive until its V3 reward and receipts are saved.
    if not is_instance_valid(battle):
        return
    var active_battle: Node = battle
    var transaction_id: String = str(battle.reward_transaction_id)
    if not BattleRewardTransaction.valid_id(transaction_id):
        _hold_battle_settlement(won,xp,money,"战斗回执ID无效，暂停结算。")
        return
    # A-line tries to restore world before completed.emit. Do not unlock an
    # unsafe handoff; it stays retryable until the collision clears.
    var handoff: Dictionary = battle.last_world_handoff_result.duplicate(true)
    if handoff.has("resume_world") and not bool(handoff.get("resume_world",false)):
        handoff = battle.handoff_to_world(world)
        if not bool(handoff.get("resume_world",false)):
            _hold_battle_settlement(won,xp,money,"安全返回位置被阻挡，请重试。")
            return
        battle.last_world_handoff_result = handoff.duplicate(true)
    elif not handoff.has("resume_world"):
        if world == null or not is_instance_valid(world.hero):
            _hold_battle_settlement(won,xp,money,"玩家或地图缺失，暂停结算。")
            return
        if not won:
            var spawn_cell: Vector2i = world.terrain_layout.get("spawn",Vector2i(10,23))
            var safe_spot: Vector2 = Vector2(spawn_cell * WorldScript.TILE) + Vector2(16,16)
            if world._blocked(safe_spot):
                _hold_battle_settlement(won,xp,money,"安全出生点被阻挡，暂停结算。")
                return
            world.hero.position = safe_spot
            world.encounter_meter = minf(0.0,world.encounter_meter)-900.0
            world._reveal_nearby()
        elif world._blocked(world.hero.position):
            _hold_battle_settlement(won,xp,money,"当前位置不可通行，暂停结算。")
            return
        # A failed V3 write must not repeatedly relocate the party on retry.
        battle.last_world_handoff_result = {"ok":true,"resume_world":true,
            "fallback":true,"reward_transaction_id":transaction_id}

    var chapter_at_fight: int = int(battle.chapter)
    var is_boss: bool = bool(battle_is_boss)
    var defeated_monster: String = str(battle.enemy.get("monster_id",""))
    var defeated_group: Array = battle.formation.units.duplicate(true) if battle.formation != null else []
    _capture_world_position()
    var settlement: Dictionary
    if won:
        settlement = BattleV3Settlement.settle_victory(
            progress,game_core,transaction_id,chapter_at_fight,is_boss,
            defeated_group,defeated_monster,xp,money,5 if five_xp else 1)
    else:
        settlement = BattleV3Settlement.settle_defeat(
            progress,transaction_id,chapter_at_fight,is_boss)
    if not bool(settlement.get("ok",false)):
        _hold_battle_settlement(won,xp,money,
            "结算保存失败（%s），奖励及进度已回滚，可重试。" % str(settlement.get("reason","unknown")))
        return

    if bool(settlement.get("repeated",false)):
        ui.show_message("该战斗已结算，不会重复领取奖励或推进章节。")
    elif won:
        var details: Dictionary = settlement.get("mutation",{})
        game_events.record("battle_victory",{"boss":is_boss,"xp":xp,"gold":money})
        if is_boss:
            cinematic.banner_card("星光未灭","强敌已倒下 · 继续调查","victory")
            var job_levels: PackedStringArray = PackedStringArray(details.get("job_levels",[]))
            if not job_levels.is_empty():
                ui.show_message("职业提升：" + "；".join(job_levels))
        else:
            var level_text: PackedStringArray = PackedStringArray(details.get("levels",[]))
            var jobs_text: PackedStringArray = PackedStringArray(details.get("job_levels",[]))
            var loot_text: PackedStringArray = PackedStringArray(details.get("loot",[]))
            ui.show_message("战斗胜利，获得 %d 经验、%d 金币。%s%s" % [
                int(details.get("xp",0)),int(details.get("gold",0)),
                "，".join(level_text) + "；".join(jobs_text),
                (" 掉落：" + "、".join(loot_text) if not loot_text.is_empty() else "")])
    else:
        game_events.record("battle_defeat",{"chapter":chapter_at_fight,"boss":is_boss})
        ui.show_message("队伍已在安全位置整备，遗失了至多15 G，可再次挑战。")

    # No earlier _advance_scene() save or premature battle queue_free.
    battle = null
    var settings: Dictionary = progress.rpg.get("settings",{})
    var outro: float = clampf(float(settings.get("battle_outro_seconds",0.72)),0.0,1.5)
    if outro <= 0.0:
        active_battle.queue_free()
    else:
        get_tree().create_timer(outro).timeout.connect(func() -> void:
            if is_instance_valid(active_battle):
                active_battle.queue_free()
        )
    ui.set_play_visible(true)
    _return_to_world()

func _hold_battle_settlement(won: bool, xp: int, money: int, explanation: String) -> void:
    # Preserve nonce and lock; retry uses the same result and cannot pay twice.
    busy = true
    world.locked = true
    ui.set_play_visible(false)
    atlas.show_exploration(false)
    push_warning(explanation)
    if not is_instance_valid(battle):
        return
    if is_instance_valid(battle.report):
        battle.report.text = explanation
    if not is_instance_valid(battle.commands):
        return
    for child in battle.commands.get_children():
        if child is Button and child.name == "DSettlementRetry":
            return
    var retry: Button = Button.new()
    retry.name = "DSettlementRetry"
    retry.text = "重试结算/安全返回"
    battle.commands.add_child(retry)
    retry.pressed.connect(_retry_battle_settlement.bind(won,xp,money))

func _retry_battle_settlement(won: bool, xp: int, money: int) -> void:
    if is_instance_valid(battle):
        _battle_finished(won,xp,money)

func _apply_effects(scene: Dictionary) -> bool:
    # The authored scene, flags and every grant share one durable V3 receipt.
    # A failed write never allows the caller to advance its scene.
    _capture_world_position()
    var tx: Dictionary = QuestV3Settlement.settle_scene_effects(progress,scene)
    if not bool(tx.get("ok",false)):
        push_warning("剧情效果存档失败：" + str(tx.get("reason","unknown")))
        return false
    return true

func _scene_effect_save_failed() -> void:
    pending = ""
    paused_for_dialogue = false
    ui.show_message("剧情奖励或章节进度未能保存，已回滚。请检查存储空间后重新调查。")
    _return_to_world()

func _advance_scene() -> bool:
    _capture_world_position()
    var result: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
        progress.scene_index += 1
        progress.task_index = 0
        progress.dialogue_seen = false
        return {"ok":true}
    )
    return bool(result.get("ok",false))

func _complete_chapter() -> bool:
    var last: int = progress.chapter
    var quest_key: String = "quest_main_%03d" % last
    _capture_world_position()
    var result: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
        progress.flags["story.ch%03d.done" % last] = true
        if not game_core.entry("quests",quest_key).is_empty():
            var quests: Dictionary = progress.rpg.get("quests",{})
            quests[quest_key] = true
            progress.rpg["quests"] = quests
        if last == 4:
            progress.recruit_sailor()
        if last == 6:
            progress.flags["world.seven_lanterns.first"] = true
        if last == 72:
            return {"ok":true,"newcomer":""}
        progress.chapter += 1
        progress.scene_index = 0
        progress.task_index = 0
        progress.dialogue_seen = false
        var newcomer: String = game_core.recruit_from_story(progress.chapter)
        progress.heal_all()
        return {"ok":true,"newcomer":newcomer}
    )
    if not bool(result.get("ok",false)):
        return false
    # Never send UI events or rebuild the world until the new chapter
    # checkpoint (including party recruit / healing) is durable.
    if last == 72:
        _begin_ending_choice()
        return true
    game_events.record("chapter_completed",{"chapter":last})
    _enter_location()
    _chapter_card(progress.chapter)
    var changes: Dictionary = result.get("mutation",{})
    var newcomer: String = str(changes.get("newcomer",""))
    if not newcomer.is_empty():
        ui.show_message(newcomer)
    var next_chapter: Dictionary = catalog.get_chapter("ch%03d" % progress.chapter)
    ui.show_message("第%d章 · %s" % [progress.chapter,str(next_chapter.get("title","新的旅程"))])
    return true

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
    cinematic.banner_card("命运的抉择","七灯的未来 · 结局 "+id,"mystery")
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
    var current_world: Dictionary = progress.rpg.get("world",{})
    current_world.erase("indoor_building")
    current_world.erase("outdoor_return")
    game_events.advance_time(45)
    game_events.record("travel",{"map_id":map_id})
    adventure_menu.close_menu()
    _enter_location()
    world.spawn_from_exit(previous_map)
    _save_progress()
    cinematic.banner_card(str(world_router.profile().get("name",map_id)),"远方的灯火 · 区域抵达","hope")
    ui.show_message("已抵达：" + str(world_router.profile().get("name",map_id)))

func _open_regional_service() -> void:
    if world.interior_building.is_empty() or is_instance_valid(battle):
        return
    var kind: String = world.interior_building
    var region_id: String = str(world.map_profile.get("region_id","region_coast"))
    busy = true
    world.locked = true
    ui.clear_movement()
    ui.set_play_visible(false)
    atlas.show_exploration(false)
    service_menu.open_service(kind,region_id,world.interior_kind,progress,game_core,world.town_life,world_router.current_map())

func _service_action(action: String) -> void:
    var message: String = ""
    var region_id: String = str(world.map_profile.get("region_id","region_coast"))
    if action.begins_with("buy:"):
        message = game_core.buy(action.trim_prefix("buy:"))
        if message.begins_with("购买了 "):
            game_events.record("shop_purchase",{"region":region_id,"item":action.trim_prefix("buy:")})
    elif action.begins_with("sell:"):
        message = game_core.sell(action.trim_prefix("sell:"))
    elif action.begins_with("forge:"):
        message = game_core.forge(action.trim_prefix("forge:"))
        if message.begins_with("锻造成品"):
            game_events.record("forge_success",{"region":region_id})
    elif action == "rest":
        if progress.gold < 30:
            message = "金币不足，无法入住。"
        else:
            progress.gold -= 30
            game_events.advance_time(480)
            progress.heal_all()
            world.sync_world_clock(int(progress.rpg.get("game_clock",{}).get("day",1)),int(progress.rpg.get("game_clock",{}).get("minutes",480)))
            game_events.record("inn_rest",{"region":region_id})
            message = "在客栈安睡一晚，队伍 HP / MP 已全部恢复。"
    elif action == "blessing":
        if progress.gold < 20:
            message = "祝福需要 20 G。"
        else:
            progress.gold -= 20
            progress.heal_all()
            game_events.advance_time(35)
            game_events.record("shrine_blessing",{"region":region_id})
            message = "祈灯仪式完成，队伍 HP / MP 全部恢复。"
    elif action == "guild":
        message = world.town_life.guild_action(region_id,progress)
        game_events.record("guild_visit",{"region":region_id})
    elif action == "home":
        service_menu.close_service()
        _open_house()
        return
    else:
        message = "这里目前没有可执行的指令。"
    _save_progress()
    service_menu.refresh(progress,game_core,world.town_life,message)

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
    _capture_world_position()
    var success: bool = save_slots.save_slot(progress,slot)
    adventure_menu.render("存档管理")
    adventure_menu.footer.text = "槽位 %d %s" % [slot,"已保存" if success else "保存失败"]

func _load_slot(slot: int) -> void:
    if not save_slots.load_slot(progress,slot):
        adventure_menu.footer.text = "槽位文件损坏或读取失败。"
        return
    game_core.bind(progress)
    world_router.bind(progress)
    map_fog.bind(progress)
    game_events.bind(progress)
    housing.bind(progress)
    optional_director.bind(progress)
    branch_runtime.bind(progress)
    adventure_menu.close_menu()
    cinematic.cancel_all()
    cinematic_camera.restore()
    cinematic_resume=""
    _enter_location()
    _save_progress()
    if progress.chapter == 72 and progress.scene_index == 4 and not bool(progress.flags.get("story.complete",false)):
        if str(progress.rpg.get("ending_id","")).is_empty():
            _begin_ending_choice()
        else:
            _play_ending_scene()
    ui.show_message("已载入手动存档 %d。" % slot)

func _capture_world_position() -> void:
    if progress == null or world == null or not is_instance_valid(world.hero) or world_router == null:
        return
    var snapshot: Dictionary = progress.rpg.get("world", {})
    snapshot["player_checkpoint"] = {
        "map_id": world_router.current_map(),
        "chapter": world.chapter,
        "indoor_building": world.interior_building,
        "xy": [world.hero.position.x, world.hero.position.y]
    }
    progress.rpg["world"] = snapshot

func _restore_world_position() -> void:
    if progress == null or world == null or not is_instance_valid(world.hero) or world_router == null:
        return
    var saved: Variant = progress.rpg.get("world", {}).get("player_checkpoint", {})
    if not (saved is Dictionary):
        return
    if str(saved.get("map_id", "")) != world_router.current_map():
        return
    if int(saved.get("chapter", -1)) != progress.chapter:
        return
    if str(saved.get("indoor_building", "")) != world.interior_building:
        return
    var xy: Variant = saved.get("xy", [])
    if not (xy is Array) or xy.size() != 2:
        return
    if typeof(xy[0]) not in [TYPE_FLOAT, TYPE_INT] or typeof(xy[1]) not in [TYPE_FLOAT, TYPE_INT]:
        return
    var p := Vector2(float(xy[0]), float(xy[1]))
    if is_nan(p.x) or is_nan(p.y) or is_inf(p.x) or is_inf(p.y):
        return
    if p.x < 16.0 or p.y < 16.0 or p.x > float(world.WIDTH * WorldScript.TILE) - 16.0 or p.y > float(world.HEIGHT * WorldScript.TILE) - 16.0:
        return
    if world._blocked(p):
        return
    world.hero.position = p
    world._reveal_nearby()

func _save_progress() -> bool:
    _capture_world_position()
    var success: bool = progress.save()
    if not success:
        push_warning("游戏主体存档写入失败")
    return success

func _save() -> void:
    var success: bool = _save_progress()
    ui.show_message("旅途进度已保存。" if success else "保存失败，请检查设备剩余空间及存储权限。")

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
    busy = paused_for_dialogue or (cinematic != null and cinematic.is_playing()) or is_instance_valid(battle) or ui.menu_layer.visible or adventure_menu.root.visible or housing_room.root.visible or service_menu.is_open() or cheat.shade.visible or atlas.is_open()
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
