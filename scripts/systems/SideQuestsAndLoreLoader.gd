class_name SideQuestsAndLoreLoader
extends Node
## 从现有正典资源读取120任务与27文献；不复制任务、不发放奖励、不写入战斗数值。
## 地图触发、对话播出、任务奖励、存档由正式运行器接入后执行。

signal side_quest_loaded(quest_id: String, category: String, act_requirement: int)
signal lore_document_unlocked(doc_id: String, title: String)
signal companion_bond_rank_updated(companion_id: String, new_rank: int, title: String)

const QUEST_SOURCES := [
    {"path": "res://story/data/side_quests.json", "category": "original", "expected": 36},
    {"path": "res://story/data/companion_quests.json", "category": "companion", "expected": 48},
    {"path": "res://story/data/regional_quests_v2.json", "category": "regional", "expected": 36}
]
const LORE_PATH := "res://story/data/lore_texts.json"
const BOND_TITLES := ["相识", "信任", "并肩", "家人"]
const COMPANION_IDS := ["lanyin", "leiso", "shouxian", "tifa", "ize", "xuanli", "nuoyi", "weisha"]

var all_side_quests: Dictionary = {}
var lore_documents: Dictionary = {}
var unlocked_lore_documents: Dictionary = {}
var companion_bonds: Dictionary = {}
var used_bond_quest_ids: Dictionary = {}
var loaded: bool = false

func _ready() -> void:
    reset_bonds()

func reset_bonds() -> void:
    companion_bonds.clear()
    used_bond_quest_ids.clear()
    for companion_id in COMPANION_IDS:
        companion_bonds[companion_id] = {"rank": 0, "title": BOND_TITLES[0]}

func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        push_error("剧情数据源不存在：" + path)
        return null
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        push_error("剧情数据源格式不正确：" + path)
        return null
    return parsed

func load_canonical_resources() -> Dictionary:
    var pending_quests: Dictionary = {}
    var pending_lore: Dictionary = {}
    for source in QUEST_SOURCES:
        var document: Variant = _read_json(source["path"])
        if not (document is Dictionary):
            return {"success": false, "reason": "quest_source_invalid"}
        var entries: Variant = document.get("quests", null)
        if not (entries is Array) or entries.size() != source["expected"]:
            return {"success": false, "reason": "quest_source_count_mismatch", "path": source["path"]}
        for entry in entries:
            if not (entry is Dictionary):
                return {"success": false, "reason": "quest_entry_invalid"}
            var quest_id: String = str(entry.get("id", ""))
            if quest_id.is_empty() or pending_quests.has(quest_id):
                return {"success": false, "reason": "quest_id_missing_or_duplicate"}
            var record: Dictionary = entry.duplicate(true)
            record["runtime_source_category"] = source["category"]
            pending_quests[quest_id] = record
    var lore_source: Variant = _read_json(LORE_PATH)
    if not (lore_source is Dictionary):
        return {"success": false, "reason": "lore_source_invalid"}
    var lore_entries: Variant = lore_source.get("entries", null)
    if not (lore_entries is Array) or lore_entries.size() != 27 or pending_quests.size() != 120:
        return {"success": false, "reason": "canonical_total_mismatch"}
    for entry in lore_entries:
        if not (entry is Dictionary):
            return {"success": false, "reason": "lore_entry_invalid"}
        var doc_id: String = str(entry.get("id", ""))
        if doc_id.is_empty() or pending_lore.has(doc_id):
            return {"success": false, "reason": "lore_id_missing_or_duplicate"}
        pending_lore[doc_id] = entry.duplicate(true)
    # 全量检查成功才替换，避免读入一半时污染运行状态。
    all_side_quests = pending_quests
    lore_documents = pending_lore
    loaded = true
    for quest_id in all_side_quests:
        var quest: Dictionary = all_side_quests[quest_id]
        var chapter_text: String = str(quest.get("required_chapter", "ch000"))
        var chapter_number: int = int(chapter_text.trim_prefix("ch"))
        side_quest_loaded.emit(quest_id, str(quest["runtime_source_category"]), int((chapter_number - 1) / 6) + 1)
    return {"success": true, "quests": all_side_quests.size(), "lore_documents": lore_documents.size()}

func get_quest(quest_id: String) -> Dictionary:
    if not all_side_quests.has(quest_id):
        return {}
    return all_side_quests[quest_id].duplicate(true)

func get_lore(doc_id: String) -> Dictionary:
    if not lore_documents.has(doc_id):
        return {}
    return lore_documents[doc_id].duplicate(true)

func is_quest_available(quest_id: String, story_flags: Dictionary) -> bool:
    if not loaded or not all_side_quests.has(quest_id):
        return false
    var quest: Dictionary = all_side_quests[quest_id]
    if story_flags.get(str(quest.get("completion_flag", "")), false):
        return false
    var chapter: String = str(quest.get("required_chapter", ""))
    if not chapter.is_empty() and not story_flags.get("story." + chapter + ".done", false):
        return false
    for flag in quest.get("required_flags", []):
        if not story_flags.get(str(flag), false):
            return false
    return true

func lore_readable(doc_id: String, story_flags: Dictionary) -> bool:
    if not loaded or not lore_documents.has(doc_id):
        return false
    var record: Dictionary = lore_documents[doc_id]
    for required in record.get("requires_flags", []):
        var key: String = str(required)
        # Older lore authored a story.chNNN.started alias, while the actual
        # campaign opening writes chNNN.started. Accept only that exact alias.
        if key.begins_with("story.ch") and key.ends_with(".started"):
            key = key.trim_prefix("story.")
        if not bool(story_flags.get(key, false)):
            return false
    return true

func lore_ids_for_chapter(chapter: int) -> Array[String]:
    var results: Array[String] = []
    for doc_id in lore_documents:
        var record: Dictionary = lore_documents[doc_id]
        if str(record.get("chapter", "")) == "ch%03d" % chapter:
            results.append(str(doc_id))
    results.sort()
    return results

func sync_companion_bonds(story_flags: Dictionary) -> bool:
    # Existing V3 quest settlements already persist canonical completion flags.
    # A completed quest may be replayed through this reconciliation safely:
    # each quest is consumed only once and affects narrative rank, never stats.
    if not loaded:
        return false
    var changed: bool = false
    var completed: Array[String] = []
    for quest_id in all_side_quests:
        var record: Dictionary = all_side_quests[quest_id]
        if record.get("runtime_source_category", "") != "companion":
            continue
        if bool(story_flags.get(str(record.get("completion_flag", "")), false)):
            completed.append(str(quest_id))
    completed.sort()
    for quest_id in completed:
        if used_bond_quest_ids.has(quest_id):
            continue
        var owner: String = str(all_side_quests[quest_id].get("lead_id", ""))
        var output: Dictionary = advance_companion_bond(owner, quest_id, story_flags)
        changed = bool(output.get("success", false)) or changed
    return changed

func unlock_lore(doc_id: String, story_flags: Dictionary) -> bool:
    if not loaded or not lore_documents.has(doc_id):
        return false
    if unlocked_lore_documents.has(doc_id):
        return false
    if not lore_readable(doc_id, story_flags):
        return false
    var record: Dictionary = lore_documents[doc_id]
    unlocked_lore_documents[doc_id] = true
    lore_document_unlocked.emit(doc_id, str(record.get("title", "")))
    return true

func advance_companion_bond(companion_id: String, completed_quest_id: String, story_flags: Dictionary) -> Dictionary:
    # 只允许一条不同的、已完成的正典伙伴任务推动一次亲情/信任阶级。
    # 诺依及所有伙伴均无恋爱与战斗属性绑定。
    if not loaded or not companion_bonds.has(companion_id) or not all_side_quests.has(completed_quest_id):
        return {"success": false, "reason": "unknown_companion_or_quest"}
    var quest: Dictionary = all_side_quests[completed_quest_id]
    if quest.get("runtime_source_category", "") != "companion" or quest.get("lead_id", "") != companion_id:
        return {"success": false, "reason": "quest_not_owned_by_companion"}
    if not story_flags.get(str(quest.get("completion_flag", "")), false):
        return {"success": false, "reason": "quest_not_completed"}
    if used_bond_quest_ids.has(completed_quest_id):
        return {"success": false, "reason": "quest_already_consumed"}
    var rank: int = int(companion_bonds[companion_id]["rank"])
    if rank >= BOND_TITLES.size() - 1:
        return {"success": false, "reason": "max_rank"}
    rank += 1
    used_bond_quest_ids[completed_quest_id] = true
    companion_bonds[companion_id] = {"rank": rank, "title": BOND_TITLES[rank]}
    companion_bond_rank_updated.emit(companion_id, rank, BOND_TITLES[rank])
    return {"success": true, "new_rank": rank, "title": BOND_TITLES[rank]}

func export_state() -> Dictionary:
    return {
        "unlocked_lore_documents": unlocked_lore_documents.duplicate(true),
        "companion_bonds": companion_bonds.duplicate(true),
        "used_bond_quest_ids": used_bond_quest_ids.duplicate(true)
    }

func restore_state(data: Dictionary) -> bool:
    if not loaded:
        return false
    var bonds: Variant = data.get("companion_bonds", null)
    var lore: Variant = data.get("unlocked_lore_documents", null)
    var used: Variant = data.get("used_bond_quest_ids", null)
    if not (bonds is Dictionary) or not (lore is Dictionary) or not (used is Dictionary):
        return false
    for companion_id in COMPANION_IDS:
        if not bonds.has(companion_id) or not (bonds[companion_id] is Dictionary):
            return false
        var rank: int = int(bonds[companion_id].get("rank", -1))
        if rank < 0 or rank >= BOND_TITLES.size() or str(bonds[companion_id].get("title", "")) != BOND_TITLES[rank]:
            return false
    for doc_id in lore:
        if not lore_documents.has(doc_id):
            return false
    for quest_id in used:
        if not all_side_quests.has(quest_id) or all_side_quests[quest_id]["runtime_source_category"] != "companion":
            return false
    companion_bonds = bonds.duplicate(true)
    unlocked_lore_documents = lore.duplicate(true)
    used_bond_quest_ids = used.duplicate(true)
    return true
