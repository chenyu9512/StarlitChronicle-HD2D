extends SceneTree
## 可选的审美辅助工具；从已审核的真实 PNG 生成二维受光法线。
## 不生产占位人物、不得替换原始纹理，也不会自动修改主场景。
## 用法：
## godot --headless --path . --script res://tools/bake_hd2d_normal_maps.gd -- \
##   res://assets/art/runtime/approved/character.png \
##   res://assets/art/runtime/approved/character_n.png 0.9

func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 2:
        push_error("Usage: source.png target_n.png [strength]")
        quit(2)
        return
    var source: String = str(args[0])
    var output: String = str(args[1])
    if not source.begins_with("res://assets/") or not output.begins_with("res://assets/") \
            or not source.ends_with(".png") or not output.ends_with("_n.png") \
            or source == output or output.contains(".."):
        push_error("Source and destination must be separate project PNG assets; destination must end in _n.png")
        quit(2)
        return
    if FileAccess.file_exists(output):
        push_error("Destination already exists; refusing to overwrite a curated normal map")
        quit(2)
        return
    var strength: float = clampf(float(args[2]), 0.1, 2.5) if args.size() > 2 else 0.95
    var image: Image = Image.load_from_file(source)
    if image == null or image.is_empty():
        push_error("Could not read approved source texture")
        quit(2)
        return
    image.convert(Image.FORMAT_RGBA8)
    var width: int = image.get_width()
    var height: int = image.get_height()
    if width < 4 or height < 4 or width * height > 4096 * 4096:
        push_error("Invalid source dimensions")
        quit(2)
        return
    var result: Image = Image.create(width,height,false,Image.FORMAT_RGBA8)
    for y in range(height):
        for x in range(width):
            var current: Color = image.get_pixel(x,y)
            if current.a <= 0.03:
                result.set_pixel(x,y,Color(0.5,0.5,1.0,0.0))
                continue
            var tl: float = _height_at(image,x-1,y-1)
            var t: float = _height_at(image,x,y-1)
            var tr: float = _height_at(image,x+1,y-1)
            var l: float = _height_at(image,x-1,y)
            var rr: float = _height_at(image,x+1,y)
            var bl: float = _height_at(image,x-1,y+1)
            var b: float = _height_at(image,x,y+1)
            var br: float = _height_at(image,x+1,y+1)
            var dx: float = ((tr + 2.0*rr + br) - (tl + 2.0*l + bl)) * 0.25 * strength
            var dy: float = ((bl + 2.0*b + br) - (tl + 2.0*t + tr)) * 0.25 * strength
            var normal: Vector3 = Vector3(-dx,-dy,1.0).normalized()
            result.set_pixel(x,y,Color(normal.x*0.5+0.5,
                normal.y*0.5+0.5,normal.z*0.5+0.5,current.a))
    var out_dir: String = ProjectSettings.globalize_path(output.get_base_dir())
    var make_error: Error = DirAccess.make_dir_recursive_absolute(out_dir)
    if make_error != OK:
        push_error("Cannot create output folder: " + str(make_error))
        quit(2)
        return
    var save_error: Error = result.save_png(ProjectSettings.globalize_path(output))
    if save_error != OK:
        push_error("Normal export failed: " + str(save_error))
        quit(2)
        return
    print("Normal map exported without modifying the diffuse source: ",output)
    quit(0)


func _height_at(image: Image, x: int, y: int) -> float:
    var px: Color = image.get_pixel(clampi(x,0,image.get_width()-1),
        clampi(y,0,image.get_height()-1))
    if px.a <= 0.03:
        return 0.0
    var luminance: float = px.r * 0.2126 + px.g * 0.7152 + px.b * 0.0722
    return (0.38 + 0.62*luminance) * px.a
