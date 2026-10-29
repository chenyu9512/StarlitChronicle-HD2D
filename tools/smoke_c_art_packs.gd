extends SceneTree
## Generated-only Main2: real 451-role factory catalog, rejected retired
## packs, safe user DLC import/activation/uninstall and UI regression.
const Overrides = preload("res://scripts/c_art_overrides.gd")
const Tiles = preload("res://scripts/world_tileset_pool.gd")
const Manager = preload("res://scripts/c_art_manager_ui.gd")
const ROOT: String = "res://assets/art/runtime/global_factory_v3/"
const TITLE: String = ROOT + "props/region_coast_cottage.png"
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(test: bool, description: String) -> void:
    if not test:
        failures.append(description)

func _run() -> void:
    var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "active.json"))
    if not (manifest is Dictionary) or not bool(manifest.get("enabled", false)):
        push_error("Generated-only canonical art manifest missing or disabled")
        quit(1)
        return
    var before: String = Overrides.active_pack()
    var original: Texture2D = Overrides.original_texture(TITLE)
    check(original != null, "Generated canonical cottage cannot be loaded")
    check(Overrides.has_slot(TITLE), "Generated cottage is not registered for one-click DLC switching")
    check(Overrides.list_assets().size() >= int(manifest.get("asset_count", 0)),
        "Live generated candidate slots absent from art manager")
    var names: Array[String] = []
    for pack in Overrides.list_packs():
        names.append(str(pack.get("id", "")))
    check(names.has("original"), "Base generated-only theme missing")
    var rev: int = Overrides.revision()
    for bad_id in ["b02_illustrated", "coast_ink", "shared_terrain", "uploaded_later_v1"]:
        var inspection: Dictionary = Overrides.pack_report(bad_id)
        check(not bool(inspection.get("ok", true)), "Purged third-party pack passed preflight: " + bad_id)
        check(not Overrides.activate_pack(bad_id), "Purged third-party pack became active: " + bad_id)
        check(Overrides.active_pack() == before, "Rejected pack changed the active pack")
    var atlas_sources: Array[String] = [
        ROOT + "terrain/region_coast_ground.png",
        ROOT + "terrain/region_coast_water.png"
    ]
    var live_tileset: TileSet = Tiles.shared(atlas_sources)
    check(live_tileset != null, "Current generated coast terrain atlas unavailable")
    if live_tileset != null:
        var source: TileSetSource = live_tileset.get_source(0)
        check(source is TileSetAtlasSource, "Generated coast terrain is not a tiled atlas")
        if source is TileSetAtlasSource:
            check(Vector2i((source as TileSetAtlasSource).texture.get_size()) == Vector2i(256, 256),
                "Generated coast atlas dimensions invalid")
    check(Overrides.revision() == rev, "Rejected packs changed revision")

    var sid: String = "c_qa_" + str(Time.get_ticks_usec())
    var test_dir: String = "user://c_art_pack_smoke"
    check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_dir)) == OK,
        "QA directory unavailable")
    var user_manifest: String = test_dir + "/manifest.json"
    var image_file: String = test_dir + "/cottage.png"
    if original != null:
        var dimensions: Vector2i = Vector2i(original.get_size())
        var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
        image.fill(Color(0.31, 0.58, 0.83, 1.0))
        check(image.save_png(image_file) == OK, "DLC source image save failed")
        var file: FileAccess = FileAccess.open(user_manifest, FileAccess.WRITE)
        if file != null:
            file.store_string(JSON.stringify({"id": sid, "name": "Generated-slot QA DLC",
                "mappings": [{"target": TITLE, "file": "cottage.png"}]}))
            file.close()
            var report: Dictionary = Overrides.install_pack(user_manifest)
            check(bool(report.get("ok", false)), "Generated-slot DLC import failed: " + str(report.get("message", "")))
            var pack_id: String = str(report.get("pack_id", ""))
            if not pack_id.is_empty():
                check(Overrides.activate_pack(pack_id), "Generated-slot DLC activation failed")
                check(Overrides.pack_has_slot(TITLE), "Generated-slot DLC is not bound to its exact ID")
                var result: Texture2D = Overrides.texture(TITLE)
                check(result != null and Vector2i(result.get_size()) == dimensions,
                    "Active DLC image missing or wrong dimensions")
                check(Overrides.uninstall_pack(pack_id), "Generated-slot DLC uninstall failed")
                check(not Overrides.list_packs().any(func(pack: Dictionary) -> bool:
                    return str(pack.get("id", "")) == pack_id), "Uninstalled DLC remains active")
        else:
            check(false, "DLC manifest could not be saved")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(image_file))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(user_manifest))
    check(Overrides.activate_pack(before), "Original selected pack could not be restored")
    var ui := Manager.new()
    root.add_child(ui)
    check(ui.pack_options != null, "Art manager pack dropdown missing")
    check(ui.pack_ids.has("original"), "Art manager omitted generated-only base theme")
    check(ui.all_assets.size() >= int(manifest.get("asset_count", 0)), "Art manager still displays retired empty catalog")
    ui.queue_free()
    if failures.is_empty():
        print("SUCCESS: live generated art catalog, reject retired packs, DLC import/activate/uninstall, theme UI")
        quit(0)
        return
    for issue in failures:
        push_error(issue)
    quit(1)
