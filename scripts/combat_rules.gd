extends RefCounted
## 回合战斗规则：弱点/抗性、持续增益、护盾、敌人预告和三档难度。
var actor_effects: Dictionary = {}
var enemy_effects: Dictionary = {}
var difficulty: String = "标准"

func start(settings: Dictionary) -> void:
    actor_effects.clear()
    enemy_effects.clear()
    difficulty = str(settings.get("difficulty","标准"))

func modifier() -> float:
    match difficulty:
        "休闲": return 0.72
        "挑战": return 1.38
        _: return 1.0

func elemental_damage(raw: int, element: String, weakness: String, resistance: String) -> int:
    var factor: float = 1.0
    if not element.is_empty() and element == weakness:
        factor = 1.5
    elif not element.is_empty() and element == resistance:
        factor = 0.7
    return maxi(1,roundi(raw * factor))

func buff(id: String, amount: int, turns: int = 3) -> void:
    var status: Dictionary = actor_effects.get(id,{})
    status["attack_bonus"] = maxi(1,amount)
    status["attack_turns"] = maxi(1,turns)
    actor_effects[id] = status

func shield(id: String, turns: int = 2) -> void:
    var status: Dictionary = actor_effects.get(id,{})
    status["shield_turns"] = maxi(int(status.get("shield_turns",0)),turns)
    actor_effects[id] = status

func charge(id: String) -> int:
    var status: Dictionary = actor_effects.get(id,{})
    status["star_charge"] = mini(3,int(status.get("star_charge",0))+1)
    actor_effects[id] = status
    return int(status["star_charge"])

func charge_level(id: String) -> int:
    return int((actor_effects.get(id,{}) as Dictionary).get("star_charge",0))

func release_charge(id: String, raw: int) -> int:
    var status: Dictionary = actor_effects.get(id,{})
    var stacks: int = int(status.get("star_charge",0))
    if stacks > 0 and raw > 0:
        status["star_charge"] = 0
        actor_effects[id] = status
        return roundi(raw*(1.0+0.35*stacks))
    return raw

func attack_bonus(id: String) -> int:
    var status: Dictionary = actor_effects.get(id,{})
    return int(status.get("attack_bonus",0)) if int(status.get("attack_turns",0)) > 0 else 0

func mitigated_damage(raw: int, id: String, guarded: bool = false) -> int:
    var status: Dictionary = actor_effects.get(id,{})
    var multiplier: float = modifier()
    if guarded:
        multiplier *= 0.35
    if int(status.get("shield_turns",0)) > 0:
        multiplier *= 0.65
    return maxi(0,roundi(raw*multiplier))

func tick_round() -> void:
    for id in actor_effects:
        var status: Dictionary = actor_effects[id]
        for key in ["attack_turns","shield_turns"]:
            if int(status.get(key,0)) > 0:
                status[key] = int(status[key]) - 1
        if int(status.get("attack_turns",0)) <= 0:
            status.erase("attack_bonus")
        actor_effects[id] = status

func enemy_intent(round_number: int, phase_two: bool, is_boss: bool) -> Dictionary:
    if is_boss and round_number % 3 == 0:
        return {"label":"蓄力重击","multiplier":1.65,"target":"lowest_hp"}
    if phase_two and round_number % 2 == 0:
        return {"label":"狂暴追击","multiplier":1.35,"target":"random"}
    return {"label":"普通攻击","multiplier":1.0,"target":"random"}

## 九种装备特性的数据驱动结算（兼容既有81把武器的trait字段）。
func weapon_damage(base_damage: int, weapon_trait: String, foe: Dictionary, tier: int) -> int:
    var raw: int = maxi(1,base_damage)
    match weapon_trait:
        "破甲": raw += mini(int(foe.get("def",0)),3+tier*2)
        "破阵": raw = roundi(raw*1.08)
        "突刺": raw += 2+tier
        "贯穿": raw += mini(int(foe.get("def",0)),5+tier*3)
        "术力": raw += 2+tier*2
        "追击": raw = roundi(raw*1.15)
        "火伤":
            raw += 2+tier*2
            if str(foe.get("weakness","")) == "火": raw = roundi(raw*1.3)
        "护佑": raw += 1
        "增幅": raw = roundi(raw*1.12)
    return maxi(1,raw)
