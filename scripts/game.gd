extends Node2D
## Game coordinator: exploration, quests, map transitions, battles and saves.

const WorldScript = preload("res://scripts/world.gd")
const UIScript = preload("res://scripts/game_ui.gd")
const BattleScript = preload("res://scripts/battle.gd")

var world
var ui
var battle
var busy := false

func _ready() -> void:
    var resumed := State.load_game()
    world = WorldScript.new()
    add_child(world)
    world.interaction_requested.connect(_handle_interaction)
    world.encounter_requested.connect(_on_encounter)
    world.load_map(State.map_id, State.spawn_tile)
    ui = UIScript.new()
    add_child(ui)
    ui.action_requested.connect(_interact)
    ui.menu_requested.connect(_open_menu)
    ui.menu_closed.connect(_unlock_world)
    ui.dialog_closed.connect(_unlock_world)
    ui.save_requested.connect(_save)
    ui.potion_requested.connect(_use_potion)
    ui.move_changed.connect(_on_move_changed)
    _refresh_hud()
    busy = true
    world.locked = true
    if resumed:
        _say(["欢迎回来，旅人。", "你的冒险已从上次存档继续。"])
    else:
        _say(["星灯纪行 · 序章：落星的回声", "夜空失去了一颗星。村中的古灯随之熄灭……", "寻找守灯人，开启属于你的旅程。", "左下角移动，右下角互动；也可用 WASD / E。"])

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        if ui.is_dialog_open():
            ui.advance_dialog()
        elif not busy:
            _interact()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("open_menu") and not busy:
        _open_menu()
        get_viewport().set_input_as_handled()

func _on_move_changed(dir: Vector2) -> void:
    world.input_vector = dir

func _interact() -> void:
    if busy:
        return
    if not world.interact():
        _say(["这里似乎没有可以调查的东西。"])

func _handle_interaction(kind: String, _data: Dictionary) -> void:
    match kind:
        "elder":
            if State.quest_stage == 0:
                State.quest_stage = 1
                _say(["守灯人：你终于来了，年轻的旅人。", "沉睡的星核就在东面的星落遗迹。", "请带回它。没有星光，村庄将迎来漫长的黑夜。", "澪：我会陪你一起去。别担心！"])
            elif State.quest_stage == 1 and State.boss_defeated:
                State.quest_stage = 2
                State.gold += 120
                State.fully_heal()
                _say(["守灯人：这是……真正的星核！", "古灯重新点亮。你们让晨露村恢复了光明！", "获得 120 金币！队伍生命与魔力已恢复。", "【序章完成】更辽阔的世界，仍在星空下等待。"])
            elif State.quest_stage == 1:
                _say(["守灯人：东边石门后就是星落遗迹。", "击败守在最深处的古代守卫，带回星核吧。"])
            else:
                _say(["守灯人：星光会为你的前路指明方向。", "感谢你，星灯的守护者。"])
        "merchant":
            if State.gold >= 20:
                State.gold -= 20
                State.potions += 1
                _say(["行商：欢迎！药草一份，20 金币。", "购买成功！现在有 %d 份药草。" % State.potions])
            else:
                _say(["行商：药草一份 20 金币。", "哎呀，你的金币还不够呢。"])
        "portal_to_ruins":
            _change_map("ruins", Vector2i(4, 14))
            _say(["你们踏进幽暗的星落遗迹……", "遗迹内行走时可能遭遇怪物。"])
        "portal_to_village":
            _change_map("village", Vector2i(39, 14))
            _say(["晨露村温暖的灯火出现在眼前。"])
        "boss":
            _start_battle(true)
        "chest":
            if not State.opened_chests.has("ruins_chest"):
                State.opened_chests.append("ruins_chest")
                State.potions += 3
                _say(["打开古老的宝箱……", "发现了 3 份药草！"])
                _change_map("ruins", world.get_player_tile())
            else:
                _say(["宝箱已经空了。"])
        "opened_chest":
            _say(["宝箱已经空了。"])
        "monument":
            _say(["石碑上刻着模糊的文字：", "「当星辰坠落，向着最后的灯火前进。」"])
        "well":
            State.fully_heal()
            _say(["泉水带着清凉的星光。", "队伍的 HP 和 MP 全部恢复了！"])
        _:
            _say(["这里安静得出奇。"])
    _refresh_hud()

func _change_map(id: String, spawn: Vector2i) -> void:
    busy = false
    State.map_id = id
    State.spawn_tile = spawn
    world.input_vector = Vector2.ZERO
    world.load_map(id, spawn)
    _refresh_hud()
    State.save_game()

func _on_encounter() -> void:
    _start_battle(false)

func _start_battle(is_boss: bool) -> void:
    busy = true
    world.locked = true
    world.input_vector = Vector2.ZERO
    ui.set_exploration_visible(false)
    battle = BattleScript.new()
    add_child(battle)
    battle.finished.connect(_on_battle_finished)
    battle.begin(is_boss)

func _on_battle_finished(victory: bool, was_boss: bool, xp: int, gold: int) -> void:
    if is_instance_valid(battle):
        battle.queue_free()
    ui.set_exploration_visible(true)
    busy = false
    if victory:
        var messages: Array[String] = ["战斗胜利！获得 %d 经验与 %d 金币。" % [xp, gold]]
        for line in State.grant_rewards(xp, gold):
            messages.append(line)
        if was_boss:
            State.boss_defeated = true
            messages.append("得到了失落的星核！返回晨露村找守灯人吧。")
            _change_map("ruins", world.get_player_tile())
        State.spawn_tile = world.get_player_tile()
        State.save_game()
        _say(messages)
    else:
        State.gold = maxi(0, State.gold - 10)
        State.fully_heal()
        _change_map("village", Vector2i(12, 17))
        _say(["队伍倒下了……", "守灯人在村庄找到了你们。", "损失至多 10 金币；生命与魔力已恢复。"])
    _refresh_hud()

func _open_menu() -> void:
    if busy:
        return
    busy = true
    world.locked = true
    world.input_vector = Vector2.ZERO
    ui.show_menu()

func _unlock_world() -> void:
    busy = false
    world.locked = false
    _refresh_hud()

func _save() -> void:
    State.spawn_tile = world.get_player_tile()
    var success := State.save_game()
    ui.set_menu_message("保存成功！" if success else "保存失败，请检查设备空间。")

func _use_potion() -> void:
    if State.potions <= 0:
        ui.set_menu_message("药草已用完。")
        return
    var candidate := -1
    var missing := 0
    for index in range(State.party.size()):
        var person: Dictionary = State.party[index]
        var gap := int(person["max_hp"]) - int(person["hp"])
        if gap > missing:
            missing = gap
            candidate = index
    if candidate == -1:
        ui.set_menu_message("大家都很健康，不需要使用药草。")
        return
    var person: Dictionary = State.party[candidate]
    person["hp"] = mini(int(person["max_hp"]), int(person["hp"]) + 40)
    State.party[candidate] = person
    State.potions -= 1
    ui.set_menu_message("%s 恢复了生命值！" % person["name"])
    _refresh_hud()

func _refresh_hud() -> void:
    if is_instance_valid(ui):
        ui.refresh_hud()

func _say(lines: Array[String]) -> void:
    busy = true
    world.locked = true
    world.input_vector = Vector2.ZERO
    ui.show_dialog(lines)
