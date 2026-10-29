extends SceneTree
## Actual controller and V3 disk rollback when a cinematic checkpoint cannot
## be persisted. Every path is sandboxed; no player autosave is touched.
const Game = preload("res://scripts/first_act.gd")
const State = preload("res://scripts/first_act_state.gd")
var failures: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)

func _run() -> void:
    var sandbox: String="user://smoke_cinematic_v3_%d" % OS.get_process_id()
    var absolute: String=ProjectSettings.globalize_path(sandbox)
    if DirAccess.make_dir_recursive_absolute(absolute)!=OK:
        push_error("Cannot create isolated cinematic save folder")
        quit(1)
        return
    var save: String=sandbox+"/save.json"
    var backup: String=sandbox+"/backup.json"
    var game=Game.new()
    game.cinematic_force_play=true
    root.add_child(game)
    game.progress.save_path=save
    game.progress.backup_path=backup
    game.ui.title_overlay.hide()
    game._start(false)
    _check(game.cinematic.is_playing() and game.cinematic.active_id=="cold_open",
        "New game has no actual cold-open cinematic")
    _check(str(game.progress.rpg.get("cinematic_checkpoint",""))=="cold_open",
        "Cold-open checkpoint missing before disk failure")

    # Reject the write exactly when the director finishes/skips.
    game.progress.save_path=sandbox+"/not_existing_folder/save.json"
    game.progress.backup_path=sandbox+"/not_existing_folder/backup.json"
    game.cinematic.skip()
    _check(not bool(game.progress.flags.get("cinematic.cold_open.seen",false)),
        "Failed finish marked opening as permanently seen")
    _check(str(game.progress.rpg.get("cinematic_checkpoint",""))=="cold_open",
        "Failed finish erased the pending cinematic recovery point")
    _check(game.ui.title_overlay.visible and game.busy and game.world.locked,
        "Failed finish allowed unsaved exploration or story progress")
    _check(not game.cinematic.is_playing(),
        "Failed finish left an active cinematic while showing recovery title")
    game.progress.save_path=save
    game.progress.backup_path=backup
    game.ui.title_overlay.hide()
    game._start(true)
    _check(game.cinematic.is_playing() and game.cinematic.active_id=="cold_open",
        "Continue did not replay interrupted cinematic from disk")
    if game.cinematic.is_playing():
        game.cinematic.skip()
    _check(bool(game.progress.flags.get("cinematic.cold_open.seen",false)) and
        not game.progress.rpg.has("cinematic_checkpoint"),
        "Successful replay did not durably finish the opening")

    # A failed START must not leave a phantom checkpoint or active cue.
    var initial: Dictionary=game.progress._pack().duplicate(true)
    game.progress.save_path=sandbox+"/not_existing_folder/save.json"
    game.progress.backup_path=sandbox+"/not_existing_folder/backup.json"
    var handled: bool=game._play_story_cinematic("prologue_0","dialogue")
    _check(handled and game.ui.title_overlay.visible and game.world.locked,
        "Start-save failure did not fail closed to recovery title")
    _check(not game.cinematic.is_playing() and
        game.progress._pack()==initial,
        "Failed cinematic start left mutated story or save state")
    game.progress.save_path=save
    game.progress.backup_path=backup
    game.ui.title_overlay.hide()
    game._start(true)
    _check(not game.cinematic.is_playing() and game.progress.scene_index==0,
        "Recovering a failed cinematic start skipped or replayed a non-durable cue")
    var reader=State.new()
    reader.save_path=save
    reader.backup_path=backup
    _check(reader.load_saved() and
        bool(reader.flags.get("cinematic.cold_open.seen",false)) and
        not reader.rpg.has("cinematic_checkpoint"),
        "Disk reload did not preserve the completed opening only")

    for filepath in [save,backup,save+".tmp",backup+".tmp"]:
        if FileAccess.file_exists(filepath):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(filepath))
    DirAccess.remove_absolute(absolute)
    game.queue_free()
    if failures.is_empty():
        print("PASS Act-I cinematic: finish/start failures roll back and Continue replays only durable checkpoints")
        quit(0)
        return
    for reason in failures:
        push_error(reason)
    quit(1)
