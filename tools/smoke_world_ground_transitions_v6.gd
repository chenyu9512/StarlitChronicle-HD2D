extends SceneTree
## Render-only terrain transition contract. The two tiles differ in material,
## but their source IDs, atlas cells and collision state must remain unchanged.
const Transitions = preload("res://scripts/world_ground_transitions_v6.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)

func _run() -> void:
    var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
    image.fill(Color("7e9c72"))
    image.fill_rect(Rect2i(0,32,256,32),Color("b6a480"))
    var texture: Texture2D = ImageTexture.create_from_image(image)
    var atlas := TileSetAtlasSource.new()
    atlas.texture = texture
    atlas.texture_region_size = Vector2i(32,32)
    atlas.create_tile(Vector2i(0,0))
    atlas.create_tile(Vector2i(0,1))
    var tiles := TileSet.new()
    tiles.tile_size = Vector2i(32,32)
    tiles.add_source(atlas,0)
    var layer := TileMapLayer.new()
    layer.tile_set = tiles
    root.add_child(layer)
    for y in range(2):
        layer.set_cell(Vector2i(0,y),0,Vector2i(0,0))
        layer.set_cell(Vector2i(1,y),0,Vector2i(0,1))
    var overlay := Transitions.new()
    root.add_child(overlay)
    overlay.configure(layer,2)
    verify(overlay.seam_count()==2,"Two grass/sand boundaries were not identified")
    verify(layer.get_used_cells().size()==4,"Visual smoothing removed gameplay cells")
    verify(layer.get_cell_atlas_coords(Vector2i(0,0))==Vector2i(0,0),"Grass atlas changed")
    verify(layer.get_cell_atlas_coords(Vector2i(1,0))==Vector2i(0,1),"Sand atlas changed")
    verify(not overlay.has_method("set_cell"),"Visual layer acquired geometry editing")
    overlay.set_visual_quality(0)
    verify(overlay.seam_count()==2,"Disabling visuals destroyed source edge data")
    overlay.set_visual_quality(1)
    overlay.configure(layer,1)
    verify(overlay.seam_count()==2,"Low quality mode changed valid seams")
    layer.queue_free()
    overlay.queue_free()
    if failures.is_empty():
        print("PASS terrain transitions: neighbor-aware edge blend, original cells intact, quality levels")
        quit(0)
        return
    for fault in failures:
        push_error(fault)
    quit(1)
