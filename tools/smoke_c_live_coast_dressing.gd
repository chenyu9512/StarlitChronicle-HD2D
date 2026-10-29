extends SceneTree
## Read-only C7 scene dressing QA. Does not alter a save or battle state.
const Dressing = preload("res://scripts/c_live_coast_dressing.gd")
const Index = "res://data/assets/c_art_live_coast_v7.json"
var issues: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, description: String) -> void:
    if not ok:
        issues.append(description)

func _run() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(Index))
    verify(raw is Dictionary, "C7 manifest missing")
    if raw is Dictionary:
        verify(int(raw.get("count", 0)) == 24, "Unexpected manifest count")
    var fake_layout: Dictionary = {"size": Vector2i(96, 56), "tiles": {}, "water_mask": {},
        "blocked": {}, "spawn": Vector2i(5, 5), "zone": {"buildings":[]}}
    var stage := Dressing.new()
    root.add_child(stage)
    stage.configure("map_coast_01", fake_layout)
    verify(stage.placed.size() == 8, "Eight coastal decorations not placed")
    for sprite in stage.placed.values():
        verify(sprite is Sprite2D, "Allocated decoration not a Sprite2D")
        if sprite is Sprite2D:
            verify((sprite as Sprite2D).texture != null, "Decoration missing texture")
            verify((sprite as Sprite2D).get_meta("source_path", "").begins_with("res://assets/art/external/"), "Bad source")
    var frozen: Dictionary = {Vector2i(12,32):true}
    var blocked_layout: Dictionary = fake_layout.duplicate(true)
    blocked_layout["blocked"] = frozen
    var relocated := Dressing.new()
    root.add_child(relocated)
    relocated.configure("map_coast_01", blocked_layout)
    verify(relocated.placed.size() == 8, "Blocked verge should safely relocate")
    for sprite in relocated.placed.values():
        if sprite is Sprite2D:
            verify(not frozen.has((sprite as Sprite2D).get_meta("map_cell", Vector2i(-1, -1))), "Decoration overlaps blocked route")
    verify(frozen.size() == 1, "Decoration mutated original blocked cells")
    var other := Dressing.new()
    root.add_child(other)
    other.configure("map_oaths_01", fake_layout)
    verify(other.placed.is_empty(), "Non-coastal maps must not receive coastal dressing")
    if issues.is_empty():
        print("SUCCESS: 24 slots, 7 image paths, safe relocation and fallback")
        quit(0)
        return
    for error in issues:
        push_error(error)
    quit(1)
