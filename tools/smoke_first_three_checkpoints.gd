extends SceneTree
## First vertical-slice save/checkpoint regression, NOT a human playthrough.
## No cheats, Boss victory flags, or account-bound test runners are required.
## This test is queued for the next full batch; do not run per small commit.
const Game = preload("res://scripts/first_act.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func ck(value: bool, description: String) -> void:
    if not value:
        failures.append(description)

func write_text(path: String, value: String) -> bool:
    var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(value)
    f.flush()
    f.close()
    return true

func find_safe_position(game, origin: Vector2) -> Vector2:
    var w = game.world
    for y in range(3, w.HEIGHT - 3):
        for x in range(3, w.WIDTH - 3):
            var spot := Vector2(float(x * 32 + 16), float(y * 32 + 16))
            if spot.distance_to(origin) > 110.0 and not w._blocked(spot):
                return spot
    return origin

func _run() -> void:
    var folder := "user://smoke_first_three_checkpoints_%d" % OS.get_process_id()
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
        push_error("Cannot create isolated first-three-chapter test folder")
        quit(1)
        return
    var game = Game.new()
    root.add_child(game)
    game.progress.save_path = folder + "/autosave.json"
    game.progress.backup_path = folder + "/autosave.bak.json"
    game.ui.title_overlay.hide()
    game._start(false)

    for chapter in range(0, 4):
        game.progress.chapter = chapter
        game.progress.scene_index = 0
        game.progress.task_index = 0
        game._enter_location()
        var start: Vector2 = game.world.hero.position
        var desired: Vector2 = find_safe_position(game, start)
        ck(desired.distance_to(start) > 110.0,
            "No independent walkable checkpoint in chapter %d" % chapter)
        game.world.hero.position = desired
        ck(game._save_progress(), "Checkpoint could not be written in chapter %d" % chapter)
        game.world.hero.position = start
        ck(game.progress.load_saved(), "Saved V3 chapter %d could not reload" % chapter)
        game._enter_location()
        ck(game.world.hero.position.distance_to(desired) < 1.0,
            "Reload unexpectedly returned to the map entrance in chapter %d" % chapter)

    # Snapshot coordinates must never place the player in a wall or outside map.
    var world_state: Dictionary = game.progress.rpg.get("world", {})
    var checkpoint: Dictionary = world_state.get("player_checkpoint", {})
    var valid_position: Vector2 = game.world.hero.position
    checkpoint["xy"] = [-12345.0, 500000.0]
    game._enter_location()
    ck(game.world.hero.position.distance_to(valid_position) > 1.0,
        "Out-of-bounds checkpoint wrongly teleported the player")
    checkpoint["xy"] = ["invalid", 50.0]
    game._enter_location()
    ck(is_instance_valid(game.world.hero),
        "Malformed checkpoint caused world rebuild failure")

    # Controller-level defeat recovery: this tests the handler, NOT boss balance.
    game.progress.chapter = 2
    game.progress.scene_index = 2
    game.progress.task_index = 1
    game._enter_location()
    game.progress.gold = 120
    var spawn_cell: Vector2i = game.world.terrain_layout.get("spawn", Vector2i(10, 23))
    var spawn_point := Vector2(spawn_cell * 32) + Vector2(16, 16)
    game.world.hero.position = find_safe_position(game, spawn_point)
    var chapter_before_defeat: int = game.progress.chapter
    var scene_before_defeat: int = game.progress.scene_index
    # Exercise the ACTUAL A→D completed signal and world handoff. Calling
    # _battle_finished directly with no battle instance is an invalid fixture.
    game._start_battle(true)
    ck(is_instance_valid(game.battle), "Cannot start real boss fight for defeat recovery")
    if is_instance_valid(game.battle):
        var first_defeat_nonce: String = game.battle_defeat_id
        ck(not first_defeat_nonce.is_empty(), "D defeat nonce missing from active fight")
        game.progress.actors[0]["hp"] = 0
        game.battle._finish(false)
        ck(game.world.hero.position.distance_to(spawn_point) < 1.0,
            "Defeat did not return the player to a safe regional entry")
        ck(game.world.encounter_meter < 0.0,
            "Defeat retry has no grace period against random encounters")
        ck(game.progress.gold == 105, "Defeat penalty applied incorrectly")
        ck(int(game.progress.actors[0]["hp"]) > 0, "Defeat did not restore the party")
        ck(game.progress.chapter == chapter_before_defeat and
            game.progress.scene_index == scene_before_defeat,
            "Defeat incorrectly advanced the main story")
        ck(not bool(game.progress.flags.get("ch002.battle_won", false)),
            "Defeat set a false Boss victory flag")
        # A second attempt at the same boss must have its own defeat receipt.
        # A stable Boss VICTORY nonce may not suppress the new loss penalty.
        game._start_battle(true)
        ck(is_instance_valid(game.battle), "Cannot retry real boss after a defeat")
        if is_instance_valid(game.battle):
            ck(game.battle_defeat_id != first_defeat_nonce,
                "Second boss attempt reused first defeat nonce")
            game.battle._finish(false)
            ck(game.progress.gold == 90, "New failed boss attempt failed to deduct second penalty")

    # Corrupting BOTH copies and selecting Continue must not overwrite either.
    var damaged_main := "{broken-main"
    var damaged_backup := "{broken-backup"
    ck(write_text(game.progress.save_path, damaged_main), "Cannot prepare corrupted main")
    ck(write_text(game.progress.backup_path, damaged_backup), "Cannot prepare corrupted backup")
    var before_chapter: int = game.progress.chapter
    game._start(true)
    ck(game.progress.chapter == before_chapter, "Failed Continue started a new journey")
    ck(game.ui.title_overlay.visible, "Failed Continue did not return to title")
    ck(game.ui.title_continue.disabled, "Failed Continue still lets the player retry broken files")
    ck(game.ui.title_status.visible and not game.ui.title_status.text.is_empty(),
        "Continue failure message is missing from the title screen")
    ck(FileAccess.get_file_as_string(game.progress.save_path) == damaged_main,
        "Failed Continue overwrote damaged main save")
    ck(FileAccess.get_file_as_string(game.progress.backup_path) == damaged_backup,
        "Failed Continue overwrote damaged backup")

    for path in [game.progress.save_path, game.progress.backup_path,
            game.progress.save_path + ".tmp", game.progress.backup_path + ".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))

    if failures.is_empty():
        print("PASS: safe physical save position across prologue and chapters 1-3, rejection of malformed spawn and no overwrite after failed Continue")
        quit(0)
        return
    for problem in failures:
        push_error(problem)
    quit(1)
