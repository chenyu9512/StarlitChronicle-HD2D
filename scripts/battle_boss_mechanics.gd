extends RefCounted
## A-line Boss runtime: one deterministic instance per encounter; no global save mutations.
## Objective progression is earned through actual party commands, never scripted victory calls.
var spec: Dictionary = {}
var progress: int = 0
var ward: int = 0
var last_action_round: Dictionary = {}
var phase_two: bool = false
var recovery_uses: int = 0
var counter_primed: bool = false
var environment_round: int = 0

func start(source: Dictionary) -> void:
    spec = source.duplicate(true)
    progress = 0
    ward = maxi(0,int(spec.get("ward",0)))
    last_action_round.clear()
    phase_two = false
    recovery_uses = 0
    counter_primed = false
    environment_round = 0

func enabled() -> bool:
    return not spec.is_empty() and str(spec.get("goal","")) != "legacy"

func objective_label() -> String:
    return str(spec.get("objective_label","击败敌人"))

func hint() -> String:
    return str(spec.get("counter_hint","观察预告，适时防御"))

func phase_hint() -> String:
    return str(spec.get("phase_hint","敌人的行动发生改变"))

func set_phase_two() -> void:
    phase_two = true

## Explicit attack-environment effects; applied once at the start of a round.
func round_effects(round_number: int) -> Dictionary:
    if environment_round == round_number or not enabled():
        return {}
    environment_round = round_number
    var kind: String = str(spec.get("archetype","weakpoint"))
    var response: Dictionary = {"heal_ratio":0.0,"speed_bonus":0,"weakness":""}
    var cadence: int = maxi(2,int(spec.get("cadence",3)))
    if kind == "ward" and round_number > 1 and round_number % (cadence+2) == 0:
        ward = mini(int(spec.get("ward",0)),ward+1)
    elif kind == "support" and round_number % 4 == 0:
        ward = mini(int(spec.get("ward",0)),ward+1)
        if recovery_uses < 2:
            response["heal_ratio"] = 0.018
            recovery_uses += 1
    elif kind == "attrition" and round_number % 3 == 0 and recovery_uses < 3:
        response["heal_ratio"] = 0.025
        recovery_uses += 1
    elif kind == "initiative" and round_number % cadence == 0:
        response["speed_bonus"] = 16
    elif kind == "element_shift" and phase_two:
        response["weakness"] = str(spec.get("phase_two_element","光")) if round_number % 2 == 0 else "影"
    return response

func intent(round_number: int) -> Dictionary:
    var cadence: int = maxi(2,int(spec.get("cadence",3)))
    var archetype: String = str(spec.get("archetype","weakpoint"))
    var heavy: bool = round_number % cadence == 0
    var multiplier: float = 1.0
    var target: String = "random"
    if heavy:
        multiplier = 1.45 if not phase_two else 1.60
        target = "lowest_hp"
    elif archetype in ["counter","attrition"] and round_number % 2 == 0:
        multiplier = 0.75
    elif archetype in ["pressure","multi_hit"] and phase_two:
        multiplier = 1.18
    if archetype == "counter" and counter_primed:
        multiplier += 0.18
        target = "highest_hp"
    elif archetype == "control" and heavy:
        target = "lowest_mp"
    elif archetype == "pressure" and phase_two and heavy:
        multiplier += 0.18
    if ward == 0 and heavy:
        multiplier *= 0.82
    var label: String = str(spec.get("telegraph","蓄力"))
    if not heavy:
        label = "换位 · " + str(spec.get("name","敌人")) if phase_two else "观察 · " + str(spec.get("name","敌人"))
    var chance: float = float(spec.get("status_chance",0.0))
    if archetype == "control" and phase_two:
        chance += 0.13
    return {"label":label,"target":target,"multiplier":clampf(multiplier,0.35,1.85),
        "status":str(spec.get("status","")) if heavy else "",
        "status_chance":clampf(chance,0.0,0.45)}

func damage_factor(skill: Dictionary = {}) -> float:
    var element: String = str(skill.get("element",""))
    var weak: String = str(spec.get("phase_two_element",""))
    var factor: float = 0.78 if ward > 0 else 1.0
    if phase_two and not weak.is_empty() and element == weak:
        factor *= 1.50 if str(spec.get("archetype","")) == "weakpoint" else 1.25
    return clampf(factor,0.5,1.5)

func record_action(action: String, skill: Dictionary, actor_id: String, round_number: int, passive: String = "") -> Dictionary:
    if not enabled():
        return {"notice":"","victory":false}
    # Per-actor/per-round dedup prevents UI re-entry from farming objective progress.
    var token: String = actor_id + ":" + str(round_number)
    if last_action_round.has(token):
        return {"notice":"","victory":false}
    last_action_round[token] = true
    var kind: String = str(spec.get("archetype",""))
    if kind == "counter":
        if action == "attack":
            counter_primed = true
        elif action in ["guard","special"]:
            counter_primed = false
    var gain: int = 0
    if action == "special":
        gain = 1 + (1 if passive == "breaker" else 0)
        ward = maxi(0,ward-(2 if passive == "breaker" or kind == "ward" else 1))
    elif action == "guard" and str(spec.get("goal","")) == "survive":
        gain = 1
    elif action == "skill":
        var kind: String = str((skill.get("effect",{}) as Dictionary).get("kind",""))
        if kind in ["heal","shield"] and str(spec.get("goal","")) == "survive":
            gain = 1
        if kind == "damage" and str(skill.get("element","")) == str(spec.get("phase_two_element","")) and phase_two:
            ward = maxi(0,ward-1)
    progress = mini(99,progress+gain)
    var message: String = ""
    if gain > 0:
        message = "战术目标 %d/%d；防护层 %d。" % [progress,maxi(1,int(spec.get("required",0))),ward]
    elif action == "skill" and ward == 0:
        message = "敌人的防护已被瓦解。"
    var goal: String = str(spec.get("goal","defeat"))
    var completed: bool = goal in ["pacify","survive"] and progress >= int(spec.get("required",999))
    if goal == "survive":
        completed = completed and round_number >= int(spec.get("minimum_round",6))
    return {"notice":message,"victory":completed}

func protect_from_lethal() -> bool:
    # Non-lethal or survival goals may never be replaced by a forged HP-kill.
    return enabled() and str(spec.get("goal","")) in ["pacify","survive"]

func report() -> Dictionary:
    return {"boss_id":str(spec.get("boss_id","")),"progress":progress,"ward":ward,
        "required":int(spec.get("required",0)),"goal":str(spec.get("goal","defeat")),
        "phase_two":phase_two}
