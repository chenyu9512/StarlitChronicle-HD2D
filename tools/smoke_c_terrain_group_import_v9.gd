extends SceneTree
## C V9: on-device regression for importing two images into 21 terrain slots.
## Uses temporary user:// files and restores the previously active theme.
const Art = preload("res://scripts/c_art_overrides.gd")
const Terrain = preload("res://scripts/world_terrain_atlas_registry.gd")
const ROOT: String = "user://c_terrain_group_import_smoke"
var issues: Array[String] = []

func verify(ok: bool, message: String) -> void:
    if not ok:
        issues.append(message)

func _initialize() -> void:
    call_deferred("_run")

func _save_tile(path: String, color: Color) -> bool:
    var image: Image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
    image.fill(color)
    return image.save_png(path) == OK

func _run() -> void:
    var previous_pack: String = Art.active_pack()
    var token: String = "terrain_probe_" + str(Time.get_ticks_usec())
    var file_dir: String = ROOT + "/" + token
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(file_dir)) != OK:
        push_error("Unable to create terrain import smoke directory")
        quit(1)
        return
    var land: String = file_dir + "/land.png"
    var water: String = file_dir + "/water.png"
    var manifest: String = file_dir + "/manifest.json"
    var created: bool = _save_tile(land, Color(0.3, 0.6, 0.3)) and _save_tile(water, Color(0.2, 0.4, 0.8))
    verify(created, "Could not create the two test PNGs")
    var pack_id: String = ""
    if created:
        var data: Dictionary = {
            "id": token, "name": "Temporary terrain import probe",
            "mappings": [
                {"group": "terrain_ground", "file": "land.png"},
                {"group": "terrain_water", "file": "water.png"}
            ]
        }
        var handle: FileAccess = FileAccess.open(manifest, FileAccess.WRITE)
        verify(handle != null, "Cannot create temporary DLC manifest")
        if handle != null:
            handle.store_string(JSON.stringify(data))
            handle.close()
            var installed: Dictionary = Art.install_pack(manifest)
            verify(bool(installed.get("ok", false)), "Two-image terrain DLC installation failed")
            if bool(installed.get("ok", false)):
                pack_id = str(installed.get("pack_id", ""))
                verify(int(installed.get("count", 0)) == 21, "Expanded slot count is not 21")
                verify(int(Art.pack_report(pack_id).get("usable", 0)) == 21, "Shared texture compatibility mismatch")
                var stored: PackedStringArray = DirAccess.get_files_at("user://c_art_packs/" + pack_id)
                verify(stored.size() == 2, "Expected only two physically saved DLC PNGs")
                verify(Art.activate_pack(pack_id), "Cannot activate test theme")
                var ground_slots: Array[String] = Terrain.group_slots("terrain_ground")
                var water_slots: Array[String] = Terrain.group_slots("terrain_water")
                if not ground_slots.is_empty() and not water_slots.is_empty():
                    var ground_texture: Texture2D = Art.texture(ground_slots[0])
                    var water_texture: Texture2D = Art.texture(water_slots[0])
                    verify(ground_texture != null and water_texture != null, "Cannot resolve shared terrain textures")
                    for slot in ground_slots:
                        if not Art.has_override(slot):
                            verify(Art.texture(slot) == ground_texture, "Ground slot did not reuse one texture: " + slot)
                    for slot in water_slots:
                        if not Art.has_override(slot):
                            verify(Art.texture(slot) == water_texture, "Water slot did not reuse one texture: " + slot)
    verify(Art.activate_pack(previous_pack), "Previous art theme not restored")
    if not pack_id.is_empty():
        verify(Art.uninstall_pack(pack_id), "Temporary DLC was not uninstalled")
    for path in [manifest, land, water]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(file_dir))
    if issues.is_empty():
        print("SUCCESS: two imported PNGs -> 21 terrain slots; original theme restored")
        quit(0)
        return
    for issue in issues:
        push_error(issue)
    quit(1)
