extends SceneTree
## Focused headless check: parse installed plugin script and exercise safe preview.
const Pipeline = preload("res://addons/starlit_art_pipeline/pipeline.gd")
const ArtPipelinePluginScript = preload("res://addons/starlit_art_pipeline/plugin.gd")
const Themes = preload("res://scripts/c_art_theme_v2.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(Pipeline.REGISTRY))
    if not raw is Dictionary:
        push_error("Missing art registry")
        quit(1)
        return
    var approved: Dictionary = {}
    for item in raw.get("themes", []):
        if item is Dictionary and str(item.get("id", "")) == "starlit_hd2d_act01":
            approved = item.get("slots", {})
    if approved.size() != 109:
        push_error("109-slot contract mismatch")
        quit(1)
        return
    for danger in ["../escape.png", "C:/Windows/system.png", "/etc/passwd", "a/../../b.png"]:
        if Pipeline._candidate("res://", danger) != "":
            push_error("Unsafe candidate accepted: " + danger)
            quit(1)
            return
    var missing: Dictionary = Pipeline._load_rows("res://build/nonexistent_art_pipeline_test.csv")
    if not missing.has("error"):
        push_error("Missing V5 CSV must fail closed")
        quit(1)
        return
    var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.6, 0.3, 0.2))
    var dest: String = "user://starlit_art_pipeline_test.png"
    if not Pipeline._preview(image, Vector2i(64, 80),
            ProjectSettings.globalize_path(dest), false):
        push_error("Art pipeline preview generation failed")
        quit(1)
        return
    var decoded: Image = Image.new()
    if decoded.load(dest) != OK or decoded.get_width() != 64 or decoded.get_height() != 80:
        push_error("Output canvas geometry incorrect")
        quit(1)
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(dest))
    # A complete theme must never be installed from a merely approved/previewed
    # record. Exercise the 109-slot audit without touching game or save files.
    var original_active: String = Themes.active_id()
    var test_csv: String = "user://starlit_art_gate_test.csv"
    var file := FileAccess.open(test_csv, FileAccess.WRITE)
    if file == null:
        push_error("Cannot write temporary test CSV")
        quit(1)
        return
    file.store_string("slot_id,approved,candidate_path,next_state,final_visual_approved,asset_role\n")
    var keys: Array = approved.keys()
    keys.sort()
    for key in keys:
        file.store_string(str(key) + ",NO,,SIZE_CONVERSION_REQUIRED,NO,\n")
    file.close()
    var gate: Dictionary = Pipeline.audit_complete_dlc("res://", test_csv)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(test_csv))
    if bool(gate.get("ok", true)) or int(gate.get("ready", -1)) != 0 \
            or int(gate.get("blocked", -1)) != 109 \
            or not FileAccess.file_exists(Pipeline.OUT + "/release_gate.csv"):
        push_error("Release gate incorrectly accepted unsigned, incomplete assets")
        quit(1)
        return
    if Themes.active_id() != original_active:
        push_error("Read-only audit unexpectedly changed the active art theme")
        quit(1)
        return
    if bool(Themes.report("user_nonexistent_theme").get("ok", true)):
        push_error("Unknown user pack incorrectly considered safe")
        quit(1)
        return
    print("PASS: plugin loads; 109 slots; path traversal denied; preview works; unsigned replacement blocked; active theme unchanged.")
    quit(0)
