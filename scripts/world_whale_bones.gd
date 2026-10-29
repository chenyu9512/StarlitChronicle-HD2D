extends Node2D
## Original first-act whale skeleton landmark, drawn in the actual Godot scene.
## This is intentionally NOT a reused cave altar or rock-sprite placeholder.
## The coast_03 chapter-five rescue cells (62,43) and (66,45) are untouched:
## this is visual-only, with no collision, save IDs or quest side effects.
const BONE: Color = Color("e5d9b8")
const HIGHLIGHT: Color = Color("fff1ce")
const SHADE: Color = Color("aa9c80")
const SAND_SHADOW: Color = Color(0.13,0.21,0.22,0.25)

func _ready() -> void:
    name = "WhaleShoalSkeleton"
    z_index = -1
    queue_redraw()

func _draw() -> void:
    # The skeleton occupies a ~13 by 5 tile silhouette, slightly buried in
    # the beach; the ground footprint and player path remain the real map.
    for i in range(9):
        var pos := Vector2(-156.0+float(i)*42.0, 0.0)
        draw_circle(pos, 29.0, SAND_SHADOW)
        draw_circle(pos+Vector2(4.0,6.0), 21.0, Color(0.31,0.40,0.35,0.11))
    # Uneven, fractured vertebral spine, inset behind the ribs.
    var spine := PackedVector2Array([
        Vector2(-170,-80),Vector2(-126,-76),Vector2(-81,-84),
        Vector2(-36,-78),Vector2(12,-75),Vector2(57,-81),
        Vector2(101,-72),Vector2(145,-67)])
    draw_polyline(spine,SHADE,18.0,true)
    draw_polyline(spine,BONE,12.0,true)
    draw_polyline(spine,HIGHLIGHT,3.2,true)
    for i in range(7):
        var a: Vector2=spine[i]
        var b: Vector2=spine[i+1]
        var center: Vector2=(a+b)*0.5
        draw_circle(center,9.0,SHADE)
        draw_circle(center+Vector2(-1,-2),6.5,BONE)
    # The ribcage flares organically towards the wet sand; no pasted atlas.
    for i in range(9):
        var t: float=float(i)/8.0
        var base_x: float=-118.0+t*232.0
        var rise: float=17.0+sin(t*PI)*17.0
        var curl: float=36.0+sin(t*PI)*23.0
        var rib := PackedVector2Array([
            Vector2(base_x,-75.0),
            Vector2(base_x-13.0,-58.0-rise*0.23),
            Vector2(base_x-16.0,-28.0),
            Vector2(base_x-9.0+curl*0.15,9.0),
            Vector2(base_x+17.0,29.0+rise*0.15)])
        var thickness: float=5.0+2.0*sin(t*PI)
        draw_polyline(rib,SHADE,thickness+4.0,true)
        draw_polyline(rib,BONE,thickness,true)
        draw_line(rib[1],rib[3],HIGHLIGHT,1.6,true)
        draw_circle(rib[0],thickness*0.75,HIGHLIGHT)
    # The far-side ribs end behind the vertebrae, giving a readable 3D curve.
    for i in range(7):
        var x: float=-98.0+float(i)*32.0
        var length: float=23.0+14.0*sin(float(i)/6.0*PI)
        var upper := PackedVector2Array([
            Vector2(x,-82),Vector2(x-14,-104),
            Vector2(x-3,-119-length*0.5)])
        draw_polyline(upper,SHADE,8.0,true)
        draw_polyline(upper,BONE,5.0,true)
    # Distinctive whale cranium and forward jaw on the eastern tip.
    var skull := PackedVector2Array([
        Vector2(110,-88),Vector2(144,-107),Vector2(187,-98),
        Vector2(207,-78),Vector2(192,-55),Vector2(148,-50),
        Vector2(120,-58)])
    draw_colored_polygon(skull,SHADE)
    var upper_skull := PackedVector2Array([
        Vector2(118,-87),Vector2(149,-101),Vector2(184,-91),
        Vector2(195,-78),Vector2(180,-66),Vector2(145,-62),
        Vector2(120,-67)])
    draw_colored_polygon(upper_skull,BONE)
    draw_circle(Vector2(157,-78),13.0,SHADE)
    draw_circle(Vector2(157,-80),9.0,Color("857b69"))
    draw_line(Vector2(168,-63),Vector2(216,-47),BONE,6.0,true)
    draw_line(Vector2(167,-55),Vector2(205,-39),SHADE,4.0,true)
    # Weathered, partly buried fluke and isolated bone splinters.
    draw_line(Vector2(-167,-80),Vector2(-209,-117),BONE,8.0,true)
    draw_line(Vector2(-205,-115),Vector2(-228,-143),BONE,6.0,true)
    draw_line(Vector2(-208,-116),Vector2(-233,-98),BONE,5.0,true)
    draw_line(Vector2(-92,40),Vector2(-115,50),SHADE,4.0,true)
    draw_line(Vector2(36,48),Vector2(53,52),HIGHLIGHT,3.0,true)
    draw_circle(Vector2(116,39),5.0,Color("c9d9c2"))
