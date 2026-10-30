extends Node2D
## Save-backed scenery echoes attached only to existing physical interaction
## anchors. This layer never participates in collision, navigation or rewards.
const CONTRACT: String = "res://story/runtime/world_legacy_projection.json"
var authored: Array = []
var active_marks: Array[Dictionary] = []

func _init() -> void:
    if not FileAccess.file_exists(CONTRACT):
        push_warning("World legacy projection contracts not found")
        return
    var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
    if source is Dictionary:
        for row in source.get("entries",[]):
            if row is Dictionary:
                authored.append(row)

func refresh(map_id: String, flags: Dictionary, anchors: Dictionary, indoor: bool = false) -> void:
    active_marks.clear()
    if indoor or map_id.is_empty():
        queue_redraw()
        return
    var palette: Dictionary = {
        "gold": Color(0.98,0.80,0.50,1.0),
        "blue": Color(0.53,0.76,0.99,1.0),
        "green": Color(0.52,0.88,0.70,1.0)
    }
    var occupied: Dictionary = {}
    for item in authored:
        var row: Dictionary = item
        if str(row.get("map_id","")) != map_id:
            continue
        if not bool(flags.get(str(row.get("required_flag","")),false)):
            continue
        var anchor_name: String = str(row.get("anchor",""))
        var marker: Variant = anchors.get(anchor_name,null)
        if not (marker is Node2D) or not is_instance_valid(marker):
            # Never place a floating icon on guessed coordinates or dead props.
            continue
        var ordinal: int = int(occupied.get(anchor_name,0))
        occupied[anchor_name] = ordinal+1
        var center: Vector2 = (marker as Node2D).position + Vector2(ordinal*27-13,-38-ordinal*5)
        active_marks.append({
            "id":str(row.get("id","")),
            "center":center,
            "prop_position":(marker as Node2D).position+Vector2(ordinal*27-13,0),
            "world_prop":str(row.get("world_prop","")),
            "icon":str(row.get("icon","lantern")),
            "color":palette.get(str(row.get("palette","gold")),palette["gold"])
        })
    queue_redraw()

func projected_ids() -> Array[String]:
    var ids: Array[String] = []
    for mark in active_marks:
        ids.append(str(mark.get("id","")))
    return ids

func _draw() -> void:
    for mark in active_marks:
        var p: Vector2 = mark["center"]
        var c: Color = mark["color"]
        # New environmental dressing belongs to the actual existing site.
        # It is decorative only, so a different save never changes walkability.
        _draw_rebuilt_prop(mark["prop_position"],str(mark["world_prop"]),c)
        draw_circle(p,17.0,Color(c.r,c.g,c.b,0.12))
        draw_arc(p,12.0,0.0,TAU,20,Color(c.r,c.g,c.b,0.48),1.1,true)
        match str(mark["icon"]):
            "lantern":
                draw_line(p+Vector2(-5,-7),p+Vector2(5,-7),c,1.4)
                draw_line(p+Vector2(-5,-7),p+Vector2(-5,4),c,1.4)
                draw_line(p+Vector2(5,-7),p+Vector2(5,4),c,1.4)
                draw_line(p+Vector2(-5,4),p+Vector2(5,4),c,1.4)
                draw_circle(p+Vector2(0,-1),3.0,c)
                draw_line(p+Vector2(0,-11),p+Vector2(0,-7),c,1.2)
            "repair":
                draw_line(p+Vector2(-7,0),p+Vector2(0,-7),c,1.6)
                draw_line(p+Vector2(0,-7),p+Vector2(7,0),c,1.6)
                draw_line(p+Vector2(-5,0),p+Vector2(-5,6),c,1.4)
                draw_line(p+Vector2(5,0),p+Vector2(5,6),c,1.4)
                draw_line(p+Vector2(-5,6),p+Vector2(5,6),c,1.4)
            "rescue":
                draw_rect(Rect2(p+Vector2(-2,-7),Vector2(4,14)),c,true)
                draw_rect(Rect2(p+Vector2(-7,-2),Vector2(14,4)),c,true)
            "memorial":
                draw_colored_polygon(PackedVector2Array([
                    p+Vector2(0,-9),p+Vector2(7,-1),p+Vector2(0,8),p+Vector2(-7,-1)
                ]),c)
            "route":
                draw_line(p+Vector2(-9,5),p+Vector2(0,-5),c,2.0)
                draw_line(p+Vector2(0,-5),p+Vector2(9,5),c,2.0)
                draw_circle(p+Vector2(0,-5),2.0,c)
            "archive":
                draw_rect(Rect2(p+Vector2(-6,-8),Vector2(12,16)),c,false,1.5)
                for offset in [-3,1,5]:
                    draw_line(p+Vector2(-3,offset),p+Vector2(3,offset),c,1.1)
            "warning":
                draw_line(p+Vector2(0,-8),p+Vector2(-7,6),c,1.6)
                draw_line(p+Vector2(-7,6),p+Vector2(7,6),c,1.6)
                draw_line(p+Vector2(7,6),p+Vector2(0,-8),c,1.6)
                draw_circle(p+Vector2(0,2),1.4,c)
            "banner":
                draw_line(p+Vector2(-6,-8),p+Vector2(-6,8),c,1.4)
                draw_colored_polygon(PackedVector2Array([
                    p+Vector2(-5,-7),p+Vector2(8,-6),p+Vector2(4,0),p+Vector2(-5,1)
                ]),c)

func _draw_rebuilt_prop(site: Vector2, kind: String, light: Color) -> void:
    # Stylized HD-2D foreground vignettes. These are not fake walkable houses.
    # Each shape is placed relative to an existing map anchor, not a guessed tile.
    var wood: Color = Color("665449")
    var stone: Color = Color("807f7d")
    match kind:
        "roof":
            draw_rect(Rect2(site+Vector2(-17,-19),Vector2(34,19)),Color("b9a28a"),true)
            draw_colored_polygon(PackedVector2Array([
                site+Vector2(-21,-19),site+Vector2(0,-33),
                site+Vector2(21,-19)]),Color("8e6154"))
            draw_rect(Rect2(site+Vector2(-5,-14),Vector2(10,14)),wood,true)
            draw_line(site+Vector2(-20,-19),site+Vector2(0,-33),light,1.2)
        "workbench":
            draw_rect(Rect2(site+Vector2(-22,-10),Vector2(44,9)),Color("93755b"),true)
            draw_rect(Rect2(site+Vector2(-19,-1),Vector2(6,17)),wood,true)
            draw_rect(Rect2(site+Vector2(13,-1),Vector2(6,17)),wood,true)
            draw_rect(Rect2(site+Vector2(-11,-16),Vector2(22,6)),stone,true)
            draw_line(site+Vector2(-18,-10),site+Vector2(18,-10),light,1.4)
        "notice","archive":
            draw_rect(Rect2(site+Vector2(-19,-27),Vector2(38,27)),wood,true)
            draw_rect(Rect2(site+Vector2(-16,-25),Vector2(32,20)),
                Color("dbc9a3"),true)
            for line_y in [-21,-16,-11]:
                draw_line(site+Vector2(-12,line_y),
                    site+Vector2(11,line_y),stone,1.1)
            draw_rect(Rect2(site+Vector2(-17,0),Vector2(4,16)),wood,true)
            draw_rect(Rect2(site+Vector2(13,0),Vector2(4,16)),wood,true)
            if kind == "archive":
                draw_circle(site+Vector2(0,-7),3.0,light)
        "banner":
            draw_line(site+Vector2(-15,-32),site+Vector2(-15,13),wood,3.0)
            draw_line(site+Vector2(15,-32),site+Vector2(15,13),wood,3.0)
            draw_rect(Rect2(site+Vector2(-15,-30),Vector2(30,21)),Color("758c86"),true)
            draw_colored_polygon(PackedVector2Array([
                site+Vector2(-15,-9),site+Vector2(0,-1),site+Vector2(15,-9)
            ]),Color("758c86"))
            draw_circle(site+Vector2(0,-20),4.0,light)
        "star_lantern":
            draw_rect(Rect2(site+Vector2(-4,-23),Vector2(8,27)),stone,true)
            draw_rect(Rect2(site+Vector2(-10,-38),Vector2(20,18)),wood,true)
            draw_circle(site+Vector2(0,-29),6.0,light)
            draw_line(site+Vector2(-12,-39),site+Vector2(12,-39),light,1.8)
            draw_circle(site+Vector2(0,-29),17.0,
                Color(light.r,light.g,light.b,0.12))
        "rescue","memorial":
            draw_rect(Rect2(site+Vector2(-16,-10),Vector2(32,13)),stone,true)
            draw_rect(Rect2(site+Vector2(-13,3),Vector2(26,8)),wood,true)
            if kind == "rescue":
                draw_rect(Rect2(site+Vector2(-4,-23),Vector2(8,19)),light,true)
                draw_rect(Rect2(site+Vector2(-11,-17),Vector2(22,7)),light,true)
            else:
                draw_rect(Rect2(site+Vector2(-10,-30),Vector2(20,22)),
                    Color("b9b3ae"),true)
                draw_line(site+Vector2(-7,-21),site+Vector2(7,-21),light,1.3)
        "warning":
            draw_line(site+Vector2(0,-35),site+Vector2(0,8),wood,3.0)
            draw_colored_polygon(PackedVector2Array([
                site+Vector2(-14,-34),site+Vector2(14,-34),
                site+Vector2(0,-13)]),Color("bf7c73"))
        _:
            pass
