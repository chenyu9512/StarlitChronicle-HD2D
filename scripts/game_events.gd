extends RefCounted
## 剧情、地图、战斗、NPC、收集共用事件账本。只记录实际发生的动作。
signal recorded(kind: String, data: Dictionary)
const HISTORY_LIMIT: int = 160
var state

func bind(progress) -> void:
    state = progress
    if not (state.rpg.get("history") is Array):
        state.rpg["history"] = []
    if not (state.rpg.get("event_counters") is Dictionary):
        state.rpg["event_counters"] = {}
    if not (state.rpg.get("achievements") is Dictionary):
        state.rpg["achievements"] = {}
    if not (state.rpg.get("game_clock") is Dictionary):
        state.rpg["game_clock"] = {"minutes":480, "day":1}

func record(kind: String, data: Dictionary = {}) -> void:
    if state == null:
        return
    var counts: Dictionary = state.rpg["event_counters"]
    counts[kind] = int(counts.get(kind,0)) + 1
    var event: Dictionary = {"kind":kind,"chapter":int(state.chapter),"day":int(state.rpg["game_clock"].get("day",1)),"payload":data.duplicate(true)}
    var list: Array = state.rpg["history"]
    list.append(event)
    if list.size() > HISTORY_LIMIT:
        list.pop_front()
    _unlock(kind)
    recorded.emit(kind,data)

func _unlock(kind: String) -> void:
    var a: Dictionary = state.rpg["achievements"]
    var counts: Dictionary = state.rpg["event_counters"]
    if kind == "battle_victory":
        a["first_victory"] = true
        if int(counts.get(kind,0)) >= 100:
            a["battle_100"] = true
    elif kind == "side_quest_completed":
        a["first_side_quest"] = true
    elif kind == "travel" and int(counts.get(kind,0)) >= 10:
        a["explorer_10"] = true
    elif kind == "chapter_completed":
        if int(state.chapter) >= 6:
            a["first_act"] = true
        if int(state.chapter) >= 72:
            a["journey_end"] = true

func advance_time(minutes: int) -> void:
    if state == null or minutes <= 0:
        return
    var clock: Dictionary = state.rpg["game_clock"]
    var full: int = int(clock.get("minutes",480)) + minutes
    clock["day"] = int(clock.get("day",1)) + int(full / 1440)
    clock["minutes"] = full % 1440

func time_label() -> String:
    if state == null:
        return "08:00"
    var minutes: int = int(state.rpg["game_clock"].get("minutes",480))
    return "%02d:%02d" % [int(minutes / 60),minutes % 60]

func phase() -> String:
    if state == null:
        return "day"
    var hour: int = int(int(state.rpg["game_clock"].get("minutes",480)) / 60)
    return "night" if hour < 5 or hour >= 19 else ("evening" if hour >= 17 else "day")

func history() -> Array:
    return state.rpg.get("history",[]) if state != null else []
