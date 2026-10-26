extends SceneTree
## Batch 0.3 isolated engine regression for V1/V2/V3 and failing checkpoints.
## Does not read or overwrite real player saves.
const V3 = preload("res://scripts/first_act_state.gd")
const Legacy = preload("res://scripts/game_state.gd")
const BStory = preload("res://scripts/story_runtime.gd")
const Transition = preload("res://scripts/d_world_interaction/v3_progress_transition.gd")

class TinyCatalog:
    extends RefCounted
    var prologue: Dictionary = {"scenes":[{"id":"qa_prologue_v1",
        "dialogue":[{"speaker":"旁白","text":"恢复旧章节"}]}]}
    func get_chapter(_chapter_id: String) -> Dictionary:
        return {}
    func requirements_met(_required: Array, _flags: Dictionary) -> bool:
        return true

var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
func write_text(path: String, payload: String) -> bool:
    var f: FileAccess = FileAccess.open(path,FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(payload)
    f.flush()
    f.close()
    return true

func _run() -> void:
    var sandbox: String = "user://d_batch03_recovery_%d" % OS.get_process_id()
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox)) != OK:
        push_error("Cannot create isolated save sandbox")
        quit(1)
        return
    var state = V3.new()
    state.save_path = sandbox + "/v3.json"
    state.backup_path = sandbox + "/v3.backup.json"
    check(state.save(), "Initial V3 checkpoint failed")
    var first_checkpoint: Dictionary = state._pack().duplicate(true)
    state.gold += 27
    check(state.save(), "Updated V3 save failed")
    check(write_text(state.save_path,"{damaged-v3"), "V3 corruption injection failed")
    var loaded = V3.new()
    loaded.save_path = state.save_path
    loaded.backup_path = state.backup_path
    check(loaded.load_saved(), "Damaged V3 did not use backup")
    check(loaded._pack() == first_checkpoint, "V3 backup produced different state")

    var good: Dictionary = loaded._pack().duplicate(true)
    var malformed: Dictionary = good.duplicate(true)
    malformed["actors"][0]["hp"] = "corrupted"
    check(not loaded.restore_snapshot(malformed), "Invalid V3 actor data was accepted")
    check(loaded._pack() == good, "Rejected V3 actor corrupted in-memory checkpoint")
    malformed = good.duplicate(true)
    malformed["scene"] = 999
    check(not loaded.restore_snapshot(malformed), "Out-of-range V3 scene was accepted")
    check(loaded._pack() == good, "Rejected V3 scene mutated memory")

    var mutating = V3.new()
    mutating.save_path = sandbox + "/missing/progress.json"
    mutating.backup_path = sandbox + "/missing/backup.json"
    var before: Dictionary = mutating._pack().duplicate(true)
    var failed: Dictionary = Transition.commit(mutating,func() -> Dictionary:
        mutating.chapter = 8
        mutating.scene_index = 0
        mutating.gold += 200
        mutating.recruit_sailor()
        mutating.heal_all()
        return {"ok":true}
    )
    check(str(failed.get("reason",""))=="save_failed", "Chapter transition ignored failed save")
    check(mutating._pack() == before, "Chapter failure leaked money, party or flags")
    mutating.save_path = sandbox + "/chapter.json"
    mutating.backup_path = sandbox + "/chapter.backup.json"
    var recovered: Dictionary = Transition.commit(mutating,func() -> Dictionary:
        mutating.chapter = 8
        mutating.scene_index = 0
        mutating.gold += 200
        mutating.recruit_sailor()
        return {"ok":true}
    )
    check(bool(recovered.get("ok",false)), "Chapter did not retry after storage repair")
    var checkpoint = V3.new()
    checkpoint.save_path = mutating.save_path
    checkpoint.backup_path = mutating.backup_path
    check(checkpoint.load_saved(), "Chapter transition was not durable")
    check(checkpoint.chapter==8 and checkpoint.gold==280 and checkpoint.actors.size()==3,
        "Chapter transition did not survive restart")

    # V1 legacy stores stay independent of the FirstAct V3 path.
    var legacy = Legacy.new()
    legacy.new_game()
    legacy.save_path = sandbox + "/v1.json"
    legacy.backup_path = sandbox + "/v1.bak"
    check(legacy.save_game(), "V1 initial atomic write failed")
    legacy.gold = 456
    check(legacy.save_game(), "V1 update failed")
    check(write_text(legacy.save_path,"{damaged-v1"), "V1 corruption injection failed")
    var reopened = Legacy.new()
    reopened.new_game()
    reopened.save_path = legacy.save_path
    reopened.backup_path = legacy.backup_path
    check(reopened.load_game() and reopened.gold==35, "V1 backup recovery failed")
    var no_v1 = Legacy.new()
    no_v1.new_game()
    no_v1.save_path = sandbox + "/missing/v1.json"
    no_v1.backup_path = sandbox + "/missing/v1.bak"
    check(not no_v1.save_game(), "V1 save accepted an inaccessible directory")
    check(FileAccess.file_exists(legacy.backup_path), "V1 failure destroyed old backup")

    # V2 B story files and historical V1 B story files have their own contract.
    var story = BStory.new()
    story.catalog = TinyCatalog.new()
    story.loaded = true
    story.current_chapter_id = "prologue"
    story.current_chapter = story.catalog.prologue
    story.save_path = sandbox + "/b_v2.json"
    story.flags["legacy.marker"] = true
    check(story.save_story(), "B story V2 write failed")
    var b2 = BStory.new()
    b2.catalog = TinyCatalog.new()
    b2.loaded = true
    b2.save_path = story.save_path
    check(b2.load_story() and bool(b2.flags.get("legacy.marker",false)),
        "B story V2 roundtrip failed")
    var legacy_b_payload: Dictionary = {"version":1,"current_chapter_id":"prologue",
        "current_scene_index":0,"flags":{"b.v1.memory":true},
        "side_quest_progress":{},"objective_progress":{}}
    var legacy_b_path: String = sandbox + "/b_v1.json"
    check(write_text(legacy_b_path,JSON.stringify(legacy_b_payload)), "B V1 fixture write failed")
    var b1 = BStory.new()
    b1.catalog = TinyCatalog.new()
    b1.loaded = true
    b1.save_path = legacy_b_path
    check(b1.load_story(), "B story historical V1 load failed")
    check(bool(b1.flags.get("b.v1.memory",false)) and b1.reward_outbox.is_empty(),
        "B V1 flags or empty legacy outbox changed")
    check(not FileAccess.file_exists(sandbox+"/new_game_v3.json"),
        "V1/V2 replay unexpectedly created V3 game save")

    for filename in ["v3.json","v3.json.tmp","v3.backup.json","v3.backup.json.tmp",
        "chapter.json","chapter.json.tmp","chapter.backup.json","chapter.backup.json.tmp",
        "v1.json","v1.json.tmp","v1.bak","v1.bak.tmp","b_v2.json","b_v2.json.tmp",
        "b_v2.json.bak","b_v2.json.bak.tmp","b_v1.json","b_v1.json.tmp",
        "b_v1.json.bak","b_v1.json.bak.tmp"]:
        var path: String = sandbox+"/"+filename
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
    if failures.is_empty():
        print("PASS: V1/V2/V3 isolated recovery, corrupt payload, transaction rollback, retry and restart")
        quit(0)
    else:
        for problem in failures:
            push_error(problem)
        quit(1)
