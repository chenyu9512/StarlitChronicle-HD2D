class_name TacticalCombatEngine
extends Node
## Adapted from the supplied deep-systems draft. This is an in-battle
## HP/Unrest/star-lock and safety layer, NOT a replacement victory/save engine.
## Battle timeline, Boss-specific canon objectives and V3 payouts stay in
## first_act_battle.gd and BattleV3Settlement.
signal tactical_action_committed(actor_id: String, skill_id: String, report: Dictionary)
signal safety_hazard_triggered(hazard: String, damage: int)
signal enemy_pacified(enemy_id: String, method: String)

enum VictoryMode { STANDARD_DEFEAT, NON_LETHAL_PACIFY, SHARED_WITNESS_SHIFT, EVACUATION_HOLD }
enum TriagePriority { NONE, MINOR_SCRAPE, HEAVY_BLEEDING, AIRWAY_CRITICAL }
const PartyCanonGuard = preload("res://scripts/systems/PartyCanonGuard.gd")
const SKILLS: Dictionary = {
    "SHIELD_ANCHOR_LINE":{"actor":"cast_lei_suo","cost":0,"name":"安全绳锚定"},
    "SHIELD_COVER_RETREAT":{"actor":"cast_lei_suo","cost":15,"name":"梯次掩护"},
    "HEALER_TRIAGE_RESCUE":{"actor":"char_tidecaller","cost":20,"name":"急诊优先分诊"},
    "RANGER_ISOLATE_AND_MARK":{"actor":"char_seeker","cost":10,"name":"退路标定与火药隔离"},
    "RANGER_DOUBLE_WHISTLE_UNLOCK":{"actor":"char_seeker","cost":20,"name":"双哨星纹拆锁"},
    "ARTIFICER_VALVE_CHECK":{"actor":"cast_ti_fa","cost":5,"name":"泄压阀校验"},
    "ARTIFICER_DIRECTIONAL_VENT":{"actor":"cast_ti_fa","cost":25,"name":"定向蒸汽阻断"},
    "BARD_COUNTER_CADENCE":{"actor":"cast_yi_ze","cost":20,"name":"逆拍共鸣"},
    "BLADE_SHADOW_PARALLAX":{"actor":"cast_xuan_li","cost":25,"name":"映世斜影"},
    "KEEPER_RECITE_TRUE_NAME":{"actor":"cast_nuo_yi","cost":10,"name":"真名核验"},
    "ARBITER_DISTRIBUTED_PROTOCOL":{"actor":"cast_wei_sha","cost":30,"name":"分布式共识"}
}
var chapter: int = 0
var active_boss: bool = false
var mode: VictoryMode = VictoryMode.STANDARD_DEFEAT
var enemy_states: Dictionary = {}
var lantern_resonance_charge: int = 30
var line_pressure: int = 45
var valve_checked: bool = false
var rope_anchored: bool = false
var exit_marked: bool = false
var powder_isolated: bool = false
var witnessed_names: Dictionary = {}
var actions_used: int = 0

func setup_encounter(ch: int, is_boss: bool, enemies: Array) -> void:
    chapter = ch
    active_boss = is_boss
    mode = VictoryMode.NON_LETHAL_PACIFY if is_boss else VictoryMode.STANDARD_DEFEAT
    enemy_states.clear()
    lantern_resonance_charge = 30
    line_pressure = 45
    valve_checked = false
    rope_anchored = false
    exit_marked = false
    powder_isolated = false
    witnessed_names.clear()
    actions_used = 0
    for i in range(enemies.size()):
        var enemy: Dictionary = enemies[i]
        enemy_states[i] = {
            "id":str(enemy.get("monster_id",enemy.get("boss_id","enemy_%d"%i))),
            "unrest":clampi(int(enemy.get("unrest",70)),0,100),
            "star_locks":maxi(0,int(enemy.get("star_locks",2 if is_boss else 0))),
            "overloaded":false,"pacified":false,"lamp_window":false
        }

func available_for(actor_id: String, ch: int, flags: Dictionary) -> Array[Dictionary]:
    var choices: Array[Dictionary] = []
    if not PartyCanonGuard.can_fight(actor_id,ch,flags):
        return choices
    for id in SKILLS:
        var meta: Dictionary = SKILLS[id]
        if PartyCanonGuard.canonical_id(actor_id) != str(meta["actor"]):
            # Layin and the original playable tidecaller share a canon job.
            if not (str(meta["actor"])=="char_tidecaller" and actor_id in ["cast_lan_yin","char_tidecaller"]):
                continue
        if ch < 49 and id=="KEEPER_RECITE_TRUE_NAME":
            continue
        if ch < 58 and id=="ARBITER_DISTRIBUTED_PROTOCOL":
            continue
        choices.append({"id":str(id),"name":str(meta["name"]),
            "cost":int(meta["cost"]),"enabled":lantern_resonance_charge>=int(meta["cost"])})
    return choices

func use_skill(actor_id: String, skill_id: String, enemy_index: int, flags: Dictionary) -> Dictionary:
    var options: Array[Dictionary] = available_for(actor_id,chapter,flags)
    var valid: bool = false
    for skill in options:
        if str(skill["id"])==skill_id and bool(skill["enabled"]):
            valid = true
            break
    if not valid or not enemy_states.has(enemy_index):
        return {"ok":false,"reason":"skill_unavailable_or_target_missing"}
    var cost: int = int(SKILLS[skill_id]["cost"])
    var target: Dictionary = enemy_states[enemy_index]
    if bool(target.get("pacified",false)):
        return {"ok":false,"reason":"target_already_pacified"}
    var result: Dictionary = {"ok":true,"name":str(SKILLS[skill_id]["name"]),
        "backlash":0,"enemy_damage":0,"heal_all":0,"heal_one":0,
        "pacified":false,"message":""}
    match skill_id:
        "SHIELD_ANCHOR_LINE":
            rope_anchored=true
            result["message"]="安全绳已固定，撤离队伍获得防坠保护。"
        "SHIELD_COVER_RETREAT":
            if not rope_anchored:
                result["backlash"]=25
                result["message"]="未锚定安全绳，气浪反震！"
            else:
                target["unrest"]=maxi(0,int(target["unrest"])-25)
                target["lamp_window"]=true
                result["message"]="完成梯次掩护，敌方失衡下降。"
        "HEALER_TRIAGE_RESCUE":
            result["heal_one"]=60 if bool(flags.get("battle.airway_critical",false)) else 30
            if bool(flags.get("battle.airway_critical",false)):
                lantern_resonance_charge=mini(100,lantern_resonance_charge+25)
            result["message"]="完成分诊。气道危重优先级由真实战场状态判定。"
        "RANGER_ISOLATE_AND_MARK":
            exit_marked=true
            powder_isolated=true
            target["lamp_window"]=true
            result["message"]="出口已标记，火药桶已隔离。"
        "RANGER_DOUBLE_WHISTLE_UNLOCK":
            if bool(target.get("overloaded",false)):
                result["backlash"]=30
                result["message"]="星纹过载时接近导致反冲。"
            else:
                target["unrest"]=maxi(0,int(target["unrest"])-30)
                target["star_locks"]=maxi(0,int(target["star_locks"])-1)
                result["message"]="双哨引导完成，拆除一处星纹锁。"
        "ARTIFICER_VALVE_CHECK":
            valve_checked=true
            line_pressure=maxi(15,line_pressure-30)
            result["message"]="泄压阀已校验，人工接管柄保持可用。"
        "ARTIFICER_DIRECTIONAL_VENT":
            if not valve_checked or line_pressure>80:
                result["backlash"]=35
                result["message"]="未校验泄压阀，蒸汽冲击反噬。"
            else:
                target["unrest"]=maxi(0,int(target["unrest"])-25)
                target["overloaded"]=false
                result["enemy_damage"]=25
                result["message"]="低压定向蒸汽解除过载。"
        "BARD_COUNTER_CADENCE":
            target["unrest"]=maxi(0,int(target["unrest"])-35)
            target["lamp_window"]=true
            target["overloaded"]=false
            result["message"]="逆拍共鸣平复失衡并暴露灯芯窗口。"
        "BLADE_SHADOW_PARALLAX":
            target["star_locks"]=maxi(0,int(target["star_locks"])-1)
            result["enemy_damage"]=20
            result["message"]="借镜影斜切拆解关节与一处星锁。"
        "KEEPER_RECITE_TRUE_NAME":
            if bool(target.get("lamp_window",false)) and bool(flags.get("battle.true_name_verified",false)):
                target["unrest"]=0
                target["star_locks"]=0
                result["message"]="根据已验证姓名与窗口，守卫停止敌对。"
            else:
                target["unrest"]=maxi(0,int(target["unrest"])-20)
                result["message"]="真名未完全核实，只能暂时动摇裁定。"
        "ARBITER_DISTRIBUTED_PROTOCOL":
            if bool(flags.get("battle.shared_witness_verified",false)):
                target["unrest"]=maxi(0,int(target["unrest"])-45)
                target["star_locks"]=maxi(0,int(target["star_locks"])-1)
                result["message"]="真实自愿见证支撑分布式裁定。"
            else:
                result["message"]="未取得真实的自愿见证，算式未能覆写。"
    lantern_resonance_charge=maxi(0,lantern_resonance_charge-cost)
    actions_used+=1
    if int(result["backlash"])>0:
        safety_hazard_triggered.emit(skill_id,int(result["backlash"]))
    # Never auto-confirm story-Boss victories. The authored Boss director and
    # first_act's live battle settlement remain the only authority.
    if int(target["unrest"])==0 and int(target["star_locks"])==0:
        target["pacified"]=true
        result["pacified"]=true
        enemy_pacified.emit(str(target["id"]),skill_id)
    enemy_states[enemy_index]=target
    result["unrest"]=int(target["unrest"])
    result["star_locks"]=int(target["star_locks"])
    tactical_action_committed.emit(actor_id,skill_id,result)
    return result

func all_pacified() -> bool:
    if enemy_states.is_empty():
        return false
    for state in enemy_states.values():
        if not bool(state.get("pacified",false)):
            return false
    return true

func overview(enemy_index: int) -> String:
    var state: Dictionary = enemy_states.get(enemy_index,{})
    if state.is_empty():
        return ""
    return " 狂躁 %d%% · 星锁 %d · 星灯 %d%%" % [
        int(state.get("unrest",0)),int(state.get("star_locks",0)),lantern_resonance_charge]
