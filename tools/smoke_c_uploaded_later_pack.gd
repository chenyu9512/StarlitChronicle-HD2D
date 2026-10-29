extends SceneTree
## C-line later-upload artwork migration: engine check, not a visual QA substitute.
## Run with a disposable Godot user:// profile; this smoke restores the chosen pack.
const Art = preload("res://scripts/c_art_overrides.gd")
const PACK_INDEX: String = "res://data/assets/c_art_packs.json"
const PACK_ID: String = "uploaded_later_v1"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACK_INDEX))
    if not raw is Dictionary:
        _fail("Art pack manifest unavailable or malformed")
        return
    var entries: Array = []
    for item in raw.get("packs", []):
        if item is Dictionary and str(item.get("id", "")) == PACK_ID:
            entries = item.get("mappings", [])
            break
    if entries.size() != 6:
        _fail("Expected exactly six approved initial source-to-slot mappings")
        return
    var inspection: Dictionary = Art.pack_report(PACK_ID)
    if not bool(inspection.get("ok", false)) or int(inspection.get("mapped", 0)) != entries.size() or int(inspection.get("fallback", -1)) != 0:
        _fail("Pack not fully registered or some source images cannot load: " + str(inspection))
        return
    var former: String = Art.active_pack()
    if not Art.activate_pack(PACK_ID):
        _fail("Could not activate later-upload pack")
        return
    var errors: Array[String] = []
    for entry in entries:
        if not entry is Dictionary:
            errors.append("Mapping has wrong type")
            continue
        var target: String = str(entry.get("target", ""))
        var source: String = str(entry.get("source", ""))
        if not source.begins_with("res://assets/art/external/cc0_named_v1/"):
            errors.append("Source is not a later-uploaded art file: " + source)
            continue
        if not Art.has_slot(target) or not Art.pack_has_slot(target):
            errors.append("Target is not a registered effective later-upload slot: " + target)
            continue
        var baseline: Texture2D = Art.original_texture(target)
        var source_texture: Texture2D = Art.original_texture(source)
        var current: Texture2D = Art.texture(target)
        if baseline == null or source_texture == null or current == null:
            errors.append("Target or uploaded source failed to load: " + target)
            continue
        var destination_size: Vector2i = Vector2i(baseline.get_size())
        if Vector2i(current.get_size()) != destination_size:
            errors.append("Wrong final runtime dimensions: " + target)
            continue
        var expected_image: Image = source_texture.get_image()
        var current_image: Image = current.get_image()
        if expected_image == null or current_image == null:
            errors.append("Cannot compare texture pixels: " + target)
            continue
        # The six-pair DLC uses aspect-preserving padding rather than
        # stretching a square legacy prop into a 96x128 figure.
        expected_image.convert(Image.FORMAT_RGBA8)
        var factor: float = minf(float(destination_size.x)/float(expected_image.get_width()),
            float(destination_size.y)/float(expected_image.get_height()))
        var fitted_w: int = maxi(1,mini(destination_size.x,roundi(float(expected_image.get_width())*factor)))
        var fitted_h: int = maxi(1,mini(destination_size.y,roundi(float(expected_image.get_height())*factor)))
        expected_image.resize(fitted_w,fitted_h,Image.INTERPOLATE_NEAREST)
        var padded: Image = Image.create(destination_size.x,destination_size.y,false,Image.FORMAT_RGBA8)
        padded.fill(Color.TRANSPARENT)
        padded.blit_rect(expected_image,Rect2i(0,0,fitted_w,fitted_h),
            Vector2i((destination_size.x-fitted_w)/2,(destination_size.y-fitted_h)/2))
        expected_image = padded
        current_image.convert(Image.FORMAT_RGBA8)
        if expected_image.get_data() != current_image.get_data():
            errors.append("Still displaying an old fallback, not uploaded pixels: " + target)
    if not Art.activate_pack(former):
        errors.append("Cannot restore previously selected art pack")
    if not errors.is_empty():
        _fail(str(errors))
        return
    print("SUCCESS: C later-upload pack has 6 loadable sources, effective targets and preserved texture footprints")
    quit(0)

func _fail(message: String) -> void:
    push_error("FAILED: " + message)
    quit(1)
