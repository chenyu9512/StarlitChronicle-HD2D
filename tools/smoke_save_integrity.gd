extends SceneTree
## P0 save integrity regression. All file writes use a process-local QA folder,
## never the player's default V3 autosave or manual slot directory.
const State = preload("res://scripts/first_act_state.gd")
const Slots = preload("res://scripts/save_slots.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _write(path: String, content: String) -> bool:
    var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if handle == null:
        return false
    handle.store_string(content)
    handle.flush()
    handle.close()
    return true

func _run() -> void:
    var sandbox: String = "user://smoke_save_integrity_%d" % OS.get_process_id()
    var absolute_root: String = ProjectSettings.globalize_path(sandbox)
    if DirAccess.make_dir_recursive_absolute(absolute_root) != OK:
        push_error("Cannot create isolated save verification directory")
        quit(1)
        return

    var state = State.new()
    state.save_path = sandbox + "/autosave.json"
    state.backup_path = sandbox + "/autosave.backup.json"
    check(state.save(), "First V3 autosave failed")
    state.gold = 245
    check(state.save(), "Second V3 autosave failed")

    var reader = State.new()
    reader.save_path = state.save_path
    reader.backup_path = state.backup_path
    check(reader.load_saved(), "Valid second autosave could not load")
    check(reader.gold == 245, "Newest autosave did not restore correct gold")

    var missing_field: Dictionary = reader._pack()
    missing_field.erase("gold")
    check(not reader._valid_payload(missing_field), "Missing gold field passed V3 validation")
    missing_field = reader._pack()
    missing_field.erase("dialogue_seen")
    check(not reader._valid_payload(missing_field), "Missing dialogue field passed V3 validation")
    missing_field = reader._pack()
    missing_field["gold"] = "not a number"
    check(not reader._valid_payload(missing_field), "Nonnumeric gold passed V3 validation")
    missing_field = reader._pack()
    missing_field["version"] = {"wrong": "type"}
    check(not reader._valid_payload(missing_field), "Malformed save version passed V3 validation")
    missing_field = reader._pack()
    missing_field["rpg"] = "bad nested state"
    check(not reader._valid_payload(missing_field), "Invalid rpg state passed V3 validation")
    missing_field = reader._pack()
    missing_field["play_seconds"] = INF
    check(not reader._valid_payload(missing_field), "Infinite play time passed V3 validation")
    missing_field = reader._pack()
    missing_field["inventory"] = {"item_herb_01": INF}
    check(not reader._valid_payload(missing_field), "Infinite item count passed V3 validation")
    missing_field = reader._pack()
    missing_field["chapter"] = 2.5
    check(not reader._valid_payload(missing_field), "Fractional chapter silently truncated")
    missing_field = reader._pack()
    missing_field["gold"] = 80.75
    check(not reader._valid_payload(missing_field), "Fractional gold silently truncated")
    missing_field = reader._pack()
    missing_field["inventory"] = {"item_herb_01": 1.5}
    check(not reader._valid_payload(missing_field), "Fractional inventory reward silently truncated")
    missing_field = reader._pack()
    missing_field["actors"] = reader.actors.duplicate(true)
    missing_field["actors"][0]["hp"] = 0.5
    check(not reader._valid_payload(missing_field), "Fractional party HP silently truncated")
    missing_field = reader._pack()
    missing_field["actors"] = reader.actors.duplicate(true)
    missing_field["actors"][0]["hp"] = -1
    check(not reader._valid_payload(missing_field), "Negative party HP passed V3 validation")
    var prior_gold: int = reader.gold
    check(not reader.restore_snapshot(missing_field), "Malformed snapshot was restored")
    check(reader.gold == prior_gold, "Failed restore mutated player state")

    check(_write(state.save_path, "{damaged json"), "Could not construct damaged autosave")
    reader.gold = 900
    check(reader.load_saved(), "Last valid autosave backup was not recovered")
    check(reader.gold == 80, "Recovered backup should contain previous valid gold")

    var missing_dir_state = State.new()
    missing_dir_state.save_path = sandbox + "/missing_directory/autosave.json"
    missing_dir_state.backup_path = sandbox + "/missing_directory/autosave.backup.json"
    check(not missing_dir_state.save(), "Autosave reported success in missing directory")

    var slots = Slots.new()
    slots.folder = sandbox + "/slots"
    var manual = State.new()
    manual.gold = 188
    check(slots.save_slot(manual, 1), "First manual slot save failed")
    manual.gold = 499
    check(slots.save_slot(manual, 1), "Manual slot replacement failed")
    var slot_path: String = slots.folder + "/slot_01.json"
    check(_write(slot_path, "{damaged json"), "Could not construct damaged manual save")
    var summary: Dictionary = slots.summary(1)
    check(bool(summary.get("exists", false)), "Healthy slot backup not listed")
    check(int(summary.get("gold", -1)) == 188, "Slot summary did not fall back to backup")
    var restored = State.new()
    check(slots.load_slot(restored, 1), "Manual slot backup was not loaded")
    check(restored.gold == 188, "Manual backup gold was not restored")
    check(_write(slot_path + ".bak", "{damaged backup"), "Could not corrupt manual backup")
    check(not bool(slots.summary(1).get("exists", true)), "Corrupt slot presented as valid")
    restored.gold = 111
    check(not slots.load_slot(restored, 1), "Both damaged slot copies were accepted")
    check(restored.gold == 111, "Failed slot restore mutated player state")

    for path in [
        state.save_path, state.backup_path, state.save_path + ".tmp",
        state.backup_path + ".tmp", slot_path, slot_path + ".bak",
        slot_path + ".tmp", slot_path + ".bak.tmp"
    ]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(slots.folder))
    DirAccess.remove_absolute(absolute_root)

    if failures.is_empty():
        print("PASS: sandboxed V3 autosave atomic replacement, backup recovery, invalid payload rejection and manual slot summary")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
