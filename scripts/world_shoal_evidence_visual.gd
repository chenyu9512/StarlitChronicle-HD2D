extends Node2D
## Small original vector field cues for the chapter-five rescue pocket.
## Presentation only; ownership, collision, progression and rewards stay in V3.
var motif: String = ""
var observed: bool = false
var animation_clock: float = 0.0
var reduced_motion: bool = false

func configure(kind: String) -> void:
    motif = kind
    name = "WhaleShoalFieldCue_"+kind
    z_index = 7
    queue_redraw()

func set_observed(value: bool) -> void:
    if observed == value:
        return
    observed = value
    queue_redraw()

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value

func _process(delta: float) -> void:
    if reduced_motion:
        return
    animation_clock += minf(delta,0.1)
    if animation_clock >= 0.25:
        animation_clock = 0.0
        queue_redraw()

func _draw() -> void:
    var glow: float = 0.57 if observed else 0.94
    draw_circle(Vector2(0,1),16.0,Color(0.06,0.13,0.16,0.24))
    match motif:
        "red_flag":
            # Red pennant is actual in-world hazard information, not a prop
            # mistakenly replaced by a water-lily/sign atlas.
            draw_line(Vector2(-8,6),Vector2(-8,-40),Color("564939"),3.0,true)
            draw_line(Vector2(-9,-39),Vector2(-9,-14),Color("c4b497"),1.0,true)
            draw_colored_polygon(PackedVector2Array([
                Vector2(-7,-39),Vector2(20,-34),Vector2(10,-23),
                Vector2(-7,-25)]),Color(0.82,0.16,0.15,glow))
            draw_line(Vector2(-4,-33),Vector2(10,-31),Color("f8c8a0"),1.6,true)
            draw_line(Vector2(-12,6),Vector2(-2,6),Color("7a6a51"),2.5,true)
        "star_chain":
            # Three deliberately separate clasps (no automatic progress):
            # the player will dismantle each in the actual boss interface.
            for i in range(3):
                var x: float = -17.0+float(i)*17.0
                var c: Vector2 = Vector2(x,-15.0+(4.0 if i==1 else 0.0))
                draw_circle(c,8.0,Color(0.84,0.65,0.28,glow))
                draw_circle(c,5.0,Color("29434e"))
                draw_line(c+Vector2(-2,-3),c+Vector2(2,2),Color("fff1b8"),1.6,true)
            draw_line(Vector2(-24,-2),Vector2(24,-2),Color("ba9c62"),2.0,true)
        "retreat_line":
            # A calm pale-sand return route, away from the glowing surge.
            draw_line(Vector2(-24,5),Vector2(0,-8),Color(0.81,0.94,0.87,glow),3.0,true)
            draw_line(Vector2(0,-8),Vector2(23,-8),Color(0.81,0.94,0.87,glow),3.0,true)
            draw_line(Vector2(13,-16),Vector2(23,-8),Color(0.81,0.94,0.87,glow),2.8,true)
            draw_line(Vector2(13,0),Vector2(23,-8),Color(0.81,0.94,0.87,glow),2.8,true)
            draw_circle(Vector2(-24,5),3.5,Color("f4ead3"))
    if observed:
        draw_circle(Vector2(21,-35),9.0,Color("31584b"))
        draw_line(Vector2(16,-35),Vector2(20,-31),Color("c2f2c9"),2.2,true)
        draw_line(Vector2(20,-31),Vector2(27,-40),Color("c2f2c9"),2.2,true)
