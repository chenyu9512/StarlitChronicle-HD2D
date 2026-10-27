extends CanvasLayer
const ArtAssets = preload("res://scripts/art_assets.gd")
const CArtOverrides = preload("res://scripts/c_art_overrides.gd")
const EncounterRegistry = preload("res://scripts/encounter_registry.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")
const BattleBossMechanics = preload("res://scripts/battle_boss_mechanics.gd")
const BattleFormation = preload("res://scripts/battle_formation.gd")
const BattleWorldHandoff = preload("res://scripts/battle_world_handoff.gd")
const BattleRewardTransaction = preload("res://scripts/battle_reward_transaction.gd")
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
var chapter: int = 1
var boss: bool = false
var round_boss_intent: Dictionary = {}
var enemy: Dictionary = {}
var hero_turn: int = 0
var party_order: Array[int] = []
var turn_queue: Array[Dictionary] = []
var turn_cursor: int = 0
var last_enemy_action: String = ""
var current_round: int = 1
var phase_two: bool = false
var chain_hp: int = 0
var resonance: int = 0
var countdown: int = 8
var defense: Dictionary = {}
var win_locked: bool = false
var invincible: bool = false
var dice: RandomNumberGenerator = RandomNumberGenerator.new()
var root: Control
var party_info: RichTextLabel
var foe_info: Label
var report: Label
var commands: HBoxContainer
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
    countdown = 8
    defense.clear()
    win_locked = false
    last_warning_round = 0
    last_warning_text = ""
    last_boss_settlement = ""
    last_world_handoff_result.clear()
    reward_transaction_id = ""
    _auto_prepare_world_handoff()
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
    var stable_boss_id: String = ""
    if boss:
        stable_boss_id = str(encounter_data.get("enemy_id",""))
        if not formation.units.is_empty():
            stable_boss_id = str(formation.units[0].get("boss_id",stable_boss_id))
        if stable_boss_id.is_empty():
            stable_boss_id = "boss.ch%03d/crisis" % chapter
    reward_transaction_id = BattleRewardTransaction.make_id(boss,chapter,stable_boss_id)
    active_target = 0
    enemy = formation.units[0]
    _begin_round()
    _build()
    _start_actor()
    var introduction: String = "%s 出现在你们面前！" % str(enemy["name"])
    if boss_mechanics != null and boss_mechanics.enabled():
        introduction += " · 目标：" + boss_mechanics.objective_label() + " · 提示：" + boss_mechanics.hint()
    _redraw(introduction)

func _style(bg: Color, outline: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = outline
    s.set_border_width_all(2)
    s.set_corner_radius_all(12)
    s.set_content_margin_all(13)
    return s

func _button(parent: Node, text_label: String, action: String) -> Button:
    var b := Button.new()
    b.text = text_label
    b.custom_minimum_size = Vector2(146, 49)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_font_size_override("font_size", 19)
    b.add_theme_stylebox_override("normal", _style(Color("102539"), Color("5c87a0")))
    b.add_theme_stylebox_override("hover", _style(Color("205075"), Color("f2ca76")))
    b.pressed.connect(func() -> void: _act(action))
    parent.add_child(b)
    return b

func _build() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    var backdrop := TextureRect.new()
    backdrop.texture = CArtOverrides.texture("res://assets/art/backdrops/coast/tide_lighthouse.png" if chapter >= 5 else "res://assets/art/backdrops/coast/white_sand_port.png")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_SCALE
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
    title_plate.add_theme_stylebox_override("panel", _style(Color("0c2035"), Color("d7b46e")))
    root.add_child(title_plate)
    foe_info = Label.new()
    foe_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    foe_info.add_theme_font_size_override("font_size", 20)
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
            if game_core.is_active(str(member.get("id",""))):
                actor_ids.append(str(member.get("id","")))
    var battle_settings: Dictionary = game_state.rpg.get("settings",{})
    actor_stage.reduced_motion = bool(battle_settings.get("reduced_motion",false))
    actor_stage.configure(game_state.actors,actor_ids)
    var lower := PanelContainer.new()
    lower.anchor_left = 0.05
    lower.anchor_right = 0.95
    lower.anchor_top = 0.61
    lower.anchor_bottom = 0.985
    lower.add_theme_stylebox_override("panel", _style(Color("0b1b2f"), Color("b49661")))
    root.add_child(lower)
    var flow := VBoxContainer.new()
    flow.add_theme_constant_override("separation", 5)
    lower.add_child(flow)
    report = Label.new()
    report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    report.add_theme_font_size_override("font_size", 19)
    report.add_theme_color_override("font_color", Color("f4d894"))
    flow.add_child(report)
    party_info = RichTextLabel.new()
    party_info.bbcode_enabled = true
    party_info.custom_minimum_size = Vector2(0, 43)
    party_info.add_theme_font_size_override("normal_font_size", 17)
    flow.add_child(party_info)
    commands = HBoxContainer.new()
    commands.add_theme_constant_override("separation", 9)
    flow.add_child(commands)
    _button(commands, "⚔ 攻击", "attack")
    _button(commands, "✧ 技能", "skill")
    _button(commands, "◇ 防御", "guard")
    _button(commands, "✦ 聚星", "charge")
    _button(commands, "✚ 药草", "potion")
    var special_name: String = "✦ 拆除星锁" if chapter == 5 and boss else ("✦ 共同见证" if chapter == 6 and boss else ("✦ 破解机制" if boss and boss_mechanics != null and boss_mechanics.enabled() else "✦ 识破弱点"))
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
        if game_core != null and not game_core.is_active(str(member.get("id",""))):
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
    last_warning_text = ""
    var eligible: Array = []
    if game_core != null:
        for member in game_state.actors:
            var actor_id: String = str(member.get("id",""))
            if game_core.is_active(actor_id):
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
        if int(member.get("hp",0)) <= 0 or (game_core != null and not game_core.is_active(actor_id)):
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

func _act(action: String) -> void:
    if win_locked or hero_turn >= game_state.actors.size():
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
            if int(chosen_ally.get("hp",0)) <= 0 or (game_core != null and not game_core.is_active(str(chosen_ally.get("id","")))):
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
                            if int(person.get("hp",0)) > 0 and (game_core == null or game_core.is_active(str(person.get("id","")))):
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
                            if game_core == null or game_core.is_active(str(game_state.actors[i].get("id",""))):
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
                            if game_core == null or game_core.is_active(str(game_state.actors[i].get("id",""))):
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
            if boss and chapter == 5:
                chain_hp = maxi(0, chain_hp - maxi(20, combat_attack + dice.randi_range(8, 20)))
                message = "%s 拆除星纹锁，剩余耐久 %d！" % [name, chain_hp]
                if is_instance_valid(vfx):
                    vfx.play_special(_vfx_foe_point())
                if chain_hp == 0:
                    _redraw(message + "古兽摆脱了控制！")
                    _finish(true)
                    return
            elif boss and chapter == 6:
                resonance += 1
                countdown = mini(8, countdown + 1)
                message = "%s 汇入一段归航见证（%d/4）。" % [name, resonance]
                if is_instance_valid(vfx):
                    vfx.play_charge(_vfx_ally_point())
                if resonance >= 4:
                    _redraw(message + "共同见证替代献祭，灯塔重新点亮！")
                    _finish(true)
                    return
            else:
                damage = maxi(8, combat_attack + dice.randi_range(5, 12) - maxi(0, int(enemy["def"]) - 6))
                message = "%s 找到敌人的破绽，造成 %d 伤害。" % [name, damage]
    if boss and boss_mechanics != null and boss_mechanics.enabled():
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
            if int(ally.get("hp",0)) > 0 and (game_core == null or game_core.is_active(str(ally.get("id","")))):
                living_party += 1
        damage = combat_rules.vocation_damage(damage,passive,action,enemy,living_party)
        damage = combat_rules.release_charge(str(member.get("id","")),damage)
        if boss and boss_mechanics != null and boss_mechanics.enabled():
            damage = maxi(1,roundi(float(damage)*boss_mechanics.damage_factor(_get_skill(chosen_skill) if action == "skill" else {})))
            if boss_mechanics.protect_from_lethal():
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
            # 古兽的剧情结局是卸下星锁，而不是杀死生命体。
            chain_hp = maxi(0, chain_hp - maxi(4, int(float(damage) * 0.45)))
            if chain_hp <= 0:
                _redraw(message + "星纹锁断裂！")
                _finish(true)
                return
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
    var original_target: int = active_target
    enemy = formation.units[index]
    var effect: Dictionary = combat_rules.resolve_enemy_turn(index,int(enemy.get("max_hp",1)))
    var damage_over_time: int = int(effect.get("damage",0))
    if damage_over_time > 0:
        if boss and boss_mechanics != null and boss_mechanics.protect_from_lethal():
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
        if int(game_state.actors[i]["hp"]) > 0 and (game_core == null or game_core.is_active(str(game_state.actors[i].get("id","")))):
            living.append(i)
    if living.is_empty():
        _finish(false)
        return
    var intent: Dictionary = round_boss_intent if boss else combat_rules.enemy_strategy(enemy,current_round,phase_two,false,game_state.actors)
    last_enemy_action = str(enemy.get("name","敌人")) + " · " + str(intent.get("label","攻击"))
    if is_instance_valid(c23_boss_body_motion):
        c23_boss_body_motion.play_attack()
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
            # 倒计时归零只会迫使队伍重新凝聚见证，不产生不可逆的死档。
            countdown = 3
            resonance = maxi(0, resonance - 1)
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
    var name: String = str(intent.get("label",""))
    if name in ["","普通攻击"]:
        return
    last_warning_round = current_round
    last_warning_text = name
    if is_instance_valid(c23_boss_body_motion):
        c23_boss_body_motion.play_charge()
    vfx.play_warning(_vfx_foe_point(),name)
    if is_instance_valid(battle_hud):
        battle_hud.sync(formation.units,game_state.actors,active_target,phase_two,last_warning_text)
    if is_instance_valid(sfx):
        sfx.play_event("charge")

func _all_fallen() -> bool:
    for member in game_state.actors:
        if int(member["hp"]) > 0 and (game_core == null or game_core.is_active(str(member.get("id","")))):
            return false
    return true

func _redraw(message: String) -> void:
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
        header = "%s   星纹锁 %d/%d" % [str(enemy["name"]), chain_hp, 125]
    elif chapter == 6 and boss:
        header += "   共鸣 %d/4" % resonance
    if phase_two:
        header += "  · 二阶段"
    header += " · 意图：" + str(round_boss_intent.get("label","攻击") if boss else combat_rules.enemy_strategy(enemy,current_round,phase_two,false,game_state.actors).get("label","攻击"))
    if boss_mechanics != null and boss_mechanics.enabled():
        var state: Dictionary = boss_mechanics.report()
        header += " · 目标：" + boss_mechanics.objective_label()
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
    foe_info.text = header
    var lines: PackedStringArray = []
    for i in range(game_state.actors.size()):
        var member: Dictionary = game_state.actors[i]
        if game_core != null and not game_core.is_active(str(member.get("id",""))):
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
    for item in commands.get_children():
        if item is Button:
            item.disabled = true
    if victory:
        if boss and boss_mechanics != null and boss_mechanics.enabled() and last_boss_settlement.is_empty():
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
