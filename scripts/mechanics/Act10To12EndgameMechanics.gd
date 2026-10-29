class_name Act10To12EndgameMechanics
extends Node
## 第10—12幕可复用机制状态。依赖正式剧情/战斗回执，不能自行写入奖励、结局或通关旗标。
## 目前仅提供脚本与存档接口；未挂接主场景，尚未经过 Godot 实机验收。

signal city_stewardship_updated(score: int, charter_signed: bool)
signal sky_rail_alignment_changed(ring_index: int, aligned: bool, all_aligned: bool)
signal hessian_phase_advanced(phase: int, prompt: String, verdict: String)

const HESSIAN_CHAPTER: String = "ch071"
const ENDING_C_REQUIRED_FLAGS = [
    "story.ch072.done",
    "ch071.battle_won",
    "world.all_twelve_pages",
    "world.distributed_network",
    "world.seven_lanterns",
]

var city_stewardship_score: int = 40
var visha_fallback_switch_installed: bool = false
var rotational_keep_charter_signed: bool = false
var sky_rail_rings_aligned: Array[bool] = [false, false, false]
var hessian_current_phase: int = 0


func install_visha_human_override_formula(story_flags: Dictionary) -> Dictionary:
    # 第58章正式收束后才允许记录人工接管；不擅自让维莎提前加入队伍。
    if not bool(story_flags.get("story.ch058.done", false)):
        return {"success": false, "changed": false, "reason": "ch058_not_completed"}
    if visha_fallback_switch_installed:
        return {"success": true, "changed": false}
    visha_fallback_switch_installed = true
    city_stewardship_score = mini(100, city_stewardship_score + 30)
    city_stewardship_updated.emit(city_stewardship_score, rotational_keep_charter_signed)
    return {"success": true, "changed": true, "message": "人工接管冗余已登记"}


func sign_rotational_lantern_charter(story_flags: Dictionary) -> Dictionary:
    if not visha_fallback_switch_installed or not bool(story_flags.get("story.ch059.done", false)):
        return {"success": false, "changed": false, "reason": "chapter_or_override_gate"}
    if rotational_keep_charter_signed:
        return {"success": true, "changed": false}
    rotational_keep_charter_signed = true
    city_stewardship_score = mini(100, city_stewardship_score + 30)
    city_stewardship_updated.emit(city_stewardship_score, rotational_keep_charter_signed)
    return {"success": true, "changed": true, "message": "轮值守灯章程已登记"}


func calibrate_sky_rail_ring(ring_index: int, story_flags: Dictionary) -> Dictionary:
    if ring_index < 0 or ring_index >= 3:
        return {"success": false, "changed": false, "reason": "ring_out_of_range"}
    if not bool(story_flags.get("story.ch064.done", false)):
        return {"success": false, "changed": false, "reason": "ch064_not_completed"}
    if sky_rail_rings_aligned[ring_index]:
        return {"success": true, "changed": false, "all_aligned": _all_rings_aligned()}
    sky_rail_rings_aligned[ring_index] = true
    var all_aligned: bool = _all_rings_aligned()
    sky_rail_alignment_changed.emit(ring_index, true, all_aligned)
    # world.seven_lanterns 必须仍由第66章正式结算写入，不由本函数伪造。
    return {"success": true, "changed": true, "all_aligned": all_aligned}


func _all_rings_aligned() -> bool:
    return sky_rail_rings_aligned[0] and sky_rail_rings_aligned[1] and sky_rail_rings_aligned[2]


func execute_hessian_final_encounter_step(story_flags: Dictionary) -> Dictionary:
    # 正式赫西安战斗为第71章，不是第72章。此接口只跟随真实剧情/战斗回执。
    var gates: Array[String] = ["ch071.started", "ch071.decision_made", "ch071.battle_won"]
    var prompts: Array[String] = [
        "核实赫西安关于永恒静止的论证与居民证言",
        "核实分担方案与代际交接的抉择已记录",
        "等待第71章真实战斗胜利回执",
    ]
    if hessian_current_phase >= gates.size():
        return {"success": true, "changed": false, "phase": 3}
    var gate: String = gates[hessian_current_phase]
    if not bool(story_flags.get(gate, false)):
        return {"success": false, "changed": false, "phase": hessian_current_phase,
                "reason": "missing_canonical_receipt", "required_flag": gate}
    hessian_current_phase += 1
    hessian_phase_advanced.emit(hessian_current_phase, prompts[hessian_current_phase - 1],
                                "本阶段回执已读取；不自动完成战斗或授予结局")
    return {"success": true, "changed": true, "phase": hessian_current_phase}


func ending_c_requirements_met(story_flags: Dictionary) -> bool:
    # 只读判断：A/B/C 的最终路线仍由正式结局系统选定。
    for key in ENDING_C_REQUIRED_FLAGS:
        if not bool(story_flags.get(key, false)):
            return false
    return true


func reset_for_save_binding() -> void:
    # Reset before slot migration so an interrupted read cannot leak the
    # previous slot's post-chapter records into a different player's history.
    city_stewardship_score = 40
    visha_fallback_switch_installed = false
    rotational_keep_charter_signed = false
    sky_rail_rings_aligned = [false, false, false]
    hessian_current_phase = 0

func export_state() -> Dictionary:
    return {
        "city_stewardship_score": city_stewardship_score,
        "visha_fallback_switch_installed": visha_fallback_switch_installed,
        "rotational_keep_charter_signed": rotational_keep_charter_signed,
        "sky_rail_rings_aligned": sky_rail_rings_aligned.duplicate(),
        "hessian_current_phase": hessian_current_phase,
    }


func restore_state(saved: Dictionary) -> bool:
    var rings: Variant = saved.get("sky_rail_rings_aligned", null)
    if not (rings is Array) or rings.size() != 3:
        return false
    for aligned in rings:
        if not (aligned is bool):
            return false
    var score: int = int(saved.get("city_stewardship_score", -1))
    var phase: int = int(saved.get("hessian_current_phase", -1))
    if score < 40 or score > 100 or phase < 0 or phase > 3:
        return false
    if not (saved.get("visha_fallback_switch_installed") is bool) or not (saved.get("rotational_keep_charter_signed") is bool):
        return false
    if bool(saved["rotational_keep_charter_signed"]) and not bool(saved["visha_fallback_switch_installed"]):
        return false
    city_stewardship_score = score
    visha_fallback_switch_installed = bool(saved["visha_fallback_switch_installed"])
    rotational_keep_charter_signed = bool(saved["rotational_keep_charter_signed"])
    sky_rail_rings_aligned = [bool(rings[0]), bool(rings[1]), bool(rings[2])]
    hessian_current_phase = phase
    return true
