extends CanvasLayer
const EncounterRegistry = preload("res://scripts/encounter_registry.gd")
const CombatRules = preload("res://scripts/combat_rules.gd")
const BattleFormation = preload("res://scripts/battle_formation.gd")
## 第一幕正式战斗循环：队伍指令、怪物数值、Boss二阶段与特殊胜利条件。
signal completed(victory: bool, xp: int, gold: int)
const BOSS_NAMES: Dictionary = {2: "雾潮寄生体", 3: "潮痕守卫", 4: "灰帷水手", 5: "缚潮古兽", 6: "潮歌守门人"}
const BOSS_ART: Dictionary = {2:"tide_ghost",3:"tide_guardian",4:"salt_wolf",5:"star_ray",6:"tide_guardian"}
const MONSTER_ART: Array[String] = ["salt_slime", "fog_crab", "shell_hermit", "tide_ghost", "sand_lizard", "salt_wolf", "white_seabird", "star_ray", "tide_guardian"]
var game_state
var game_core
var encounter_registry
var combat_rules
var formation
var active_target: int = 0
var skill_picker: PanelContainer
var encounter_data: Dictionary = {}
var chapter: int = 1
var boss: bool = false
var enemy: Dictionary = {}
var hero_turn: int = 0
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
var special_button: Button

func _ready() -> void:
    layer = 40
    dice.randomize()

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
    if boss:
        var hp: int = 145 + chapter * 55
        var dmg: int = 12 + chapter * 2
        enemy = {"name":BOSS_NAMES.get(chapter, "遗迹守卫"), "hp":hp, "max_hp":hp, "atk":dmg, "def":4+chapter, "xp":150+chapter*65, "gold":85+chapter*40, "art":BOSS_ART.get(chapter,"tide_guardian")}
        if not encounter_data.is_empty():
            enemy["name"] = str(encounter_data.get("display_name", enemy["name"]))
        enemy = encounter_registry.story_boss(chapter,encounter_data,enemy)
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
    active_target = 0
    enemy = formation.units[0]
    _build()
    _start_actor()
    _redraw("%s 出现在你们面前！" % str(enemy["name"]))

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
    backdrop.texture = load("res://assets/art/backdrops/coast/tide_lighthouse.png" if chapter >= 5 else "res://assets/art/backdrops/coast/white_sand_port.png")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_SCALE
    root.add_child(backdrop)
    var dim := ColorRect.new()
    dim.color = Color(0.015, 0.032, 0.060, 0.54)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(dim)
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
    var art: String = str(enemy["art"])
    var art_path: String = "res://assets/art/monsters/coast/%s/battle.png" % art
    if not ResourceLoader.exists(art_path):
        art_path = "res://assets/enemies/boss.png"
    portrait.texture = load(art_path)
    portrait.anchor_left = 0.38
    portrait.anchor_right = 0.62
    portrait.anchor_top = 0.15
    portrait.anchor_bottom = 0.58
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    root.add_child(portrait)
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
    var special_name: String = "✦ 拆除星锁" if chapter == 5 and boss else ("✦ 共同见证" if chapter == 6 and boss else "✦ 识破弱点")
    special_button = _button(commands, special_name, "special")

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
        var title: String = "%s · MP %d · %s" % [str(record.get("name",id)),cost,str(record.get("description",""))]
        var b: Button = _button(list,title,"skill:"+id)
        b.disabled = int(actor.get("mp",0)) < cost
    _button(list,"返回战斗","cancel_skill")

func _select_enemy(index: int) -> void:
    if formation == null or not formation.valid_target(index):
        return
    active_target = index
    enemy = formation.units[index]
    if is_instance_valid(portrait):
        var art: String = str(enemy.get("art",""))
        var path: String = "res://assets/art/monsters/coast/%s/battle.png" % art
        if not ResourceLoader.exists(path):
            path = "res://assets/enemies/boss.png"
        portrait.texture = load(path)

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

func _start_actor() -> void:
    while hero_turn < game_state.actors.size() and (int(game_state.actors[hero_turn]["hp"]) <= 0 or (game_core != null and not game_core.is_active(str(game_state.actors[hero_turn].get("id",""))))):
        hero_turn += 1
    if hero_turn >= game_state.actors.size():
        _enemy_turn()
        combat_rules.tick_round()
        hero_turn = 0
        defense.clear()
        current_round += 1
        while hero_turn < game_state.actors.size() and (int(game_state.actors[hero_turn]["hp"]) <= 0 or (game_core != null and not game_core.is_active(str(game_state.actors[hero_turn].get("id",""))))):
            hero_turn += 1
    if hero_turn >= game_state.actors.size() and not win_locked:
        _finish(false)

func _act(action: String) -> void:
    if win_locked or hero_turn >= game_state.actors.size():
        return
    if action in ["attack","special"] and not boss and formation.alive_indices().size() > 1:
        _choose_enemy_target(action)
        return
    if action == "skill":
        _choose_skill()
        return
    if action == "cancel_skill":
        _hide_skills()
        return
    if "#" in action:
        var enemy_select: PackedStringArray = action.split("#",false,1)
        if enemy_select.size() != 2 or not formation.valid_target(int(enemy_select[1])):
            _redraw("该敌人已经被击败，请重新选择。")
            return
        _select_enemy(int(enemy_select[1]))
        action = str(enemy_select[0])
        _hide_skills()
    var chosen_skill: String = ""
    var target_index: int = hero_turn
    var hit_all_enemies: bool = false
    if action.begins_with("skill:"):
        var token: String = action.trim_prefix("skill:")
        if "@" in token:
            var fields: PackedStringArray = token.split("@",false,1)
            chosen_skill = str(fields[0])
            target_index = int(fields[1])
        else:
            chosen_skill = token
            var candidate: Dictionary = _get_skill(chosen_skill)
            if str(candidate.get("target","")) == "single_ally":
                _choose_target(chosen_skill)
                return
            if str(candidate.get("target","")) == "single_enemy" and formation.alive_indices().size() > 1:
                _choose_enemy_target("skill:"+chosen_skill)
                return
        action = "skill"
        _hide_skills()
        hit_all_enemies = str(_get_skill(chosen_skill).get("target","")) == "all_enemies"
    var member: Dictionary = game_state.actors[hero_turn]
    var name: String = str(member["name"])
    var stats: Dictionary = game_core.gear_stats(str(member.get("id",""))) if game_core != null else member
    var combat_attack: int = int(stats.get("attack",member.get("attack",0))) + combat_rules.attack_bonus(str(member.get("id","")))
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
                var power: int = int(effect.get("power",0))
                var target_type: String = str(chosen.get("target","single_enemy"))
                var label: String = str(chosen.get("name","技能"))
                if kind == "heal":
                    game_state.actors[hero_turn] = member
                    if target_type == "all_allies":
                        for i in range(game_state.actors.size()):
                            var person: Dictionary = game_state.actors[i]
                            if int(person.get("hp",0)) > 0 and (game_core == null or game_core.is_active(str(person.get("id","")))):
                                game_state.heal_member(i,maxi(10,power))
                        message = "%s 施展%s，全队恢复体力。" % [name,label]
                    else:
                        if target_index >= 0 and target_index < game_state.actors.size():
                            game_state.heal_member(target_index,maxi(20,power*2))
                        message = "%s 施展%s，治疗%s。" % [name,label,str(game_state.actors[target_index].get("name",""))]
                    healed_via_skill = true
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
                else:
                    var base: int = maxi(3,combat_attack + power - int(enemy["def"]))
                    damage = combat_rules.elemental_damage(base,str(chosen.get("element","")),str(enemy.get("weakness","")),str(enemy.get("element","")))
                    message = "%s 发动%s，造成%d伤害%s" % [name,label,damage,"！ 触发弱点！" if str(chosen.get("element","")) == str(enemy.get("weakness","")) else "。"]
        "charge":
            var stack: int = combat_rules.charge(str(member.get("id","")))
            message = "%s 凝聚星辉（%d/3），下一次攻击威力提高！" % [name,stack]
        "guard":
            defense[hero_turn] = true
            message = "%s 严阵以待，本回合受到的伤害降低。" % name
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
            message = "%s 使用药草恢复生命。" % name
        "special":
            if boss and chapter == 5:
                chain_hp = maxi(0, chain_hp - maxi(20, combat_attack + dice.randi_range(8, 20)))
                message = "%s 拆除星纹锁，剩余耐久 %d！" % [name, chain_hp]
                if chain_hp == 0:
                    _redraw(message + "古兽摆脱了控制！")
                    _finish(true)
                    return
            elif boss and chapter == 6:
                resonance += 1
                countdown = mini(8, countdown + 1)
                message = "%s 汇入一段归航见证（%d/4）。" % [name, resonance]
                if resonance >= 4:
                    _redraw(message + "共同见证替代献祭，灯塔重新点亮！")
                    _finish(true)
                    return
            else:
                damage = maxi(8, combat_attack + dice.randi_range(5, 12) - maxi(0, int(enemy["def"]) - 6))
                message = "%s 找到敌人的破绽，造成 %d 伤害。" % [name, damage]
    if not healed_via_skill:
        game_state.actors[hero_turn] = member
    if damage > 0:
        damage = combat_rules.release_charge(str(member.get("id","")),damage)
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
            enemy = formation.units[active_target]
        else:
            formation.apply_damage(active_target,damage)
            enemy = formation.units[active_target]
    if not phase_two and boss and int(enemy["hp"]) <= int(enemy["max_hp"]) / 2:
        phase_two = true
        message += "  敌人进入第二阶段！"
        enemy["atk"] = int(enemy["atk"]) + 4
    if formation.complete() and (not boss or chapter != 5):
        _redraw(message)
        _finish(true)
        return
    if not formation.valid_target(active_target):
        var remaining: Array[int] = formation.alive_indices()
        if not remaining.is_empty():
            _select_enemy(remaining[0])
    hero_turn += 1
    _start_actor()
    if not win_locked:
        _redraw(message)

func _enemy_turn() -> void:
    if win_locked:
        return
    var original_target: int = active_target
    for index in formation.alive_indices():
        if win_locked:
            break
        enemy = formation.units[index]
        _enemy_strike()
    if formation.valid_target(original_target):
        _select_enemy(original_target)
    elif not formation.alive_indices().is_empty():
        _select_enemy(formation.alive_indices()[0])

func _enemy_strike() -> void:
    var living: Array[int] = []
    for i in range(game_state.actors.size()):
        if int(game_state.actors[i]["hp"]) > 0 and (game_core == null or game_core.is_active(str(game_state.actors[i].get("id","")))):
            living.append(i)
    if living.is_empty():
        _finish(false)
        return
    var intent: Dictionary = combat_rules.enemy_intent(current_round,phase_two,boss)
    var target: int = living[dice.randi_range(0, living.size() - 1)]
    if str(intent.get("target","")) == "lowest_hp":
        for i in living:
            if int(game_state.actors[i].get("hp",0)) < int(game_state.actors[target].get("hp",0)):
                target = i
    var member: Dictionary = game_state.actors[target]
    var stats: Dictionary = game_core.gear_stats(str(member.get("id",""))) if game_core != null else member
    var raw_damage: int = maxi(1, roundi((int(enemy["atk"]) + dice.randi_range(-3, 5) - int(stats.get("defense",member["defense"]))) * float(intent.get("multiplier",1.0))))
    var damage: int = combat_rules.mitigated_damage(raw_damage,str(member.get("id","")),defense.has(target))
    if invincible:
        damage = 0
    member["hp"] = maxi(0, int(member["hp"]) - damage)
    game_state.actors[target] = member
    if boss and chapter == 6:
        countdown -= 1
        if countdown <= 0:
            # 倒计时归零只会迫使队伍重新凝聚见证，不产生不可逆的死档。
            countdown = 3
            resonance = maxi(0, resonance - 1)
    if _all_fallen():
        _finish(false)

func _all_fallen() -> bool:
    for member in game_state.actors:
        if int(member["hp"]) > 0 and (game_core == null or game_core.is_active(str(member.get("id","")))):
            return false
    return true

func _redraw(message: String) -> void:
    report.text = message
    var header: String = "%s   HP %d/%d" % [str(enemy["name"]), int(enemy["hp"]), int(enemy["max_hp"])]
    if chapter == 5 and boss:
        header = "%s   星纹锁 %d/%d" % [str(enemy["name"]), chain_hp, 125]
    elif chapter == 6 and boss:
        header += "   共鸣 %d/4" % resonance
    if phase_two:
        header += "  · 二阶段"
    header += " · 下一步：" + str(combat_rules.enemy_intent(current_round,phase_two,boss).get("label","攻击"))
    if formation != null and formation.units.size() > 1:
        var roster: Array[String] = []
        for i in range(formation.units.size()):
            var unit: Dictionary = formation.units[i]
            if int(unit.get("hp",0)) > 0:
                roster.append(("%d▶" % (i+1) if i == active_target else "%d" % (i+1))+" "+str(unit.get("name",""))+" "+str(unit.get("hp",0))+"HP")
        header = " | ".join(roster)
    foe_info.text = header
    var lines: PackedStringArray = []
    for i in range(game_state.actors.size()):
        var member: Dictionary = game_state.actors[i]
        if game_core != null and not game_core.is_active(str(member.get("id",""))):
            continue
        var current: String = "[color=#f9d58b]▶ " if i == hero_turn else "[color=#c9e4eb]"
        var status: Dictionary = combat_rules.actor_effects.get(str(member.get("id","")),{})
        var buffs: String = (" ✦增强" if int(status.get("attack_turns",0)) > 0 else "") + (" ◈护盾" if int(status.get("shield_turns",0)) > 0 else "") + (" ★聚星%d" % int(status.get("star_charge",0)) if int(status.get("star_charge",0)) > 0 else "")
        lines.append("%s%s  Lv.%d   HP %d/%d  MP %d/%d%s[/color]" % [current, str(member["name"]), int(member["level"]), int(member["hp"]), int(member["max_hp"]), int(member["mp"]), int(member["max_mp"]),buffs])
    party_info.text = "    ".join(lines)

func _finish(victory: bool) -> void:
    if win_locked:
        return
    win_locked = true
    for item in commands.get_children():
        if item is Button:
            item.disabled = true
    if victory:
        report.text = "胜利！%s" % ("古兽已经重获自由。" if boss and chapter == 5 else "战斗结束，大家平安归来。")
    else:
        report.text = "全队失去战斗力，准备在营地重新整备。"
    var reward: Dictionary = formation.rewards() if formation != null else {"xp":int(enemy["xp"]),"gold":int(enemy["gold"])}
    completed.emit(victory, int(reward["xp"]) if victory else 0, int(reward["gold"]) if victory else 0)
