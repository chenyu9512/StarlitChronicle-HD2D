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
