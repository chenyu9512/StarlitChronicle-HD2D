extends SceneTree
## Generated-only replacement for the retired six-pair third-party upload test.
## Verify the purge is actually enforced and the canonical generator is usable.
const Art = preload("res://scripts/c_art_overrides.gd")
const PACK_INDEX: String = "res://data/assets/c_art_packs.json"
const FACTORY: String = "res://assets/art/runtime/global_factory_v3/active.json"
const PROBE: String = "res://assets/art/runtime/global_factory_v3/props/region_coast_well.png"
const PACK_ID: String = "uploaded_later_v1"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACK_INDEX))
    if not (manifest is Dictionary) or str(manifest.get("schema", "")) != "starlit.c.art_packs.v1":
        _fail("The canonical art pack index is missing or malformed")
        return
    var forbidden: Array = manifest.get("packs", [])
    if not forbidden.is_empty():
        _fail("Retired third-party art packs still shipped in built-in index")
        return
    var factory: Variant = JSON.parse_string(FileAccess.get_file_as_string(FACTORY))
    if not (factory is Dictionary) or str(factory.get("schema", "")) != "starlit.global_factory.live.v3" or not bool(factory.get("enabled", false)):
        _fail("Canonical generated-only art factory inactive")
        return
    var source: Texture2D = Art.original_texture(PROBE)
    if source == null or not Art.has_slot(PROBE):
        _fail("Generated replacement is not loadable and selectable")
        return
    var prior: String = Art.active_pack()
    if bool(Art.pack_report(PACK_ID).get("ok", true)):
        _fail("Removed third-party upload pack still passes preflight")
        return
    if Art.activate_pack(PACK_ID) or Art.active_pack() != prior:
        _fail("Retired uploaded pack unexpectedly became active")
        return
    if Art.texture(PROBE) == null:
        _fail("Official generated image is not visible in live art resolver")
        return
    print("SUCCESS: purged uploaded third-party pack rejected; generated replacement registered and drawable")
    quit(0)

func _fail(message: String) -> void:
    push_error("FAILED: " + message)
    quit(1)
