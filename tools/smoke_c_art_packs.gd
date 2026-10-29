extends SceneTree
## C5 art pack switching and preservation smoke. Run once per C batch in Godot.
const Overrides = preload("res://scripts/c_art_overrides.gd")
const Tiles = preload("res://scripts/world_tileset_pool.gd")
const Manager = preload("res://scripts/c_art_manager_ui.gd")
const TITLE: String = "res://assets/art/backdrops/coast/tide_lighthouse.png"
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(test: bool, description: String) -> void:
    if not test:
        failures.append(description)

func _run() -> void:
    var before: String = Overrides.active_pack()
    var original: Texture2D = Overrides.original_texture(TITLE)
    check(original != null, "Canonical title art unavailable")
    var names: Array[String] = []
    for pack in Overrides.list_packs():
        names.append(str(pack.get("id", "")))
    check(names.has("original") and names.has("b02_illustrated") and names.has("coast_ink"), "Built-in packs missing")
    var rev: int = Overrides.revision()
    # Three archived packs contain semantically false object identities and
    # must never enter gameplay, regardless of their file readability.
    for bad_id in ["b02_illustrated", "coast_ink", "shared_terrain"]:
        var inspection: Dictionary = Overrides.pack_report(bad_id)
        check(not bool(inspection.get("ok",true)), "Bad built-in pack passed preflight: "+bad_id)
        check(not Overrides.activate_pack(bad_id), "Unsafe built-in theme activated: "+bad_id)
        check(Overrides.active_pack() == before, "Rejecting unsafe pack changed active pack")
    var atlas_sources: Array[String] = [
        "res://assets/art/tilesets/coast_ground.png",
        "res://assets/art/tilesets/coast_water.png"]
    var live_tileset: TileSet = Tiles.shared(atlas_sources)
    check(live_tileset != null, "Original physical coastal TileSet lost")
    if live_tileset != null:
        check(Vector2i((live_tileset.get_source(0) as TileSetAtlasSource).texture.get_size()) == Vector2i(256,256),
            "Coast atlas layout invalid")
    check(Overrides.revision() == rev, "Rejecting unsafe pack changed revision")

    var sid: String = "c_qa_" + str(Time.get_ticks_usec())
    var test_dir: String = "user://c_art_pack_smoke"
    check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_dir)) == OK, "QA directory unavailable")
    var manifest: String = test_dir + "/manifest.json"
    var image_file: String = test_dir + "/title.png"
    if original != null:
        var dimensions: Vector2i = Vector2i(original.get_size())
        var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
        image.fill(Color(0.3, 0.6, 0.85, 1.0))
        check(image.save_png(image_file) == OK, "QA image save failed")
        var file: FileAccess = FileAccess.open(manifest, FileAccess.WRITE)
        if file != null:
            file.store_string(JSON.stringify({"id": sid, "name": "QA DLC", "mappings": [{"target": TITLE, "file": "title.png"}]}))
            file.close()
            var import_report: Dictionary = Overrides.install_pack(manifest)
            check(bool(import_report.get("ok", false)), "DLC install failed: " + str(import_report.get("message", "")))
            var id: String = str(import_report.get("pack_id", ""))
            if not id.is_empty():
                check(Overrides.activate_pack(id), "Imported DLC activation failed")
                check(Overrides.pack_has_slot(TITLE), "Installed DLC art missing")
                check(Overrides.texture(TITLE) is Texture2D, "Installed DLC image not visible")
                check(Overrides.uninstall_pack(id), "DLC uninstall failed")
                check(not Overrides.list_packs().any(func(pack: Dictionary) -> bool: return str(pack.get("id", "")) == id), "Removed DLC still listed")
        else:
            check(false, "QA manifest could not be written")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(image_file))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(manifest))
    check(Overrides.activate_pack(before), "Original theme could not be restored after test")
    var ui := Manager.new()
    root.add_child(ui)
    check(ui.pack_options != null, "Pack selector missing from title gallery")
    check(ui.pack_ids.has("b02_illustrated") and ui.pack_ids.has("coast_ink"), "UI lacks built-in theme IDs")
    ui.queue_free()
    if failures.is_empty():
        print("SUCCESS: art theme packs, automatic fallback, DLC import, uninstall and UI")
        quit(0)
        return
    for issue in failures:
        push_error(issue)
    quit(1)
