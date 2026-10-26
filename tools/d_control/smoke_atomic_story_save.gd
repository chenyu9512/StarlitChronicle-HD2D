extends SceneTree
## Executable Godot test; isolated user:// folder, never modifies production saves.
const Store = preload("res://tools/d_control/atomic_story_save.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, detail: String) -> void:
    if not ok:
        failures.append(detail)

func _write(path: String, data: String) -> bool:
    var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(data)
    f.flush()
    f.close()
    return true

func _run() -> void:
    var sandbox: String = "user://d_atomic_story_" + str(OS.get_process_id())
    var location: String = ProjectSettings.globalize_path(sandbox)
    if DirAccess.make_dir_recursive_absolute(location) != OK:
        push_error("No isolated save test directory")
        quit(1)
        return
    var path: String = sandbox + "/story.json"
    var v2: Dictionary = {"version": 2, "current_chapter_id": "ch002",
            "current_scene_index": 1, "line_index": 0, "flags": {"story.ch001.done": true},
            "objective_progress": {}, "side_quest_progress": {}, "pending_branch_dialogue": [],
            "dialogue_ended": false, "waiting_battle": false, "choice_made": false}
    check(Store.write_verified(path, v2), "first save failed")
    check(Store.read_verified(path).get("current_scene_index") == 1, "v2 did not restore")
    v2["current_scene_index"] = 2
    check(Store.write_verified(path, v2), "second save failed")
    check(Store.read_verified(path).get("current_scene_index") == 2, "new snapshot incorrect")
    check(_write(path, "{broken"), "failed to create corrupted primary")
    check(Store.read_verified(path).get("current_scene_index") == 1, "valid backup not restored")
    v2["current_scene_index"] = 3
    check(Store.write_verified(path, v2), "write over corrupted primary failed")
    check(_write(path, "{broken again"), "failed to corrupt second primary")
    check(Store.read_verified(path).get("current_scene_index") == 1,
            "corrupt primary overwrote last valid backup")
    check(not Store.write_verified(path, {"version": 2, "flags": {}}),
            "invalid snapshot was accepted")
    var v1: Dictionary = {"version": 1, "current_chapter_id": "ch005", "flags": {}}
    check(Store.write_verified(path, v1), "old v1 snapshot rejected")
    check(Store.read_verified(path).get("version") == 1, "v1 version changed")
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
        var file: String = path + suffix
        if FileAccess.file_exists(file):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
    DirAccess.remove_absolute(location)
    if failures.is_empty():
        print("PASS: D atomic story IO, old schema, corrupt primary fallback and backup protection")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
