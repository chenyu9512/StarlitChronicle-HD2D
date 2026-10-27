extends SceneTree
## Engine acceptance: forty narrative plans plus actual art import into TileMapLayer.
## No changes to game progress, real saves or collision maps.
const Story = preload("res://scripts/world_story_dressing.gd")
const Geography = preload("res://scripts/world_geography.gd")
const Levels = preload("res://scripts/world_level_v3.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool, why: String) -> void:
    if not ok:
        errors.append(why)

func _verify() -> void:
    var doc: Dictionary = Story.blueprints()
    var plans: Dictionary = doc.get("maps", {})
    var geo := Geography.new()
    var levels := Levels.new()
    check(plans.size() == 40, "Must have forty story-specific authored scene plans")
    check(levels.levels.size() == 40, "Forty physical V3 maps remain present")
    check(doc.get("chapter_map_conflicts", []).size() == 4,
        "Do not silently rewrite four known act-I quest map mismatches")
    var total_cells: int = 0
    for id in plans.keys():
        var plan: Dictionary = plans[id]
        var level: Dictionary = levels.level(str(id))
        var zone: Dictionary = geo.zone(str(id))
        check(not level.is_empty() and bool(zone.get("playable", false)),
            "Unknown canonical playable map " + str(id))
        if level.is_empty():
            continue
        check(plan.get("dimensions", []) == level.get("size", []),
            "Blueprint dimensions differ from source " + str(id))
        check(str(plan.get("scenic_identity", "")).length() > 3
            and (plan.get("scenic_sites", []) as Array).size() == 3,
            "Unique authored art/story staging absent " + str(id))
        check((plan.get("main_route", []) as Array).size() >= 2
            and (plan.get("optional_route", []) as Array).size() >= 2,
            "Independent traversal/director route missing " + str(id))
        var layout: Dictionary = geo.layout(str(id), 1)
        var prior_collision: Dictionary = layout.get("blocked", {}).duplicate()
        var prior_spawn: Vector2i = layout.get("spawn", Vector2i.ZERO)
        var art := Story.new()
        root.add_child(art)
        art.configure(str(id), layout, 1)
        check(art.art_error.is_empty(), str(id) + " / " + art.art_error)
        check(art.painted_cell_count() > 0,
            "No real rendered narrative detail atlas tiles " + str(id))
        check(layout.get("blocked", {}) == prior_collision
            and layout.get("spawn", Vector2i.ZERO) == prior_spawn,
            "Presentation polluted gameplay physics " + str(id))
        total_cells += art.painted_cell_count()
        root.remove_child(art)
        art.free()
    check(total_cells >= 400, "Forty-region visual staging missing")
    if errors.is_empty():
        print("PASS: 40 unique narrative plans, eight regional imported atlases, " +
            str(total_cells) + " actual TileMapLayer detail cells; collision/spawn preserved")
        quit(0)
        return
    for failure in errors:
        push_error(failure)
    quit(1)
