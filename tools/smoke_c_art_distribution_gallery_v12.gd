extends SceneTree
## Smoke the developer-only C-art V12 inventory browser.
## Explicitly does not claim artistic acceptance or modify scene content.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var resource: PackedScene = load("res://scenes/c_art_distribution_gallery.tscn") as PackedScene
    if resource == null:
        push_error("V12 distribution gallery scene failed to import")
        quit(1)
        return
    var ui: Control = resource.instantiate() as Control
    if ui == null:
        push_error("V12 gallery scene did not instantiate a Control")
        quit(1)
        return
    root.add_child(ui)
    await process_frame
    var records: Array = ui.get("entries") as Array
    var groups: Array = ui.get("group_ids") as Array
    var shown: Array = ui.get("filtered") as Array
    var grid: GridContainer = ui.get("grid") as GridContainer
    if records.size() != 1517 or groups.size() != 27:
        push_error("V12 gallery count does not match source registry: entries=%d groups=%d" % [records.size(), groups.size()])
        quit(1)
        return
    if shown.size() != 1517 or grid == null or grid.get_child_count() != 18:
        push_error("V12 gallery initial page missing: %d" % grid.get_child_count())
        quit(1)
        return
    ui.call("_change_group", 1)
    shown = ui.get("filtered") as Array
    if shown.is_empty() or shown.size() >= 1517:
        push_error("V12 group dropdown does not filter art")
        quit(1)
        return
    print("PASS V12 gallery: 1517 tracked art files, 27 browseable groups, 18 thumbnails per page")
    ui.queue_free()
    quit(0)
