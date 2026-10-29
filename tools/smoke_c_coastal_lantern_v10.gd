extends SceneTree
## C V10 visual-only regression. No gameplay save, map collision or DLC change.
const Dressing = preload("res://scripts/c_live_coast_dressing.gd")
var issues: Array[String] = []

func verify(value: bool, message: String) -> void:
    if not value:
        issues.append(message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var layout: Dictionary = {
        "size": Vector2i(96, 56),
        "tiles": {},
        "water_mask": {},
        "blocked": {},
        "spawn": Vector2i(5, 5),
        "zone": {"buildings": []},
        "features": [{"cell": Vector2i(12, 32)}],
        "gates": [{"cell": Vector2i(29, 20)}]
    }
    var decor := Dressing.new()
    root.add_child(decor)
    decor.configure("map_coast_01", layout)
    verify(decor.placed.size() == 8, "Morning Dew should receive its eight curated decorations")
    verify(decor.active_lights.size() == 1, "Morning Dew paper lantern should create one light")
    for sprite in decor.placed.values():
        if not sprite is Sprite2D:
            verify(false, "A decoration is not a Sprite2D")
            continue
        var cell: Vector2i = sprite.get_meta("map_cell", Vector2i(-1,-1))
        verify(absi(cell.x - 12) > 1 or absi(cell.y - 32) > 1,
            "Decor overlaps visual safety halo of quest or story feature")
        verify(absi(cell.x - 29) > 2 or absi(cell.y - 20) > 2,
            "Decor blocks the visual approach to a map exit")
    decor.set_visual_quality(2)
    decor.set_clock(1200)
    if decor.active_lights.size() == 1:
        var lamp: PointLight2D = decor.active_lights[0]
        verify(lamp.visible and lamp.energy > 0.1, "Night lantern failed to illuminate")
        decor.set_clock(720)
        verify(not lamp.visible, "Daylight lantern should be off")
        decor.set_clock(1200)
        decor.set_visual_quality(0)
        verify(not lamp.visible, "Lowest graphics quality should disable the lamp")
        decor.set_visual_quality(1)
        verify(lamp.visible, "Medium graphics quality should allow one lantern")
    var initial_children: int = decor.get_child_count()
    decor.configure("map_coast_01", layout)
    verify(decor.placed.size() == 8, "Rebuild changed curated decoration count")
    verify(decor.active_lights.size() == 1, "Rebuild duplicated lantern lights")
    verify(decor.get_child_count() == initial_children, "Rebuild left ghost decoration nodes")
    var untouched: Dictionary = layout["blocked"]
    verify(untouched.is_empty(), "Visual-only decoration mutated collision")
    var harbor := Dressing.new()
    root.add_child(harbor)
    harbor.configure("map_coast_02", layout)
    verify(harbor.active_lights.size() == 2, "Harbor paper/stone lamps need two pooled lights")
    harbor.set_clock(1200)
    harbor.set_visual_quality(1)
    if harbor.active_lights.size() == 2:
        verify(harbor.active_lights[0].visible and not harbor.active_lights[1].visible,
            "Medium graphics quality should light only one harbor prop")
        harbor.set_visual_quality(2)
        verify(harbor.active_lights[0].visible and harbor.active_lights[1].visible,
            "High graphics quality should light both harbor props")
    if issues.is_empty():
        print("SUCCESS: C V10 daytime/nighttime, quality budget, quest/gate halo and scene rebuilding")
        quit(0)
        return
    for message in issues:
        push_error(message)
    quit(1)
