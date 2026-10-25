extends SceneTree
## 玩家房屋+职业战斗完整机制验收：地契、房间、家具、仓库、休息、存档及策略。
const State = preload("res://scripts/first_act_state.gd")
const Housing = preload("res://scripts/housing_service.gd")
const Room = preload("res://scripts/housing_room.gd")
const Combat = preload("res://scripts/combat_rules.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
const RPG = preload("res://scripts/rpg_core.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func require(condition: bool, problem: String) -> void:
    if not condition:
        failures.append(problem)

func _run() -> void:
    var state = State.new()
    state.new_game()
    state.chapter = 1
    state.gold = 1500
    var house = Housing.new()
    house.bind(state)
    require(house.goods.size() == 20,"Expected twenty original furniture designs")
    require(not house.owned(),"New save must not own house")
    require(not house.purchase({"kind":"field","region_id":"region_coast"}).begins_with("成功"),"Player purchased land outside town")
    require(house.purchase({"kind":"town","region_id":"region_coast"}).begins_with("成功"),"Cannot buy home in town")
    require(house.owned(),"House not marked owned")
    require(house.valid_layout(),"Initial house layout invalid")
    require((house.data()["placed"] as Array).size() == 2,"Starter furniture count incorrect")
    state.actors[0]["hp"] = 1
    require(house.rest().begins_with("全队"),"Bed does not permit resting")
    require(int(state.actors[0]["hp"]) == int(state.actors[0]["max_hp"]),"Bed did not heal")
    var original: int = state.potions
    require(house.deposit("item_herb_01").begins_with("已经"),"Deposit herb failed")
    require(state.potions == original-1,"Herb count not synced after deposit")
    require(house.withdraw("item_herb_01").begins_with("已经"),"Withdraw herb failed")
    require(state.potions == original,"Herb count not synced after withdraw")
    require(house.buy_furniture("table_wood").begins_with("购入"),"Furniture purchase failed")
    require(house.place("table_wood",3,3).begins_with("已布置"),"Furniture placement failed")
    require(not house.place("table_wood",3,3).begins_with("已布置"),"Overlapping furniture allowed")
    require(not house.place("table_wood",4,6).begins_with("已布置"),"Doorway was blocked")
    require(house.remove_at(3,3).begins_with("已收回"),"Furniture pick up failed")
    require(house.stock("table_wood") == 1,"Returned furniture not in stock")
    require(house.recolor("wall","星夜蓝").begins_with("已更换"),"Wall recolor failed")
    require(house.upgrade().begins_with("升级成功"),"House tier upgrade failed")
    require(house.valid_layout(),"Layout invalid after upgrade")
    var room = Room.new()
    root.add_child(room)
    room.open_house(house,state)
    require(room.root.visible,"The housing room window did not open")
    require(room.tiles.get_child_count() == 70,"Interactive 10x7 floor not built")
    room._pick("table_wood")
    room._click(3,3)
    require(not house.at(3,3).is_empty(),"Room grid did not place item")
    room.close_house()
    require(not room.root.visible,"House did not close")
    state.rpg["settings"] = {"difficulty":"挑战"}
    var rules = Combat.new()
    rules.start(state.rpg["settings"])
    require(rules.modifier() > 1.3,"Challenge difficulty not applied")
    require(rules.elemental_damage(100,"光","光","") == 150,"Element weakness multiplier broken")
    require(rules.elemental_damage(100,"光","","光") == 70,"Element resistance multiplier broken")
    rules.buff("hero",8,3)
    rules.shield("hero",2)
    require(rules.attack_bonus("hero") == 8,"Buff not affecting power")
    require(rules.mitigated_damage(100,"hero",true) < 40,"Combined shield and guard did not reduce damage")
    rules.tick_round()
    rules.tick_round()
    require(rules.attack_bonus("hero") == 8,"Buff expired too early")
    rules.tick_round()
    require(rules.attack_bonus("hero") == 0,"Buff did not expire")
    require(rules.enemy_intent(3,false,true).get("label","") == "蓄力重击","Boss intent cycle missing")
    var core = RPG.new()
    core.bind(state)
    var battle = Battle.new()
    root.add_child(battle)
    battle.game_core = core
    battle.start(state,2,false)
    require(battle.combat_rules.difficulty == "挑战","Battle did not receive saved difficulty")
    require(is_instance_valid(battle.root),"Battle scene did not appear")
    battle._act("skill")
    require(is_instance_valid(battle.skill_picker),"Skill menu cannot open")
    battle._act("cancel_skill")
    require(not is_instance_valid(battle.skill_picker),"Skill menu cannot close")
    state.actors[0]["hp"] = 15
    battle.hero_turn = 1
    var learned_healing: String = ""
    for skill in core.skills("char_tidecaller"):
        if str(skill.get("target","")) == "single_ally" and str((skill.get("effect",{}) as Dictionary).get("kind","")) == "heal":
            learned_healing = str(skill.get("id",""))
            break
    require(not learned_healing.is_empty(),"Healer has no targeted healing skill")
    if not learned_healing.is_empty():
        battle._act("skill:"+learned_healing)
        require(is_instance_valid(battle.skill_picker),"Selecting a healing skill did not open ally target chooser")
        battle._act("skill:"+learned_healing+"@0")
        require(int(state.actors[0]["hp"]) > 15,"Chosen ally did not receive healing")
    battle.queue_free()
    require(state.save(),"Housing save failed")
    var new_state = State.new()
    require(new_state.load_saved(),"Housing load failed")
    var restored = Housing.new()
    restored.bind(new_state)
    require(restored.owned(),"Housing ownership lost on reload")
    require(not restored.at(3,3).is_empty(),"Furniture layout lost on reload")
    require(str(restored.data().get("wall",""))=="星夜蓝","Decoration lost on reload")
    require(int(restored.data().get("tier",0))==1,"Upgrade lost on reload")
    if failures.is_empty():
        print("PASS: housing deed, 20 furniture, 70-cell interior, placement, storage, resting, remodeling, 4 tiers, save, combat elements/buffs/guard/intent/difficulty")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
