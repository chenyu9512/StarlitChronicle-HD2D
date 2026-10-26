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

## P1 status effects are battle-local and never persisted as a permanent save debuff.
## Resistances and immunities may be supplied by future monster/job catalog rows.
const NEGATIVE_STATUS_LABELS: Dictionary = {
    "poison":"中毒", "burn":"灼烧", "stun":"眩晕",
    "sleep":"睡眠", "freeze":"冻结", "silence":"沉默", "slow":"迟缓"
}

func apply_negative(actor_id: String, kind: String, turns: int = 2) -> bool:
    if actor_id.is_empty() or not NEGATIVE_STATUS_LABELS.has(kind):
        return false
    var status: Dictionary = actor_effects.get(actor_id,{})
    var negative: Dictionary = status.get("negative",{})
    negative[kind] = maxi(int(negative.get(kind,0)),clampi(turns,1,8))
    status["negative"] = negative
    actor_effects[actor_id] = status
    return true

func has_negative(actor_id: String, kind: String) -> bool:
    var status: Dictionary = actor_effects.get(actor_id,{})
    var negative: Dictionary = status.get("negative",{})
    return int(negative.get(kind,0)) > 0

func status_report(actor_id: String) -> String:
    var status: Dictionary = actor_effects.get(actor_id,{})
    var negative: Dictionary = status.get("negative",{})
    var labels: PackedStringArray = []
    for kind in NEGATIVE_STATUS_LABELS.keys():
        if int(negative.get(kind,0)) > 0:
            labels.append(str(NEGATIVE_STATUS_LABELS[kind]))
    return "、".join(labels)

func cure_negative(actor_id: String, kind: String = "") -> void:
    var status: Dictionary = actor_effects.get(actor_id,{})
    var negative: Dictionary = status.get("negative",{})
    if kind.is_empty():
        negative.clear()
    else:
        negative.erase(kind)
    status["negative"] = negative
    actor_effects[actor_id] = status

func resolve_actor_turn(actor_id: String, max_hp: int) -> Dictionary:
    # Called exactly once when the ally becomes active, not on UI redraw.
    var status: Dictionary = actor_effects.get(actor_id,{})
    var negative: Dictionary = status.get("negative",{})
    var total_damage: int = 0
    var skip: bool = false
    var notices: PackedStringArray = []
    if int(negative.get("poison",0)) > 0:
        total_damage += maxi(1,roundi(maxi(1,max_hp)*0.05))
        notices.append("中毒")
    if int(negative.get("burn",0)) > 0:
        total_damage += maxi(1,roundi(maxi(1,max_hp)*0.07))
        notices.append("灼烧")
    for kind in ["stun","sleep","freeze"]:
        if int(negative.get(kind,0)) > 0:
            skip = true
            notices.append(str(NEGATIVE_STATUS_LABELS[kind]))
    for kind in negative.keys():
        var remaining: int = int(negative[kind]) - 1
        if remaining <= 0:
            negative.erase(kind)
        else:
            negative[kind] = remaining
    status["negative"] = negative
    actor_effects[actor_id] = status
    return {"damage":total_damage,"skip":skip,"text":"、".join(notices)}

func initiative_order(actors: Array, eligible_ids: Array = []) -> Array[int]:
    # Stable ties follow party order; slow affects initiative but never damages speed stats.
    var scored: Array[Dictionary] = []
    for i in range(actors.size()):
        var member: Dictionary = actors[i]
        var actor_id: String = str(member.get("id",""))
        if int(member.get("hp",0)) <= 0:
            continue
        if not eligible_ids.is_empty() and actor_id not in eligible_ids:
            continue
        var speed: int = maxi(1,int(member.get("speed",10)))
        if has_negative(actor_id,"slow"):
            speed = maxi(1,roundi(float(speed)*0.55))
        scored.append({"index":i,"speed":speed})
    scored.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        if int(a["speed"]) == int(b["speed"]):
            return int(a["index"]) < int(b["index"])
        return int(a["speed"]) > int(b["speed"])
    )
    var result: Array[int] = []
    for scored_actor in scored:
        result.append(int(scored_actor["index"]))
    return result

## Unified timeline: both teams are sorted in one deterministic queue.
## Equal speed gives player actors priority, then keeps original side order.
func turn_timeline(actors: Array, enemies: Array, eligible_ids: Array = []) -> Array[Dictionary]:
    var order: Array[Dictionary] = []
    for i in range(actors.size()):
        var ally: Dictionary = actors[i]
        var id: String = str(ally.get("id",""))
        if int(ally.get("hp",0)) <= 0 or (not eligible_ids.is_empty() and id not in eligible_ids):
            continue
        var speed: int = maxi(1,int(ally.get("speed",10)))
        if has_negative(id,"slow"):
            speed = maxi(1,roundi(float(speed)*0.55))
        order.append({"team":"ally","index":i,"speed":speed})
    for i in range(enemies.size()):
        var foe: Dictionary = enemies[i]
        if int(foe.get("hp",0)) <= 0:
            continue
        var enemy_speed: int = maxi(1,int(foe.get("speed",maxi(5,int(foe.get("atk",10))/2))))
        if has_enemy_negative(i,"slow"):
            enemy_speed = maxi(1,roundi(float(enemy_speed)*0.55))
        order.append({"team":"enemy","index":i,"speed":enemy_speed})
    order.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        if int(a["speed"]) != int(b["speed"]):
            return int(a["speed"]) > int(b["speed"])
        if str(a["team"]) != str(b["team"]):
            return str(a["team"]) == "ally"
        return int(a["index"]) < int(b["index"])
    )
    return order

## Enemy debuffs are indexed per individual formation member.  Boss and family
## metadata may specify status_immunities and status_resistances explicitly.
func enemy_immune(foe: Dictionary, kind: String) -> bool:
    var immune: Array = foe.get("status_immunities",[])
    if kind in immune:
        return true
    if bool(foe.get("is_boss",false)) and kind in ["sleep","stun","freeze"]:
        return true
    var resistance: Dictionary = foe.get("status_resistances",{})
    return float(resistance.get(kind,0.0)) >= 1.0

func enemy_status_chance(foe: Dictionary, kind: String, base_chance: float) -> float:
    if not NEGATIVE_STATUS_LABELS.has(kind) or enemy_immune(foe,kind):
        return 0.0
    var resistances: Dictionary = foe.get("status_resistances",{})
    return clampf(base_chance*(1.0-clampf(float(resistances.get(kind,0.0)),0.0,1.0)),0.0,1.0)

func apply_enemy_negative(index: int, foe: Dictionary, kind: String, turns: int = 2) -> bool:
    if index < 0 or not NEGATIVE_STATUS_LABELS.has(kind) or enemy_immune(foe,kind):
        return false
    var status: Dictionary = enemy_effects.get(index,{})
    var negative: Dictionary = status.get("negative",{})
    negative[kind] = maxi(int(negative.get(kind,0)),clampi(turns,1,8))
    status["negative"] = negative
    enemy_effects[index] = status
    return true

func has_enemy_negative(index: int, kind: String) -> bool:
    var status: Dictionary = enemy_effects.get(index,{})
    var negative: Dictionary = status.get("negative",{})
    return int(negative.get(kind,0)) > 0

func enemy_status_report(index: int) -> String:
    var status: Dictionary = enemy_effects.get(index,{})
    var negative: Dictionary = status.get("negative",{})
    var labels: PackedStringArray = []
    for kind in NEGATIVE_STATUS_LABELS.keys():
        if int(negative.get(kind,0)) > 0:
            labels.append(str(NEGATIVE_STATUS_LABELS[kind]))
    return "、".join(labels)

func resolve_enemy_turn(index: int, max_hp: int) -> Dictionary:
    var status: Dictionary = enemy_effects.get(index,{})
    var negative: Dictionary = status.get("negative",{})
    var damage: int = 0
    if int(negative.get("poison",0)) > 0:
        damage += maxi(1,roundi(maxi(1,max_hp)*0.05))
    if int(negative.get("burn",0)) > 0:
        damage += maxi(1,roundi(maxi(1,max_hp)*0.07))
    var skip: bool = false
    for kind in ["stun","sleep","freeze"]:
        if int(negative.get(kind,0)) > 0:
            skip = true
    for kind in negative.keys():
        var left: int = int(negative[kind])-1
        if left <= 0:
            negative.erase(kind)
        else:
            negative[kind] = left
    status["negative"] = negative
    enemy_effects[index] = status
    return {"damage":damage,"skip":skip}

func enemy_strategy(foe: Dictionary, round_number: int, phase_two: bool, is_boss: bool, party: Array) -> Dictionary:
    # Opening bosses teach readable cycles before later phase-dependent fights.
    var opening_boss: String = str(foe.get("boss_id",""))
    if is_boss and opening_boss in ["boss.ch002","boss.ch003"]:
        var beat: int = (round_number - 1) % 3
        if beat == 1:
            return {"label":"潮雾蓄力 · 本回合防御" if opening_boss == "boss.ch002" else "守卫重击 · 本回合防御", "multiplier":1.65, "target":"lowest_hp"}
        if beat == 2:
            return {"label":"退潮喘息 · 趁机回复或进攻", "multiplier":0.45, "target":"random"}
        return {"label":"试探攻击", "multiplier":1.0, "target":"random"}
    var directive: Dictionary = enemy_intent(round_number,phase_two,is_boss)
    var personality: String = str(foe.get("ai_pattern",""))
    var hp_ratio: float = float(foe.get("hp",1))/float(maxi(1,int(foe.get("max_hp",1))))
    if is_boss and hp_ratio <= 0.25 and round_number % 2 == 0:
        return {"label":"绝境反击","multiplier":1.42,"target":"lowest_hp"}
    if not is_boss and personality.contains("蓄力") and round_number % 3 == 0:
        return {"label":"蓄力猛击","multiplier":1.35,"target":"lowest_hp"}
    if not is_boss and personality.contains("反击"):
        directive["label"] = "守势反击"
        directive["multiplier"] = 0.85
    if not is_boss and personality.contains("优先") and not party.is_empty():
        directive["target"] = "lowest_hp"
    return directive

## Career techniques share the deterministic action path instead of cloning 63 skills.
## Only battle-local combat choices are changed; saved actor base attributes stay intact.
func vocation_skill_power(power: int, passive: String, kind: String) -> int:
    if kind == "heal" and passive in ["mercy","sanctuary"]:
        return roundi(float(power) * (1.20 if passive == "mercy" else 1.12))
    if kind == "buff" and passive in ["chorus","anthem"]:
        return roundi(float(power) * 1.25)
    if kind == "damage" and passive == "arcana":
        return roundi(float(power) * 1.18)
    return power

func vocation_damage(raw: int, passive: String, action: String, foe: Dictionary, living_allies: int) -> int:
    var amount: int = maxi(0,raw)
    var ratio: float = float(foe.get("hp",1))/float(maxi(1,int(foe.get("max_hp",1))))
    match passive:
        "duelist":
            if bool(foe.get("is_boss",false)): amount = roundi(float(amount)*1.12)
        "hunter":
            if ratio <= 0.5: amount = roundi(float(amount)*1.13)
        "arcana":
            if action == "skill": amount = roundi(float(amount)*1.08)
        "breaker":
            if action == "special": amount += mini(25,int(foe.get("def",0))/4)
        "shadow_blade":
            pass
        "execute":
            if ratio <= 0.35: amount = roundi(float(amount)*1.22)
        "affinity":
            if action == "skill" and ratio <= 0.6: amount = roundi(float(amount)*1.13)
        "pack":
            if living_allies >= 2: amount = roundi(float(amount)*1.10)
        "pierce":
            amount += mini(55,roundi(float(foe.get("def",0))*0.32))
        "navigation":
            if bool(foe.get("is_boss",false)) and ratio <= 0.5: amount = roundi(float(amount)*1.16)
        "starlight":
            if action == "special": amount = roundi(float(amount)*1.07)
    return maxi(0,amount)

func vocation_mitigation(raw: int, passive: String, hp_ratio: float) -> int:
    if passive == "vow":
        return maxi(0,roundi(float(raw)*(0.72 if hp_ratio <= 0.35 else 0.87)))
    if passive == "aegis":
        return maxi(0,roundi(float(raw)*0.95))
    return maxi(0,raw)
