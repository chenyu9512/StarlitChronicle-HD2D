extends RefCounted
## 三个正典结局的条件判定与四段后日谈。所有条件来自 story/data/endings.json。
const PATH: String = "res://story/data/endings.json"
var endings: Dictionary = {}

func _init() -> void:
    var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if loaded is Dictionary:
        for record in loaded.get("endings", []):
            if record is Dictionary:
                endings[str(record.get("id", ""))] = record

func details(id: String) -> Dictionary:
    return endings.get(id, {})

func missing(id: String, flags: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var record: Dictionary = details(id)
    if record.is_empty():
        result.append("未知结局")
        return result
    for requirement in record.get("requirements", []):
        var flag: String = str(requirement)
        if not bool(flags.get(flag, false)):
            match flag:
                "world.all_twelve_pages": result.append("尚未集齐12张失落航页")
                "world.distributed_network": result.append("尚未建立分散灯网（第60章）")
                "world.seven_lanterns": result.append("尚未修复七灯（第66章）")
                "ch071.battle_won": result.append("尚未完成第71章的决战")
                "story.ch072.done": result.append("尚未完成第72章的最终对话")
                _: result.append("缺少条件：" + flag)
    return result

func can_choose(id: String, flags: Dictionary) -> bool:
    return missing(id, flags).is_empty()

func choices(source: Dictionary, flags: Dictionary) -> Dictionary:
    var generated: Dictionary = {"prompt": str(source.get("prompt", "决定世界未来的道路。")), "options": []}
    var options: Array = source.get("options", [])
    var available: int = 0
    for option in options:
        if not option is Dictionary:
            continue
        var candidate: Dictionary = option.duplicate(true)
        var id: String = str((candidate.get("sets", {}) as Dictionary).get("world.ending", ""))
        var needs: Array[String] = missing(id, flags)
        if not needs.is_empty():
            candidate["locked"] = true
            candidate["locked_reason"] = "；".join(needs)
            candidate["label"] = "🔒 " + str(candidate.get("label", id)) + " · 条件不足"
        else:
            available += 1
        (generated["options"] as Array).append(candidate)
    if available == 0:
        generated["prompt"] += "\n尚未达成任何结局的前置条件。"
    return generated

func scenes(id: String) -> Array:
    return details(id).get("scenes", [])

func scene(id: String, index: int) -> Dictionary:
    var sequence: Array = scenes(id)
    if index < 0 or index >= sequence.size():
        return {}
    return sequence[index]

func title(id: String) -> String:
    return str(details(id).get("title", "未知的黎明"))
