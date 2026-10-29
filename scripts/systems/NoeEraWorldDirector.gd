extends Node2D
## Postwar, visible world blocking for the CH52-54 Noe handover.
## The active adult Noe is already world.hero: NEVER spawn a second Noe.
## Decorations and conversation witnesses are presentation only; archival
## choices and original ticket authority remain with EndgameExpansionBridge.
const NPCVisual = preload("res://scripts/world_npc_visual.gd")
const STATIONS := [
    {"name":"旧队友 · 岚音","role":"lore","offset":Vector2i(-2,0)},
    {"name":"旧队友 · 雷索","role":"quest","offset":Vector2i(2,0)},
    {"name":"旧队友 · 朔弦","role":"lore","offset":Vector2i(0,3)}
]
var world
var bridge
var last_signature: String = ""

func bind_world(target_world, runtime_bridge) -> void:
    world = target_world
    bridge = runtime_bridge
    if get_parent() != world:
        if get_parent() != null:
            get_parent().remove_child(self)
        world.add_child(self)
    position = Vector2.ZERO
    last_signature = ""
    refresh()

func refresh() -> void:
    if world == null or bridge == null or not bridge.registry_loaded             or world.chapter not in [52,53,54] or not world.interior_building.is_empty():
        visible = false
        return
    visible = true
    var signature: String = "%d/%d/%d/%s/%s" % [
        world.chapter,bridge.noe.leadership_handover_phase,
        bridge.noe.memorial_archive_step,str(bridge.noe.memorial_finalized),
        str(bridge.ticket_source_verified)]
    if signature == last_signature:
        return
    last_signature = signature
    for old in get_children():
        remove_child(old)
        old.queue_free()
    var handover: Node2D = world.nodes.get("endgame:handover") as Node2D
    if handover == null:
        return
    var walkable: Dictionary = world._walkable_tiles()
    var center: Vector2i = Vector2i(floori(handover.position.x/32.0),
        floori(handover.position.y/32.0))
    for index in range(STATIONS.size()):
        var record: Dictionary = STATIONS[index]
        var proposed: Vector2i = center + record["offset"]
        var found: Vector2i = _nearest_reachable(proposed,walkable)
        if found.x < 0:
            continue
        var person = NPCVisual.new()
        person.setup({"name":record["name"],"role":record["role"],"id":""})
        person.position = Vector2(found*32)+Vector2(16,16)
        person.z_index = 6
        add_child(person)
        if index == 0:
            person.perform_life_action("wave")
    var plaque := Label.new()
    plaque.text = "职责交接 · %d/3" % bridge.noe.leadership_handover_phase
    plaque.position = handover.position + Vector2(-70,48)
    plaque.add_theme_font_size_override("font_size",15)
    plaque.add_theme_color_override("font_color",Color("ebd4ad"))
    plaque.z_index = 9
    add_child(plaque)
    if world.chapter == 54:
        var table_marker: Node2D = world.nodes.get("endgame:memorial") as Node2D
        if is_instance_valid(table_marker):
            _draw_memorial_worktable(table_marker.position)

func _shape(target: Node2D,points: Array[Vector2],color: Color) -> void:
    var polygon := Polygon2D.new()
    polygon.polygon = PackedVector2Array(points)
    polygon.color = color
    target.add_child(polygon)

func _draw_memorial_worktable(at: Vector2) -> void:
    # A simple original 2D in-world dossier prop until dedicated HD2D art is
    # reviewed. The book grows visibly with REAL saved archival steps.
    var stand := Node2D.new()
    stand.name = "NoeMemorialArchivePresentation"
    stand.position = at + Vector2(0,-20)
    stand.z_index = 8
    add_child(stand)
    _shape(stand,[Vector2(-26,-11),Vector2(26,-11),Vector2(26,15),
        Vector2(-26,15)],Color("4e3840"))
    _shape(stand,[Vector2(-20,-10),Vector2(0,-14),Vector2(0,9),
        Vector2(-20,11)],Color("e6d6b9"))
    _shape(stand,[Vector2(0,-14),Vector2(20,-10),Vector2(20,11),
        Vector2(0,9)],Color("e1cfae"))
    _shape(stand,[Vector2(-1,-14),Vector2(1,-14),Vector2(1,10),
        Vector2(-1,10)],Color("86604c"))
    var step: int = bridge.noe.memorial_archive_step
    if bridge.ticket_source_verified and step >= 1:
        _shape(stand,[Vector2(-16,-5),Vector2(-4,-6),Vector2(-4,-4),
            Vector2(-16,-3)],Color("647b80"))
    if bridge.ticket_source_verified and step >= 2:
        _shape(stand,[Vector2(5,-5),Vector2(15,-4),Vector2(15,-2),
            Vector2(5,-3)],Color("968578"))
    if bridge.ticket_source_verified and step >= 3 and bridge.noe.memorial_finalized:
        # Ticket is a single archived original, not a fresh inventory item.
        _shape(stand,[Vector2(4,0),Vector2(15,0),Vector2(15,7),
            Vector2(4,7)],Color("d9b98a"))
        _shape(stand,[Vector2(6,3),Vector2(13,3),Vector2(13,4),
            Vector2(6,4)],Color("8e735f"))
    var caption := Label.new()
    caption.text = ("第39章原始车票来源未核实" if not bridge.ticket_source_verified
        else ("旧车票已归档 · 纪念册完成" if bridge.noe.memorial_finalized
        else "纪念册实地调查 · %d/3" % step))
    caption.position = Vector2(-96,22)
    caption.add_theme_font_size_override("font_size",14)
    caption.add_theme_color_override("font_color",Color("ead9b8"))
    stand.add_child(caption)

func _nearest_reachable(origin: Vector2i,walkable: Dictionary) -> Vector2i:
    for radius in range(0,9):
        for dx in range(-radius,radius+1):
            for dy in range(-radius,radius+1):
                if absi(dx)+absi(dy)!=radius:
                    continue
                var tile: Vector2i = origin+Vector2i(dx,dy)
                if walkable.has(tile) and not world._blocked(
                        Vector2(tile*32)+Vector2(16,16)):
                    return tile
    return Vector2i(-1,-1)
