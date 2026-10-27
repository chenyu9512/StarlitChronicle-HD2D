extends SceneTree
## C2.1: verify six independent in-world decorative image sets on V4 geometry.
const V4 = preload("res://scripts/world_interior_v4.gd")
const InteriorArt = preload("res://scripts/world_interior_art.gd")
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func verify(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)
func _run() -> void:
    var loader = V4.new()
    for kind in ["inn", "house", "shop", "guild", "smith", "shrine"]:
        var layout: Dictionary = loader.load_level("map_coast_01", kind, kind)
        verify(not layout.is_empty(), kind + ": cannot load original V4 room")
        if layout.is_empty():
            continue
        var before: Dictionary = layout.get("blocked", {}).duplicate(true)
        var terrain_before: Dictionary = layout.get("tiles", {}).duplicate(true)
        var stage := Node2D.new()
        stage.y_sort_enabled = true
        root.add_child(stage)
        var art = InteriorArt.new()
        stage.add_child(art)
        art.install(stage, layout, 720)
        verify(art.signature_nodes.size() == 2, kind + ": missing in-world signature art")
        var seen: Dictionary = {}
        for id in art.signature_nodes.keys():
            var sprite: Sprite2D = art.signature_nodes[id]
            verify(is_instance_valid(sprite) and sprite.texture != null, kind + ": image failed to import")
            var cell: Vector2i = sprite.get_meta("signature_cell", Vector2i(-1,-1))
            var layer: String = str(sprite.get_meta("signature_layer", ""))
            verify(not seen.has(layer), kind + ": duplicate layer")
            seen[layer] = true
            if layer == "floor":
                verify(not before.has(cell), kind + ": decal on solid cell")
                verify(layout.get("tiles", {}).has(cell), kind + ": decal outside real room")
                verify(sprite.z_index == -3, kind + ": floor layer must be behind feet")
            elif layer == "wall":
                verify(sprite.z_index == -1, kind + ": wall display layer invalid")
            else:
                verify(false, kind + ": unexpected image layer")
        verify(layout.get("blocked", {}) == before, kind + ": art modified collision")
        verify(layout.get("tiles", {}) == terrain_before, kind + ": art modified terrain")
        stage.queue_free()
    if failures.is_empty():
        print("PASS: six Morning Dew V4 rooms, 12 original sprites, safe floor/wall planes, unchanged geometry")
        quit(0)
    else:
        for msg in failures:
            push_error(msg)
        quit(1)
