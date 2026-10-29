extends Node2D
## 《星灯纪行》72章全篇：地图、分支任务、三结局、战斗与存档协调器。
const WorldScript = preload("res://scripts/first_act_world.gd")
const UIScript = preload("res://scripts/first_act_ui.gd")
const MapScript = preload("res://scripts/map_hud.gd")
const BattleScript = preload("res://scripts/first_act_battle.gd")
const BattleRewardTransaction = preload("res://scripts/battle_reward_transaction.gd")
const BattleV3Settlement = preload("res://scripts/d_world_interaction/battle_v3_settlement.gd")
const QuestV3Settlement = preload("res://scripts/d_world_interaction/quest_v3_settlement.gd")
const NPCV3Contact = preload("res://scripts/d_world_interaction/npc_v3_contact.gd")
const V3ProgressTransition = preload("res://scripts/d_world_interaction/v3_progress_transition.gd")
const WorldObjectSettlement = preload("res://scripts/d_world_interaction/world_object_settlement.gd")
const EvidenceTransactions = preload("res://scripts/d_world_interaction/story_evidence_transaction.gd")
const Act01ChoiceTransaction = preload("res://scripts/d_world_interaction/act01_choice_transaction.gd")
const WorldHomeInteractions = preload("res://scripts/world_home_interactions.gd")
const RegionalServiceSettlement = preload("res://scripts/d_world_interaction/service_v3_settlement.gd")
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
const MechanicsRegistryScript = preload("res://scripts/systems/MechanicsRegistry.gd")
const EndgameBridgeScript = preload("res://scripts/systems/EndgameExpansionBridge.gd")
const EvacuationHudScript = preload("res://scripts/systems/EvacuationSquadHud.gd")
const RescueWorldDirectorScript = preload("res://scripts/systems/Act08RescueWorldDirector.gd")
const NoeWorldDirectorScript = preload("res://scripts/systems/NoeEraWorldDirector.gd")
const EvacuationRoster = preload("res://scripts/systems/EvacuationBattleRoster.gd")
const RescueProfiles = preload("res://scripts/systems/RescueEncounterProfiles.gd")
const StarlightJournalScript = preload("res://scripts/systems/StarlightJournal.gd")
const DeductionGraph = preload("res://scripts/systems/DeductiveReasoningGraph.gd")
const NativeSaveManager = preload("res://scripts/core/SaveLoadManager.gd")
const ThreeRealmsOptics = preload("res://scripts/systems/ThreeRealmsOptics.gd")
const CH021_DIRECTION_CUE: String = "direction.ch021.crisis"
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
var native_save_manager = NativeSaveManager.new()
var realm_optics
var housing
var housing_room
var optional_director
var branch_runtime
var evidence_puzzles = EvidencePuzzles.new()
var room_investigations = WorldHomeInteractions.new()
var active_puzzle_quest: String = ""
var story_world_bindings
var service_menu
var cinematic
var cinematic_camera
var mechanics_registry
var evidence_journal
var active_evidence_id: String = ""
var direction_cutscene
var endgame_bridge
var evacuation_hud
var rescue_world_director
var noe_world_director
var active_evacuation_choice: String = ""
var active_evacuation_battle_squad: String = ""
var chapter_mechanic_controller
var chapter_mechanic_id: String = ""
var cinematic_resume: String = ""
var cinematic_force_play: bool = false
var cinematic_prologue: Dictionary = {}
var cinematic_chapters: Dictionary = {}
var cinematic_scene_blocking: Dictionary = {}
var pending_optional: Dictionary = {}
var clock_tick: float = 0.0
var ui_hint_clock: float = 0.0
var active_optional_flag: String = ""
var ending_replay_id: String = ""
var ending_replay_scene: int = 0
var busy: bool = true
var paused_for_dialogue: bool = false
var pending: String = ""
var battle_is_boss: bool = false
# Per-attempt nonce for the defeat penalty. Boss victory keeps its stable story ID.
var battle_defeat_id: String = ""
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
    evidence_journal = StarlightJournalScript.new()
    evidence_journal.object_closeup_requested.connect(_on_canon_evidence_closeup_requested)
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
    add_child(world)
    realm_optics = ThreeRealmsOptics.new()
    add_child(realm_optics)
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
    adventure_menu.map_requested.connect(_open_local_map_from_book)
    adventure_menu.visual_quality_changed.connect(_change_visual_quality)
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
    mechanics_registry = MechanicsRegistryScript.new()
    if not mechanics_registry.load_all():
        push_error("章节机制注册表无效：" + "；".join(mechanics_registry.errors))
    direction_cutscene = mechanics_registry.create_controller("ch021")
    if direction_cutscene != null:
        add_child(direction_cutscene)
    else:
        push_error("第21章正式导演控制器未装载；该章选择将被锁定。")
    endgame_bridge = EndgameBridgeScript.new()
    add_child(endgame_bridge)
    if not endgame_bridge.load_registry():
        push_error("终局第三批资源无法载入：" + "；".join(endgame_bridge.errors))
    endgame_bridge.evacuation_expired.connect(_endgame_evacuation_expired)
    evacuation_hud = EvacuationHudScript.new()
    add_child(evacuation_hud)
    evacuation_hud.squad_requested.connect(_request_endgame_squad)
    rescue_world_director = RescueWorldDirectorScript.new()
    add_child(rescue_world_director)
    evacuation_hud.world_director = rescue_world_director
    noe_world_director = NoeWorldDirectorScript.new()
    add_child(noe_world_director)
    adventure_menu.lore_loader = endgame_bridge.quests
    adventure_menu.lore_read_requested.connect(_read_canonical_lore)
    adventure_menu.deduction_requested.connect(_record_epistemic_deduction)
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
    if progress != null and progress.chapter == 47 and endgame_bridge != null and endgame_bridge.registry_loaded:
        endgame_bridge.evacuation.set_time_suspended(
            busy or paused_for_dialogue or is_instance_valid(battle))
    if evacuation_hud != null and progress != null and endgame_bridge != null:
        evacuation_hud.update_from_bridge(endgame_bridge,progress.chapter)
    if progress == null or game_events == null:
        return
    if busy:
        return
    # Context action follows the world interaction solver; no fake HUD targets.
    ui_hint_clock += delta
    if ui_hint_clock >= 0.12:
        ui_hint_clock = 0.0
        ui.set_interaction_hint(world.interaction_hint())
    progress.play_seconds += delta
    clock_tick += delta
    if clock_tick >= 8.0:
        var elapsed: int = int(clock_tick / 8.0)
        clock_tick = fmod(clock_tick,8.0)
        game_events.advance_time(elapsed)
        world.sync_world_clock(int(progress.rpg.get("game_clock",{}).get("day",1)),int(progress.rpg.get("game_clock",{}).get("minutes",480)))

func _unhandled_input(event: InputEvent) -> void:
    # Mouse selection is constrained by the SAME real player-range resolver as
    # keyboard interaction; clicking distant markers never teleports or triggers.
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not busy:
        var target_id: String = world.nearest_interaction()
        if target_id != "none" and world.nodes.has(target_id):
            var target_node: Node2D = world.nodes[target_id]
            if is_instance_valid(target_node) and target_node.visible:
                var screen_position: Vector2 = target_node.get_global_transform_with_canvas() * Vector2.ZERO
                if event.position.distance_to(screen_position) <= 42.0:
                    world.interact()
                    get_viewport().set_input_as_handled()
                    return
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
    game_events.bind(progress)
    housing.bind(progress)
    optional_director.bind(progress)
    branch_runtime.bind(progress)
    if not endgame_bridge.bind_progress(progress):
        ui.show_title(false,"终局扩展存档校验失败，原文件保留：" + "；".join(endgame_bridge.errors))
        return
    _restore_canon_evidence_journal()
    world.set_visual_quality(int(progress.rpg.get("settings",{}).get("visual_quality",1)))
    if progress.chapter == 72 and bool(progress.flags.get("story.complete",false)) and str(progress.rpg.get("ending_id","")).is_empty():
        # Legacy V3 ending flag has no authored ending ID. Migrate only after
        # confirmed V3 disk commit; never advance world on failed migration.
        var migrate: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
            progress.flags.erase("story.complete")
            progress.flags["story.ch072.done"] = true
            progress.scene_index = 4
            return {"ok":true}
        )
        if not bool(migrate.get("ok",false)):
            ui.show_title(false,"旧结局存档迁移失败，原文件已保留。请检查设备存储空间。")
            return
    _enter_location()
    _restore_cheat_settings()
    var interrupted_cue: String = str(progress.rpg.get("cinematic_checkpoint",""))
    if not fresh_game and interrupted_cue == CH021_DIRECTION_CUE:
        if not _begin_ch021_direction(true):
            _block_ch021_direction("第21章演出检查点不能恢复，请保留存档并检查剧情资源。")
        return
    if not fresh_game and not interrupted_cue.is_empty():
        var desired_resume: String = "explore" if interrupted_cue=="cold_open" else "dialogue"
        if _play_story_cinematic(interrupted_cue,desired_resume):
            return
        progress.rpg.erase("cinematic_checkpoint")
    if not fresh_game and progress.chapter == 21 and progress.scene_index == 2:
        # A choice committed before a crash is authoritative. Do not ask again.
        if bool(progress.flags.get("ch021.choice.chosen", false)) or bool(progress.flags.get("ch021.decision_made", false)):
            _crisis_choice_complete()
            return
        if _ch021_choice_ready():
            pending = "choice"
            busy = true
            paused_for_dialogue = true
            world.locked = true
            ui.show_choices(_current_scene().get("choice", {}))
            return
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
    var prior_cinema: Dictionary=progress._pack().duplicate(true)
    progress.rpg["cinematic_checkpoint"]=cue_id
    if not _save_progress():
        progress.restore_snapshot(prior_cinema)
        _cinematic_save_failed()
        # The attempted presentation was handled by the recovery title.
        # Never fall through to a dialogue or active world with an
        # unpersisted cinematic checkpoint.
        return true
    busy=true
    paused_for_dialogue=true
    world.locked=true
    ui.set_play_visible(false)
    atlas.show_exploration(false)
    _mix_world_for_cinematic(true)
    return true

func _cinematic_finished(cue_id: String,_skipped: bool) -> void:
    if cue_id == CH021_DIRECTION_CUE:
        _finish_ch021_direction()
        return
    # Completed and skipped scenes have identical canonical state effects.
    # This is presentation-only: narrative effects remain in _dialogue_ended.
    if cue_id.is_empty():
        return
    _mix_world_for_cinematic(false)
    var previous_cinema: Dictionary=progress._pack().duplicate(true)
    progress.flags["cinematic."+cue_id+".seen"]=true
    progress.rpg.erase("cinematic_checkpoint")
    if not _save_progress():
        # On next Continue the saved checkpoint must replay the exact
        # interrupted cue. Do not apply dialogue, chapter or reward effects.
        progress.restore_snapshot(previous_cinema)
        _cinematic_save_failed()
        return
    var resume: String=cinematic_resume
    cinematic_resume=""
    paused_for_dialogue=false
    if resume=="dialogue":
        busy=false
        _present("prologue")
    elif resume=="explore":
        _return_to_world()

func _cinematic_save_failed() -> void:
    # Fail closed: the player cannot progress past an unsaved cinematic.
    # Continue replays the last durable cue without touching the backup.
    cinematic.cancel_all()
    _mix_world_for_cinematic(false)
    cinematic_resume=""
    busy=true
    paused_for_dialogue=false
    world.locked=true
    ui.set_play_visible(false)
    atlas.show_exploration(false)
    ui.show_title(true,"演出状态保存失败，剧情尚未推进。检查存储空间后选择继续，以重播未完成演出。")

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

func _runtime_world_party_ids() -> Array:
    var base: Array = game_core.active_party_ids()
    if progress == null or progress.chapter != 47 or endgame_bridge == null             or not endgame_bridge.registry_loaded or not endgame_bridge.evacuation.running:
        return base
    var squad_id: String = str(endgame_bridge.evacuation.active_controlled_squad)
    var lane: Dictionary = EvacuationRoster.resolve(squad_id,47,progress.actors,progress.flags)
    if bool(lane.get("ok",false)):
        return (lane.get("ids",[]) as Array).duplicate()
    # Never invent a missing actor or silently add a protected child.
    return base

func _enter_location() -> void:
    game_core.register_chapter(progress.chapter)
    world_router.sync_chapter(progress.chapter)
    world.map_profile = world_router.profile()
    var production: Dictionary = catalog.production_contract("ch%03d" % progress.chapter,progress.flags)
    world.world_epoch = str(production.get("epoch","present"))
    world.custom_region = str(world.map_profile.get("name",game_core.location_name(progress.chapter)))
    # Bind the chapter's live rescue state BEFORE calculating its on-screen
    # squad, otherwise world.build incorrectly uses the permanent party.
    if endgame_bridge != null and endgame_bridge.current_chapter != progress.chapter:
        if not endgame_bridge.bind_progress(progress):
            push_error("终局状态无法重绑：" + "；".join(endgame_bridge.errors))
    world.party_ids = _runtime_world_party_ids()
    world.world_legacy_flags = progress.flags.duplicate(true)
    world.build(progress.chapter, world.party_ids.size())
    _update_realm_optics()
    world.apply_canon_pov(progress.flags)
    if progress.chapter == 47 and endgame_bridge != null and endgame_bridge.registry_loaded:
        world.apply_rescue_squad_pov(str(endgame_bridge.evacuation.active_controlled_squad))
    # Only durable completion, not combat victory alone, relights the tower.
    # Historical V3 saves with the lantern completion bit remain compatible.
    var lantern_saved: bool = bool(progress.flags.get("world.seven_lanterns.first",false)) or (
        bool(progress.flags.get("story.ch006.done",false)) and
        bool(progress.flags.get("ch006.lighthouse_testimony",false)))
    world.set_lighthouse_rekindled(lantern_saved)
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
    # Travel/rebuilding the same chapter must never replenish the live countdown.
    # Slot loads rebind explicitly in _load_slot.
    if endgame_bridge != null and endgame_bridge.current_chapter != progress.chapter and not endgame_bridge.bind_progress(progress):
        push_error("终局状态重绑失败：" + "；".join(endgame_bridge.errors))
    _install_endgame_markers()
    rescue_world_director.bind_world(world,endgame_bridge)
    noe_world_director.bind_world(world,endgame_bridge)
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
    if progress.chapter >= 1 and progress.chapter <= 6:
        var chapter_destination: String = world_router.act01_target_map(progress.chapter)
        if not chapter_destination.is_empty() and world_router.current_map() != chapter_destination:
            var travel_route: Array[String] = world_router.route_towards(chapter_destination)
            var target_name: String = str(world_router.map_info(chapter_destination).get("name",chapter_destination))
            if not world.interior_building.is_empty():
                return "【本章目的地】%s\n先离开房屋，再沿已解锁道路前往。" % target_name
            if travel_route.size()>1:
                var next_name: String = str(world_router.map_info(travel_route[1]).get("name",travel_route[1]))
                return "【本章目的地】%s\n从当前地图前往下一出口：%s" % [target_name,next_name]
            return "【本章目的地】%s\n当前路线尚未开放，请先完成必要条件。" % target_name
    if progress.chapter == 0:
        return "前往 ✦ 光点：" + prefix
    if progress.chapter == 2 and progress.scene_index >= 1:
        if world.interior_building != "shelter":
            return "【白砂港收容所】沿港口街道进入正式收容所；病患调查、医师抉择和冲突不可在室外完成。"
        if progress.scene_index == 1:
            if progress.task_index == 0 and not bool(progress.flags.get("ch002.evidence",false)):
                var pending_items: Array[String] = []
                for evidence_id in world.terrain_layout.get("act01_main_story_evidence",[]):
                    var state: Dictionary = room_investigations.snapshot(
                        progress,world_router.current_map(),"shelter",str(evidence_id))
                    if not bool(state.get("seen_before",false)):
                        pending_items.append("搁浅水手行囊" if str(evidence_id).ends_with("_2") else "临时名册")
                if not pending_items.is_empty():
                    return "【收容所调查】先亲自查看：" + "、".join(pending_items) + "，成功保存后再向水手核对。"
            return ("【病历核对】前往病例核对台，询问失忆病患。" if progress.task_index == 0
                else "【水手证言】前往床旁水手位置询问两次钟声与失落航海日志。")
        if progress.scene_index == 2:
            return "【主任抉择】在诊疗区与主任面对面确认病历隐私，并进行正式守卫战。"
        if progress.scene_index == 3:
            return "【匿名求援】在收容所内完成病历交接后返回白砂港街道。"
    if progress.chapter == 4:
        if world.interior_building != "tavern":
            return "【黑帆酒馆】请从白砂港街巷寻找真正的酒馆正门，进入室内继续调查。"
        match progress.scene_index:
            0: return "【酒馆接待】走到吧台，向酒馆老板了解近期夜船的去向。"
            1:
                if progress.task_index == 0 and not bool(progress.flags.get("ch004.evidence",false)):
                    var missing_clues: Array[String] = []
                    for evidence_id in world.terrain_layout.get("act01_main_story_evidence",[]):
                        var record: Dictionary = room_investigations.snapshot(
                            progress,world_router.current_map(),"tavern",str(evidence_id))
                        if not bool(record.get("seen_before",false)):
                            missing_clues.append("夹层货单" if str(evidence_id).ends_with("_1") else "无日期船员告示")
                    if not missing_clues.is_empty():
                        return "【室内调查】先亲自查看：" + "、".join(missing_clues) + "；再去主线线索点核对假货单。"
                return "【船员口供】与靠近长桌的目击水手核对账目和夜船航线。" if progress.task_index == 1 else "【酒馆调查】前往货单核对点整理证据。"
            2: return "【酒馆危机】接近灰帷会冲突点，保护普通酒客后由原有战斗系统解决威胁。"
            3: return "【朔弦坦白】在酒馆出口内侧与朔弦对话，完成第四章后再离开。"
    if progress.chapter == 5 and world_router.current_map() == "map_coast_03" and progress.scene_index >= 1 and progress.scene_index <= 2:
        if not world.shoal_plan.ready():
            return "【鲸骨浅滩】正式救援场景数据缺失，禁止以通用标记替代。"
        var next_record: String = world.shoal_plan.next_required(progress)
        if not next_record.is_empty():
            var pending_record: Dictionary = world.shoal_plan.entry(next_record)
            return "【鲸骨浅滩】沿盐风古道支路走到半月湾，先调查「%s」。红旗→星锁→撤离线须实地确认后方可营救古兽。" % str(pending_record.get("title","救援线索"))
        if progress.scene_index == 2:
            return "【古兽救援】已核对红旗、三重星锁及撤离线。与冲突现场交互，在战斗中先双哨引导、再逐一拆除三锁。"
    if progress.chapter == 6 and world_router.current_map() == "map_coast_05":
        if not world.lighthouse_plan.ready():
            return "【潮歌灯塔】正式供能室记录缺失，主线不能继续。"
        if progress.scene_index == 0:
            return "【灯塔工匠】沿真实悬崖折返步道，到工匠维护站与守灯工匠交谈。"
        var missing_wick: String = world.lighthouse_plan.next_required(progress)
        if progress.scene_index in [1,2] and not missing_wick.is_empty():
            var record: Dictionary = world.lighthouse_plan.fragment(missing_wick)
            return "【三枚灯芯】请亲自前往「%s」调查、保存；海堤→塔底→塔顶三处独立供能室不可跳过。" % str(record.get("title","灯芯"))
        if progress.scene_index == 1:
            return "【三芯合灯】三枚灯芯均已记录。前往反光镜架核对台，再向归航者回声处询问。"
        if progress.scene_index == 2:
            return "【共同见证】到塔前守门人处拒绝记忆献祭，以四段不同归航见证代替旧供能规则。"
        if progress.scene_index == 3:
            return "【归航母灯】返回塔顶灯坛，与守灯工匠确认第一幕归航灯重燃。"
    if progress.chapter <= 3:
        if progress.chapter == 3 and progress.scene_index == 2:
            # V7 cave devices b -> a -> c are real map-coast-04 interactions.
            # Solving the sequence enables badge recognition; HP victory remains legal.
            var cave_records: Dictionary = progress.rpg.get("dungeon_puzzles_v7",{})
            var cave_progress: Dictionary = cave_records.get("map_coast_04",{})
            var valves: int = clampi(int(cave_progress.get("index",0)),0,3)
            if valves < 3:
                return "【断桅海蚀洞】可调查三座实体石阀（中→左→右，%d/3）。完成后在胸灯停顿时出示歪树船徽，或按正常战斗挑战守卫。" % valves
            return "【潮痕守卫】三道石阀已响应。确认半枚船徽上的歪树刻痕，待胸灯停顿时选择战术行动。"
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
        2:
            if progress.chapter == 5:
                return prefix + " · 缚潮古兽不能靠伤害击杀。战斗中先由朔弦吹双哨引导，再对未发亮的锁扣逐一拆除，共需安全拆解3处。"
            return prefix + (" · 迎战敌人" if progress.task_index == 1 else " · 前往冲突现场")
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
    world.refresh_shoal_evidence(progress)
    world.refresh_lighthouse_fragments(progress)
    world.refresh_world_legacy(progress.flags)
    world.sync_prologue_markers(progress.scene_index,progress.chapter)
    var required_act01_map: String = world_router.act01_target_map(progress.chapter)
    var story_here: bool = required_act01_map.is_empty() or world_router.current_map()==required_act01_map
    # City Act X uses its own exact chapter destination, not generic markers.
    if progress.chapter>=55 and progress.chapter<=60:
        story_here = world_router.current_map() == world_router.chapter_map(progress.chapter)
    if not story_here:
        # Otherwise old procedural chapter props would let the player finish
        # cave/tavern/shoal/lighthouse scenes on an unrelated sector.
        for main_marker in ["key_npc","clue","witness","crisis","resolve"]:
            if world.nodes.has(main_marker):
                world.nodes[main_marker].visible = false
    var current_focus: String = _target() if story_here and not (progress.chapter == 72 and bool(progress.flags.get("story.complete", false))) else ""
    if progress.chapter == 2:
        if progress.scene_index == 0 and not world.interior_building.is_empty():
            current_focus = "interior_exit"
        elif progress.scene_index >= 1:
            if world.interior_building == "shelter":
                current_focus = _target() if story_here else ""
            else:
                current_focus = "building:shelter" if story_here and world.nodes.has("building:shelter") else ""
    if progress.chapter == 4:
        if world.interior_building == "tavern":
            current_focus = _target() if story_here else ""
        else:
            current_focus = "building:tavern" if story_here and world.nodes.has("building:tavern") else ""
    world.set_focus(current_focus)
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
    if endgame_bridge != null and progress.chapter == 47 and not endgame_bridge.evacuation.finished:
        side_target = endgame_bridge.evacuation.current_objective_marker(endgame_bridge.evacuation.active_controlled_squad)
        if side_target.is_empty():
            side_target = "evac:command"
    if endgame_bridge != null and endgame_bridge.registry_loaded:
        for stage_marker in endgame_bridge.eligible_interactions():
            if not str(stage_marker).begins_with("evac:") or stage_marker == "evac:command" or not world.nodes.has(stage_marker):
                continue
            var active_stage: bool = false
            for team in endgame_bridge.evacuation.OBJECTIVE_MARKERS:
                if endgame_bridge.evacuation.current_objective_marker(str(team)) == stage_marker:
                    active_stage = true
            world.nodes[stage_marker].visible = active_stage
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
    var endgame_hint: String = endgame_bridge.summary() if endgame_bridge != null else ""
    ui.set_hud(progress.chapter, world.region_name(), _objective() + ("\n" + extra if show_extra else "") + ("\n" + endgame_hint if not endgame_hint.is_empty() else ""), progress.actors, progress.gold, progress.potions)
    atlas.set_targets(world.focus_name,side_target)
    var nav_event: Dictionary = branch_runtime.get_event(tracked)
    if not nav_event.is_empty() and not branch_runtime.is_seen(tracked):
        var quest_id: String = str(nav_event.get("quest_id",""))
        atlas.set_story_route(story_world_bindings.map_for(quest_id),
            story_world_bindings.route_summary(quest_id,world_router))
    else:
        atlas.set_story_route("","")
    if evacuation_hud != null:
        evacuation_hud.update_from_bridge(endgame_bridge,progress.chapter)
    if endgame_bridge != null and endgame_bridge.registry_loaded and progress.chapter == 47:
        world.apply_rescue_squad_pov(endgame_bridge.evacuation.active_controlled_squad)
    if rescue_world_director != null:
        rescue_world_director.refresh()
    if noe_world_director != null:
        noe_world_director.refresh()

func _reserve_rescue_reward_id(squad_id: String) -> String:
    if progress.chapter != 47 or not endgame_bridge.evacuation.running:
        return ""
    var records_value: Variant = progress.rpg.get("evacuation_battle_pending_v1",{})
    if not (records_value is Dictionary):
        return ""
    var records: Dictionary = records_value
    var recorded_id: String = str(records.get(squad_id,""))
    if not recorded_id.is_empty():
        return recorded_id if BattleRewardTransaction.valid_id(recorded_id)             and recorded_id.begins_with("random:") else ""
    var receipt_id: String = BattleRewardTransaction.make_id(false,47)
    if not BattleRewardTransaction.valid_id(receipt_id):
        return ""
    _capture_world_position()
    var transaction: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
        var pending_records: Dictionary = progress.rpg.get("evacuation_battle_pending_v1",{}).duplicate(true)
        if pending_records.has(squad_id):
            return {"ok":false,"reason":"rescue_nonce_collision"}
        pending_records[squad_id] = receipt_id
        progress.rpg["evacuation_battle_pending_v1"] = pending_records
        return {"ok":true}
    )
    return receipt_id if bool(transaction.get("ok",false)) else ""

func _resume_saved_rescue_victory(squad_id: String, transaction_id: String) -> Dictionary:
    # Recovery is ONLY authorized by an actually persisted A-line victory
    # receipt for this chapter, never by a claim, choice or boss flag.
    var ledger_value: Variant = progress.rpg.get("battle_reward_transactions",{})
    if not (ledger_value is Dictionary):
        return {"ok":false,"reason":"missing_battle_v3_ledger"}
    var ledger: Dictionary = ledger_value
    var record_value: Variant = ledger.get(transaction_id,{})
    if not (record_value is Dictionary):
        return {"ok":false,"reason":"no_paid_real_battle"}
    var record: Dictionary = record_value
    if not BattleRewardTransaction.valid_id(transaction_id)             or not transaction_id.begins_with("random:")             or int(record.get("chapter",0)) != 47 or bool(record.get("boss",true)):
        return {"ok":false,"reason":"invalid_or_unrelated_combat_receipt"}
    if endgame_bridge == null or not endgame_bridge.registry_loaded             or not endgame_bridge.evacuation.running             or endgame_bridge.evacuation.failed             or endgame_bridge.evacuation.active_controlled_squad != squad_id:
        return {"ok":false,"reason":"rescue_context_expired"}
    var pending_value: Variant = progress.rpg.get("evacuation_battle_pending_v1",{})
    if not (pending_value is Dictionary) or             str(pending_value.get(squad_id,"")) != transaction_id:
        return {"ok":false,"reason":"pending_receipt_does_not_match"}
    var confirmed: Dictionary = endgame_bridge.confirm_real_encounter(squad_id,47,transaction_id)
    if not bool(confirmed.get("success",false)):
        return {"ok":false,"reason":str(confirmed.get("reason","rescue_objective_invalid"))}
    _capture_world_position()
    var saved: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
        var pending_ids: Dictionary = progress.rpg.get("evacuation_battle_pending_v1",{}).duplicate(true)
        if str(pending_ids.get(squad_id,"")) != transaction_id:
            return {"ok":false,"reason":"pending_receipt_changed"}
        pending_ids.erase(squad_id)
        progress.rpg["evacuation_battle_pending_v1"] = pending_ids
        progress.rpg["endgame_expansion"] = endgame_bridge.export_state()
        return {"ok":true}
    )
    if not bool(saved.get("ok",false)):
        if not endgame_bridge.bind_progress(progress):
            push_error("撤离战斗历史回执恢复后，桥接状态回滚失败。")
        return {"ok":false,"reason":"rescue_checkpoint_save_failed"}
    return {"ok":true,"message":"已从实际战斗胜利V3账本恢复本队救援进度；未重新发放经验或金币。"}

func _handle_endgame_interaction(target: String, action_id: String = "") -> void:
    if endgame_bridge == null or not endgame_bridge.registry_loaded:
        ui.show_message("终局场景尚未装载，行动未记录。")
        return
    # Only a physically reachable marker supplies target here; menu callbacks
    # may continue exactly the same pending target but cannot make a fake win.
    if progress.chapter == 47 and target in ["evac:east:escort","evac:south:route"]:
        if rescue_world_director == null or not rescue_world_director.escort_arrived(target):
            pending = ""
            active_evacuation_choice = ""
            paused_for_dialogue = false
            _return_to_world()
            ui.show_message("护送队尚未到达！请带队沿可通行路线抵达城门，再确认行动。")
            return
    var before_endgame: Dictionary = progress._pack().duplicate(true)
    var result: Dictionary = endgame_bridge.interact(target,progress.flags,action_id)
    if bool(result.get("needs_choice",false)):
        active_evacuation_choice = target
        pending = "endgame_evac_choice"
        busy = true
        paused_for_dialogue = true
        world.locked = true
        ui.show_choices(result.get("choice_data",{}))
        return
    active_evacuation_choice = ""
    pending = ""
    paused_for_dialogue = false
    if bool(result.get("start_encounter",false)):
        var squad_id: String = str(result.get("squad_id",""))
        if squad_id.is_empty() or is_instance_valid(battle):
            _return_to_world()
            ui.show_message("守军战斗无法启动；救援阶段没有推进。")
            return
        var reserved_receipt: String = _reserve_rescue_reward_id(squad_id)
        if reserved_receipt.is_empty():
            _return_to_world()
            ui.show_message("无法写入独立救援战斗回执；尚未启动战斗。")
            return
        if BattleRewardTransaction.already_applied(progress.rpg,reserved_receipt):
            # A previous session already saved the real combat payout but
            # crashed before the squad rescue checkpoint. Never demand a
            # second battle or create a second nonce for that same win.
            var recovered: Dictionary = _resume_saved_rescue_victory(squad_id,reserved_receipt)
            _return_to_world()
            ui.show_message(str(recovered.get("message",
                "战斗胜利已入账，但救援回执恢复失败：" + str(recovered.get("reason","unknown")))))
            return
        active_evacuation_battle_squad = squad_id
        _start_battle(false)
        if not is_instance_valid(battle):
            active_evacuation_battle_squad = ""
            _return_to_world()
            ui.show_message("守军战斗未能建立，原救援进度保留。")
        return
    if bool(result.get("changed",false)):
        _capture_world_position()
        if bool(result.get("restarted",false)):
            progress.rpg.erase("evacuation_battle_pending_v1")
        progress.rpg["endgame_expansion"] = endgame_bridge.export_state()
        if not progress.save():
            progress.restore_snapshot(before_endgame)
            if not endgame_bridge.bind_progress(progress):
                push_error("终局事务失败后桥接恢复失败：" + "；".join(endgame_bridge.errors))
            _return_to_world()
            ui.show_message("撤离或交接进度未能保存，操作已回滚。")
            return
    _return_to_world()
    if bool(result.get("changed",false)) and target.begins_with("evac:") and rescue_world_director != null:
        for team_id in endgame_bridge.evacuation.OBJECTIVE_MARKERS:
            if target in endgame_bridge.evacuation.OBJECTIVE_MARKERS[team_id]:
                rescue_world_director.play_checkpoint(str(team_id))
                break
    ui.show_message(str(result.get("message","当前目标未完成。")))

func _interact(target: String) -> void:
    if busy:
        return
    if target == "deduction:ch008_requisition_ledger":
        if progress.chapter != 8 or not world.interior_building.is_empty()                 or not world.nodes.has(target) or not is_instance_valid(world.hero):
            return
        var marker: Node2D = world.nodes[target]
        if world.hero.position.distance_to(marker.position)>55.0:
            return
        pending = "deductive_ledger_review"
        busy = true
        paused_for_dialogue = true
        world.locked = true
        ui.show_choices({"prompt":"第8章 · 现场强征账册：同款止血药粉并不能证明流民实施劫掠，应该怎样核对其真实流向？",
            "options":[
                {"id":"compare_armory_requisition","label":"核对卫戍队三天前的征用记录，再与现场断箭批号交叉调查"},
                {"id":"blame_refugees_without_trace","label":"仅凭止血药粉便直接给救济站流民定罪"}
            ]})
        return
    if target.begins_with("evac:") or target in ["endgame:handover","endgame:memorial"]:
        _handle_endgame_interaction(target)
        return
    if target.begins_with("lore:"):
        _open_adventure_book()
        _read_canonical_lore(target.trim_prefix("lore:"))
        return
    if target.begins_with("wick:"):
        if progress.chapter != 6 or world_router.current_map() != "map_coast_05" or not world.interior_building.is_empty():
            return
        if not world.lighthouse_plan.ready() or not world.nodes.has(target) or not is_instance_valid(world.hero):
            ui.show_message("潮歌灯塔碎片位置未能加载，章节进度已保留。")
            return
        var artifact: Node2D = world.nodes[target]
        if not is_instance_valid(artifact) or not artifact.visible or world.hero.position.distance_to(artifact.position) > 42.0:
            return
        var wick_id: String = target.trim_prefix("wick:")
        if world.lighthouse_plan.fragment(wick_id).is_empty():
            return
        _capture_world_position()
        var wick_tx: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
            return world.lighthouse_plan.inspect(progress,wick_id)
        )
        if not bool(wick_tx.get("ok",false)):
            ui.show_message("灯芯实地调查存档失败，状态已回滚，请在此处重新查看。")
            return
        var proof: Dictionary = wick_tx.get("mutation",{})
        if bool(proof.get("changed",false)):
            game_events.record("lighthouse_wick_found",{"chapter":6,"site":wick_id,"map":"map_coast_05"})
        _focus()
        ui.show_message(str(proof.get("message","灯芯已调查。")))
        return
    if target.begins_with("shoal:"):
        # The player must be physically at the stage's reachable marker.
        if progress.chapter != 5 or world_router.current_map() != "map_coast_03" or not world.interior_building.is_empty():
            return
        if not world.shoal_plan.ready() or not world.nodes.has(target) or not is_instance_valid(world.hero):
            ui.show_message("当前浅滩调查点尚不可达。")
            return
        var shoal_marker: Node2D = world.nodes[target]
        if not is_instance_valid(shoal_marker) or not shoal_marker.visible or world.hero.position.distance_to(shoal_marker.position) > 42.0:
            return
        var shoal_id: String = target.trim_prefix("shoal:")
        if world.shoal_plan.entry(shoal_id).is_empty():
            return
        _capture_world_position()
        var shoal_tx: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
            return world.shoal_plan.inspect(progress,shoal_id)
        )
        if not bool(shoal_tx.get("ok",false)):
            ui.show_message("浅滩救援调查未能保存，本次线索状态已回滚。请重新调查。")
            return
        var observed: Dictionary = shoal_tx.get("mutation",{})
        if bool(observed.get("changed",false)):
            game_events.record("shoal_rescue_evidence",{"chapter":5,"id":shoal_id,"map_id":"map_coast_03"})
        _focus()
        ui.show_message(str(observed.get("message","此处已调查。")))
        return
    if target.begins_with("field:"):
        if not world.interior_building.is_empty():
            return
        var field_map: String=world_router.current_map()
        var field_action: String=target.trim_prefix("field:")
        var field_clock: Dictionary=progress.rpg.get("game_clock",{})
        var field_weather: String=str(world.ambience.weather) if world.ambience!=null else "clear"
        _capture_world_position()
        var field_handler: Callable = func() -> Dictionary:
            var applied: Dictionary = world.field_ecology.interact(field_map,field_action,progress,
                field_weather,int(field_clock.get("minutes",480)),int(field_clock.get("day",1)))
            if bool(applied.get("changed",false)):
                game_events.record("field_ecology_v7",
                    {"map":field_map,"event":field_action,"weather":field_weather})
            return applied
        var field_tx: Dictionary = WorldObjectSettlement.interact(progress,game_core,field_handler)
        if not bool(field_tx.get("ok",false)):
            ui.show_message("野外探索状态或采集奖励保存失败，HP和物品已回滚。请重新尝试。")
            return
        var field_result: Dictionary = (field_tx.get("outcome",{}) as Dictionary).get("result",{})
        if bool(field_tx.get("changed",false)):
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
        _capture_world_position()
        var town_handler: Callable = func() -> Dictionary:
            var applied: Dictionary = world.town_ecology.interact(town_id,task_id,progress,hour)
            if bool(applied.get("changed",false)):
                var town_reward: Dictionary = applied.get("reward",{})
                game_events.record("town_ecology_completed" if not town_reward.is_empty()
                    else "town_ecology_activity",{"map":town_id,"activity":task_id})
            return applied
        var town_tx: Dictionary = WorldObjectSettlement.interact(progress,game_core,town_handler)
        if not bool(town_tx.get("ok",false)):
            ui.show_message("街区活动进度或酬谢保存失败，物品和完成记录已回滚。请重试。")
            return
        var result: Dictionary = (town_tx.get("outcome",{}) as Dictionary).get("result",{})
        var message: String = str(result.get("message","街区活动暂时无法办理。"))
        if bool(town_tx.get("changed",false)):
            var reward: Dictionary = result.get("reward",{})
            if not reward.is_empty():
                message += "\n社区酬谢：%d G 与补给 ×%d。" % [int(reward.get("gold",0)),int(reward.get("amount",0))]
            _focus()
        ui.show_message(message)
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
        var narrative: String = str(record.get("text",""))
        var reward: Dictionary = record.get("reward",{}) if record.get("reward",{}) is Dictionary else {}
        _capture_world_position()
        var discovery_tx: Dictionary = WorldObjectSettlement.claim(progress,game_core,completion,reward)
        if not bool(discovery_tx.get("ok",false)):
            ui.show_message("调查进度尚未保存，物品和奖励已回滚。请检查存储空间后重试。")
            return
        var payout: String = ""
        if not reward.is_empty():
            payout = "\n获得 %d G 与地区补给 ×%d。" % [int(reward.get("gold",0)),int(reward.get("amount",0))]
        game_events.record("world_discovery",{"map":map_id,"site":event_id})
        ui.show_message("【%s】\n%s%s" % [str(record.get("name","地标")),narrative,payout])
        return
    if target.begins_with("puzzle:"):
        if not world.interior_building.is_empty():
            return
        var region_id: String = world_router.current_map()
        var device_id: String = target.trim_prefix("puzzle:")
        _capture_world_position()
        var puzzle_tx: Dictionary = WorldObjectSettlement.puzzle(progress,game_core,world.dungeon_puzzles,region_id,device_id)
        if not bool(puzzle_tx.get("ok",false)):
            ui.show_message("机关状态或秘藏奖励未能保存，已恢复操作前状态。请重新尝试。")
            return
        var solved: Dictionary = (puzzle_tx.get("outcome",{}) as Dictionary).get("result",{})
        if bool(puzzle_tx.get("changed",false)) and bool(solved.get("completed",false)):
            game_events.record("dungeon_puzzle_solved",{"map":region_id,"mode":str(world.dungeon_puzzles.config(region_id).get("mode",""))})
        ui.show_message(str(solved.get("message","这里没有可操作的机关。")))
        return
    if target.begins_with("dungeon_switch_"):
        var key: String = "map.%s.%s" % [world_router.current_map(),target]
        if bool(progress.flags.get(key,false)):
            ui.show_message("符文机关已经启动。")
        else:
            _capture_world_position()
            var switch_tx: Dictionary = WorldObjectSettlement.claim(progress,game_core,key)
            if not bool(switch_tx.get("ok",false)):
                ui.show_message("机关开启状态保存失败，已回滚。请重试。")
                return
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
            _capture_world_position()
            var chest_tx: Dictionary = WorldObjectSettlement.claim(progress,game_core,
                lock_prefix+"chest_claimed",{"gold":60+8*maxi(1,progress.chapter),"item_id":"item_herb_01","amount":2})
            if not bool(chest_tx.get("ok",false)):
                ui.show_message("宝箱奖励保存失败，已回滚。请重试。")
                return
            ui.show_message("发现地下城秘藏！获得两株盐露草与旅行金币。")
        return
    if target == "wild_cache":
        var cache_flag: String = "map.%s.wild_cache" % world_router.current_map()
        if bool(progress.flags.get(cache_flag,false)):
            ui.show_message("补给箱已被取走。")
        else:
            _capture_world_position()
            var cache_tx: Dictionary = WorldObjectSettlement.claim(progress,game_core,
                cache_flag,{"item_id":"item_herb_01","amount":1})
            if not bool(cache_tx.get("ok",false)):
                ui.show_message("补给箱领取记录保存失败，物品已回滚。请重试。")
                return
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
        _capture_world_position()
        var rest_handler: Callable = func() -> Dictionary:
            var saved_days: Dictionary = (progress.rpg.get("camp_last_day",{}) as Dictionary).duplicate(true)
            saved_days[region_id] = today
            progress.rpg["camp_last_day"] = saved_days
            for i in range(progress.actors.size()):
                var person: Dictionary = progress.actors[i]
                if int(person.get("hp",0))>0:
                    person["hp"]=mini(int(person.get("max_hp",1)),int(person.get("hp",1))+maxi(12,roundi(float(person.get("max_hp",1))*0.38)))
                    person["mp"]=mini(int(person.get("max_mp",1)),int(person.get("mp",0))+maxi(6,roundi(float(person.get("max_mp",1))*0.30)))
                    progress.actors[i]=person
            game_events.advance_time(120)
            game_events.record("camp_rest",{"map":region_id})
            return {"ok":true,"changed":true}
        var camp_tx: Dictionary = WorldObjectSettlement.transact(progress,rest_handler)
        if not bool(camp_tx.get("ok",false)):
            ui.show_message("营地状态保存失败，休息恢复与经过的时间已回滚。请重试。")
            return
        world.encounter_meter=-380.0
        world.sync_world_clock(int(progress.rpg["game_clock"].get("day",1)),int(progress.rpg["game_clock"].get("minutes",480)))
        _focus()
        ui.show_message("队伍在安全营地整备两小时，恢复部分 HP / MP；附近的怪物暂时不会接近。")
        return
    if target.begins_with("exit:"):
        _travel_to(target.trim_prefix("exit:"))
        return
    if target.begins_with("questdoor:"):
        var lost_page_id: String = target.trim_prefix("questdoor:")
        _capture_world_position()
        var room_before: Dictionary = progress._pack().duplicate(true)
        if world.enter_story_submap(lost_page_id):
            var current_world: Dictionary = progress.rpg.get("world",{})
            current_world["indoor_building"] = world.interior_building
            current_world["outdoor_return"] = [world.exterior_position.x,world.exterior_position.y]
            if not _save_progress():
                progress.restore_snapshot(room_before)
                _enter_location()
                ui.show_message("调查室进入进度保存失败，已返回原地图。")
                return
            game_events.record("lost_page_scene_entered",{"quest_id":lost_page_id,"map":world_router.current_map()})
            _focus()
            ui.show_message("进入"+world.quest_submaps.room_name(lost_page_id)+"。现场调查、证物与离开进度均可保存。")
        return
    if target.begins_with("building:"):
        var building_id: String = target.trim_prefix("building:")
        _capture_world_position()
        var building_before: Dictionary = progress._pack().duplicate(true)
        if world.enter_building(building_id):
            var current_world: Dictionary = progress.rpg.get("world",{})
            current_world["indoor_building"] = building_id
            current_world["outdoor_return"] = [world.exterior_position.x,world.exterior_position.y]
            if not _save_progress():
                progress.restore_snapshot(building_before)
                _enter_location()
                ui.show_message("进门状态保存失败，已返回原来的安全位置。")
                return
            game_events.record("building_entered",{"building":building_id,"map":world_router.current_map()})
            _focus()
            ui.show_message("进入 " + world.region_name() + "。室内进度已自动保存。")
        elif (building_id == "tavern" and progress.chapter == 4) or (building_id == "shelter" and progress.chapter == 2):
            # Failed V4 geometry must never silently become a generic room.
            _focus()
            ui.show_message(("黑帆酒馆" if building_id=="tavern" else "白砂港收容所") +
                "正式室内布局未能加载，原位置已保留；本章主线不会被跳过。")
        return
    if target == "interior_exit":
        _capture_world_position()
        var exit_before: Dictionary = progress._pack().duplicate(true)
        if world.leave_building():
            var current_world: Dictionary = progress.rpg.get("world",{})
            current_world.erase("indoor_building")
            current_world.erase("outdoor_return")
            if not _save_progress():
                progress.restore_snapshot(exit_before)
                _enter_location()
                ui.show_message("室内离开进度保存失败，已恢复屋内状态。")
                return
            _focus()
            ui.show_message("返回 " + world.region_name() + "。")
        return
    if target.begins_with("homeinspect:"):
        # No synthetic dialogue markers: the selected hotspot must belong to
        # this exact V4 room and be within actual player interaction distance.
        if world.interior_building.is_empty() or world.interior_building.begins_with("quest__") or not world.nodes.has(target):
            return
        var room_marker: Node2D = world.nodes[target]
        if not is_instance_valid(room_marker) or not room_marker.visible or not is_instance_valid(world.hero) or world.hero.position.distance_to(room_marker.position)>45.0:
            return
        var inspected_id: String = target.trim_prefix("homeinspect:")
        var inspected_map: String = world_router.current_map()
        var inspected_building: String = world.interior_building
        if not bool(room_investigations.preview(inspected_map,inspected_building,inspected_id,progress).get("available",false)):
            ui.show_message("此处尚没有可调查的线索。")
            return
        _capture_world_position()
        var inspection_tx: Dictionary = WorldObjectSettlement.transact(progress,func() -> Dictionary:
            var report: Dictionary = room_investigations.inspect(
                inspected_map,inspected_building,inspected_id,progress,false)
            return {"ok":true,"changed":bool(report.get("changed",false)),"result":report}
        )
        if not bool(inspection_tx.get("ok",false)):
            ui.show_message("室内调查记录保存失败，调查状态已回滚，请重试。")
            return
        var inspection_report: Dictionary = (inspection_tx.get("outcome",{}) as Dictionary).get("result",{})
        if inspected_map == "map_coast_02" and inspected_building in ["tavern","shelter"] and is_instance_valid(world.interior_art):
            # Furniture feedback only follows the already committed V3
            # investigation. This never grants or repeats a quest reward.
            var room_props: Dictionary = {
                "inspect_act01_tavern_1":"shipment_ledger_box",
                "inspect_act01_tavern_2":"crew_noticeboard",
                "inspect_act01_tavern_3":"old_sailors_table",
                "inspect_act01_tavern_4":"lost_wages_book",
                "inspect_act01_shelter_1":"bedside_medicine",
                "inspect_act01_shelter_2":"washed_luggage",
                "inspect_act01_shelter_3":"public_patient_roster",
                "inspect_act01_shelter_4":"saltgrass_treatment"
            }
            if room_props.has(inspected_id):
                world.interior_art.play_prop_action(str(room_props[inspected_id]),"inspect")
        _focus()
        ui.show_message(str(inspection_report.get("message","这里没有新的线索。")))
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
            # Save before showing the clue or unlocking deduction choices.
            # A failed write must not leave the gallery marked seen in RAM.
            var before_case: Dictionary=progress._pack().duplicate(true)
            _capture_world_position()
            var case_tx: Dictionary=EvidenceTransactions.observe(progress,quest_id,step)
            if not bool(case_tx.get("ok",false)):
                progress.restore_snapshot(before_case)
                ui.show_message("调查档案保存失败，线索状态已回滚，请重试。")
                return
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
        var map_id: String = world_router.current_map()
        var region_id: String = str(world.map_profile.get("region_id","region_coast"))
        _capture_world_position()
        var contact: Dictionary = NPCV3Contact.converse(
            progress,world.town_life,citizen_id,region_id,map_id,clock)
        if not bool(contact.get("ok",false)):
            ui.show_message("居民对话状态未能保存，请检查存储空间后重新交谈。")
            return
        var conversation: Dictionary = contact.get("preview",{})
        var neighborhood_gossip: String = world.town_ecology.resident_hint(map_id,progress,int(float(clock.get("minutes",480))/60.0))
        if not neighborhood_gossip.is_empty():
            conversation["text"]=str(conversation.get("text",""))+"\n"+neighborhood_gossip
        if bool(contact.get("applied",false)):
            game_events.record("resident_met",{"id":citizen_id,"region_id":region_id})
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
            _capture_world_position()
            var purchase: Dictionary = WorldObjectSettlement.transact(progress,func() -> Dictionary:
                if progress.gold < 16:
                    return {"ok":false,"reason":"insufficient_gold"}
                progress.gold -= 16
                game_core.add_item("item_herb_01",1)
                return {"ok":true,"changed":true}
            )
            if bool(purchase.get("ok",false)):
                ui.show_message("购买盐露草 ×1，剩余金币 %d。" % progress.gold)
            else:
                ui.show_message("商店结算保存失败，金币和药草已恢复，请重试。")
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
    if target != _target() or (
            progress.chapter>=1 and progress.chapter<=6 and
            not world_router.act01_target_map(progress.chapter).is_empty() and
            world_router.current_map()!=world_router.act01_target_map(progress.chapter)):
        ui.show_message("当前目标：" + _objective())
        return
    # The chapter 2 harbor opening happens outside; after that the clinic
    # diagnosis, witness statement, crisis and resolution are physical V4
    # shelter interactions, never the harbor's generic outdoor markers.
    if progress.chapter == 2:
        if progress.scene_index == 0 and not world.interior_building.is_empty():
            ui.show_message("先回港口街道与港务员交谈，再进入收容所寻找失忆水手。")
            return
        if progress.scene_index >= 1:
            if world.interior_building != "shelter":
                ui.show_message("请沿白砂港街道从正门进入收容所，不能在室外代替病患完成调查。")
                return
            if progress.scene_index == 1 and progress.task_index == 0 and not bool(progress.flags.get("ch002.evidence",false)):
                var required_clues: Array = world.terrain_layout.get("act01_main_story_evidence",[])
                if required_clues.size()!=2:
                    ui.show_message("收容所正式病例调查点缺失，本章不能跳过调查。")
                    return
                for evidence_id in required_clues:
                    var seen_record: Dictionary = room_investigations.snapshot(
                        progress,world_router.current_map(),"shelter",str(evidence_id))
                    if not bool(seen_record.get("seen_before",false)):
                        ui.show_message("先在真实室内查看搁浅行囊及临时名册，并确认两个调查记录都已保存。")
                        return
    # Chapter four is exclusively playable on the physical tavern floor.
    # Old outdoor generic markers are never a substitute for this room.
    if progress.chapter == 4:
        if world.interior_building != "tavern":
            ui.show_message("先走到黑帆酒馆正门，进入室内与酒馆老板、船员交谈。")
            return
        if progress.scene_index == 1 and progress.task_index == 0 and not bool(progress.flags.get("ch004.evidence",false)):
            for evidence_id in world.terrain_layout.get("act01_main_story_evidence",[]):
                var inspected: Dictionary = room_investigations.snapshot(
                    progress,world_router.current_map(),"tavern",str(evidence_id))
                if not bool(inspected.get("seen_before",false)):
                    ui.show_message("仍需实地调查夹层货单与无日期船员告示，且成功保存调查记录。")
                    return
    # A real, persisted red-flag / star-lock / evacuation trace is mandatory
    # before chapter five's investigation or crisis dialogue can complete.
    if progress.chapter == 5 and progress.scene_index in [1,2]:
        if not world.shoal_plan.ready() or not world.shoal_plan.fully_observed(progress):
            ui.show_message("先走到鲸骨半月湾，依次实地核对渔民红旗、三重星锁及安全退潮线。当前章节不会跳过调查。")
            return
    # The lamp's three real, saved fragments must precede its investigation
    # and crisis; a generic old world marker cannot conjure the missing pieces.
    if progress.chapter == 6 and progress.scene_index in [1,2]:
        if not world.lighthouse_plan.ready() or not world.lighthouse_plan.all_fragments_found(progress):
            ui.show_message("请走上潮歌灯塔正式悬崖路，先后调查海堤、塔底和塔顶的三枚灯芯碎片，并保存成功。")
            return
    # Physical close-up choices are only offered at the reachable main clue marker.
    # Existing V3 saves past the investigation step are never forced back through them.
    if target == "clue" and _begin_canon_evidence_inspection():
        return
    # Crash/quit during a chapter mechanism: the canonical crisis choice was
    # already durably recorded. Resume at the next saved action instead of
    # replaying the scene and offering the same A/B choice a second time.
    if progress.scene_index == 2 and progress.task_index == 0 and _chapter_mechanic_required():
        var saved_choice: Dictionary = _current_scene().get("choice",{})
        var saved_choice_id: String = str(saved_choice.get("id",""))
        if not saved_choice_id.is_empty() and bool(progress.flags.get(saved_choice_id+".chosen",false)):
            if _begin_chapter_mechanic():
                return
            if _chapter_mechanic_done():
                _crisis_choice_complete()
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
                if _begin_chapter_mechanic():
                    return
                _start_battle(true)
            else:
                _present("crisis")
        3:
            if progress.chapter == 47 and not endgame_bridge.chapter_gate_message().is_empty():
                ui.show_message(endgame_bridge.chapter_gate_message())
                return
            _present("resolve")
        4: _present("ending_intro")

# V2.1 inspected evidence is persisted alongside existing V3 RPG metadata.
# No quest rewards, chapter flags or dialogue stages are directly advanced here.
func _canon_evidence_for_chapter() -> String:
    match progress.chapter:
        1: return "ev_ch001_envelope"
        3: return "ev_ch003_half_badge"
        7: return "ev_ch007_rejected_letters"
        8: return "ev_ch008_caravan_site"
    return ""

func _begin_canon_evidence_inspection() -> bool:
    if progress.scene_index != 1 or progress.task_index != 0:
        return false
    var evidence_id: String = _canon_evidence_for_chapter()
    if evidence_id.is_empty() or not StarlightJournalScript.INTERACTIVE_EVIDENCE_DB.has(evidence_id):
        return false
    active_evidence_id = evidence_id
    evidence_journal.inspect_physical_object(evidence_id)
    return true

func _on_canon_evidence_closeup_requested(evidence_id: String, hotspots: Array) -> void:
    if evidence_id != active_evidence_id or progress == null:
        return
    var gallery: Dictionary = progress.rpg.get("canon_evidence", {})
    var visited: Dictionary = gallery.get(evidence_id, {})
    var options: Array = []
    for hotspot in hotspots:
        if not (hotspot is Dictionary):
            continue
        var hotspot_id: String = str(hotspot.get("id",""))
        if hotspot_id.is_empty() or bool(visited.get(hotspot_id,false)):
            continue
        options.append({"id":hotspot_id,"label":"查看 · "+str(hotspot.get("label","物证细节"))})
    if options.is_empty():
        active_evidence_id = ""
        pending = ""
        paused_for_dialogue = false
        _present("clue")
        return
    pending = "canon_evidence"
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.show_evidence_choices(evidence_id,
        {"prompt":"仔细观察实物证据（已记录的痕迹无需重复调查）","options":options})

func _record_canon_evidence_hotspot(item: Dictionary) -> void:
    var evidence_id: String = active_evidence_id
    var data: Dictionary = StarlightJournalScript.INTERACTIVE_EVIDENCE_DB.get(evidence_id, {})
    var hotspot_id: String = str(item.get("id",""))
    var selected: Dictionary = {}
    for hotspot in data.get("hotspots",[]):
        if hotspot is Dictionary and str(hotspot.get("id","")) == hotspot_id:
            selected = hotspot
            break
    if selected.is_empty() or evidence_id != _canon_evidence_for_chapter() or progress.scene_index != 1 or progress.task_index != 0:
        pending = ""
        paused_for_dialogue = false
        active_evidence_id = ""
        _return_to_world()
        ui.show_message("线索交互已失效，请回到调查点重新查看。")
        return
    _capture_world_position()
    var tx: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
        var gallery: Dictionary = progress.rpg.get("canon_evidence", {}).duplicate(true)
        var visited: Dictionary = gallery.get(evidence_id, {}).duplicate(true)
        visited[hotspot_id] = true
        gallery[evidence_id] = visited
        progress.rpg["canon_evidence"] = gallery
        return {"ok":true}
    )
    if not bool(tx.get("ok",false)):
        pending = ""
        paused_for_dialogue = false
        active_evidence_id = ""
        _return_to_world()
        ui.show_message("物证调查未能保存，原有存档已恢复；请重新操作。")
        return
    evidence_journal.register_clue(str(selected.get("grants_clue","")),str(selected.get("label","物证")),
        str(data.get("title","")),StarlightJournalScript.ClueCategory.VERIFIED_FACT)
    evidence_journal.inspect_physical_object(evidence_id)

func _restore_canon_evidence_journal() -> void:
    if evidence_journal == null:
        return
    evidence_journal.verified_facts.clear()
    evidence_journal.pending_inferences.clear()
    active_evidence_id = ""
    var gallery: Dictionary = progress.rpg.get("canon_evidence", {})
    for evidence_id in gallery.keys():
        var data: Dictionary = StarlightJournalScript.INTERACTIVE_EVIDENCE_DB.get(evidence_id,{})
        if data.is_empty():
            continue
        var visited: Dictionary = gallery.get(evidence_id,{})
        for hotspot in data.get("hotspots",[]):
            if hotspot is Dictionary and bool(visited.get(str(hotspot.get("id","")),false)):
                evidence_journal.register_clue(str(hotspot.get("grants_clue","")),
                    str(hotspot.get("label","物证")),str(data.get("title","")),
                    StarlightJournalScript.ClueCategory.VERIFIED_FACT)

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
    var tracking_before: Dictionary=progress._pack().duplicate(true)
    _capture_world_position()
    var tracked_tx: Dictionary=EvidenceTransactions.track(progress,event_id)
    if not bool(tracked_tx.get("ok",false)):
        progress.restore_snapshot(tracking_before)
        ui.show_message("支线追踪保存失败，当前追踪目标未改变。")
        return
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
        var bonds: Dictionary = endgame_bridge.after_scene_committed(progress)
        if bool(bonds.get("changed",false)) and not _save_progress():
            push_warning("伙伴羁绊附加缓存未能保存，可从正典支线旗标恢复。")
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

# Global chapter mechanics: canonical pre-crisis player interactions only.
# The RPGCore job system and BattleV3Settlement remain sole reward authorities.
func _chapter_mechanic_key() -> String:
    return "ch%03d" % progress.chapter

func _chapter_mechanic_state() -> Dictionary:
    var entries: Dictionary = progress.rpg.get("chapter_mechanics_v2", {})
    return (entries.get(_chapter_mechanic_key(), {}) as Dictionary).duplicate(true)

func _chapter_mechanic_required() -> bool:
    # Newly mounted mechanics must not invalidate old saves containing a
    # genuine Boss victory or an already committed chapter resolution.
    if progress.chapter in [58,59,60,64,66,71,72]:
        if bool(progress.flags.get("story.ch%03d.done" % progress.chapter,false)):
            return false
        if progress.chapter != 72 and bool(progress.flags.get("ch%03d.battle_won" % progress.chapter,false)):
            return false
    return progress.chapter in [15,17,23,27,29,36,40,55,56,57,58,59,60,61,62,64,65,66,70,71,72]

func _chapter_mechanic_done() -> bool:
    var state: Dictionary = _chapter_mechanic_state()
    if not bool(state.get("done",false)):
        return false
    var controller: Node = _load_chapter_mechanic()
    if controller == null:
        return false
    if controller.has_method("verified_complete"):
        return bool(controller.call("verified_complete",state))
    return true

func _chapter_mechanic_block(message: String) -> void:
    # Fail closed: an invalid controller cannot grant the canonical boss entry.
    pending = ""
    paused_for_dialogue = false
    _return_to_world()
    ui.show_message(message)

func _load_chapter_mechanic() -> Node:
    var key: String = _chapter_mechanic_key()
    if is_instance_valid(chapter_mechanic_controller) and chapter_mechanic_id == key:
        return chapter_mechanic_controller
    if is_instance_valid(chapter_mechanic_controller):
        chapter_mechanic_controller.queue_free()
    chapter_mechanic_controller = null
    chapter_mechanic_id = ""
    if mechanics_registry == null or str(mechanics_registry.binding_for(key).get("status","")) != "active":
        return null
    var created: Node = mechanics_registry.create_controller(key)
    if created == null or not created.has_method("get_prompt") or not created.has_method("apply_action"):
        if is_instance_valid(created):
            created.queue_free()
        return null
    if created.has_method("configure") and not bool(created.call("configure",key)):
        created.free()
        return null
    add_child(created)
    chapter_mechanic_controller = created
    chapter_mechanic_id = key
    return created

func _begin_chapter_mechanic() -> bool:
    if not _chapter_mechanic_required() or _chapter_mechanic_done():
        return false
    var controller: Node = _load_chapter_mechanic()
    if controller == null:
        _chapter_mechanic_block("本章机关数据无法读取，Boss战已安全锁定；请检查正式剧情资源。")
        return true
    var screen: Dictionary = controller.call("get_prompt", _chapter_mechanic_state())
    if screen.is_empty() or bool(screen.get("done",false)) or (screen.get("options",[]) as Array).is_empty():
        _chapter_mechanic_block("本章机关记录异常，禁止跳过至战斗。")
        return true
    pending = "chapter_mechanic"
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.show_choices(screen)
    return true

func _chapter_mechanic_picked(item: Dictionary) -> void:
    var controller: Node = _load_chapter_mechanic()
    if controller == null:
        _chapter_mechanic_block("本章控制器已丢失，操作未计入进度。")
        return
    var next_state: Dictionary = _chapter_mechanic_state()
    var action: Dictionary = controller.call("apply_action",next_state,str(item.get("id","")))
    if not bool(action.get("ok",false)):
        ui.show_message(str(action.get("message","操作无效，请重试。")))
        _begin_chapter_mechanic()
        return
    _capture_world_position()
    var chapter_id: String = _chapter_mechanic_key()
    var transaction: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
        var recorded: Dictionary = progress.rpg.get("chapter_mechanics_v2",{}).duplicate(true)
        recorded[chapter_id] = next_state.duplicate(true)
        progress.rpg["chapter_mechanics_v2"] = recorded
        if bool(next_state.get("done",false)):
            progress.flags["mechanic."+chapter_id+".ready"] = true
        return {"ok":true}
    )
    if not bool(transaction.get("ok",false)):
        ui.show_message("机关存档失败，当前操作已回滚；请重新选择。")
        _begin_chapter_mechanic()
        return
    ui.show_message(str(action.get("message","机关操作已保存。")))
    if not _chapter_mechanic_done():
        _begin_chapter_mechanic()
        return
    # A/B choice was already committed BEFORE the player-operated sequence.
    # Never reopen it and double-record choice/reaction flags.
    pending = ""
    paused_for_dialogue = false
    _crisis_choice_complete()

func _ch021_choice_ready() -> bool:
    return direction_cutscene != null and bool(direction_cutscene.choice_is_unlocked(progress))

func _block_ch021_direction(message: String) -> void:
    # Failure cannot silently fall through into the choice while in the past.
    busy = true
    paused_for_dialogue = false
    world.locked = true
    pending = ""
    ui.set_play_visible(false)
    atlas.show_exploration(false)
    ui.show_title(true, message)

func _begin_ch021_direction(resume: bool = false) -> bool:
    if progress.chapter != 21 or str(_current_scene().get("id", "")) != "ch021.crisis":
        return false
    if direction_cutscene == null:
        _block_ch021_direction("第21章导演控制器不存在，选择已锁定。")
        return true
    var cue: Dictionary = direction_cutscene.build_cue(_current_scene())
    if cue.is_empty():
        _block_ch021_direction("第21章正典导演提示或选择数据无效，选择已锁定。")
        return true
    if not resume:
        _capture_world_position()
        var tx: Dictionary = V3ProgressTransition.commit(progress, func() -> Dictionary:
            progress.rpg["cinematic_checkpoint"] = CH021_DIRECTION_CUE
            return {"ok":true}
        )
        if not bool(tx.get("ok", false)):
            _cinematic_save_failed()
            return true
    pending = "ch021_direction"
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.set_play_visible(false)
    atlas.show_exploration(false)
    if DisplayServer.get_name() == "headless" and not cinematic_force_play:
        # Transaction tests only; this is not evidence of on-screen presentation.
        _finish_ch021_direction()
        return true
    if not cinematic.start(CH021_DIRECTION_CUE, cue):
        _block_ch021_direction("第21章演出未能启动；V3 检查点已保留，请读取存档重试。")
        return true
    _mix_world_for_cinematic(true)
    return true

func _finish_ch021_direction() -> void:
    # Never make the adult choice visible before the era flag and checkpoint
    # removal have been persisted in the same V3 save.
    var tx: Dictionary = V3ProgressTransition.commit(progress, func() -> Dictionary:
        progress.flags["ch021.campfire_returned"] = true
        progress.rpg["direction_ch021_era"] = "present_campfire"
        progress.rpg.erase("cinematic_checkpoint")
        return {"ok":true}
    )
    _mix_world_for_cinematic(false)
    if not bool(tx.get("ok", false)):
        _cinematic_save_failed()
        return
    # The saved era was restored: refresh visual treatment before the adult choice.
    world.world_epoch = "present"
    if is_instance_valid(world.ambience):
        world.ambience.set_world_epoch("present")
    if not _ch021_choice_ready():
        _block_ch021_direction("第21章现世场景状态校验失败，已禁止弹出抉择。")
        return
    pending = "choice"
    busy = true
    paused_for_dialogue = true
    world.locked = true
    ui.show_choices(_current_scene().get("choice", {}))

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
            if _begin_chapter_mechanic():
                return
            var choice: Dictionary = _current_scene().get("choice", {})
            if progress.chapter == 21 and str(_current_scene().get("id", "")) == "ch021.crisis":
                if bool(progress.flags.get("ch021.choice.chosen", false)) or bool(progress.flags.get("ch021.decision_made", false)):
                    _crisis_choice_complete()
                    return
                if not _ch021_choice_ready():
                    _begin_ch021_direction()
                    return
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
            # Chapter 54 memorial/handover is a real field interaction, not
            # an automatic flag added by completing the resolution dialogue.
            # Keep the player in the chapter with the world unlocked until
            # the verified original ticket has actually been archived.
            if progress.chapter == 54 and endgame_bridge != null:
                var memorial_gate: String = endgame_bridge.chapter_gate_message()
                if not memorial_gate.is_empty():
                    pending = ""
                    paused_for_dialogue = false
                    _return_to_world()
                    ui.show_message(memorial_gate)
                    return
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
    if pending == "deductive_ledger_review":
        pending = ""
        paused_for_dialogue = false
        if progress.chapter != 8 or str(item.get("id","")) != "compare_armory_requisition":
            _return_to_world()
            ui.show_message("仅凭同款药粉不能认定罪责，必须核对实物和强征账册。")
            return
        _capture_world_position()
        var ledger_tx: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
            var sources: Dictionary = progress.rpg.get("deductive_physical_sources_v1",{}).duplicate(true)
            sources["ch008_requisition_ledger"] = {
                "source":"world_field_inspection","requisition_batch_read":true,
                "chapter":"ch008","evidence_kind":"PHYSICAL_TRACE",
                "procedure":"cross_reference_requisition_to_armory_batches"
            }
            progress.rpg["deductive_physical_sources_v1"] = sources
            return {"ok":true}
        )
        _return_to_world()
        ui.show_message("已记录卫戍队强征药粉的原始调拨账册。可与断箭批号交叉检定。" if bool(ledger_tx.get("ok",false)) else
            "账册证据尚未保存，现场进度保持不变。")
        return
    if pending == "endgame_evac_choice":
        var action_target: String = active_evacuation_choice
        if action_target.is_empty():
            pending = ""
            paused_for_dialogue = false
            _return_to_world()
            return
        _handle_endgame_interaction(action_target,str(item.get("id","")))
        return
    if pending == "chapter_mechanic":
        _chapter_mechanic_picked(item)
        return
    if pending == "canon_evidence":
        _record_canon_evidence_hotspot(item)
        return
    if pending == "quest_puzzle_choice":
        var case_id: String = active_puzzle_quest
        active_puzzle_quest = ""
        var choice_before: Dictionary=progress._pack().duplicate(true)
        _capture_world_position()
        var answer_tx: Dictionary=EvidenceTransactions.answer(
            progress,evidence_puzzles,case_id,str(item.get("id","")),progress.chapter)
        pending = ""
        paused_for_dialogue = false
        if not bool(answer_tx.get("ok",false)):
            progress.restore_snapshot(choice_before)
            _focus()
            _return_to_world()
            ui.show_message("推理结果保存失败，答案与尝试次数已恢复，请重新调查。")
            return
        var outcome: Dictionary=(answer_tx.get("outcome",{}) as Dictionary).get("result",{})
        if bool(outcome.get("solved",false)) and bool(answer_tx.get("changed",false)):
            game_events.record("lost_page_evidence_solved",{"quest_id":case_id})
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
    var scene: Dictionary = _current_scene()
    var choice: Dictionary = scene.get("choice", {})
    # Commit the canonical option and the optional reaction receipt in one
    # durable snapshot before displaying any reaction dialogue. Neither flag
    # may survive in RAM if V3 saving fails.
    var before_choice: Dictionary=progress._pack().duplicate(true)
    _capture_world_position()
    var choice_tx: Dictionary=Act01ChoiceTransaction.commit(
        progress,optional_director,item,str(choice.get("id","choice")))
    if not bool(choice_tx.get("ok",false)):
        progress.restore_snapshot(before_choice)
        pending = ""
        paused_for_dialogue = false
        _focus()
        _return_to_world()
        ui.show_message("剧情选择未能保存，分支和追加对话状态已回滚，请重新选择。")
        return
    # A/B response lines are presentation only; the saved optional-event ID
    # is the authoritative one-time receipt after a successful commit.
    var response_lines: Array=item.get("branch_dialogue",[]).duplicate(true)
    var mutation: Dictionary=choice_tx.get("mutation",{})
    response_lines.append_array(mutation.get("response_dialogue",[]))
    if not response_lines.is_empty():
        pending = "choice_reaction"
        ui.show_dialogue(response_lines)
        return
    _crisis_choice_complete()

func _crisis_choice_complete() -> void:
    if _begin_chapter_mechanic():
        return
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
    if is_boss and progress.chapter == 2:
        if world_router.current_map() != "map_coast_02" or world.interior_building != "shelter":
            ui.show_message("雾潮寄生体必须从收容所的真实病历冲突触发，不能在港口街道代替病患完成战斗。")
            return
        var shelter_evidence: Array = world.terrain_layout.get("act01_main_story_evidence",[])
        if shelter_evidence.size()!=2:
            ui.show_message("收容所病历与水手行囊的现场记录缺失，Boss入口保持关闭。")
            return
        for evidence_id in shelter_evidence:
            if not bool(room_investigations.snapshot(
                    progress,world_router.current_map(),"shelter",str(evidence_id)).get("seen_before",false)):
                ui.show_message("须先查阅并保存搁浅行囊及临时名册两份现场证据。")
                return
    if is_boss and progress.chapter == 4 and world.interior_building != "tavern":
        ui.show_message("第四章灰帷会冲突必须在黑帆酒馆内部触发，不能从室外跳过现场调查。")
        return
    if is_boss and progress.chapter == 5:
        if world_router.current_map() != "map_coast_03" or not world.interior_building.is_empty() or not world.shoal_plan.fully_observed(progress):
            ui.show_message("古兽救援现场未准备妥当。须从正式盐风古道进入鲸骨浅滩，并核对全部三项实地证据。")
            return
    if is_boss and progress.chapter == 6:
        if world_router.current_map() != "map_coast_05" or not world.interior_building.is_empty() or not world.lighthouse_plan.all_fragments_found(progress):
            ui.show_message("灯塔守门人尚未开放战斗：必须真实取得三枚灯芯碎片并回到塔前。")
            return
    if is_boss and _begin_chapter_mechanic():
        return
    if is_instance_valid(battle):
        return
    if progress.chapter < 1:
        return
    # A missing or malformed three-gate profile must not silently turn the
    # rescue into a generic random fight that still awards a rescue receipt.
    if not is_boss and progress.chapter == 47 and not active_evacuation_battle_squad.is_empty():
        if not RescueProfiles.configured(active_evacuation_battle_squad):
            active_evacuation_battle_squad = ""
            ui.show_message("本队守军编队数据无效，战斗入口暂时关闭；救援进度保持不变。")
            return
    # Older V3 saves may already have a Boss victory flag without a nonce.
    if is_boss and bool(progress.flags.get("ch%03d.battle_won" % progress.chapter,false)):
        ui.show_message("本章强敌已经解决，无需重复挑战。")
        return
    battle_is_boss = is_boss
    # Different attempts against the SAME boss must pay their own defeat
    # penalty. A duplicate completion callback for one attempt stays idempotent.
    battle_defeat_id = BattleRewardTransaction.make_id(false,progress.chapter)
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
    if not is_boss and progress.chapter == 47 and not active_evacuation_battle_squad.is_empty():
        var selected: Dictionary = EvacuationRoster.resolve(
            active_evacuation_battle_squad,progress.chapter,progress.actors,progress.flags)
        if not bool(selected.get("ok",false)):
            var reason: String = str(selected.get("reason","unknown"))
            active_evacuation_battle_squad = ""
            battle.queue_free()
            battle = null
            battle_defeat_id = ""
            busy = false
            world.locked = false
            ui.set_play_visible(true)
            atlas.show_exploration(true)
            ui.show_message("撤离战斗小队不符合正典或全员失去行动能力：" + reason +
                "。请先确认伙伴招募与治疗，不能自动替换其他人。")
            return
        for actor_id in selected.get("ids",[]):
            battle.forced_party_ids.append(str(actor_id))
    var battle_event: Variant = _current_scene().get("encounter", {}) if is_boss else {}
    battle.encounter_data = battle_event.duplicate(true) if battle_event is Dictionary else {}
    if not is_boss and progress.chapter == 47 and not active_evacuation_battle_squad.is_empty():
        var pending_map: Dictionary = progress.rpg.get("evacuation_battle_pending_v1",{})
        var assigned_id: String = str(pending_map.get(active_evacuation_battle_squad,""))
        if not BattleRewardTransaction.valid_id(assigned_id) or not assigned_id.begins_with("random:"):
            active_evacuation_battle_squad = ""
            battle.queue_free()
            battle = null
            battle_defeat_id = ""
            _return_to_world()
            ui.show_message("无法核对已预存的战斗回执，禁止发起可能重复结算的战斗。")
            return
        battle.encounter_data["rescue_squad_id"] = active_evacuation_battle_squad
        battle.encounter_data["rescue_reward_transaction_id"] = assigned_id
    if is_boss and progress.chapter == 3:
        # Read the actual V7 cave puzzle snapshot; never fabricate a badge.
        battle.encounter_data["cave_snapshot"] = (progress.rpg.get("dungeon_puzzles_v7",{}) as Dictionary).get("map_coast_04",{}).duplicate(true)
    if is_boss and progress.chapter == 5:
        battle.encounter_data["shoal_snapshot"] = world.shoal_plan.snapshot(progress)
    if is_boss and progress.chapter == 6:
        battle.encounter_data["lighthouse_fragments"] = world.lighthouse_plan.snapshot(progress)
        battle.encounter_data["lighthouse_testimonies"] = world.lighthouse_plan.testimony_rows()
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
    if progress.chapter == 47 and endgame_bridge != null and             endgame_bridge.registry_loaded and not endgame_bridge.evacuation.finished:
        # During the three concurrent rescue routes all guard waves must
        # originate from their real, reachable squad encounter markers.
        world.locked = false
        return
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
    if not won and not BattleRewardTransaction.valid_id(battle_defeat_id):
        _hold_battle_settlement(won,xp,money,"战败回执ID无效，暂停结算。")
        return
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
    # A special story boss cannot grant a generic victory receipt. Chapter 5
    # must actually remove the beast's star chains; chapter 6 requires four
    # shared testimony actions. Normal defeats and old save recovery are intact.
    if won and is_boss and chapter_at_fight == 5 and (
            battle.act01_mechanics == null
            or not battle.act01_mechanics.boss_ch005_is_complete
            or int(battle.act01_mechanics.beast_star_locks_remaining) != 0
            or battle.chain_hp > 0 or str(battle.last_boss_settlement) != "nonlethal"):
        _hold_battle_settlement(won,xp,money,"星锁尚未解除，禁止以普通击杀结算第五章。")
        return
    if won and is_boss and chapter_at_fight == 6 and (
            battle.resonance < 4 or battle.lighthouse_witnesses_heard.size() != 4
            or str(battle.last_boss_settlement) != "testimony"):
        _hold_battle_settlement(won,xp,money,"仍需四份归航见证，禁止跳过灯塔剧情结算。")
        return
    _capture_world_position()
    var settlement: Dictionary
    if won:
        settlement = BattleV3Settlement.settle_victory(
            progress,game_core,transaction_id,chapter_at_fight,is_boss,
            defeated_group,defeated_monster,xp,money,5 if five_xp else 1,
            str(battle.last_boss_settlement) if is_boss else "")
    else:
        settlement = BattleV3Settlement.settle_defeat(
            progress,battle_defeat_id,chapter_at_fight,is_boss)
    if not bool(settlement.get("ok",false)):
        _hold_battle_settlement(won,xp,money,
            "结算保存失败（%s），奖励及进度已回滚，可重试。" % str(settlement.get("reason","unknown")))
        return

    # A squad victory is confirmed only after the ordinary combat transaction
    # has actually been written to V3. Different squads need different fights.
    if not active_evacuation_battle_squad.is_empty():
        if won and not is_boss and endgame_bridge.evacuation.failed:
            # The battle rewards are real, but the west-gate deadline was
            # missed. Do not trap the completed battle in a retry loop or
            # claim that the rescue objective was achieved.
            ui.show_message("守军已击退，但西门撤离超时；本次救援不计完成。请重新部署。")
        elif won and not is_boss:
            var squad_result: Dictionary = endgame_bridge.confirm_real_encounter(
                active_evacuation_battle_squad,chapter_at_fight,transaction_id)
            if not bool(squad_result.get("success",false)):
                _hold_battle_settlement(won,xp,money,
                    "实际战斗已经保存，但对应撤离小队无法确认：" +
                    str(squad_result.get("reason","unknown")))
                return
            var before_squad_save: Dictionary = progress._pack().duplicate(true)
            var pending_ids: Dictionary = progress.rpg.get("evacuation_battle_pending_v1",{}).duplicate(true)
            if str(pending_ids.get(active_evacuation_battle_squad,"")) != transaction_id:
                progress.restore_snapshot(before_squad_save)
                if not endgame_bridge.bind_progress(progress):
                    push_error("救援回执来源冲突，终局状态无法恢复")
                _hold_battle_settlement(won,xp,money,
                    "战斗回执与V3预存ID不一致，禁止确认救援。")
                return
            pending_ids.erase(active_evacuation_battle_squad)
            progress.rpg["evacuation_battle_pending_v1"] = pending_ids
            progress.rpg["endgame_expansion"] = endgame_bridge.export_state()
            if not progress.save():
                progress.restore_snapshot(before_squad_save)
                if not endgame_bridge.bind_progress(progress):
                    push_error("撤离战斗回执写入失败后状态恢复失败")
                _hold_battle_settlement(won,xp,money,
                    "战斗胜利已经结算，但撤离回执保存失败；请重试确认。")
                return
            ui.show_message(str(squad_result.get("message","小队守军已清除。")))
        active_evacuation_battle_squad = ""

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
    battle_defeat_id = ""
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
    if endgame_bridge != null:
        var update: Dictionary = endgame_bridge.after_scene_committed(progress)
        if bool(update.get("changed",false)) and not _save_progress():
            push_warning("正典剧情已写入V3，但终局扩展快照保存失败，可根据正典旗标恢复。")
    # Repaint only after authoritative scene effects are durable.
    world.refresh_world_legacy(progress.flags)
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
    if progress.chapter in [47,54] and endgame_bridge != null:
        var chapter_gate: String = endgame_bridge.chapter_gate_message()
        if not chapter_gate.is_empty():
            push_warning(chapter_gate)
            return false
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
            game_core.register_actor("char_seeker")
        if last in [2,4] and world.interior_building == ("shelter" if last==2 else "tavern"):
            # Chapter 3 and 5 start outdoors. Clear the prior canonical room
            # and capture its REAL exterior doorstep in the SAME V3 chapter
            # settlement; failed storage does not strand the new chapter indoors.
            var safe_outside: Dictionary = progress.rpg.get("world",{}).duplicate(true)
            safe_outside.erase("indoor_building")
            safe_outside.erase("outdoor_return")
            safe_outside["player_checkpoint"] = {
                "map_id":world_router.current_map(),"chapter":last+1,
                "indoor_building":"",
                "xy":[world.exterior_position.x,world.exterior_position.y]
            }
            progress.rpg["world"] = safe_outside
        if last == 6:
            # Re-lighting is a single post-boss chapter receipt, not a lamp
            # that can activate merely by clicking its mesh or collecting
            # invisible 'items'.
            if not bool(progress.flags.get("ch006.battle_won",false)):
                return {"ok":false,"reason":"lighthouse_keeper_unresolved"}
            progress.flags["world.seven_lanterns.first"] = true
            progress.flags["ch006.lighthouse_testimony"] = true
        if last == 39:
            # Canonical item provenance is recorded only after this actual
            # investigation and chapter resolution. No inventory item is forged.
            if not bool(progress.flags.get("ch039.evidence",false)):
                return {"ok":false,"reason":"ch039_ticket_investigation_missing"}
            var ledger: Dictionary = progress.rpg.get("canonical_item_provenance_v1",{}).duplicate(true)
            var ticket_key: String = "ch039.noe_mothers_ticket"
            var provenance: Dictionary = {
                "id":ticket_key,"acquired":true,"mother_name_inscribed":true,
                "source_scene":"ch039.investigate","source_chapter":"ch039",
                "custodian":"cast_nuo_yi"
            }
            if ledger.has(ticket_key) and ledger[ticket_key] != provenance:
                return {"ok":false,"reason":"ch039_ticket_provenance_collision"}
            ledger[ticket_key] = provenance
            progress.rpg["canonical_item_provenance_v1"] = ledger
        if last == 72:
            return {"ok":true,"newcomer":""}
        var unlocked_last: String = game_core.recruit_from_story(last)
        progress.chapter += 1
        progress.scene_index = 0
        progress.task_index = 0
        progress.dialogue_seen = false
        var newcomer: String = game_core.recruit_from_story(progress.chapter)
        if not unlocked_last.is_empty():
            newcomer = unlocked_last if newcomer.is_empty() else unlocked_last + "\n" + newcomer
        progress.heal_all()
        return {"ok":true,"newcomer":newcomer}
    )
    if not bool(result.get("ok",false)):
        return false
    if last in [2,4] and world.interior_building == ("shelter" if last==2 else "tavern"):
        # The durable V3 transaction already contains the next chapter's
        # exterior position; release the prior interior before later saves.
        world.leave_building()
    var after_chapter: Dictionary = endgame_bridge.after_scene_committed(progress)
    if bool(after_chapter.get("changed",false)) and not _save_progress():
        push_warning("章节已保存，但终局扩展记录尚未写入；可依据正典完成旗标恢复。")
    # Never send UI events or rebuild the world until the new chapter
    # checkpoint (including party recruit / healing) is durable.
    if last == 72:
        _begin_ending_choice()
        return true
    game_events.record("chapter_completed",{"chapter":last})
    if last == 6:
        # Called only after V3ProgressTransition.commit succeeded.
        world.set_lighthouse_rekindled(true)
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
    _capture_world_position()
    var choice_tx: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
        progress.flags["world.ending"] = id
        progress.rpg["ending_id"] = id
        progress.rpg["ending_scene_index"] = 0
        progress.rpg["ending_complete"] = false
        var quests: Dictionary = progress.rpg.get("quests",{})
        quests["quest_main_072"] = true
        progress.rpg["quests"] = quests
        return {"ok":true}
    )
    if not bool(choice_tx.get("ok",false)):
        ui.show_message("结局选择未能保存，进度已回滚；请重新选择。")
        _begin_ending_choice()
        return
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
    _capture_world_position()
    var epilogue_tx: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
        progress.rpg["ending_scene_index"] = int(progress.rpg.get("ending_scene_index",0)) + 1
        return {"ok":true}
    )
    if not bool(epilogue_tx.get("ok",false)):
        ui.show_message("后日谈未保存，已恢复上一段；请检查存储空间并重试。")
        _play_ending_scene()
        return
    _play_ending_scene()

func _finalize_ending() -> void:
    var id: String = str(progress.rpg.get("ending_id",""))
    if ending_director.details(id).is_empty():
        push_error("不能保存无效结局：" + id)
        return
    _capture_world_position()
    var finish_tx: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
        progress.flags["story.ch072.done"] = true
        progress.flags["story.complete"] = true
        progress.rpg["ending_complete"] = true
        var archive: Dictionary = progress.rpg.get("ending_archive",{})
        archive[id] = true
        progress.rpg["ending_archive"] = archive
        progress.scene_index = 5
        progress.task_index = 0
        return {"ok":true}
    )
    if not bool(finish_tx.get("ok",false)):
        pending = ""
        paused_for_dialogue = false
        _return_to_world()
        ui.show_message("结局档案保存失败，尚未标记通关；请检查存储空间后继续。")
        return
    pending = ""
    paused_for_dialogue = false
    game_events.record("chapter_completed",{"chapter":72,"ending":id})
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
    if progress.chapter == 47 and rescue_world_director != null and rescue_world_director.escort_in_progress():
        ui.show_message("护送正在进行！先把伤员或儿童带到当前城门，再前往其他地区。")
        return
    if not world.interior_building.is_empty():
        ui.show_message("请先从建筑出口返回街道，再前往其他区域。")
        return
    var previous_map: String = world_router.current_map()
    _capture_world_position()
    var travel_before: Dictionary = progress._pack().duplicate(true)
    if not world_router.travel(map_id):
        ui.show_message("航路尚未解锁，请先沿主线探索相邻地区。")
        return
    var current_world: Dictionary = progress.rpg.get("world",{})
    current_world.erase("indoor_building")
    current_world.erase("outdoor_return")
    game_events.advance_time(45)
    adventure_menu.close_menu()
    _enter_location()
    world.spawn_from_exit(previous_map)
    if not _save_progress():
        progress.restore_snapshot(travel_before)
        _enter_location()
        ui.show_message("区域旅行存档失败，地图、时间和位置均已恢复。")
        return
    game_events.record("travel",{"map_id":map_id})
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
    if action == "home":
        service_menu.close_service()
        _open_house()
        return
    # Preserve the current physical return point before taking the V3 snapshot.
    # Every economic/state/event mutation is written or rolled back as one unit.
    _capture_world_position()
    var region_id: String = str(world.map_profile.get("region_id","region_coast"))
    var settled: Dictionary = RegionalServiceSettlement.execute(
        progress,game_core,world.town_life,game_events,action,region_id)
    var message: String = ""
    if not bool(settled.get("ok",false)):
        message = "服务记录未能保存，金币、物品、恢复状态及公会奖励已回滚。请检查存储空间后重试。"
    else:
        var outcome: Dictionary = settled.get("outcome",{})
        message = str(outcome.get("message","服务已处理。"))
        if bool(settled.get("changed",false)) and action in ["rest","blessing"]:
            # Presentation must reflect only successfully persisted game time.
            world.sync_world_clock(int(progress.rpg.get("game_clock",{}).get("day",1)),
                int(progress.rpg.get("game_clock",{}).get("minutes",480)))
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
    var before: Dictionary = progress._pack().duplicate(true)
    _capture_world_position()
    if endgame_bridge != null and endgame_bridge.registry_loaded:
        progress.rpg["endgame_expansion"] = endgame_bridge.export_state()
    var success: bool = bool(native_save_manager.save_to_slot(slot,progress,save_slots).get("ok",false))
    if not success:
        progress.restore_snapshot(before)
        endgame_bridge.bind_progress(progress)
    adventure_menu.render("存档管理")
    adventure_menu.footer.text = "槽位 %d %s" % [slot,"已保存" if success else "保存失败"]

func _load_slot(slot: int) -> void:
    # A manual-slot load changes the running party AND becomes the new
    # autosave. Do not destroy the running session if that V3 write fails.
    var before: Dictionary = progress._pack().duplicate(true)
    if not bool(native_save_manager.load_from_slot(slot,progress,save_slots).get("ok",false)):
        adventure_menu.footer.text = "槽位文件损坏或读取失败。"
        return
    if not endgame_bridge.bind_progress(progress):
        progress.restore_snapshot(before)
        endgame_bridge.bind_progress(progress)
        adventure_menu.footer.text = "终局扩展状态不完整，槽位未覆盖现有进度。"
        return
    if not progress.save():
        progress.restore_snapshot(before)
        endgame_bridge.bind_progress(progress)
        adventure_menu.footer.text = "槽位可读取，但主进度保存失败；已恢复载入前状态。"
        return
    game_core.bind(progress)
    world_router.bind(progress)
    game_events.bind(progress)
    housing.bind(progress)
    optional_director.bind(progress)
    branch_runtime.bind(progress)
    _restore_canon_evidence_journal()
    world.set_visual_quality(int(progress.rpg.get("settings",{}).get("visual_quality",1)))
    adventure_menu.close_menu()
    cinematic.cancel_all()
    cinematic_camera.restore()
    cinematic_resume=""
    _enter_location()
    _restore_cheat_settings()
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
    # A saved checkpoint may have become a collision-free yet disconnected
    # pocket after map revisions. Validate the walkable component too.
    var cell: Vector2i=Vector2i(floori(p.x/WorldScript.TILE),floori(p.y/WorldScript.TILE))
    if world._blocked(p) or not world._walkable_tiles().has(cell):
        var recovery: Vector2=world._safe_return_outside(p)
        var recovered_cell: Vector2i=Vector2i(floori(recovery.x/WorldScript.TILE),floori(recovery.y/WorldScript.TILE))
        if world._walkable_tiles().has(recovered_cell) and not world._blocked(recovery):
            world.hero.position=recovery
        return
    world.hero.position = p

func _save_progress() -> bool:
    _capture_world_position()
    if endgame_bridge != null and endgame_bridge.registry_loaded:
        progress.rpg["endgame_expansion"] = endgame_bridge.export_state()
    var success: bool = progress.save()
    if not success:
        push_warning("游戏主体存档写入失败")
    return success

func _save() -> void:
    var success: bool = _save_progress()
    ui.show_message("旅途进度已保存。" if success else "保存失败，请检查设备剩余空间及存储权限。")

func _record_epistemic_deduction(rule_id: String) -> void:
    if progress == null:
        return
    var evaluated: Dictionary = DeductionGraph.evaluate(rule_id,progress.rpg,progress.flags)
    if not bool(evaluated.get("ok",false)):
        adventure_menu.footer.text = "不能直接生成结论：缺少实地记录 " +             "、".join(evaluated.get("missing",[]))
        return
    _capture_world_position()
    var tx: Dictionary = V3ProgressTransition.commit(progress,func() -> Dictionary:
        var archive: Dictionary = progress.rpg.get("deductive_reasoning_v1",{}).duplicate(true)
        if archive.has(rule_id):
            return {"ok":true,"changed":false}
        archive[rule_id] = {
            "outcome":str(evaluated["outcome"]),
            "inputs":(evaluated["inputs"] as Array).duplicate(),
            "chapter_recorded":progress.chapter,
            "archive_mode":str(evaluated.get("archive_mode","cross_verified"))
        }
        progress.rpg["deductive_reasoning_v1"] = archive
        return {"ok":true,"changed":true}
    )
    if not bool(tx.get("ok",false)):
        adventure_menu.footer.text = "推理记录保存失败，卷宗状态未改变。"
        return
    adventure_menu.render("认知推理")
    adventure_menu.footer.text = "证据交叉检定已按V3卷宗保存，不产生奖励或跳过剧情。"

func _read_canonical_lore(doc_id: String) -> void:
    if endgame_bridge == null or not endgame_bridge.registry_loaded or progress == null:
        adventure_menu.footer.text = "文献服务尚未准备好。"
        return
    var reader = endgame_bridge.quests
    var record: Dictionary = reader.get_lore(doc_id)
    if record.is_empty():
        adventure_menu.footer.text = "文献不存在；没有改动存档。"
        return
    if bool(reader.unlocked_lore_documents.get(doc_id,false)):
        adventure_menu.show_lore_document(doc_id)
        return
    var before: Dictionary = progress._pack().duplicate(true)
    if not reader.unlock_lore(doc_id,progress.flags):
        adventure_menu.footer.text = "尚未满足文献阅读条件，请先完成对应剧情调查。"
        return
    _capture_world_position()
    progress.rpg["endgame_expansion"] = endgame_bridge.export_state()
    if not progress.save():
        progress.restore_snapshot(before)
        if not endgame_bridge.bind_progress(progress):
            push_error("文献入档失败后终局桥接状态无法恢复")
        adventure_menu.footer.text = "文献阅读记录未能保存，已回滚；请重新打开。"
        return
    adventure_menu.show_lore_document(doc_id)

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

func _open_local_map_from_book() -> void:
    if is_instance_valid(battle):
        return
    adventure_menu.close_menu()
    _return_to_world()
    atlas.show_exploration(true)
    atlas.open_map()

func _update_realm_optics() -> void:
    if realm_optics == null or progress == null or world == null:
        return
    var settings: Dictionary = progress.rpg.get("settings",{})
    var clock: Dictionary = progress.rpg.get("game_clock",{})
    var weather: String = str(world.ambience.weather) if world.ambience != null else "clear"
    realm_optics.update_realm(world.world_epoch,progress.flags,progress.rpg,
        int(settings.get("visual_quality",1)),weather,int(clock.get("minutes",480)))

func _change_visual_quality(level: int) -> void:
    world.set_visual_quality(level)
    _update_realm_optics()

func _open_map_from_quick_menu() -> void:
    if is_instance_valid(battle):
        return
    ui.close_menu()
    atlas.open_map()

func _return_to_world() -> void:
    busy = paused_for_dialogue or (cinematic != null and cinematic.is_playing()) or is_instance_valid(battle) or ui.menu_layer.visible or adventure_menu.root.visible or housing_room.root.visible or service_menu.is_open() or cheat.shade.visible or atlas.is_open()
    # World presentation uses the canonically filtered active roster. The
    # saved rpg.party may include reserve members, protected child Noe, or
    # historical adults; comparing to it rebuilds the map on every return.
    if not busy and world.party_ids != _runtime_world_party_ids():
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
    _capture_world_position()
    var herb_tx: Dictionary = WorldObjectSettlement.transact(progress,func() -> Dictionary:
        if not game_core.take_item("item_herb_01",1):
            return {"ok":false,"reason":"missing_herb"}
        if not progress.heal_member(who,65):
            return {"ok":false,"reason":"no_healing_needed"}
        return {"ok":true,"changed":true}
    )
    if not bool(herb_tx.get("ok",false)):
        ui.show_message("药草使用记录未保存，治疗和消耗已回滚。")
    ui.show_menu(progress.actors, progress.gold, progress.potions)
    _focus()

func _rest() -> void:
    if progress.gold < 30:
        ui.show_message("需要30 G才能休息。")
        return
    _capture_world_position()
    var inn_tx: Dictionary = WorldObjectSettlement.transact(progress,func() -> Dictionary:
        if progress.gold < 30:
            return {"ok":false,"reason":"insufficient_gold"}
        progress.gold -= 30
        game_events.advance_time(480)
        progress.heal_all()
        return {"ok":true,"changed":true}
    )
    if not bool(inn_tx.get("ok",false)):
        ui.show_message("旅馆结算未保存，金币、时间和HP/MP均已回滚。")
        return
    world.sync_world_clock(int(progress.rpg.get("game_clock",{}).get("day",1)),
        int(progress.rpg.get("game_clock",{}).get("minutes",480)))
    ui.show_message("全队休息完毕，HP/MP完全恢复。")
    _focus()

func _on_cheat_opened() -> void:
    if is_instance_valid(battle):
        return
    busy = true
    world.locked = true

func _restore_cheat_settings() -> void:
    if progress == null:
        return
    var stored: Variant = progress.rpg.get("cheat_settings_v1",{})
    if not (stored is Dictionary):
        return
    invincible = bool(stored.get("invincible",false))
    no_encounters = bool(stored.get("no_encounters",false))
    five_xp = bool(stored.get("five_xp",false))
    if world != null:
        world.walk_speed = 240.0 if bool(stored.get("speed_boost",false)) else 141.0

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
    # The original star-panel commands remain owner-controlled and may
    # persist across autosave/manual-slot reload. No SHA gate can reject
    # these legitimate player-side mutations.
    progress.rpg["cheat_settings_v1"] = {
        "invincible":invincible,"no_encounters":no_encounters,
        "five_xp":five_xp,"speed_boost":world.walk_speed>141.0
    }
    _save_progress()
    _focus()
    cheat.report(message)

func _endgame_evacuation_expired(_reason: String) -> void:
    # A missed rescue never produces a victory flag or a reward receipt.
    if endgame_bridge == null or progress == null or progress.chapter != 47:
        return
    _save_progress()
    _focus()
    ui.show_message("西门机械臂未及时修复，防线告急。请返回指挥台重新部署，不会获得胜利奖励。")

func _install_endgame_markers() -> void:
    if endgame_bridge == null or not endgame_bridge.registry_loaded or not world.interior_building.is_empty():
        return
    var positions := {
        "evac:command":Vector2i(25,25),
        "evac:east:triage":Vector2i(12,12),"evac:east:escort":Vector2i(16,15),
        "evac:east:secure":Vector2i(21,12),
        "evac:south:children":Vector2i(27,34),"evac:south:route":Vector2i(33,34),
        "evac:south:secure":Vector2i(39,34),
        "evac:west:repair":Vector2i(42,12),"evac:west:manual":Vector2i(46,15),
        "evac:west:secure":Vector2i(51,12),
        "endgame:handover":Vector2i(25,26),
        "endgame:memorial":Vector2i(34,26),
        "deduction:ch008_requisition_ledger":Vector2i(33,22)
    }
    var labels := {
        "evac:command":"撤离指挥台",
        "evac:east:triage":"东门 · 分诊","evac:east:escort":"东门 · 护送",
        "evac:east:secure":"东门 · 守卫战",
        "evac:south:children":"南门 · 清点儿童","evac:south:route":"南门 · 通路",
        "evac:south:secure":"南门 · 守卫战",
        "evac:west:repair":"西门 · 抢修","evac:west:manual":"西门 · 手动停机柄",
        "evac:west:secure":"西门 · 守卫战",
        "endgame:handover":"诺依 · 交接会议",
        "endgame:memorial":"诺依 · 原始车票纪念册",
        "deduction:ch008_requisition_ledger":"第8章 · 强征调拨账册"
    }
    var walkable: Dictionary = world._walkable_tiles()
    var reserved: Array[Vector2] = []
    var interactive_ids: Array[String] = []
    for available_id in endgame_bridge.eligible_interactions():
        interactive_ids.append(str(available_id))
    if progress.chapter == 8:
        interactive_ids.append("deduction:ch008_requisition_ledger")
    for id in interactive_ids:
        var wanted: Vector2i = positions.get(id,Vector2i(20,20))
        var found: bool = false
        var chosen: Vector2i = wanted
        for radius in range(0,22):
            if found:
                break
            for dx in range(-radius,radius+1):
                if found:
                    break
                for dy in range(-radius,radius+1):
                    if absi(dx)+absi(dy)!=radius:
                        continue
                    var cell: Vector2i = wanted+Vector2i(dx,dy)
                    if not walkable.has(cell):
                        continue
                    var spot: Vector2 = Vector2(cell*WorldScript.TILE)+Vector2(16,16)
                    if world._blocked(spot):
                        continue
                    var conflict: bool = false
                    for placed in reserved:
                        if placed.distance_to(spot)<100.0:
                            conflict = true
                            break
                    for important in ["key_npc","clue","witness","crisis","resolve","inn","shop"]:
                        if world.nodes.has(important) and is_instance_valid(world.nodes[important]) and world.nodes[important].position.distance_to(spot)<84.0:
                            conflict = true
                            break
                    if not conflict:
                        chosen = cell
                        found = true
                        break
        if not found:
            push_warning("终局交互点无安全可达坐标：" + str(id))
            continue
        var marker := Sprite2D.new()
        marker.name = str(id).replace(":","_")
        marker.texture = world.focus_light.texture if is_instance_valid(world.focus_light) else null
        marker.modulate = Color(0.40,0.86,0.95,0.92)
        marker.scale = Vector2(0.85,0.85)
        marker.z_index = 8
        marker.position = Vector2(chosen*WorldScript.TILE)+Vector2(16,16)
        world.scenery.add_child(marker)
        world.nodes[id] = marker
        reserved.append(marker.position)
        var sign := Label.new()
        var marker_label: String = str(labels.get(id,id))
        if str(id).begins_with("lore:"):
            var document: Dictionary = endgame_bridge.quests.get_lore(str(id).trim_prefix("lore:"))
            marker_label = "文献 · " + str(document.get("title","地区文献"))
            marker.modulate = Color(0.92,0.74,0.45,0.9)
        sign.text = marker_label
        sign.add_theme_font_size_override("font_size",14)
        sign.add_theme_color_override("font_color",Color(1.0,0.94,0.73))
        sign.position = Vector2(-55,-65)
        sign.z_index = 3
        marker.add_child(sign)
func _request_endgame_squad(squad_id: String) -> void:
    if busy or progress == null or progress.chapter != 47 or endgame_bridge == null:
        return
    if not bool(progress.flags.get("ch047.decision_made",false)):
        ui.show_message("请先完成第47章现场撤离抉择。")
        return
    if not endgame_bridge.evacuation.running:
        return
    var before: Dictionary = progress._pack().duplicate(true)
    var previous: String = endgame_bridge.evacuation.active_controlled_squad
    if previous == squad_id:
        return
    var info: String = endgame_bridge.evacuation.switch_controlled_squad(squad_id)
    if endgame_bridge.evacuation.active_controlled_squad != squad_id:
        ui.show_message(info)
        return
    if not _save_progress():
        progress.restore_snapshot(before)
        endgame_bridge.bind_progress(progress)
        _focus()
        ui.show_message("切换小队的存档失败，已回滚。")
        return
    # Rebuild world presentation with this squad's actual visible fighters;
    # collision, player position and remaining time stay in the V3 snapshot.
    if world.party_ids != _runtime_world_party_ids():
        _enter_location()
    _focus()
    ui.show_message(info)
