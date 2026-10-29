class_name Act08EvacuationController
extends Node
## 第46–47章撤离事件状态控制器。关卡、战斗、分屏 UI 需订阅信号并上报真实结果。
## 本类不生成战斗胜利、不直接移动角色，也不自动完成目标。

signal squad_task_progress_updated(squad_id: String, progress_percent: float)
signal squad_control_changed(squad_id: String)
signal evacuation_gate_breached(gate_id: String)
signal evacuation_failed(reason: String)
signal all_squads_safely_withdrawn()

const OBJECTIVES := {
    "EAST_GATE_LEISO": ["east_triage_complete", "east_convoy_escorted", "east_encounter_won"],
    "SOUTH_GATE_SHUOXIAN": ["south_children_assembled", "south_safe_route_open", "south_encounter_won"],
    "WEST_GATE_TIFA": ["west_support_repaired", "west_dual_manual_unlock", "west_encounter_won"]
}

const OBJECTIVE_MARKERS := {
    "EAST_GATE_LEISO": ["evac:east:triage", "evac:east:escort", "evac:east:secure"],
    "SOUTH_GATE_SHUOXIAN": ["evac:south:children", "evac:south:route", "evac:south:secure"],
    "WEST_GATE_TIFA": ["evac:west:repair", "evac:west:manual", "evac:west:secure"]
}

const OBJECTIVE_TEXTS := {
    "east_triage_complete": "岚音完成伤员分诊，雷索确认担架队名单",
    "east_convoy_escorted": "重伤员队伍沿东门安全通道实际送达",
    "east_encounter_won": "东门守卫战结算确认，救护队安全撤离",
    "south_children_assembled": "朔弦与童年诺依清点儿童并确认监护人",
    "south_safe_route_open": "儿童队伍完成南门道路引导",
    "south_encounter_won": "南门守卫战结算确认，儿童撤离",
    "west_support_repaired": "缇珐完成西门机械臂抢修",
    "west_dual_manual_unlock": "机械臂手动停机柄和双重解锁已确认",
    "west_encounter_won": "西门守卫战结算确认，设备和人员已撤离"
}

const SQUAD_MEMBERS := {
    "EAST_GATE_LEISO": ["leiso", "lanyin"],
    "SOUTH_GATE_SHUOXIAN": ["shouxian", "nuoyi"],
    "WEST_GATE_TIFA": ["tifa"]
}

var squad_statuses: Dictionary = {}
var active_controlled_squad: String = "EAST_GATE_LEISO"
var chapter_id: String = ""
var seconds_remaining: float = 0.0
var running: bool = false
var time_suspended: bool = false
var failed: bool = false
var finished: bool = false

func _ready() -> void:
    reset()

func reset() -> void:
    squad_statuses.clear()
    for squad_id in OBJECTIVES:
        squad_statuses[squad_id] = {
            "members": SQUAD_MEMBERS[squad_id].duplicate(),
            "completed_objectives": [],
            "progress": 0.0,
            "secured": false
        }
    active_controlled_squad = "EAST_GATE_LEISO"
    chapter_id = ""
    seconds_remaining = 0.0
    running = false
    time_suspended = false
    failed = false
    finished = false

func begin_evacuation(chapter: String, west_gate_time_limit_seconds: float) -> bool:
    if chapter != "ch047" or west_gate_time_limit_seconds <= 0.0:
        return false
    if running or failed or finished:
        return false
    reset()
    chapter_id = chapter
    seconds_remaining = west_gate_time_limit_seconds
    running = true
    squad_control_changed.emit(active_controlled_squad)
    return true

func set_time_suspended(value: bool) -> void:
    # Exploration deadlines advance only in playable walking time; reading
    # choices, menus and real turn-based battles never consume the deadline.
    time_suspended = value

func _process(delta: float) -> void:
    if not running or failed or finished or time_suspended:
        return
    if not squad_statuses["WEST_GATE_TIFA"]["secured"]:
        seconds_remaining = maxf(0.0, seconds_remaining - delta)
        if seconds_remaining <= 0.0:
            failed = true
            running = false
            evacuation_gate_breached.emit("WEST_GATE_TIFA")
            evacuation_failed.emit("west_gate_timeout")

func switch_controlled_squad(squad_id: String) -> String:
    if not running or failed or not squad_statuses.has(squad_id):
        return "小队不可切换：撤离未开始、已结束或编号无效。"
    active_controlled_squad = squad_id
    squad_control_changed.emit(squad_id)
    return "已切换至小队：%s" % squad_id

func current_objective_marker(squad_id: String) -> String:
    if not squad_statuses.has(squad_id):
        return ""
    var done: Array = squad_statuses[squad_id]["completed_objectives"]
    var markers: Array = OBJECTIVE_MARKERS[squad_id]
    if done.size() >= markers.size():
        return ""
    return str(markers[done.size()])

func current_objective_text(squad_id: String) -> String:
    if not squad_statuses.has(squad_id):
        return ""
    var done: Array = squad_statuses[squad_id]["completed_objectives"]
    var objectives: Array = OBJECTIVES[squad_id]
    if done.size() >= objectives.size():
        return "该队已完成撤离"
    return str(OBJECTIVE_TEXTS.get(objectives[done.size()], objectives[done.size()]))

func confirm_objective(squad_id: String, objective_id: String) -> Dictionary:
    # 仅由实际地图、救援物件或战斗结算调用；不能用百分比伪造胜利。
    if not running or failed or not OBJECTIVES.has(squad_id):
        return {"success": false, "reason": "inactive_or_unknown_squad"}
    var objectives: Array = OBJECTIVES[squad_id]
    var done: Array = squad_statuses[squad_id]["completed_objectives"]
    if done.has(objective_id):
        return {"success": false, "reason": "duplicate_event"}
    if done.size() >= objectives.size() or objective_id != objectives[done.size()]:
        return {"success": false, "reason": "out_of_order_or_invalid_objective"}
    done.append(objective_id)
    var percent: float = 100.0 * float(done.size()) / float(objectives.size())
    squad_statuses[squad_id]["progress"] = percent
    squad_statuses[squad_id]["secured"] = done.size() == objectives.size()
    squad_task_progress_updated.emit(squad_id, percent)
    var all_safe: bool = true
    for key in OBJECTIVES:
        if not squad_statuses[key]["secured"]:
            all_safe = false
            break
    if all_safe:
        finished = true
        running = false
        all_squads_safely_withdrawn.emit()
    return {"success": true, "progress": percent, "secured": squad_statuses[squad_id]["secured"], "all_withdrawn": all_safe}

func export_state() -> Dictionary:
    return {
        "chapter_id": chapter_id,
        "seconds_remaining": seconds_remaining,
        "running": running,
        "failed": failed,
        "finished": finished,
        "active_controlled_squad": active_controlled_squad,
        "squad_statuses": squad_statuses.duplicate(true)
    }

func restore_state(data: Dictionary) -> bool:
    var target_chapter: String = str(data.get("chapter_id", ""))
    if target_chapter != "ch047":
        return false
    var raw_status: Variant = data.get("squad_statuses", null)
    if not (raw_status is Dictionary):
        return false
    var normalized: Dictionary = {}
    for squad_id in OBJECTIVES:
        if not raw_status.has(squad_id) or not (raw_status[squad_id] is Dictionary):
            return false
        var raw_done: Variant = raw_status[squad_id].get("completed_objectives", null)
        if not (raw_done is Array) or raw_done.size() > OBJECTIVES[squad_id].size():
            return false
        for index in range(raw_done.size()):
            if raw_done[index] != OBJECTIVES[squad_id][index]:
                return false
        normalized[squad_id] = {
            "members": SQUAD_MEMBERS[squad_id].duplicate(),
            "completed_objectives": raw_done.duplicate(),
            "progress": 100.0 * float(raw_done.size()) / float(OBJECTIVES[squad_id].size()),
            "secured": raw_done.size() == OBJECTIVES[squad_id].size()
        }
    var target_squad: String = str(data.get("active_controlled_squad", ""))
    if not OBJECTIVES.has(target_squad):
        return false
    var all_safe: bool = true
    for key in OBJECTIVES:
        if not normalized[key]["secured"]:
            all_safe = false
    var saved_finished: bool = data.get("finished", false)
    if saved_finished != all_safe:
        return false
    var saved_failed: bool = data.get("failed", false)
    if saved_finished and saved_failed:
        return false
    if typeof(data.get("seconds_remaining", null)) not in [TYPE_INT, TYPE_FLOAT]:
        return false
    var remaining: float = float(data["seconds_remaining"])
    if is_nan(remaining) or is_inf(remaining) or remaining < 0.0 or remaining > 1800.0:
        return false
    if typeof(data.get("running", null)) != TYPE_BOOL or typeof(data.get("failed", null)) != TYPE_BOOL or typeof(data.get("finished", null)) != TYPE_BOOL:
        return false
    if data["running"] and (saved_finished or saved_failed or remaining <= 0.0):
        return false
    reset()
    chapter_id = target_chapter
    squad_statuses = normalized
    active_controlled_squad = target_squad
    seconds_remaining = minf(remaining,600.0) # Old third-batch 1800s saves migrate to the canonical ten-minute limit.
    finished = saved_finished
    failed = saved_failed
    running = bool(data.get("running", false)) and not finished and not failed
    return true
