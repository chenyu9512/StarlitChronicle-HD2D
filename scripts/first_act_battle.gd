extends CanvasLayer
const ArtAssets = preload("res://scripts/art_assets.gd")
const CVisual = preload("res://scripts/c_visual_design.gd")
const CArtOverrides = preload("res://scripts/c_art_overrides.gd")
const EncounterRegistry = preload("res://scripts/encounter_registry.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")
const Act01Mechanics = preload("res://scripts/mechanics/Act01Mechanics.gd")
const BattleBossMechanics = preload("res://scripts/battle_boss_mechanics.gd")
const BattleFormation = preload("res://scripts/battle_formation.gd")
const BattleWorldHandoff = preload("res://scripts/battle_world_handoff.gd")
const BattleRewardTransaction = preload("res://scripts/battle_reward_transaction.gd")
const RescueEncounterProfiles = preload("res://scripts/systems/RescueEncounterProfiles.gd")
const TacticalEngineScript = preload("res://scripts/combat/TacticalCombatEngine.gd")
const BattleFX = preload("res://scripts/battle_fx.gd")
const BattleActors = preload("res://scripts/battle_actors.gd")
const BattleSFX = preload("res://scripts/battle_sfx.gd")
const BattleEnemies = preload("res://scripts/battle_enemies.gd")
const BattleTimeline = preload("res://scripts/battle_timeline.gd")
const BattleCamera = preload("res://scripts/battle_camera.gd")
const BattleHud = preload("res://scripts/battle_hud.gd")
const BossAwakening = preload("res://scripts/battle_boss_awakening.gd")
const C23FogTideBodyMotion = preload("res://scripts/c_b03_fog_tide_body_motion.gd")
const C23OtherBossMotion = preload("res://scripts/c_b03_other_boss_motion.gd")
const GeneratedBossMotion = preload("res://scripts/battle_generated_boss_motion.gd")
const LibrariumBossIdle = preload("res://scripts/c_art_librarium_boss_idle.gd")
## 第一幕正式战斗循环：队伍指令、怪物数值、Boss二阶段与特殊胜利条件。
signal completed(victory: bool, xp: int, gold: int)
const BOSS_NAMES: Dictionary = {2: "雾潮寄生体", 3: "潮痕守卫", 4: "灰帷水手", 5: "缚潮古兽", 6: "潮歌守门人"}
const BOSS_ART: Dictionary = {2:"tide_ghost",3:"tide_guardian",4:"salt_wolf",5:"star_ray",6:"tide_guardian"}
const MONSTER_ART: Array[String] = ["salt_slime", "fog_crab", "shell_hermit", "tide_ghost", "sand_lizard", "salt_wolf", "white_seabird", "star_ray", "tide_guardian"]
var game_state
var game_core
var encounter_registry
var combat_rules
var act01_mechanics
var boss_mechanics
var last_boss_settlement: String = ""
var world_handoff
var last_world_handoff_result: Dictionary = {}
## Immutable for one combat instance; D-line uses it to deduplicate the complete reward/save transaction.
var reward_transaction_id: String = ""
var formation
var active_target: int = 0
var skill_picker: PanelContainer
var encounter_data: Dictionary = {}
var forced_party_ids: Array[String] = []  # Rescue-only, never persisted in rpg.party.
var rescue_encounter_hint: String = ""
var tactical_engine
var chapter: int = 1
var boss: bool = false
var round_boss_intent: Dictionary = {}
var enemy: Dictionary = {}
var hero_turn: int = 0
var party_order: Array[int] = []
var turn_queue: Array[Dictionary] = []
var turn_cursor: int = 0
var last_enemy_action: String = ""
# Battle-local telemetry: cannot award XP, alter V3 saves or affect AI.
var enemy_strike_count: int = 0
var enemy_damage_dealt: int = 0
var enemy_guarded_strikes: int = 0
var current_round: int = 1
var phase_two: bool = false
var chain_hp: int = 0
var resonance: int = 0
var lighthouse_witnesses_heard: Array[String] = []
var lighthouse_testimony_rows: Array = []
var lighthouse_wicks_verified: bool = false
var countdown: int = 8
var defense: Dictionary = {}
var win_locked: bool = false
var invincible: bool = false
var dice: RandomNumberGenerator = RandomNumberGenerator.new()
var root: Control
var party_info: RichTextLabel
var foe_info: Label
var report: Label
var commands: GridContainer
var portrait: TextureRect
var enemy_grounding: TextureRect
var actor_stage
var enemy_stage
var vfx
var sfx
var timeline
var camera_motion
var battle_hud
var boss_animation
var c23_boss_body_motion
var generated_boss_motion
var librarium_boss_idle
var last_warning_text: String = ""
var last_warning_round: int = 0
var special_button: Button

func _ready() -> void:
    layer = 40
    dice.randomize()

## Optional D-line integration: call before start() while the world is still visible.
func prepare_world_handoff(world_node: Node, context: Dictionary, is_boss: bool) -> Dictionary:
    if world_handoff != null and world_handoff.active:
        return {"ok":false,"reason":"handoff_already_active"}
    var fresh = BattleWorldHandoff.new()
    var result: Dictionary = fresh.begin(world_node,"boss" if is_boss else "random",context)
    if bool(result.get("ok",false)):
        world_handoff = fresh
    return result

## Optional D-line integration: restore after completed, before UI input unlock.
func handoff_to_world(world_node: Node) -> Dictionary:
    if world_handoff == null:
        return {"ok":false,"reason":"handoff_not_configured"}
    return world_handoff.restore(world_node)

## Existing FirstAct hosts have no D-line wiring yet. Snapshot transparently,
## while preserving explicit prepare_world_handoff() for a future strict guard.
func _auto_prepare_world_handoff() -> void:
    if world_handoff != null and world_handoff.active:
        return
    var controller: Node = get_parent()
    if controller == null:
        return
    if not controller.has_method("_battle_finished"):
        return
    var current_world: Node = controller.get("world") as Node
    if not is_instance_valid(current_world):
        return

    # Build context one property at a time. No nested conditional expression
    # is needed inside a multiline Dictionary literal.
    var profile: Dictionary = current_world.get("map_profile")
    var actor: Node2D = current_world.get("hero") as Node2D
    var trigger_id: String = str(encounter_data.get("enemy_id", ""))
    if trigger_id.is_empty() and boss:
        trigger_id = "boss.ch%03d/crisis" % chapter

    var context: Dictionary = {}
    context["chapter"] = chapter
    context["trigger_id"] = trigger_id
    context["player_valid"] = is_instance_valid(actor)
    context["settlement"] = bool(profile.get("settlement", false))
    context["interior_building"] = str(current_world.get("interior_building"))
    context["no_encounters"] = bool(controller.get("no_encounters"))
    context["clock"] = game_state.rpg.get("game_clock", {})
    context["audio_cue"] = str(profile.get("id", ""))
    context["width_tiles"] = maxi(8, int(current_world.get("WIDTH")))
    context["height_tiles"] = maxi(8, int(current_world.get("HEIGHT")))

    var environment: Object = current_world.get("ambience") as Object
    context["weather"] = ""
    if is_instance_valid(environment):
        context["weather"] = str(environment.get("weather"))

    # FirstAct locks the world before creating Battle; this lock alone
    # must not count as an active dialogue or an interrupted transition.
    var prepared: Dictionary = prepare_world_handoff(current_world, context, boss)
    if not bool(prepared.get("ok", false)):
        push_warning("A-line battle/world snapshot unavailable: " + str(prepared.get("reason", "unknown")))

func _actor_eligible(actor_id: String) -> bool:
    if not forced_party_ids.is_empty():
        return actor_id in forced_party_ids
    return game_core != null and game_core.is_active(actor_id)

func start(save_state, chapter_no: int, is_boss: bool) -> void:
    game_state = save_state
    if combat_rules == null:
        combat_rules = CombatRules.new()
    combat_rules.start(game_state.rpg.get("settings",{}))
    if encounter_registry == null:
        encounter_registry = EncounterRegistry.new()
    chapter = chapter_no
    boss = is_boss
    hero_turn = 0
    current_round = 1
    phase_two = false
    resonance = 0
    lighthouse_witnesses_heard.clear()
    lighthouse_testimony_rows.clear()
    lighthouse_wicks_verified = false
    if boss and chapter == 6:
        var verified: Dictionary = encounter_data.get("lighthouse_fragments",{})
        lighthouse_wicks_verified = (
            bool(verified.get("breakwater_wick",false)) and
            bool(verified.get("keeper_wick",false)) and
            bool(verified.get("summit_wick",false)))
        var witness_rows: Variant = encounter_data.get("lighthouse_testimonies",[])
        if witness_rows is Array and witness_rows.size() == 4:
            var distinct: Dictionary = {}
            var valid: bool = true
            for testimony in witness_rows:
                if not (testimony is Dictionary):
                    valid = false
                    break
                var name_id: String = str(testimony.get("id",""))
                if name_id.is_empty() or distinct.has(name_id) or str(testimony.get("line","")).is_empty():
                    valid = false
                    break
                distinct[name_id] = true
            if valid and distinct.size() == 4:
                lighthouse_testimony_rows = witness_rows.duplicate(true)
    countdown = 8
    defense.clear()
    win_locked = false
    last_warning_round = 0
    last_warning_text = ""
    enemy_strike_count = 0
    enemy_damage_dealt = 0
    enemy_guarded_strikes = 0
    last_boss_settlement = ""
    last_world_handoff_result.clear()
    reward_transaction_id = ""
    rescue_encounter_hint = ""
    _auto_prepare_world_handoff()
    act01_mechanics = null
    if boss and chapter in [3,5]:
        act01_mechanics = Act01Mechanics.new()
        add_child(act01_mechanics)
        if chapter == 3:
            var cave_state: Dictionary = encounter_data.get("cave_snapshot",{})
            act01_mechanics.restore_from_cave_snapshot(cave_state)
        elif chapter == 5:
            act01_mechanics.trigger_fisherman_red_flag_warning()
    boss_mechanics = null
    if boss:
        var hp: int = 145 + chapter * 55
        var dmg: int = 12 + chapter * 2
        enemy = {"name":BOSS_NAMES.get(chapter, "遗迹守卫"), "hp":hp, "max_hp":hp, "atk":dmg, "def":4+chapter, "xp":150+chapter*65, "gold":85+chapter*40, "art":BOSS_ART.get(chapter,"tide_guardian")}
        if not encounter_data.is_empty():
            enemy["name"] = str(encounter_data.get("display_name", enemy["name"]))
        enemy = encounter_registry.story_boss(chapter,encounter_data,enemy)
        boss_mechanics = BattleBossMechanics.new()
        boss_mechanics.start(enemy.get("boss_mechanics",{}))
        chain_hp = 125 if chapter == 5 else 0
    else:
        var monster_number: int = dice.randi_range(0, mini(8, chapter + 2))
        var monster_names: Array[String] = ["盐泥团", "雾壳蟹", "寄壳隐士", "潮雾幽灵", "砂蜥", "盐牙狼", "白沙海鸟", "星纹鳐", "潮痕守卫"]
        var hp: int = 25 + chapter * 10 + monster_number * 8
        enemy = {"name":monster_names[monster_number], "hp":hp, "max_hp":hp, "atk":7+chapter*2+monster_number, "def":2+int(monster_number/2), "xp":20+chapter*8+monster_number*3, "gold":12+chapter*4+monster_number*2, "art":MONSTER_ART[monster_number]}
        chain_hp = 0
        enemy = encounter_registry.roll_monster(chapter)
    formation = BattleFormation.new()
    formation.start(encounter_registry,chapter,boss,enemy)
    # Adapt the real encounter's ordinary enemies (HP, speed, number and
    # defense differ by gate). Names are diegetic, but monster IDs, drops,
    # art and real turn resolution remain authoritative.
    if not boss and chapter == 47 and not forced_party_ids.is_empty():
        var squad_id: String = str(encounter_data.get("rescue_squad_id",""))
        var rescue_profile: Dictionary = RescueEncounterProfiles.apply(formation,squad_id)
        if bool(rescue_profile.get("ok",false)):
            enemy = formation.units[0]
            rescue_encounter_hint = str(rescue_profile.get("hint",""))
        else:
            push_error("Three-gate rescue encounter profile unavailable: " +
                str(rescue_profile.get("reason","unknown")))
    var stable_boss_id: String = ""
    if boss:
        stable_boss_id = str(encounter_data.get("enemy_id",""))
        if not formation.units.is_empty():
            stable_boss_id = str(formation.units[0].get("boss_id",stable_boss_id))
        if stable_boss_id.is_empty():
            stable_boss_id = "boss.ch%03d/crisis" % chapter
    # A chapter-47 rescue reserves a real V3 nonce BEFORE combat. Reloading
    # after the combat receipt but before squad checkpoint must reuse it;
    # generating a new random nonce there would pay the same victory twice.
    var reserved_id: String = str(encounter_data.get("rescue_reward_transaction_id",""))
    var valid_rescue: bool = not boss and chapter == 47         and not forced_party_ids.is_empty()         and str(encounter_data.get("rescue_squad_id","")) in [
            "EAST_GATE_LEISO","SOUTH_GATE_SHUOXIAN","WEST_GATE_TIFA"]         and BattleRewardTransaction.valid_id(reserved_id) and reserved_id.begins_with("random:")
    reward_transaction_id = reserved_id if valid_rescue else BattleRewardTransaction.make_id(
        boss,chapter,stable_boss_id)
    if is_instance_valid(tactical_engine):
        tactical_engine.queue_free()
    tactical_engine = TacticalEngineScript.new()
    add_child(tactical_engine)
    tactical_engine.setup_encounter(chapter,boss,formation.units)
    active_target = 0
    enemy = formation.units[0]
    _begin_round()
    _build()
    _start_actor()
    var introduction: String = "%s 出现在你们面前！" % str(enemy["name"])
    if boss and chapter == 5:
        # Authored in-world red flag and safe retreat observations are read
        # from the world handoff. These are hints only, not an extra reward
        # or an alternative to the three earned lock-removal turns.
        var shoal_proof: Dictionary = encounter_data.get("shoal_snapshot",{})
        if bool(shoal_proof.get("red_flag",false)) and bool(shoal_proof.get("star_chain",false)) and bool(shoal_proof.get("retreat_line",false)):
            introduction += " · 红旗警示：避开发亮的过载星纹！朔弦先吹双哨，每次仅能安全拆下一处锁扣，合计三处。"
        else:
            introduction += " · 浅滩三项救援调查未获确认。"
    if not rescue_encounter_hint.is_empty():
        introduction += " · " + rescue_encounter_hint
    if _show_boss_objective():
        introduction += " · 目标：" + boss_mechanics.objective_label() + " · 提示：" + boss_mechanics.hint()
    _redraw(introduction)

func _style(bg: Color, outline: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = outline
    s.set_border_width_all(1)
    s.border_width_top = 2
    s.set_corner_radius_all(9)
    s.set_content_margin_all(12)
    s.shadow_color = Color(0.01,0.02,0.04,0.36)
    s.shadow_size = 4
    return s

func _button(parent: Node, text_label: String, action: String) -> Button:
    var b := Button.new()
    b.text = text_label
    b.custom_minimum_size = Vector2(120, 44)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_font_size_override("font_size", 17)
    CVisual.style_button(b)
    b.focus_mode = Control.FOCUS_ALL
    b.pressed.connect(func() -> void: _act(action))
    parent.add_child(b)
    return b

func _build() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    # A 12-act gradient establishes a coherent realm mood when a curated
    # story backdrop is unavailable. Never reuse a coastal painting as a
    # misleading universal scene or replace official combat art with sprites.
    var accent: Color = CVisual.act_accent(chapter)
    var gradient := Gradient.new()
    gradient.set_color(0,CVisual.INK.lerp(accent,0.09))
    gradient.set_color(1,CVisual.NAVY.lerp(accent,0.22))
    var gradient_tex := GradientTexture2D.new()
    gradient_tex.gradient = gradient
    gradient_tex.width = 512
    gradient_tex.height = 512
    var painted_base := TextureRect.new()
    painted_base.texture = gradient_tex
    painted_base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    painted_base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    painted_base.stretch_mode = TextureRect.STRETCH_SCALE
    painted_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(painted_base)
    var backdrop := TextureRect.new()
    if chapter <= 6:
        var original_path: String = "res://assets/art/backdrops/coast/tide_lighthouse.png" if chapter >= 5 else "res://assets/art/backdrops/coast/white_sand_port.png"
        backdrop.texture = CArtOverrides.texture(original_path)
    backdrop.visible = backdrop.texture != null
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(backdrop)
    var dim := ColorRect.new()
    dim.color = Color(0.015, 0.032, 0.060, 0.54)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(dim)
    # The single-foe and boss compositions use the same footing treatment as
    # the multi-foe stage, without changing targeting or combat decisions.
    enemy_grounding=TextureRect.new()
    enemy_grounding.name="SingleFoeGrounding"
    enemy_grounding.texture=CArtOverrides.texture("res://assets/art/battle/a15/boss_footing.svg" if boss else "res://assets/art/battle/a15/enemy_footing.svg")
    enemy_grounding.anchor_left=0.32
    enemy_grounding.anchor_right=0.68
    enemy_grounding.anchor_top=0.49
    enemy_grounding.anchor_bottom=0.62
    enemy_grounding.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    enemy_grounding.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    enemy_grounding.mouse_filter=Control.MOUSE_FILTER_IGNORE
    root.add_child(enemy_grounding)
    var title_plate := PanelContainer.new()
    title_plate.anchor_left = 0.25
    title_plate.anchor_right = 0.75
    title_plate.anchor_top = 0.03
    title_plate.anchor_bottom = 0.13
    title_plate.add_theme_stylebox_override("panel", CVisual.surface(true,chapter))
    root.add_child(title_plate)
    foe_info = Label.new()
    foe_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    foe_info.add_theme_font_size_override("font_size", 20)
    foe_info.add_theme_color_override("font_color",CVisual.PAPER)
    title_plate.add_child(foe_info)
    portrait = TextureRect.new()
    portrait.texture = CArtOverrides.texture(ArtAssets.battle_image(enemy, boss, chapter))
    portrait.anchor_left = 0.38
    portrait.anchor_right = 0.62
    portrait.anchor_top = 0.15
    portrait.anchor_bottom = 0.58
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    root.add_child(portrait)
    librarium_boss_idle = null
    if boss and LibrariumBossIdle.accepts(str(enemy.get("boss_id",""))):
        librarium_boss_idle = LibrariumBossIdle.new()
        librarium_boss_idle.name = "CanonicalThreeFrameBossIdle"
        root.add_child(librarium_boss_idle)
        librarium_boss_idle.configure(portrait, enemy, bool(game_state.rpg.get("settings",{}).get("reduced_motion",false)))
    c23_boss_body_motion = null
    if boss and chapter >= 2 and chapter <= 6:
        if chapter == 2:
            c23_boss_body_motion = C23FogTideBodyMotion.new()
        else:
            c23_boss_body_motion = C23OtherBossMotion.new()
        c23_boss_body_motion.name = "C23BossBodyMotion_%d" % chapter
        root.add_child(c23_boss_body_motion)
        c23_boss_body_motion.configure(portrait,chapter,bool(game_state.rpg.get("settings",{}).get("reduced_motion",false)))
    generated_boss_motion = null
    if boss and chapter >= 7:
        # Later chapters now use the same physically generated six-state
        # identity sheets as Act I, without replacing any battle mechanics.
        var later_motion = GeneratedBossMotion.new()
        later_motion.name = "CanonicalChapterBossMotion_%d" % chapter
        root.add_child(later_motion)
        if later_motion.configure(portrait, chapter,
                bool(game_state.rpg.get("settings", {}).get("reduced_motion", false))):
            generated_boss_motion = later_motion
        else:
            later_motion.queue_free()
    if boss:
        boss_animation=BossAwakening.new()
        boss_animation.name="BossSixFrameAwakening"
        root.add_child(boss_animation)
        boss_animation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        boss_animation.configure(portrait,chapter,bool(game_state.rpg.get("settings",{}).get("reduced_motion",false)))
    enemy_stage = BattleEnemies.new()
    enemy_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    enemy_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(enemy_stage)
    var multi_foe: bool = formation.units.size() > 1
    enemy_stage.visible = multi_foe
    portrait.visible = not multi_foe
    enemy_grounding.visible=not multi_foe
    var enemy_settings: Dictionary = game_state.rpg.get("settings",{})
    enemy_stage.reduced_motion = bool(enemy_settings.get("reduced_motion",false))
    if multi_foe:
        enemy_stage.configure(formation.units,chapter,boss)
    actor_stage = BattleActors.new()
    actor_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    actor_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(actor_stage)
    var actor_ids: Array = []
    if game_core != null:
        for member in game_state.actors:
            if _actor_eligible(str(member.get("id",""))):
                actor_ids.append(str(member.get("id","")))
    var battle_settings: Dictionary = game_state.rpg.get("settings",{})
    actor_stage.reduced_motion = bool(battle_settings.get("reduced_motion",false))
    actor_stage.configure(game_state.actors,actor_ids)
    var lower := PanelContainer.new()
    lower.anchor_left = 0.05
    lower.anchor_right = 0.95
    lower.anchor_top = 0.61
    lower.anchor_bottom = 0.985
    lower.add_theme_stylebox_override("panel", CVisual.surface(true,chapter))
    root.add_child(lower)
    var flow := VBoxContainer.new()
    flow.add_theme_constant_override("separation", 5)
    lower.add_child(flow)
    report = Label.new()
    report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    report.add_theme_font_size_override("font_size", 19)
    report.add_theme_color_override("font_color", CVisual.act_accent(chapter))
    flow.add_child(report)
    party_info = RichTextLabel.new()
    party_info.bbcode_enabled = true
    party_info.custom_minimum_size = Vector2(0, 43)
    party_info.add_theme_font_size_override("normal_font_size", 17)
    flow.add_child(party_info)
    # Two balanced rows prevent seven commands overflowing landscape phones.
    # The original command IDs and their battle callbacks are unchanged.
    commands = GridContainer.new()
    commands.columns = 4
    commands.add_theme_constant_override("h_separation", 8)
    commands.add_theme_constant_override("v_separation", 7)
    commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    flow.add_child(commands)
    _button(commands, "⚔ 攻击", "attack")
    _button(commands, "✧ 技能", "skill")
    _button(commands, "✥ 战术", "tactical")
    _button(commands, "◇ 防御", "guard")
    _button(commands, "✦ 聚星", "charge")
    _button(commands, "✚ 药草", "potion")
    var special_name: String = "✦ 双哨 / 拆锁" if chapter == 5 and boss else ("✦ 共同见证" if chapter == 6 and boss else ("✦ 破解机制" if boss and boss_mechanics != null and boss_mechanics.enabled() else "✦ 识破弱点"))
    special_button = _button(commands, special_name, "special")
    vfx = BattleFX.new()
    vfx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vfx.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(vfx)
    var settings: Dictionary = game_state.rpg.get("settings", {})
    vfx.reduced_motion = bool(settings.get("reduced_motion",false))
    vfx.bind_enemy(portrait,str(enemy.get("art","")),boss)
    sfx = BattleSFX.new()
    sfx.enabled = bool(settings.get("battle_sfx_enabled",true))
    root.add_child(sfx)
    camera_motion = BattleCamera.new()
    camera_motion.reduced_motion = bool(settings.get("reduced_motion",false))
    root.add_child(camera_motion)
    camera_motion.bind_targets([backdrop,portrait,enemy_stage,actor_stage])
    timeline = BattleTimeline.new()
    timeline.reduced_motion = bool(settings.get("reduced_motion",false))
    root.add_child(timeline)
    timeline.bind_layers(vfx,sfx,camera_motion)
    battle_hud = BattleHud.new()
    battle_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battle_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(battle_hud)
    battle_hud.configure(enemy_stage,actor_stage,boss,chapter,settings)
    battle_hud.sync(formation.units,game_state.actors,active_target,phase_two)

func _choose_skill() -> void:
    if is_instance_valid(skill_picker):
        skill_picker.queue_free()
    var actor: Dictionary = game_state.actors[hero_turn]
    var learned: Array = game_core.skills(str(actor.get("id",""))) if game_core != null else []
    skill_picker = PanelContainer.new()
    skill_picker.anchor_left = 0.16
    skill_picker.anchor_right = 0.84
    skill_picker.anchor_top = 0.20
    skill_picker.anchor_bottom = 0.84
    skill_picker.add_theme_stylebox_override("panel",_style(Color("091b31"),Color("e6c47d")))
    root.add_child(skill_picker)
    var scroll := ScrollContainer.new()
    skill_picker.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)
    var caption := Label.new()
    caption.text = "选择技能 · "+str(actor.get("name",""))
    caption.add_theme_font_size_override("font_size",22)
    list.add_child(caption)
    if learned.is_empty():
        var unavailable := Label.new()
        unavailable.text = "尚未学会职业技能，先提升等级或转职。"
        list.add_child(unavailable)
    for record in learned:
        var id: String = str(record.get("id",""))
        var cost: int = int(record.get("mp_cost",0))
        var element: String = str(record.get("element","光"))
        var tier: int = int(record.get("tier",1))
        var title: String = "✦ %s  · %s  · Ⅰ–Ⅶ %d  · MP %d  | %s" % [
            str(record.get("name",id)),element,tier,cost,str(record.get("description",""))]
        var b: Button = _button(list,title,"skill:"+id)
        b.disabled = int(actor.get("mp",0)) < cost
    _button(list,"返回战斗","cancel_skill")

func _select_enemy(index: int) -> void:
    if formation == null or not formation.valid_target(index):
        return
    active_target = index
    enemy = formation.units[index]
    if is_instance_valid(enemy_stage):
        enemy_stage.focus(index)
    if is_instance_valid(portrait) and portrait.visible:
        # The atlas already represents the active chapter boss. Reassigning
        # a static portrait during focus would silently stop its animation.
        if not is_instance_valid(generated_boss_motion) or not generated_boss_motion.enabled:
            portrait.texture = CArtOverrides.texture(ArtAssets.battle_image(enemy, boss, chapter))
        if is_instance_valid(librarium_boss_idle):
            librarium_boss_idle.configure(portrait, enemy, bool(game_state.rpg.get("settings",{}).get("reduced_motion",false)))
        if is_instance_valid(vfx):
            vfx.bind_enemy(portrait,str(enemy.get("art","")),boss)

func _choose_enemy_target(command: String) -> void:
    _hide_skills()
    skill_picker = PanelContainer.new()
    skill_picker.anchor_left = 0.20
    skill_picker.anchor_right = 0.80
    skill_picker.anchor_top = 0.22
    skill_picker.anchor_bottom = 0.82
    skill_picker.add_theme_stylebox_override("panel",_style(Color("091b31"),Color("e6c47d")))
    root.add_child(skill_picker)
    var layout := VBoxContainer.new()
    skill_picker.add_child(layout)
    var heading := Label.new()
    heading.text = "选择敌方目标"
    layout.add_child(heading)
    for i in formation.alive_indices():
        var record: Dictionary = formation.units[i]
        _button(layout,"%s · HP %d/%d" % [str(record.get("name","敌人")),int(record.get("hp",0)),int(record.get("max_hp",1))],command+"#"+str(i))
    _button(layout,"返回战斗","cancel_skill")

func _get_skill(id: String) -> Dictionary:
    if game_core == null:
        return {}
    var person: Dictionary = game_state.actors[hero_turn]
    for item in game_core.skills(str(person.get("id",""))):
        if str(item.get("id","")) == id:
            return item
    return {}

func _choose_target(skill_id: String) -> void:
    _hide_skills()
    skill_picker = PanelContainer.new()
    skill_picker.anchor_left = 0.19
    skill_picker.anchor_right = 0.81
    skill_picker.anchor_top = 0.26
    skill_picker.anchor_bottom = 0.76
    skill_picker.add_theme_stylebox_override("panel",_style(Color("091b31"),Color("e6c47d")))
    root.add_child(skill_picker)
    var body := VBoxContainer.new()
    skill_picker.add_child(body)
    var title := Label.new()
    title.text = "选择队友目标"
    body.add_child(title)
    for i in range(game_state.actors.size()):
        var index: int = i
        var member: Dictionary = game_state.actors[i]
        if int(member.get("hp",0)) <= 0:
            continue
        if game_core != null and not _actor_eligible(str(member.get("id",""))):
            continue
        _button(body,"%s  HP %d/%d" % [str(member.get("name","")),int(member.get("hp",0)),int(member.get("max_hp",0))],"skill:%s@%d" % [skill_id,index])
    _button(body,"返回技能列表","skill")

func _hide_skills() -> void:
    if is_instance_valid(skill_picker):
        skill_picker.queue_free()
        skill_picker = null

func _begin_round() -> void:
    # Freeze the announced action: crossing half HP during player turns must
    # not silently replace it with a different phase/low-health attack.
    if boss and boss_mechanics != null and boss_mechanics.enabled():
        var environment: Dictionary = boss_mechanics.round_effects(current_round)
        var restoration: int = roundi(float(enemy.get("max_hp",1))*float(environment.get("heal_ratio",0.0)))
        if restoration > 0:
            enemy["hp"] = mini(int(enemy.get("max_hp",1)),int(enemy.get("hp",0))+restoration)
        if not str(environment.get("weakness","")).is_empty():
            enemy["weakness"] = str(environment.get("weakness",""))
        enemy["speed"] = maxi(1,int(enemy.get("base_speed",enemy.get("speed",8)))+int(environment.get("speed_bonus",0)))
        if not enemy.has("base_speed"):
            enemy["base_speed"] = int(enemy.get("speed",8))-int(environment.get("speed_bonus",0))
        formation.units[0] = enemy
    round_boss_intent = (boss_mechanics.intent(current_round) if boss_mechanics != null and boss_mechanics.enabled() else combat_rules.enemy_strategy(enemy,current_round,phase_two,true,game_state.actors)).duplicate(true) if boss else {}
    if boss and chapter == 3 and act01_mechanics != null:
        act01_mechanics.on_boss_ch003_pre_attack_telegraph()
    if boss and chapter == 5 and act01_mechanics != null and current_round > 1 and current_round % 3 == 0:
        # The red flag visibly reopens the hazard; another whistle clears it.
        act01_mechanics.trigger_fisherman_red_flag_warning()
    last_warning_text = ""
    var eligible: Array = []
    if game_core != null:
        for member in game_state.actors:
            var actor_id: String = str(member.get("id",""))
            if _actor_eligible(actor_id):
                eligible.append(actor_id)
    # Apply shared vocation and weapon speed to the turn timeline without
    # changing permanently saved actor base stats.
    var initiative_actors: Array = game_state.actors.duplicate(true)
    if game_core != null:
        for i in range(initiative_actors.size()):
            var id: String = str(initiative_actors[i].get("id",""))
            var derived: Dictionary = game_core.gear_stats(id)
            initiative_actors[i]["speed"] = maxi(1,int(derived.get("speed",initiative_actors[i].get("speed",10))))
    party_order = combat_rules.initiative_order(initiative_actors,eligible)
    turn_queue = combat_rules.turn_timeline(initiative_actors,formation.units,eligible)
    turn_cursor = 0
    hero_turn = party_order[0] if not party_order.is_empty() else game_state.actors.size()

func _start_actor() -> void:
    # Advance through enemy and ally actions in one round without duplicate turns.
    # Enemies whose HP reached zero before their scheduled turn simply lose it.
    var attempts: int = 0
    while not win_locked and attempts < 128:
        attempts += 1
        if _all_fallen():
            _finish(false)
            return
        if turn_cursor >= turn_queue.size():
            combat_rules.tick_round()
            defense.clear()
            current_round += 1
            _begin_round()
            if party_order.is_empty():
                _finish(false)
                return
        var action_entry: Dictionary = turn_queue[turn_cursor]
        var index: int = int(action_entry.get("index",-1))
        if str(action_entry.get("team","")) == "enemy":
            turn_cursor += 1
            if formation.valid_target(index):
                _enemy_action(index)
            continue
        if index < 0 or index >= game_state.actors.size():
            turn_cursor += 1
            continue
        hero_turn = index
        var member: Dictionary = game_state.actors[hero_turn]
        var actor_id: String = str(member.get("id",""))
        if int(member.get("hp",0)) <= 0 or (game_core != null and not _actor_eligible(actor_id)):
            turn_cursor += 1
            continue
        var effect: Dictionary = combat_rules.resolve_actor_turn(actor_id,int(member.get("max_hp",1)))
        var poison_damage: int = int(effect.get("damage",0))
        if poison_damage > 0:
            member["hp"] = maxi(0,int(member.get("hp",0))-poison_damage)
            game_state.actors[hero_turn] = member
            if is_instance_valid(actor_stage):
                actor_stage.play_hit(actor_id,int(member["hp"]) <= 0)
        if int(member.get("hp",0)) <= 0 or bool(effect.get("skip",false)):
            turn_cursor += 1
            continue
        _telegraph_next_boss_action()
        return
    if not win_locked:
        push_warning("Mixed combat timeline exceeded the 128-action safety cap")
        _finish(false)

func _choose_tactical_action() -> void:
    if tactical_engine == null or (boss and chapter in [3,5,6]):
        _redraw("本场正典Boss需要通过原有专属救援和见证机制结算。")
        return
    _hide_skills()
    var actor_id: String = str(game_state.actors[hero_turn].get("id",""))
    var options: Array[Dictionary] = tactical_engine.available_for(actor_id,chapter,game_state.flags)
    if options.is_empty():
        _redraw("当前角色尚未具备相应的安全战术职业权限。")
        return
    skill_picker = PanelContainer.new()
    skill_picker.anchor_left = 0.18
    skill_picker.anchor_right = 0.82
    skill_picker.anchor_top = 0.20
    skill_picker.anchor_bottom = 0.83
    skill_picker.add_theme_stylebox_override("panel",_style(Color("091b31"),Color("e6c47d")))
    root.add_child(skill_picker)
    var list := VBoxContainer.new()
    skill_picker.add_child(list)
    var title := Label.new()
    title.text = "安全战术 · 狂躁/星纹锁 · 当前星灯%d%%" % tactical_engine.lantern_resonance_charge
    list.add_child(title)
    for option in options:
        var id: String = str(option.get("id",""))
        var btn: Button = _button(list,"%s · 共鸣%d" % [
            str(option.get("name",id)),int(option.get("cost",0))],"tactic:"+id)
        btn.disabled = not bool(option.get("enabled",false))
    _button(list,"返回战斗","cancel_skill")

func _tactical_ally_picker(skill_id: String) -> void:
    _hide_skills()
    skill_picker = PanelContainer.new()
    skill_picker.anchor_left = 0.23
    skill_picker.anchor_right = 0.77
    skill_picker.anchor_top = 0.24
    skill_picker.anchor_bottom = 0.76
    root.add_child(skill_picker)
    var list := VBoxContainer.new()
    skill_picker.add_child(list)
    var label := Label.new()
    label.text = "按真实伤情选择救护对象"
    list.add_child(label)
    for i in range(game_state.actors.size()):
        var ally: Dictionary = game_state.actors[i]
        if not _actor_eligible(str(ally.get("id",""))) or int(ally.get("hp",0)) <= 0:
            continue
        _button(list,"%s · HP %d/%d" % [str(ally.get("name","同伴")),
            int(ally.get("hp",0)),int(ally.get("max_hp",0))],
            "tactic:"+skill_id+"@"+str(i))
    _button(list,"返回战术","tactical")

func _tactical_act(token: String) -> void:
    if tactical_engine == null or not formation.valid_target(active_target):
        _redraw("战术状态或目标已失效。")
        return
    var parts: PackedStringArray = token.split("@",false,1)
    var skill_id: String = str(parts[0])
    var ally_index: int = hero_turn
    if skill_id == "HEALER_TRIAGE_RESCUE" and parts.size() == 1:
        _tactical_ally_picker(skill_id)
        return
    if parts.size() == 2:
        if not str(parts[1]).is_valid_int():
            return
        ally_index = int(parts[1])
        if ally_index < 0 or ally_index >= game_state.actors.size() or                 not _actor_eligible(str(game_state.actors[ally_index].get("id",""))):
            _redraw("该成员不在本场真实战斗编成。")
            return
    var actor: Dictionary = game_state.actors[hero_turn]
    var ephemeral: Dictionary = game_state.flags.duplicate()
    if ally_index >= 0 and ally_index < game_state.actors.size():
        ephemeral["battle.airway_critical"] = int(
            game_state.actors[ally_index].get("triage_state",0)) ==             TacticalEngineScript.TriagePriority.AIRWAY_CRITICAL
    var result: Dictionary = tactical_engine.use_skill(str(actor.get("id","")),
        skill_id,active_target,ephemeral)
    if not bool(result.get("ok",false)):
        _redraw("战术操作未生效：" + str(result.get("reason","invalid")))
        return
    _hide_skills()
    var backlash: int = int(result.get("backlash",0))
    if backlash > 0:
        actor["hp"] = maxi(1,int(actor.get("hp",1))-backlash)
        game_state.actors[hero_turn] = actor
    var heal: int = int(result.get("heal_one",0))
    if heal > 0 and ally_index < game_state.actors.size():
        var rescued: Dictionary = game_state.actors[ally_index]
        rescued["hp"] = mini(int(rescued.get("max_hp",1)),int(rescued.get("hp",0))+heal)
        game_state.actors[ally_index] = rescued
    var hit: int = int(result.get("enemy_damage",0))
    if hit > 0:
        if boss and boss_mechanics != null and boss_mechanics.protect_from_lethal():
            hit = mini(hit,maxi(0,int(enemy.get("hp",1))-1))
        formation.apply_damage(active_target,hit)
    var chosen_enemy: Dictionary = formation.units[active_target]
    chosen_enemy["unrest"] = int(result.get("unrest",0))
    chosen_enemy["star_locks"] = int(result.get("star_locks",0))
    chosen_enemy["pacified"] = bool(result.get("pacified",false))
    formation.units[active_target] = chosen_enemy
    enemy = chosen_enemy
    var outcome: String = str(result.get("message","战术操作已执行。"))
    # Only a real nonboss battle with every enemy pacified can conclude here.
    # Bespoke story Bosses retain their original safety/identity/witness gates.
    if not boss and tactical_engine.all_pacified():
        last_boss_settlement = "nonlethal"
        _redraw(outcome+" · 全体敌人非暴力平息。")
        _finish(true)
        return
    turn_cursor += 1
    _start_actor()
    if not win_locked:
        _redraw(outcome)

func _act(action: String) -> void:
    if win_locked or hero_turn >= game_state.actors.size():
        return
    if action == "tactical":
        _choose_tactical_action()
        return
    if action.begins_with("tactic:"):
        _tactical_act(action.trim_prefix("tactic:"))
        return
    if action in ["attack","special"] and not boss and formation.alive_indices().size() > 1:
        _choose_enemy_target(action)
        return
    if action == "skill":
        if combat_rules.has_negative(str(game_state.actors[hero_turn].get("id","")),"silence"):
            _redraw("沉默状态无法施展技能。")
            return
        _choose_skill()
        return
    if action.begins_with("skill:") and combat_rules.has_negative(str(game_state.actors[hero_turn].get("id","")),"silence"):
        _hide_skills()
        _redraw("沉默状态无法施展技能。")
        return
    if action == "cancel_skill":
        _hide_skills()
        return
    var explicit_enemy_selected: bool = false
    if "#" in action:
        var enemy_select: PackedStringArray = action.split("#",false,1)
        if enemy_select.size() != 2 or not str(enemy_select[1]).is_valid_int() or not formation.valid_target(int(enemy_select[1])):
            _redraw("敌方目标已失效，请重新选择。")
            return
        _select_enemy(int(enemy_select[1]))
        action = str(enemy_select[0])
        explicit_enemy_selected = true
        _hide_skills()
    var chosen_skill: String = ""
    var target_index: int = hero_turn
    var hit_all_enemies: bool = false
    if action.begins_with("skill:"):
        var token: String = action.trim_prefix("skill:")
        if "@" in token:
            var fields: PackedStringArray = token.split("@",false,1)
            if fields.size() != 2 or not str(fields[1]).is_valid_int():
                _redraw("队友目标无效，请重新选择。")
                return
            chosen_skill = str(fields[0])
            target_index = int(fields[1])
            var selected_skill: Dictionary = _get_skill(chosen_skill)
            if str(selected_skill.get("target","")) != "single_ally" or target_index < 0 or target_index >= game_state.actors.size():
                _redraw("队友目标已经失效，请重新选择。")
                return
            var chosen_ally: Dictionary = game_state.actors[target_index]
            if int(chosen_ally.get("hp",0)) <= 0 or (game_core != null and not _actor_eligible(str(chosen_ally.get("id","")))):
                _redraw("当前队友无法成为该技能的目标。")
                return
        else:
            chosen_skill = token
            var candidate: Dictionary = _get_skill(chosen_skill)
            if str(candidate.get("target","")) == "single_ally":
                _choose_target(chosen_skill)
                return
            if str(candidate.get("target","")) == "single_enemy" and formation.alive_indices().size() > 1 and not explicit_enemy_selected:
                _choose_enemy_target("skill:"+chosen_skill)
                return
        action = "skill"
        _hide_skills()
        hit_all_enemies = str(_get_skill(chosen_skill).get("target","")) == "all_enemies"
    var member: Dictionary = game_state.actors[hero_turn]
    var name: String = str(member["name"])
    var stats: Dictionary = game_core.gear_stats(str(member.get("id",""))) if game_core != null else member
    var combat_attack: int = int(stats.get("attack",member.get("attack",0))) + combat_rules.attack_bonus(str(member.get("id","")))
    var actor_job: String = str(game_state.rpg.get("jobs",{}).get(str(member.get("id","")),"swordsman"))
    var vocation: Dictionary = game_core.vocation_profiles.get(actor_job,{}) if game_core != null else {}
    var passive: String = str(vocation.get("passive",""))
    var message: String = ""
    var damage: int = 0
    var healed_via_skill: bool = false
    match action:
        "attack":
            damage = maxi(3, combat_attack + dice.randi_range(-5, 8) - int(enemy["def"]))
            message = "%s 攻击造成 %d 伤害。" % [name, damage]
        "skill":
            var owned: Array = game_core.skills(str(member.get("id",""))) if game_core != null else []
            var chosen: Dictionary = {}
            for available in owned:
                if str(available.get("id","")) == chosen_skill:
                    chosen = available
                    break
            if chosen.is_empty() or int(chosen.get("mp_cost",999)) > int(member.get("mp",0)):
                _redraw("当前技能不可使用。")
                return
            else:
                member["mp"] = int(member["mp"]) - int(chosen.get("mp_cost",0))
                var effect: Dictionary = chosen.get("effect",{})
                var kind: String = str(effect.get("kind","damage"))
                var power: int = combat_rules.vocation_skill_power(int(effect.get("power",0)),passive,kind)
                # The shared magic equipment/job stat was previously displayed
                # but ignored by restorative skills in actual fights.
                var magic_bonus: int = maxi(0,int(stats.get("magic",0))) if str(effect.get("scaling","")) == "magic" else 0
                var target_type: String = str(chosen.get("target","single_enemy"))
                var label: String = str(chosen.get("name","技能"))
                if kind == "heal":
                    game_state.actors[hero_turn] = member
                    if target_type == "all_allies":
                        for i in range(game_state.actors.size()):
                            var person: Dictionary = game_state.actors[i]
                            if int(person.get("hp",0)) > 0 and (game_core == null or _actor_eligible(str(person.get("id","")))):
                                game_state.heal_member(i,maxi(10,power + magic_bonus))
                        message = "%s 施展%s，全队恢复体力。" % [name,label]
                    else:
                        if target_index >= 0 and target_index < game_state.actors.size():
                            game_state.heal_member(target_index,maxi(20,power*2 + magic_bonus))
                        message = "%s 施展%s，治疗%s。" % [name,label,str(game_state.actors[target_index].get("name",""))]
                    healed_via_skill = true
                    if passive in ["mercy","sanctuary"]:
                        if target_type == "all_allies":
                            for ally in game_state.actors:
                                combat_rules.cure_negative(str(ally.get("id","")),"" if passive == "sanctuary" else "poison")
                        elif target_index >= 0 and target_index < game_state.actors.size():
                            combat_rules.cure_negative(str(game_state.actors[target_index].get("id","")),"" if passive == "sanctuary" else "poison")
                    if is_instance_valid(vfx):
                        vfx.play_heal(_vfx_member_point(target_index),label)
                elif kind == "shield":
                    var targets: Array[int] = []
                    if target_type == "all_allies":
                        for i in range(game_state.actors.size()):
                            if game_core == null or _actor_eligible(str(game_state.actors[i].get("id",""))):
                                targets.append(i)
                    else:
                        targets.append(target_index)
                    for i in targets:
                        if i >= 0 and i < game_state.actors.size():
                            combat_rules.shield(str(game_state.actors[i].get("id","")),2)
                    message = "%s 施放%s，护盾持续两回合！" % [name,label]
                    if is_instance_valid(vfx):
                        vfx.play_guard(_vfx_ally_point())
                elif kind == "buff":
                    var targets: Array[int] = []
                    if target_type == "all_allies":
                        for i in range(game_state.actors.size()):
                            if game_core == null or _actor_eligible(str(game_state.actors[i].get("id",""))):
                                targets.append(i)
                    else:
                        targets.append(target_index)
                    for i in targets:
                        if i >= 0 and i < game_state.actors.size():
                            combat_rules.buff(str(game_state.actors[i].get("id","")),maxi(2,int(power/4)),3)
                    message = "%s 施展%s，强化战斗能力三回合。" % [name,label]
                    if is_instance_valid(vfx):
                        vfx.play_charge(_vfx_ally_point())
                else:
                    var base: int = maxi(3,combat_attack + power - int(enemy["def"]))
                    damage = combat_rules.elemental_damage(base,str(chosen.get("element","")),str(enemy.get("weakness","")),str(enemy.get("element","")))
                    message = "%s 发动%s，造成%d伤害%s" % [name,label,damage,"！ 触发弱点！" if str(chosen.get("element","")) == str(enemy.get("weakness","")) else "。"]
        "charge":
            var stack: int = combat_rules.charge(str(member.get("id","")))
            message = "%s 凝聚星辉（%d/3），下一次攻击威力提高！" % [name,stack]
            if is_instance_valid(vfx):
                vfx.play_charge(_vfx_ally_point())
        "guard":
            defense[hero_turn] = true
            message = "%s 严阵以待，本回合受到的伤害降低。" % name
            match passive:
                "aegis":
                    combat_rules.shield(str(member.get("id","")),3)
                    message += " · 壁垒护盾。"
                "momentum":
                    combat_rules.charge(str(member.get("id","")))
                    message += " · 连势聚星。"
                "fortify":
                    for ally in game_state.actors:
                        if int(ally.get("hp",0)) > 0:
                            combat_rules.shield(str(ally.get("id","")),2)
                    message += " · 铸阵全体护盾。"
                "anthem":
                    combat_rules.buff(str(member.get("id","")),5,2)
                    message += " · 号令战歌。"
                "synthesis":
                    member["mp"] = mini(int(member.get("max_mp",0)),int(member.get("mp",0))+8)
                    message += " · 炼造恢复8点魔力。"
            if is_instance_valid(vfx):
                vfx.play_guard(_vfx_ally_point())
        "potion":
            if game_state.potions <= 0:
                _redraw("药草已经用完。")
                return
            if not game_state.heal_member(hero_turn, 65):
                _redraw("%s 的生命已经全满。" % name)
                return
            if game_core != null:
                game_core.take_item("item_herb_01", 1)
            else:
                game_state.potions -= 1
            # heal_member() updated the authoritative actor entry. The local
            # 'member' still has PRE-heal HP; never copy it back at action end.
            healed_via_skill = true
            message = "%s 使用药草恢复生命。" % name
            if is_instance_valid(vfx):
                vfx.play_heal(_vfx_ally_point(),"药草")
        "special":
            if boss and chapter == 3 and act01_mechanics != null:
                # Three physically operated V7 cave valves, not a synthetic inventory item.
                # Old saves without the close-up gallery retain their archived clue flag.
                var records: Dictionary = game_state.rpg.get("canon_evidence",{})
                var badge_record: Dictionary = records.get("ev_ch003_half_badge",{})
                var saw_badge: bool = bool(badge_record.get("crooked_tree",false))
                var legacy_badge: bool = not records.has("ev_ch003_half_badge") and bool(game_state.flags.get("ch003.evidence",false))
                var has_badge: bool = act01_mechanics.valve_3_guardian_shutoff and (saw_badge or legacy_badge)
                var action_id: String = "SHOW_CROOKED_TREE_BADGE" if has_badge else "PULL_BACK_ALLY"
                var result: Dictionary = act01_mechanics.execute_boss_ch003_tactical_action(action_id,has_badge)
                message = str(result.get("msg","守卫未响应。"))
                if bool(result.get("success",false)) and not act01_mechanics.boss_ch003_is_pacified:
                    # Rescuing an ally must matter in the real combat loop.
                    combat_rules.shield(str(member.get("id","")),2)
                    message += " · 队伍重新站稳，获得短暂防护。"
                    if is_instance_valid(vfx):
                        vfx.play_guard(_vfx_ally_point())
                if bool(result.get("success",false)) and act01_mechanics.boss_ch003_is_pacified:
                    last_boss_settlement = "nonlethal"
                    _redraw(message)
                    _finish(true)
                    return
            elif boss and chapter == 5 and act01_mechanics != null:
                # A whole player turn is spent exposing the unlit lock, then a
                # separate turn removes EXACTLY ONE of the three restraints.
                # Pure attack damage cannot substitute for a rescue action.
                var sailor_ready: bool = false
                for ally in game_state.actors:
                    if str(ally.get("id","")) == "char_seeker" and int(ally.get("hp",0)) > 0:
                        # A living reserve companion may whistle as scene support.
                        sailor_ready = true
                        break
                if not sailor_ready:
                    message = "朔弦当前失去意识，必须先救治，才能吹响安全引导双哨。"
                elif not act01_mechanics.beast_back_vulnerable or act01_mechanics.star_vein_glowing_hazard:
                    message = act01_mechanics.trigger_shuoxian_double_whistle()
                    if is_instance_valid(vfx):
                        vfx.play_charge(_vfx_ally_point())
                else:
                    var dismantle: Dictionary = act01_mechanics.attempt_dismantle_star_lock(false)
                    message = str(dismantle.get("msg","当前锁扣无法解除。"))
                    if bool(dismantle.get("success",false)):
                        chain_hp = act01_mechanics.beast_star_locks_remaining * 42
                        if is_instance_valid(vfx):
                            vfx.play_special(_vfx_foe_point())
                    if bool(dismantle.get("battle_complete",false)) and act01_mechanics.boss_ch005_is_complete:
                        last_boss_settlement = "nonlethal"
                        _redraw(message)
                        _finish(true)
                        return
            elif boss and chapter == 6:
                if not lighthouse_wicks_verified or lighthouse_testimony_rows.size()!=4:
                    message = "三枚灯芯的实地凭证或四份归航见证正典数据缺失，禁止以重复指令伪造重燃。"
                elif lighthouse_witnesses_heard.size() < lighthouse_testimony_rows.size():
                    # Four separate canonical voices, one earned player action
                    # each. A timeout can interrupt the most recent voice,
                    # but cannot convert identical actions into extra witnesses.
                    var witness: Dictionary = lighthouse_testimony_rows[lighthouse_witnesses_heard.size()]
                    var witness_id: String = str(witness.get("id",""))
                    if witness_id in lighthouse_witnesses_heard:
                        message = "重复的归航回声不能作为新的见证。"
                    else:
                        lighthouse_witnesses_heard.append(witness_id)
                        resonance = lighthouse_witnesses_heard.size()
                        countdown = mini(8,countdown + 2)
                        message = "%s 接续「%s」：%s（%d/4）。" % [
                            name,str(witness.get("name","归航者")),str(witness.get("line","")),resonance]
                        if is_instance_valid(vfx):
                            vfx.play_charge(_vfx_ally_point())
                        if resonance == 4:
                            last_boss_settlement = "testimony"
                            _redraw(message + "四份不同的共同见证已达成；无人献出私人记忆。")
                            _finish(true)
                            return
            else:
                damage = maxi(8, combat_attack + dice.randi_range(5, 12) - maxi(0, int(enemy["def"]) - 6))
                message = "%s 找到敌人的破绽，造成 %d 伤害。" % [name, damage]
    if boss and boss_mechanics != null and boss_mechanics.enabled() and not ((chapter == 5 and act01_mechanics != null) or chapter == 6):
        # The chapter-5 rescue owns its victory flag; generic boss objectives
        # must not create a second, easier settlement.
        var selected_profile: Dictionary = _get_skill(chosen_skill) if action == "skill" else {}
        var boss_action: Dictionary = boss_mechanics.record_action(action,selected_profile,str(member.get("id","")),current_round,passive)
        var boss_notice: String = str(boss_action.get("notice",""))
        if not boss_notice.is_empty():
            message += " · " + boss_notice
        if bool(boss_action.get("victory",false)):
            last_boss_settlement = str(boss_mechanics.spec.get("settlement","nonlethal"))
            _redraw(message + "战术目标达成。")
            _finish(true)
            return
    if action == "special" and passive in ["starlight","tempo"]:
        if passive == "starlight":
            combat_rules.shield(str(member.get("id","")),2)
        elif formation.valid_target(active_target):
            combat_rules.apply_enemy_negative(active_target,enemy,"slow",2)
    if is_instance_valid(sfx):
        var sound_key: String = action
        var sound_element: String = ""
        if action == "skill":
            var sound_skill: Dictionary = _get_skill(chosen_skill)
            var sound_effect: Dictionary = sound_skill.get("effect",{})
            sound_element = str(sound_skill.get("element",""))
            match str(sound_effect.get("kind","damage")):
                "heal": sound_key = "heal"
                "shield": sound_key = "guard"
                "buff": sound_key = "charge"
                _: sound_key = "cast"
        elif action == "potion":
            sound_key = "heal"
        elif action == "special":
            sound_key = "charge"
        sfx.play_event(sound_key,sound_element)
    if is_instance_valid(actor_stage):
        actor_stage.play_action(str(member.get("id","")),action)
        actor_stage.update_party(game_state.actors)
    if action == "skill" and damage <= 0 and is_instance_valid(vfx):
        var support_skill: Dictionary = _get_skill(chosen_skill)
        vfx.play_skill(_vfx_ally_point(),_vfx_member_point(target_index),support_skill,0,str(support_skill.get("target","")) == "all_allies")
    if not healed_via_skill:
        game_state.actors[hero_turn] = member
    if damage > 0:
        if game_core != null:
            var weapon_trait_id: String = str(game_core.weapon_trait(str(member.get("id",""))))
            var weapon_tier_rank: int = int(game_core.weapon_tier(str(member.get("id",""))))
            damage = combat_rules.weapon_damage(damage, weapon_trait_id, enemy, weapon_tier_rank)
            if not weapon_trait_id.is_empty():
                message += " · 武器特性：" + weapon_trait_id
        var living_party: int = 0
        for ally in game_state.actors:
            if int(ally.get("hp",0)) > 0 and (game_core == null or _actor_eligible(str(ally.get("id","")))):
                living_party += 1
        damage = combat_rules.vocation_damage(damage,passive,action,enemy,living_party)
        damage = combat_rules.release_charge(str(member.get("id","")),damage)
        if boss and boss_mechanics != null and boss_mechanics.enabled():
            damage = maxi(1,roundi(float(damage)*boss_mechanics.damage_factor(_get_skill(chosen_skill) if action == "skill" else {})))
            if boss_mechanics.protect_from_lethal():
                damage = mini(damage,maxi(0,int(enemy.get("hp",1))-1))
        # The keeper cannot be defeated by HP depletion before the required
        # four shared testimonies. Preserve the legal special-action victory.
        if boss and chapter == 6 and resonance < 4:
            damage = mini(damage,maxi(0,int(enemy.get("hp",1))-1))
        if is_instance_valid(timeline):
            timeline.queue_actor(action,_vfx_ally_point(),_vfx_foe_point(),damage,_get_skill(chosen_skill) if action == "skill" else {},hit_all_enemies)
        if not boss or chapter != 5:
            var status_kind: String = ""
            var status_rate: float = 0.0
            if action == "skill":
                var active_skill: Dictionary = _get_skill(chosen_skill)
                var skill_effect: Dictionary = active_skill.get("effect",{})
                status_kind = str(skill_effect.get("status",skill_effect.get("ailment","")))
                status_rate = clampf(float(skill_effect.get("status_chance",0.45)),0.0,1.0)
            elif game_core != null and str(game_core.weapon_trait(str(member.get("id","")))) == "火伤":
                status_kind = "burn"
                status_rate = 0.22
            if action == "skill" and passive == "arcana" and status_kind.is_empty():
                status_kind = "burn"
                status_rate = 0.22
            if not status_kind.is_empty():
                var possible_targets: Array[int] = formation.alive_indices() if hit_all_enemies else [active_target]
                for foe_index in possible_targets:
                    if formation.valid_target(foe_index):
                        var foe_profile: Dictionary = formation.units[foe_index]
                        if dice.randf() < combat_rules.enemy_status_chance(foe_profile,status_kind,status_rate):
                            if combat_rules.apply_enemy_negative(foe_index,foe_profile,status_kind,2):
                                message += " · " + str(foe_profile.get("name","目标")) + "陷入" + str(CombatRules.NEGATIVE_STATUS_LABELS.get(status_kind,status_kind))
        if boss and chapter == 5:
            # Normal combat pressure only creates room for the rescue:
            # the beast itself takes no lethal damage, and no chains disappear.
            message += " · 古兽甲壳仍在抵抗；需要双哨引导后逐个拆除星纹锁。"
        elif hit_all_enemies:
            for index in formation.alive_indices():
                formation.apply_damage(index,damage)
                if is_instance_valid(enemy_stage):
                    enemy_stage.hit(index,int(formation.units[index].get("hp",0)) <= 0)
                if is_instance_valid(vfx) and is_instance_valid(enemy_stage) and enemy_stage.visible and index != active_target:
                    vfx.play_hit_marker(enemy_stage.point(index),damage,str(_get_skill(chosen_skill).get("element","")))
            enemy = formation.units[active_target]
        else:
            formation.apply_damage(active_target,damage)
            enemy = formation.units[active_target]
            if is_instance_valid(enemy_stage):
                enemy_stage.hit(active_target,int(enemy.get("hp",0)) <= 0)
    if is_instance_valid(c23_boss_body_motion) and not enemy_stage.visible:
        c23_boss_body_motion.play_hit(int(enemy.get("hp",0)) <= 0)
    if is_instance_valid(generated_boss_motion) and not enemy_stage.visible:
        generated_boss_motion.play_hit(int(enemy.get("hp",0)) <= 0)
    if not phase_two and boss and int(enemy["hp"]) <= int(enemy["max_hp"]) / 2:
        phase_two = true
        if boss_mechanics != null and boss_mechanics.enabled():
            boss_mechanics.set_phase_two()
            enemy["weakness"] = str(boss_mechanics.spec.get("phase_two_element",enemy.get("weakness","")))
            message += " · " + boss_mechanics.phase_hint()
        message += "  敌人进入第二阶段！"
        enemy["atk"] = int(enemy["atk"]) + 4
        if is_instance_valid(vfx):
            vfx.play_phase(_vfx_foe_point())
            vfx.play_boss_cue(_vfx_foe_point(),chapter,true)
        if is_instance_valid(boss_animation):
            boss_animation.awaken()
        if is_instance_valid(c23_boss_body_motion):
            c23_boss_body_motion.play_phase()
        if is_instance_valid(generated_boss_motion):
            generated_boss_motion.play_phase()
        if is_instance_valid(camera_motion):
            camera_motion.impulse(7.0)
        if is_instance_valid(sfx):
            sfx.play_event("phase")
    if formation.complete() and (not boss or chapter != 5):
        _redraw(message)
        _finish(true)
        return
    if not formation.valid_target(active_target):
        var remaining: Array[int] = formation.alive_indices()
        if not remaining.is_empty():
            _select_enemy(remaining[0])
    turn_cursor += 1
    _start_actor()
    if not win_locked:
        _redraw(message)

func _enemy_turn() -> void:
    # Compatibility hook for older scripted tests; runtime uses _enemy_action.
    for index in formation.alive_indices():
        if win_locked:
            break
        _enemy_action(index)

func _enemy_action(index: int) -> void:
    if win_locked or not formation.valid_target(index):
        return
    if tactical_engine != null and bool(
            tactical_engine.enemy_states.get(index,{}).get("pacified",false)):
        return
    var original_target: int = active_target
    enemy = formation.units[index]
    var effect: Dictionary = combat_rules.resolve_enemy_turn(index,int(enemy.get("max_hp",1)))
    var damage_over_time: int = int(effect.get("damage",0))
    if damage_over_time > 0:
        if boss and ((boss_mechanics != null and boss_mechanics.protect_from_lethal()) or (chapter == 6 and resonance < 4)):
            damage_over_time = mini(damage_over_time,maxi(0,int(enemy.get("hp",1))-1))
        formation.apply_damage(index,damage_over_time)
        enemy = formation.units[index]
        if is_instance_valid(enemy_stage):
            enemy_stage.hit(index,int(enemy.get("hp",0)) <= 0)
        if is_instance_valid(vfx):
            vfx.play_status(_vfx_enemy_point(index),damage_over_time)
    if formation.complete() and (not boss or chapter != 5):
        _finish(true)
        return
    if int(enemy.get("hp",0)) > 0 and not bool(effect.get("skip",false)):
        _enemy_strike(index)
        if boss and boss_mechanics != null and boss_mechanics.enabled() and not win_locked:
            if str(boss_mechanics.spec.get("archetype","")) == "multi_hit" and boss_mechanics.phase_two and current_round % maxi(2,int(boss_mechanics.spec.get("cadence",3))) == 0:
                _enemy_strike(index)
    if formation.valid_target(original_target):
        _select_enemy(original_target)
    elif not formation.alive_indices().is_empty():
        _select_enemy(formation.alive_indices()[0])

func _enemy_strike(attacker_index: int = -1) -> void:
    var living: Array[int] = []
    for i in range(game_state.actors.size()):
        if int(game_state.actors[i]["hp"]) > 0 and (game_core == null or _actor_eligible(str(game_state.actors[i].get("id","")))):
            living.append(i)
    if living.is_empty():
        _finish(false)
        return
    var intent: Dictionary = round_boss_intent if boss else combat_rules.enemy_strategy(enemy,current_round,phase_two,false,game_state.actors)
    last_enemy_action = str(enemy.get("name","敌人")) + " · " + str(intent.get("label","攻击"))
    if is_instance_valid(c23_boss_body_motion):
        c23_boss_body_motion.play_attack()
    if is_instance_valid(generated_boss_motion):
        generated_boss_motion.play_attack()
    var target: int = living[dice.randi_range(0, living.size() - 1)]
    var targeting: String = str(intent.get("target",""))
    if targeting in ["lowest_hp","highest_hp","lowest_mp"]:
        for i in living:
            if targeting == "lowest_hp" and int(game_state.actors[i].get("hp",0)) < int(game_state.actors[target].get("hp",0)):
                target = i
            elif targeting == "highest_hp" and int(game_state.actors[i].get("hp",0)) > int(game_state.actors[target].get("hp",0)):
                target = i
            elif targeting == "lowest_mp" and int(game_state.actors[i].get("mp",0)) < int(game_state.actors[target].get("mp",0)):
                target = i
    var member: Dictionary = game_state.actors[target]
    var stats: Dictionary = game_core.gear_stats(str(member.get("id",""))) if game_core != null else member
    var raw_damage: int = maxi(1, roundi((int(enemy["atk"]) + dice.randi_range(-3, 5) - int(stats.get("defense",member["defense"]))) * float(intent.get("multiplier",1.0))))
    var damage: int = combat_rules.mitigated_damage(raw_damage,str(member.get("id","")),defense.has(target))
    if game_core != null:
        var defender_job: String = str(game_state.rpg.get("jobs",{}).get(str(member.get("id","")),"swordsman"))
        var defender_role: String = str(game_core.vocation_profiles.get(defender_job,{}).get("passive",""))
        damage = combat_rules.vocation_mitigation(damage,defender_role,float(member.get("hp",0))/float(maxi(1,int(member.get("max_hp",1)))))
    if invincible:
        damage = 0
    enemy_strike_count += 1
    enemy_damage_dealt += damage
    if defense.has(target):
        enemy_guarded_strikes += 1
    member["hp"] = maxi(0, int(member["hp"]) - damage)
    game_state.actors[target] = member
    if is_instance_valid(actor_stage):
        actor_stage.play_hit(str(member.get("id","")),int(member["hp"]) <= 0)
    if is_instance_valid(enemy_stage) and enemy_stage.visible:
        enemy_stage.attack(attacker_index)
    if is_instance_valid(timeline):
        timeline.queue_enemy(_vfx_enemy_point(attacker_index),_vfx_member_point(target),damage)
    if damage > 0 and int(member["hp"]) > 0:
        var element: String = str(enemy.get("element",""))
        var ailment: String = ""
        if element in ["毒","暗"] and dice.randf() < 0.14:
            ailment = "poison"
        elif element == "火" and dice.randf() < 0.14:
            ailment = "burn"
        elif element in ["冰","霜"] and dice.randf() < 0.12:
            ailment = "freeze"
        elif boss and current_round % 4 == 0 and dice.randf() < 0.12:
            ailment = "stun"
        if boss and not str(intent.get("status","")).is_empty() and dice.randf() < float(intent.get("status_chance",0.0)):
            ailment = str(intent.get("status",""))
        if not ailment.is_empty():
            var immunity: Array = member.get("status_immunities",[])
            var gear_immunity: Array = stats.get("status_immunities",[])
            if ailment not in immunity and ailment not in gear_immunity:
                combat_rules.apply_negative(str(member.get("id","")),ailment,2 if ailment in ["poison","burn"] else 1)
    if boss and chapter == 6:
        countdown -= 1
        if countdown <= 0:
            # A lapsed last voice must genuinely be repeated, not retained
            # as an invisible counting receipt. Existing turn rhythm stays.
            countdown = 3
            if not lighthouse_witnesses_heard.is_empty():
                lighthouse_witnesses_heard.pop_back()
            resonance = lighthouse_witnesses_heard.size()
    if _all_fallen():
        _finish(false)

func _vfx_enemy_point(index: int) -> Vector2:
    if is_instance_valid(enemy_stage) and enemy_stage.visible:
        return enemy_stage.point(index)
    if is_instance_valid(portrait):
        return portrait.position+portrait.size*0.5
    return Vector2(576,245)

func _vfx_foe_point() -> Vector2:
    return _vfx_enemy_point(active_target)

func _legacy_portrait_point() -> Vector2:
    if is_instance_valid(portrait):
        return portrait.position + portrait.size * 0.5
    return Vector2(root.size.x*0.5,root.size.y*0.38) if is_instance_valid(root) else Vector2(576,246)

func _vfx_member_point(index: int) -> Vector2:
    if index >= 0 and index < game_state.actors.size() and is_instance_valid(actor_stage):
        return actor_stage.actor_point(str(game_state.actors[index].get("id","")))
    return Vector2(root.size.x*0.28,root.size.y*0.48) if is_instance_valid(root) else Vector2(322,310)

func _vfx_ally_point() -> Vector2:
    return _vfx_member_point(hero_turn)

# Red charge warnings are reserved for genuinely dangerous frozen round
# intents. Routine observation/weak recovery turns stay in the enemy-intent
# HUD without pretending to be a heavy attack.
func _boss_warning_label(intent: Dictionary) -> String:
    if float(intent.get("multiplier",1.0)) < 1.25:
        return ""
    var action_name: String = str(intent.get("label",""))
    if action_name.is_empty() or action_name == "普通攻击":
        return ""
    var focus: String = ""
    match str(intent.get("target","random")):
        "lowest_hp": focus = " · 倾向低生命队友"
        "highest_hp": focus = " · 倾向高生命队友"
        "lowest_mp": focus = " · 倾向低魔力队友"
        _: focus = " · 攻击目标不定"
    # A player can change the priority with healing; do not claim a fixed
    # target before the boss actually selects it during its attack turn.
    return action_name + focus + " · 防御可减伤"

func _telegraph_next_boss_action() -> void:
    if not boss or last_warning_round == current_round or not is_instance_valid(vfx):
        return
    var has_future_enemy: bool = false
    for i in range(turn_cursor+1,turn_queue.size()):
        if str(turn_queue[i].get("team","")) == "enemy":
            has_future_enemy = true
            break
    if not has_future_enemy:
        return
    var intent: Dictionary = round_boss_intent
    var name: String = _boss_warning_label(intent)
    if name.is_empty():
        return
    last_warning_round = current_round
    last_warning_text = name
    if is_instance_valid(c23_boss_body_motion):
        c23_boss_body_motion.play_charge()
    if is_instance_valid(generated_boss_motion):
        generated_boss_motion.play_charge()
    vfx.play_warning(_vfx_foe_point(),name)
    if is_instance_valid(battle_hud):
        battle_hud.sync(formation.units,game_state.actors,active_target,phase_two,last_warning_text)
    if is_instance_valid(sfx):
        sfx.play_event("charge")

func _all_fallen() -> bool:
    for member in game_state.actors:
        if int(member["hp"]) > 0 and (game_core == null or _actor_eligible(str(member.get("id","")))):
            return false
    return true

# Chapters five and six use authored scene mechanics instead of the generic
# BattleBossMechanics progress counter. Their goals must still be visible
# without activating a second, unintended battle victory pathway.
func _show_boss_objective() -> bool:
    return boss and boss_mechanics != null and (boss_mechanics.enabled() or chapter in [5,6])

func _redraw(message: String) -> void:
    # The single existing command slot reflects the real interaction phase.
    # It never introduces a second victory or reward route.
    if boss and is_instance_valid(special_button) and act01_mechanics != null:
        if chapter == 5:
            if act01_mechanics.beast_back_vulnerable and not act01_mechanics.star_vein_glowing_hazard:
                special_button.text = "✦ 安全拆锁（剩余%d处）" % act01_mechanics.beast_star_locks_remaining
            else:
                special_button.text = "✦ 朔弦双哨 · 暂避发亮区"
        elif chapter == 3:
            special_button.text = "✦ 守卫胸灯停顿 · 旧船徽/救援" if act01_mechanics.boss_ch003_chest_lamp_blinking else "✦ 等待胸灯停顿"
    if boss and chapter == 6 and is_instance_valid(special_button):
        if not lighthouse_wicks_verified or lighthouse_testimony_rows.size()!=4:
            special_button.text = "✦ 见证资料缺失 · 暂不可用"
        elif lighthouse_witnesses_heard.size() < 4:
            var next_voice: Dictionary = lighthouse_testimony_rows[lighthouse_witnesses_heard.size()]
            special_button.text = "✦ 接续见证：" + str(next_voice.get("name","归航者"))
    if is_instance_valid(battle_hud):
        battle_hud.sync(formation.units,game_state.actors,active_target,phase_two,
            last_warning_text if last_warning_round == current_round else "")
    if is_instance_valid(actor_stage):
        actor_stage.update_party(game_state.actors)
    if is_instance_valid(enemy_stage) and enemy_stage.visible:
        enemy_stage.sync(formation.units)
    report.text = message
    var header: String = "%s   HP %d/%d" % [str(enemy["name"]), int(enemy["hp"]), int(enemy["max_hp"])]
    if chapter == 5 and boss:
        var locks_remaining: int = act01_mechanics.beast_star_locks_remaining if act01_mechanics != null else 3
        header = "%s   已拆星锁 %d/3  · 余链 %d" % [str(enemy["name"]), 3 - locks_remaining, chain_hp]
        if act01_mechanics != null and act01_mechanics.star_vein_glowing_hazard:
            header += " · 红旗警戒"
    elif chapter == 6 and boss:
        header += "   共鸣 %d/4" % resonance
    if tactical_engine != null:
        header += tactical_engine.overview(active_target)
    if phase_two:
        header += "  · 二阶段"
    header += " · 意图：" + str(round_boss_intent.get("label","攻击") if boss else combat_rules.enemy_strategy(enemy,current_round,phase_two,false,game_state.actors).get("label","攻击"))
    if _show_boss_objective():
        header += " · 目标：" + boss_mechanics.objective_label()
        if boss_mechanics.enabled():
            var state: Dictionary = boss_mechanics.report()
            if int(state.get("required",0)) > 0:
                header += " %d/%d" % [int(state.get("progress",0)),int(state.get("required",0))]
            header += " · 防护 %d" % int(state.get("ward",0))
    if formation != null and formation.units.size() > 1:
        var roster: Array[String] = []
        for i in range(formation.units.size()):
            var unit: Dictionary = formation.units[i]
            if int(unit.get("hp",0)) > 0:
                roster.append(("%d▶" % (i+1) if i == active_target else "%d" % (i+1))+" "+str(unit.get("name",""))+" "+str(unit.get("hp",0))+"HP")
        header = " | ".join(roster)
    var foe_ailments: String = combat_rules.enemy_status_report(active_target)
    if not foe_ailments.is_empty():
        header += "  ⚠" + foe_ailments
    # Keep the round visible even if multiple enemy names replace the header.
    # It helps players judge when to defend, heal or retry a long Boss fight.
    if boss:
        header += " · 第%d回合" % current_round
    foe_info.text = header
    var lines: PackedStringArray = []
    for i in range(game_state.actors.size()):
        var member: Dictionary = game_state.actors[i]
        if game_core != null and not _actor_eligible(str(member.get("id",""))):
            continue
        var current: String = "[color=#f9d58b]▶ " if i == hero_turn else "[color=#c9e4eb]"
        var status: Dictionary = combat_rules.actor_effects.get(str(member.get("id","")),{})
        var buffs: String = (" ✦增强" if int(status.get("attack_turns",0)) > 0 else "") + (" ◈护盾" if int(status.get("shield_turns",0)) > 0 else "") + (" ★聚星%d" % int(status.get("star_charge",0)) if int(status.get("star_charge",0)) > 0 else "")
        var condition: String = combat_rules.status_report(str(member.get("id","")))
        if not condition.is_empty():
            buffs += " ⚠" + condition
        lines.append("%s%s  Lv.%d   HP %d/%d  MP %d/%d%s[/color]" % [current, str(member["name"]), int(member["level"]), int(member["hp"]), int(member["max_hp"]), int(member["mp"]), int(member["max_mp"]),buffs])
    party_info.text = "    ".join(lines)

func _finish(victory: bool) -> void:
    if win_locked:
        return
    win_locked = true
    if victory and boss and is_instance_valid(c23_boss_body_motion):
        c23_boss_body_motion.play_defeat()
    if victory and boss and is_instance_valid(generated_boss_motion):
        generated_boss_motion.play_defeat()
    for item in commands.get_children():
        if item is Button:
            item.disabled = true
    if victory:
        # Chapter 5 rescues the chained beast; chapter 6 replaces the
        # sacrifice with four player-earned memories. Their outcomes are
        # explicit and must not degrade to the generic "legacy_story" receipt.
        if boss and chapter == 5 and act01_mechanics != null and act01_mechanics.boss_ch005_is_complete and act01_mechanics.beast_star_locks_remaining == 0:
            last_boss_settlement = "nonlethal"
        elif boss and chapter == 6 and lighthouse_wicks_verified and lighthouse_testimony_rows.size()==4 and lighthouse_witnesses_heard.size()==4 and resonance==4:
            last_boss_settlement = "testimony"
        elif boss and boss_mechanics != null and boss_mechanics.enabled() and last_boss_settlement.is_empty():
            last_boss_settlement = str(boss_mechanics.spec.get("settlement","defeated"))
        if is_instance_valid(vfx):
            vfx.play_victory(_vfx_foe_point())
        if is_instance_valid(actor_stage):
            actor_stage.play_victory()
        if is_instance_valid(sfx):
            sfx.play_event("victory")
        var settlement_text: String = "战术目标达成，相关人员已安全撤离。" if last_boss_settlement == "rescued" else ("已解除敌方控制，避免了不必要的伤亡。" if last_boss_settlement == "nonlethal" else "战斗结束，大家平安归来。")
        report.text = "胜利！%s" % ("古兽已经重获自由。" if boss and chapter == 5 else settlement_text)
    else:
        report.text = "全队失去战斗力，准备在营地重新整备。"
    var reward: Dictionary = formation.rewards() if formation != null else {"xp":int(enemy["xp"]),"gold":int(enemy["gold"])}
    if is_instance_valid(battle_hud):
        battle_hud.show_result(victory,int(reward["xp"]) if victory else 0,int(reward["gold"]) if victory else 0)
    if world_handoff != null and world_handoff.active:
        last_world_handoff_result = world_handoff.mark_result(victory,last_boss_settlement)
        var controller: Node = get_parent()
        if controller != null and controller.has_method("_battle_finished"):
            var current_world: Node = controller.get("world") as Node
            if is_instance_valid(current_world):
                # Restore before completed.emit, so the existing controller's
                # defeat/save/UI flow sees the safe coordinates and grace.
                last_world_handoff_result = world_handoff.restore(current_world)
    # Keep completed(victory,xp,gold) unchanged for older D-line hosts.
    # Ledger mutation belongs to the D-line owner of all reward and save side effects.
    last_world_handoff_result["reward_transaction_id"] = reward_transaction_id
    completed.emit(victory, int(reward["xp"]) if victory else 0, int(reward["gold"]) if victory else 0)
