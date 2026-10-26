extends SceneTree
## B-line transactional story regression. Isolated user:// files only; never real player saves.
const Runtime = preload("res://scripts/story_runtime.gd")
var faults: Array[String] = []

class FixtureCatalog:
    extends RefCounted
    var prologue: Dictionary = {"scenes":[]}
    func get_chapter(_id: String) -> Dictionary:
        return {}
    func requirements_met(_required: Array, _flags: Dictionary) -> bool:
        return true
    func get_quest(id: String) -> Dictionary:
        if id == "b_qa_quest":
            return {"id":id,"completion_flag":"b.qa.quest.done",
                "type":"lost_page","page_number":1,"stages":[],
                "rewards":{"xp":12,"gold":5}}
        return {}

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, detail: String) -> void:
    if not ok:
        faults.append(detail)

func _write(path: String, content: String) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(content)
    file.flush()
    file.close()
    return true

func _runner(path: String):
    var r = Runtime.new()
    r.loaded = true
    r.catalog = FixtureCatalog.new()
    r.save_path = path
    r.current_chapter_id = "prologue"
    r.current_chapter = {"scenes":[{"id":"b_qa_scene",
        "effects":[{"type":"set_flag","key":"b.qa.scene.done","value":true},
            {"type":"grant","xp":19,"gold":7},
            {"type":"time_skip","years":2}]}]}
    return r

func _run() -> void:
    var sandbox: String = "user://b_story_tx_%d" % OS.get_process_id()
    var root_path: String = ProjectSettings.globalize_path(sandbox)
    if DirAccess.make_dir_recursive_absolute(root_path) != OK:
        push_error("Cannot create isolated B story smoke directory")
        quit(1)
        return
    var valid_path: String = sandbox + "/story.json"
    var failure_path: String = sandbox + "/missing/story.json"
    var run = _runner(failure_path)
    var emitted: Array[Dictionary] = []
    var world_calls: Array[Dictionary] = []
    run.reward_granted.connect(func(reward: Dictionary) -> void: emitted.append(reward.duplicate(true)))
    run.world_event.connect(func(event: Dictionary) -> void: world_calls.append(event.duplicate(true)))

    run._finish_scene()
    check(run.current_scene_index == 0, "Failed scene save advanced the scene")
    check(run.flags.is_empty(), "Failed scene save retained flags or milestones")
    check(run.pending_reward_receipts().is_empty(), "Failed save leaked reward outbox")
    check(emitted.is_empty() and world_calls.is_empty(), "Failed scene save emitted effects")

    run.save_path = valid_path
    run._finish_scene()
    check(run.current_scene_index == 1, "Successful scene not completed")
    check(bool(run.flags.get("b.qa.scene.done",false)), "Scene effect flag missing")
    check(int(run.flags.get("world.years_passed",0)) == 2, "Time skip not persisted")
    check(emitted.size() == 1 and world_calls.size() == 1, "Scene effects not emitted once")
    var eid: String = "b.story.scene.b_qa_scene.reward.1"
    check(run.pending_reward_receipts().has(eid), "Scene reward receipt not durable")
    if not emitted.is_empty():
        check(str(emitted[0].get("event_id","")) == eid, "Unstable reward event ID")
    run._finish_scene()
    check(emitted.size() == 1, "Duplicate scene callback emitted second payout")

    var reopened = _runner(valid_path)
    check(reopened.load_story(), "Saved story cannot load")
    check(reopened.pending_reward_receipts().has(eid), "Pending reward lost after reload")
    var replayed: Array[String] = []
    reopened.reward_granted.connect(func(reward: Dictionary) -> void: replayed.append(str(reward.get("event_id",""))))
    reopened.replay_pending_rewards()
    check(replayed == [eid], "Pending reward not available for idempotent replay")
    reopened.save_path = failure_path
    check(not reopened.acknowledge_reward(eid), "Receipt acknowledged despite save failure")
    check(reopened.pending_reward_receipts().has(eid), "Failed receipt save lost pending event")
    reopened.save_path = valid_path
    check(reopened.acknowledge_reward(eid), "Durable reward acknowledgement failed")
    check(reopened.pending_reward_receipts().is_empty(), "Acknowledged reward still pending")

    # The previous verified story should survive a damaged active JSON.
    check(_write(valid_path, "{damaged"), "Failed to inject corrupted primary")
    var backup = _runner(valid_path)
    check(backup.load_story(), "Corrupt primary did not fall back to valid backup")
    check(backup.pending_reward_receipts().has(eid), "Backup reward receipt was lost")

    var quest = _runner(failure_path)
    quest.side_quest_progress["b_qa_quest"] = 0
    var quest_emits: Array[String] = []
    quest.reward_granted.connect(func(payload: Dictionary) -> void: quest_emits.append(str(payload.get("event_id",""))))
    check(not quest.complete_side_quest("b_qa_quest"), "Quest succeeded without a disk commit")
    check(not bool(quest.flags.get("b.qa.quest.done",false)), "Quest flag survived failed save")
    check(quest.pending_reward_receipts().is_empty(), "Quest leaked an unsaved receipt")
    check(quest_emits.is_empty(), "Quest rewarded before save")
    quest.save_path = sandbox + "/quest.json"
    check(quest.complete_side_quest("b_qa_quest"), "Quest completion failed with valid disk")
    check(quest_emits == ["b.story.quest.b_qa_quest.reward"], "Quest receipt ID mismatch")
    check(not quest.complete_side_quest("b_qa_quest"), "Quest was completed twice")
    check(quest_emits.size() == 1, "Quest reward was emitted twice")

    var choice = _runner(failure_path)
    choice.current_chapter = {"scenes":[{"id":"b_qa_choice",
        "choice":{"id":"b_qa_select","options":[{"id":"pick_a","sets":{"b.qa.selected":true}}]}}]}
    choice.dialogue_ended = true
    check(not choice.choose_option("pick_a"), "Unsaved choice incorrectly succeeded")
    check(not choice.flags.has("b.qa.selected") and not choice.choice_made, "Choice rollback failed")
    var battle = _runner(failure_path)
    battle.waiting_battle = true
    battle.current_chapter = {"scenes":[{"id":"b_qa_battle",
        "encounter":{"win_flag":"b.qa.battle_won"}}]}
    battle.report_battle_result(true)
    check(battle.waiting_battle and not battle.flags.has("b.qa.battle_won"),
        "Battle progress advanced despite failed story save")

    for suffix in ["story.json","story.json.bak","story.json.tmp",
        "story.json.bak.tmp","quest.json","quest.json.tmp","quest.json.bak",
        "quest.json.bak.tmp"]:
        var file_path: String = sandbox + "/" + suffix
        if FileAccess.file_exists(file_path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
    DirAccess.remove_absolute(root_path)
    if faults.is_empty():
        print("PASS: B story scene/quest/choice/battle save gating, backup recovery, stable receipts")
        quit(0)
        return
    for issue in faults:
        push_error(issue)
    quit(1)
