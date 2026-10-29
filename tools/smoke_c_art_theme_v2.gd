extends SceneTree
## Real Godot import and semantic texture smoke; not a substitute for visual signoff.
const ArtTheme = preload("res://scripts/c_art_theme_v2.gd")
const Art = preload("res://scripts/c_art_overrides.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var before: String = ArtTheme.active_id()
    var info: Dictionary = ArtTheme.report("starlit_hd2d_act01")
    if not bool(info.get("ok", false)):
        push_error("V2 required art is missing: "+JSON.stringify(info.get("missing",[])))
        quit(1)
        return
    if not ArtTheme.activate("starlit_hd2d_act01"):
        push_error("V2 one-click activation failed")
        quit(1)
        return
    var expected: Array[String] = [
        "prop.coast.cottage", "prop.coast.sign",
        "scenery.coast.harbor_crane", "scenery.coast.cave_crystal",
        "terrain.coast.map_1_ground", "terrain.coast.map_1_water",
        "interior.tavern.tavern_counter", "interior.tavern.tavern_wood_atlas"
    ]
    for slot_id in expected:
        var tex: Texture2D = ArtTheme.texture(slot_id)
        if tex == null or tex.get_width() < 8:
            push_error("V2 unresolved semantic slot: "+slot_id)
            ArtTheme.activate(before)
            quit(1)
            return
    # Every official semantic texture must resolve through the same gameplay entrypoint
    # through the SAME Art.texture() entrypoint used by real gameplay scenes.
    # A temporary in-memory marker proves routing actually happens even when
    # the official baseline image happens to be identical to the V2 source.
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
        "res://data/assets/art_theme_v2.json"))
    if not raw is Dictionary:
        push_error("Cannot load official V2 semantic manifest")
        ArtTheme.activate(before)
        quit(1)
        return
    var themes: Array = raw.get("themes", [])
    var manifest_slots: Dictionary = {}
    for theme in themes:
        if theme is Dictionary and str(theme.get("id", "")) == "starlit_hd2d_act01":
            manifest_slots = theme.get("slots", {})
            break
    if manifest_slots.size() != 109:
        push_error("Official semantic scene register unexpectedly incomplete")
        ArtTheme.activate(before)
        quit(1)
        return
    # World V18 already displays fourteen distinct prop textures. Every one
    # must be themable, not only the original six curated V2 entries.
    var v18_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
        "res://data/assets/c_act01_hd2d_v18.json"))
    if not v18_raw is Dictionary:
        push_error("Cannot inspect live V18 world placements")
        ArtTheme.activate(before)
        quit(1)
        return
    var tested_v18: Dictionary = {}
    for placement in v18_raw.get("placements", []):
        var path: String = str(placement.get("source", ""))
        if tested_v18.has(path):
            continue
        tested_v18[path] = true
        if ArtTheme.texture_for_path(path) == null or Art.texture(path) == null:
            push_error("Visible V18 world prop missing from full theme: " + path)
            ArtTheme.activate(before)
            quit(1)
            return
    if tested_v18.size() != 14:
        push_error("Live world V18 prop contract changed unexpectedly")
        ArtTheme.activate(before)
        quit(1)
        return
    var uncatalogued: String = ""
    for slot_id in manifest_slots.keys():
        var p: String = str((manifest_slots[slot_id] as Dictionary).get("source", ""))
        if Art.texture(p) == null:
            push_error("Actual gameplay art resolver misses physical V2 slot: " + str(slot_id))
            ArtTheme.activate(before)
            quit(1)
            return
        if uncatalogued.is_empty() and not Art.has_slot(p):
            uncatalogued = p
    if uncatalogued.is_empty():
        push_error("Routing smoke needs at least one uncatalogued V2 runtime source")
        ArtTheme.activate(before)
        quit(1)
        return
    var pixel: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
    pixel.fill(Color("cc315e"))
    var marker: Texture2D = ImageTexture.create_from_image(pixel)
    var original_cache_entry: Variant = ArtTheme._cache.get(uncatalogued, null)
    ArtTheme._cache[uncatalogued] = marker
    var directly_routed: bool = Art.texture(uncatalogued) == marker
    if original_cache_entry == null:
        ArtTheme._cache.erase(uncatalogued)
    else:
        ArtTheme._cache[uncatalogued] = original_cache_entry
    if not directly_routed:
        push_error("Art.texture bypasses active V2 for uncatalogued runtime source: " + uncatalogued)
        ArtTheme.activate(before)
        quit(1)
        return
    if not ArtTheme.activate(before):
        push_error("V2 failed to restore previous theme")
        quit(1)
        return
    if ArtTheme.active_id() != before:
        push_error("V2 theme restore inconsistent")
        quit(1)
        return
    # Simulate an already-installed complete DLC losing one file while open.
    # The renderer must return to the original theme for the entire scene,
    # rather than showing a partial mixture of user and official textures.
    var probe_id: String = "user_v2_rollback_smoke"
    var probe_slot: String = str(manifest_slots.keys()[0])
    var probe_path: String = str((manifest_slots[probe_slot] as Dictionary).get("source", ""))
    var fake_theme: Dictionary = ArtTheme._themes["starlit_hd2d_act01"].duplicate(true)
    fake_theme["id"] = probe_id
    (fake_theme["slots"][probe_slot] as Dictionary)["source"] = (
        "user://c_art_theme_v2/" + probe_id + "/missing_texture.png")
    ArtTheme._themes[probe_id] = fake_theme
    if bool(ArtTheme.report(probe_id).get("ok", true)):
        push_error("V2 allowed an incomplete user DLC to pass full-pack preflight")
        ArtTheme._themes.erase(probe_id)
        quit(1)
        return
    ArtTheme._active = probe_id
    ArtTheme._cache.clear()
    ArtTheme._reindex()
    var recovered: Texture2D = Art.texture(probe_path)
    var rolled_back: bool = ArtTheme.active_id() == "original"
    ArtTheme._themes.erase(probe_id)
    if not rolled_back or recovered == null:
        push_error("V2 broken user DLC did not fail closed to the original texture")
        ArtTheme.activate(before)
        quit(1)
        return
    if not ArtTheme.activate(before):
        push_error("V2 could not restore theme after corrupted-DLC regression")
        quit(1)
        return
    print("PASS: incomplete user DLC rejected and runtime texture failure rolls back entire theme.")
    print("PASS: semantic art theme validated, applied and rolled back; no save data touched.")
    quit(0)
