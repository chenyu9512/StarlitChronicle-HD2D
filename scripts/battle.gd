extends CanvasLayer
const CArtOverrides = preload("res://scripts/c_art_overrides.gd")
## Playable two-character command battle: attack, special, defend, potion.
## Rewards and party HP/MP are passed back to the campaign coordinator.

signal finished(victory: bool, was_boss: bool, xp: int, gold: int)

var root: Control
var party_label: Label
var enemy_label: Label
var narration: Label
var command_title: Label
var enemy_sprites: Array[TextureRect] = []
var buttons: Array[Button] = []
var enemies: Array[Dictionary] = []
var actor_index := 0
var boss_fight := false
var defending: Dictionary = {}
var rng := RandomNumberGenerator.new()
var battle_over := false
const ContentDB = preload("res://scripts/content_db.gd")

func _ready() -> void:
    layer = 30
    rng.randomize()
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    var bg := TextureRect.new()
    bg.texture = CArtOverrides.texture("res://assets/maps/battle_ruins.png")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    root.add_child(bg)
    var tint := ColorRect.new()
    tint.color = Color(0.028, 0.049, 0.11, 0.22)
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(tint)

    enemy_label = _label(22, Color(1, 0.93, 0.76))
    enemy_label.anchor_left = 0.3
    enemy_label.anchor_right = 0.7
    enemy_label.anchor_top = 0.1
    enemy_label.anchor_bottom = 0.28
    enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(enemy_label)

    var enemy_area := HBoxContainer.new()
    enemy_area.anchor_left = 0.24
    enemy_area.anchor_right = 0.76
    enemy_area.anchor_top = 0.26
    enemy_area.anchor_bottom = 0.60
    enemy_area.alignment = BoxContainer.ALIGNMENT_CENTER
    enemy_area.add_theme_constant_override("separation", 40)
    enemy_area.name = "EnemyArea"
    root.add_child(enemy_area)
    for j in range(2):
        var portrait := TextureRect.new()
        portrait.custom_minimum_size = Vector2(180, 180)
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        enemy_area.add_child(portrait)
        enemy_sprites.append(portrait)

    var control_panel := PanelContainer.new()
    control_panel.anchor_left = 0.055
    control_panel.anchor_right = 0.945
    control_panel.anchor_top = 0.63
    control_panel.anchor_bottom = 0.97
    control_panel.add_theme_stylebox_override("panel", _panel_style())
    root.add_child(control_panel)
    var main_flow := VBoxContainer.new()
    main_flow.add_theme_constant_override("separation", 6)
    control_panel.add_child(main_flow)
    narration = _label(20, Color(1, 0.91, 0.69))
    narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    main_flow.add_child(narration)
    party_label = _label(17, Color(0.8, 0.95, 1))
    main_flow.add_child(party_label)
    command_title = _label(19, Color(0.95, 0.88, 0.98))
    main_flow.add_child(command_title)
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 12)
    main_flow.add_child(actions)
    var labels := ["⚔ 攻击", "✦ 技能", "◆ 防御", "✚ 药草"]
    var keys := ["attack", "skill", "defend", "potion"]
    for i in range(labels.size()):
        var button := Button.new()
        button.text = labels[i]
        button.custom_minimum_size = Vector2(130, 56)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 22)
        button.add_theme_color_override("font_color", Color(1, 0.98, 0.91))
        button.add_theme_stylebox_override("normal", _panel_style())
        button.add_theme_stylebox_override("hover", _panel_style())
        button.focus_mode = Control.FOCUS_NONE
        var action_key: String = keys[i]
        button.pressed.connect(func() -> void: _act(action_key))
        actions.add_child(button)
        buttons.append(button)

func _panel_style() -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color(0.07, 0.10, 0.20, 0.93)
    box.border_color = Color(0.73, 0.72, 0.91, 0.9)
    box.set_border_width_all(2)
    box.set_corner_radius_all(9)
    box.set_content_margin_all(12)
    return box

func _label(size: int, color_value: Color) -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color_value)
    return label

func begin(is_boss: bool) -> void:
    boss_fight = is_boss
    actor_index = 0
    defending.clear()
    battle_over = false
    if boss_fight:
        enemies = [{"name":"遗迹守卫·阿斯特", "id":"boss", "hp":158, "max_hp":158, "attack":18, "defense":5, "xp":82, "gold":70}]
        narration.text = "古代守卫苏醒了！星光凝聚成巨大身影！"
    else:
        var pick := rng.randi_range(0, 2)
        if pick == 0:
            enemies = [
                {"name":"青露软泥", "id":"slime", "hp":32, "max_hp":32, "attack":9, "defense":1, "xp":12, "gold":8},
                {"name":"青露软泥", "id":"slime", "hp":32, "max_hp":32, "attack":9, "defense":1, "xp":12, "gold":8}
            ]
        elif pick == 1:
            enemies = [{"name":"暮影蝠", "id":"bat", "hp":47, "max_hp":47, "attack":12, "defense":2, "xp":26, "gold":14}]
        else:
            enemies = [{"name":"石甲幽灵", "id":"golem", "hp":64, "max_hp":64, "attack":14, "defense":4, "xp":32, "gold":20}]
        narration.text = "野生魔物出现了！"
    _next_living_actor()
    _refresh()

func begin_story(enemy_id: String, display_name: String) -> void:
    boss_fight = true
    actor_index = 0
    defending.clear()
    battle_over = false
    var entry: Dictionary = ContentDB.lookup("bosses", enemy_id)
    if entry.is_empty():
        entry = ContentDB.lookup("monsters", enemy_id)
    var chapter_level: int = maxi(1, State.story_chapter)
    var level_scale: int = maxi(1, mini(50, chapter_level * 2))
    var image_path: String = str(entry.get("preview_fallback", "res://assets/enemies/boss.png"))
    if not CArtOverrides.exists(image_path):
        image_path = "res://assets/enemies/boss.png"
    enemies = [{
        "name": display_name, "id": enemy_id, "sprite_path": image_path,
        "hp": int(entry.get("hp", 85 + level_scale * 18)),
        "max_hp": int(entry.get("hp", 85 + level_scale * 18)),
        "attack": int(entry.get("attack", 12 + level_scale * 2)),
        "defense": int(entry.get("defense", 3 + level_scale)),
        "xp": int(entry.get("xp", 60 + level_scale * 15)),
        "gold": int(entry.get("gold", 25 + level_scale * 6))
    }]
    narration.text = display_name + " 出现在你们面前！"
    _next_living_actor()
    _refresh()

func _refresh() -> void:
    var enemy_info := ""
    for i in range(enemies.size()):
        var monster: Dictionary = enemies[i]
        enemy_info += "%s  HP %d/%d\n" % [monster["name"], maxi(0, int(monster["hp"])), monster["max_hp"]]
    enemy_label.text = enemy_info
    for i in range(enemy_sprites.size()):
        var portrait := enemy_sprites[i]
        portrait.visible = i < enemies.size() and int(enemies[i]["hp"]) > 0
        if i < enemies.size():
            var sprite_path: String = str(enemies[i].get("sprite_path", "res://assets/enemies/%s.png" % str(enemies[i]["id"])))
            if CArtOverrides.exists(sprite_path):
                portrait.texture = CArtOverrides.texture(sprite_path)
    var stats := ""
    for person in State.party:
        stats += "%s  HP %s/%s  MP %s/%s       " % [person["name"], person["hp"], person["max_hp"], person["mp"], person["max_mp"]]
    party_label.text = stats
    if actor_index < State.party.size():
        command_title.text = "轮到 %s 行动 — %s" % [State.party[actor_index]["name"], State.party[actor_index]["skill"]]

func _act(kind: String) -> void:
    if battle_over:
        return
    var actor: Dictionary = State.party[actor_index]
    if int(actor["hp"]) <= 0:
        _advance_actor()
        return
    var action_text := ""
    if kind == "potion":
        if State.potions <= 0:
            narration.text = "药草不足！请选择其他行动。"
            return
        if int(actor["hp"]) >= int(actor["max_hp"]):
            narration.text = "这名角色生命值已满。"
            return
        State.potions -= 1
        actor["hp"] = mini(int(actor["max_hp"]), int(actor["hp"]) + 40)
        State.party[actor_index] = actor
        action_text = "%s 使用药草，恢复生命！" % actor["name"]
    elif kind == "defend":
        defending[actor_index] = true
        action_text = "%s 举起武器，进入防御姿态。" % actor["name"]
    elif kind == "skill":
        var mp_cost := 6
        if not State.cheat_god and int(actor["mp"]) < mp_cost:
            narration.text = "MP 不足！请选择普通攻击或道具。"
            return
        actor["mp"] = int(actor["mp"]) if State.cheat_god else int(actor["mp"]) - mp_cost
        State.party[actor_index] = actor
        var damage := maxi(4, int(actor["attack"]) + rng.randi_range(12, 22) - _target_defense())
        var hit_name := _hit_enemy(damage)
        action_text = "%s 发动%s！对%s造成 %d 伤害！" % [actor["name"], actor["skill"], hit_name, damage]
    else:
        var damage := maxi(2, int(actor["attack"]) + rng.randi_range(-3, 6) - _target_defense())
        var hit_name := _hit_enemy(damage)
        action_text = "%s 攻击%s，造成 %d 伤害。" % [actor["name"], hit_name, damage]
    narration.text = action_text
    if _all_enemies_down():
        battle_over = true
        var total_xp := 0
        var total_gold := 0
        for enemy in enemies:
            total_xp += int(enemy["xp"])
            total_gold += int(enemy["gold"])
        finished.emit(true, boss_fight, total_xp, total_gold)
        return
    _advance_actor()
    if not battle_over:
        _refresh()

func _hit_enemy(damage: int) -> String:
    for enemy in enemies:
        if int(enemy["hp"]) > 0:
            enemy["hp"] = maxi(0, int(enemy["hp"]) - damage)
            return str(enemy["name"])
    return "魔物"

func _target_defense() -> int:
    for enemy in enemies:
        if int(enemy["hp"]) > 0:
            return int(enemy["defense"])
    return 0

func _all_enemies_down() -> bool:
    for enemy in enemies:
        if int(enemy["hp"]) > 0:
            return false
    return true

func _advance_actor() -> void:
    actor_index += 1
    while actor_index < State.party.size() and int(State.party[actor_index]["hp"]) <= 0:
        actor_index += 1
    if actor_index >= State.party.size():
        _enemy_phase()
        actor_index = 0
        defending.clear()
        _next_living_actor()

func _next_living_actor() -> void:
    while actor_index < State.party.size() and int(State.party[actor_index]["hp"]) <= 0:
        actor_index += 1

func _enemy_phase() -> void:
    var summary: Array[String] = []
    for monster in enemies:
        if int(monster["hp"]) <= 0:
            continue
        var living: Array[int] = []
        for idx in range(State.party.size()):
            if int(State.party[idx]["hp"]) > 0:
                living.append(idx)
        if living.is_empty():
            break
        var victim_index := living[rng.randi_range(0, living.size() - 1)]
        var victim: Dictionary = State.party[victim_index]
        var dmg := maxi(1, int(monster["attack"]) + rng.randi_range(-3, 4) - int(victim["defense"]))
        if defending.has(victim_index):
            dmg = maxi(1, int(dmg / 2))
        if State.cheat_god:
            dmg = 0
        victim["hp"] = maxi(0, int(victim["hp"]) - dmg)
        State.party[victim_index] = victim
        summary.append("%s 攻击%s（-%d HP）" % [monster["name"], victim["name"], dmg])
    narration.text = "；".join(summary)
    var all_fallen := true
    for person in State.party:
        if int(person["hp"]) > 0:
            all_fallen = false
    if all_fallen:
        battle_over = true
        finished.emit(false, boss_fight, 0, 0)
