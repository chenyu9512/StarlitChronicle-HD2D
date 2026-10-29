extends SceneTree
## Explicit-semantic 8x8 atlas compiler. Never sample an unrelated tileset.
## This produces an editable build artifact; never auto-promote to commercial runtime.
const CONTRACT: String = "res://data/assets/art_atlas_contract_v2.json"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var conf: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
    if not conf is Dictionary or str(conf.get("schema","")) != "starlit.atlas_contract.v2":
        push_error("Invalid V2 atlas contract")
        quit(1)
        return
    if int(conf.get("tile_size",0)) != 32 or int(conf.get("grid",0)) != 8:
        push_error("Atlas must be explicit 32px / 8x8")
        quit(1)
        return
    var rows: Array = conf.get("rows",[])
    if rows.size()!=8:
        push_error("Atlas must have exactly eight semantic rows")
        quit(1)
        return
    var atlas: Image = Image.create(256,256,false,Image.FORMAT_RGBA8)
    for row in range(8):
        var spec: Dictionary = rows[row]
        var path: String = str(spec.get("material",""))
        if not path.begins_with("res://assets/art/runtime/") or path.contains(".."):
            push_error("Forbidden source for semantic row "+str(row))
            quit(1)
            return
        if int(spec.get("columns",0)) != 8:
            push_error("Incomplete semantic row "+str(row))
            quit(1)
            return
        var src: Image = Image.new()
        if src.load(path) != OK or src.get_width() < 256 or src.get_height() < 32:
            push_error("Missing or undersized real material: "+path)
            quit(1)
            return
        if src.get_format() != Image.FORMAT_RGBA8:
            src.convert(Image.FORMAT_RGBA8)
        var sample_y: int = clampi(int(spec.get("crop_row",0))*32,0,src.get_height()-32)
        for col in range(8):
            var origin: Vector2i = Vector2i(col*32,sample_y)
            atlas.blit_rect(src,Rect2i(origin,Vector2i(32,32)),Vector2i(col*32,row*32))
    var output: String = str(conf.get("output",""))
    if not output.begins_with("res://build/art-theme-v2/") or not output.ends_with(".png") or output.contains(".."):
        push_error("Unsafe output location")
        quit(1)
        return
    var resolved: String = ProjectSettings.globalize_path(output)
    if DirAccess.make_dir_recursive_absolute(resolved.get_base_dir()) != OK:
        push_error("Cannot create build output directory")
        quit(1)
        return
    if atlas.save_png(resolved) != OK:
        push_error("Atlas export failed")
        quit(1)
        return
    print("PASS: semantic row atlas compiled at "+resolved)
    quit(0)
