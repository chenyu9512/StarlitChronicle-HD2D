extends CanvasLayer
## 第一幕正式战斗循环：队伍指令、怪物数值、Boss二阶段与特殊胜利条件。
signal completed(victory: bool, xp: int, gold: int)
const BOSS_NAMES: Dictionary = {2: "雾潮寄生体", 3: "潮痕守卫", 4: "灰帷水手", 5: "缚潮古兽", 6: "潮歌守门人"}
const BOSS_ART: Dictionary = {2:"tide_ghost",3:"tide_guardian",4:"salt_wolf",5:"star_ray",6:"tide_guardian"}
const MONSTER_ART: Array[String] = ["salt_slime", "fog_crab", "shell_hermit", "tide_ghost", "sand_lizard", "salt_wolf", "white_seabird", "star_ray", "tide_guardian"]
var game_state
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
        chain_hp = 125 if chapter == 5 else 0
    else:
        var monster_number: int = dice.randi_range(0, mini(8, chapter + 2))
        var monster_names: Array[String] = ["盐泥团", "雾壳蟹", "寄壳隐士", "潮雾幽灵", "砂蜥", "盐牙狼", "白沙海鸟", "星纹鳐", "潮痕守卫"]
        var hp: int = 25 + chapter * 10 + monster_number * 8
        enemy = {"name":monster_names[monster_number], "hp":hp, "max_hp":hp, "atk":7+chapter*2+monster_number, "def":2+int(monster_number/2), "xp":20+chapter*8+monster_number*3, "gold":12+chapter*4+monster_number*2, "art":MONSTER_ART[monster_number]}
        chain_hp = 0
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
    _button(commands, "✚ 药草", "potion")
    var special_name: String = "✦ 拆除星锁" if chapter == 5 and boss else ("✦ 共同见证" if chapter == 6 and boss else "✦ 识破弱点")
    special_button = _button(commands, special_name, "special")

func _start_actor() -> void:
    while hero_turn < game_state.actors.size() and int(game_state.actors[hero_turn]["hp"]) <= 0:
        hero_turn += 1
    if hero_turn >= game_state.actors.size():
        _enemy_turn()
        hero_turn = 0
        defense.clear()
        current_round += 1
        while hero_turn < game_state.actors.size() and int(game_state.actors[hero_turn]["hp"]) <= 0:
            hero_turn += 1
    if hero_turn >= game_state.actors.size() and not win_locked:
        _finish(false)

func _act(action: String) -> void:
    if win_locked or hero_turn >= game_state.actors.size():
        return
    var member: Dictionary = game_state.actors[hero_turn]
    var name: String = str(member["name"])
    var message: String = ""
    var damage: int = 0
    match action:
        "attack":
            damage = maxi(3, int(member["attack"]) + dice.randi_range(-5, 8) - int(enemy["def"]))
            message = "%s 攻击造成 %d 伤害。" % [name, damage]
        "skill":
            if int(member["mp"]) < 6:
                _redraw("%s 的 MP 不够。" % name)
                return
            member["mp"] = int(member["mp"]) - 6
            if str(member["id"]) == "char_tidecaller":
                var best_index: int = 0
                for idx in range(game_state.actors.size()):
                    if int(game_state.actors[idx]["max_hp"]) - int(game_state.actors[idx]["hp"]) > int(game_state.actors[best_index]["max_hp"]) - int(game_state.actors[best_index]["hp"]):
                        best_index = idx
                game_state.actors[hero_turn] = member
                game_state.heal_member(best_index, 48 + int(member["level"]) * 3)
                message = "%s 使用潮愈术，治疗了 %s！" % [name, str(game_state.actors[best_index]["name"])]
            else:
                damage = maxi(8, int(member["attack"]) + dice.randi_range(15, 29) - int(enemy["def"]))
                message = "%s 发动%s，造成 %d 伤害！" % [name, str(member["skill"]), damage]
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
            game_state.potions -= 1
            message = "%s 使用药草恢复生命。" % name
        "special":
            if boss and chapter == 5:
                chain_hp = maxi(0, chain_hp - maxi(20, int(member["attack"]) + dice.randi_range(8, 20)))
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
                damage = maxi(8, int(member["attack"]) + dice.randi_range(5, 12) - maxi(0, int(enemy["def"]) - 6))
                message = "%s 找到敌人的破绽，造成 %d 伤害。" % [name, damage]
    game_state.actors[hero_turn] = member if action != "skill" or str(member["id"]) != "char_tidecaller" else game_state.actors[hero_turn]
    if damage > 0:
        if boss and chapter == 5:
            # 古兽的剧情结局是卸下星锁，而不是杀死生命体。
            chain_hp = maxi(0, chain_hp - maxi(4, int(float(damage) * 0.45)))
            if chain_hp <= 0:
                _redraw(message + "星纹锁断裂！")
                _finish(true)
                return
        else:
            enemy["hp"] = maxi(0, int(enemy["hp"]) - damage)
    if not phase_two and boss and int(enemy["hp"]) <= int(enemy["max_hp"]) / 2:
        phase_two = true
        message += "  敌人进入第二阶段！"
        enemy["atk"] = int(enemy["atk"]) + 4
    if int(enemy["hp"]) <= 0 and (not boss or chapter != 5):
        _redraw(message)
        _finish(true)
        return
    hero_turn += 1
    _start_actor()
    if not win_locked:
        _redraw(message)

func _enemy_turn() -> void:
    if win_locked:
        return
    var living: Array[int] = []
    for i in range(game_state.actors.size()):
        if int(game_state.actors[i]["hp"]) > 0:
            living.append(i)
    if living.is_empty():
        _finish(false)
        return
    var target: int = living[dice.randi_range(0, living.size() - 1)]
    var member: Dictionary = game_state.actors[target]
    var damage: int = maxi(1, int(enemy["atk"]) + dice.randi_range(-3, 5) - int(member["defense"]))
    if defense.has(target):
        damage = maxi(1, int(float(damage) * 0.35))
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
        if int(member["hp"]) > 0:
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
    foe_info.text = header
    var lines: PackedStringArray = []
    for i in range(game_state.actors.size()):
        var member: Dictionary = game_state.actors[i]
        var current: String = "[color=#f9d58b]▶ " if i == hero_turn else "[color=#c9e4eb]"
        lines.append("%s%s  Lv.%d   HP %d/%d  MP %d/%d[/color]" % [current, str(member["name"]), int(member["level"]), int(member["hp"]), int(member["max_hp"]), int(member["mp"]), int(member["max_mp"])])
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
    completed.emit(victory, int(enemy["xp"]) if victory else 0, int(enemy["gold"]) if victory else 0)
