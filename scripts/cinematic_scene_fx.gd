extends Control
## Native 2D cinematic lighting and motion; no stock footage or flashing screen.
var effect: String=""
var elapsed: float=0.0
var stars: Array[Vector2]=[]

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for i in range(36):
        stars.append(Vector2(float(posmod(i*113+37,991))/991.0,float(posmod(i*313+71,997))/997.0))
    set_process(false)

func play(next: String) -> void:
    effect=next
    elapsed=0.0
    visible=not effect.is_empty()
    set_process(visible)
    queue_redraw()

func _process(delta: float) -> void:
    elapsed+=minf(delta,0.1)
    queue_redraw()

func _draw() -> void:
    if effect.is_empty(): return
    var size: Vector2=get_rect().size
    if size.x<10.0 or size.y<10.0: size=get_viewport_rect().size
    match effect:
        "black_star": _meteor(size)
        "lights_out": _lamps(size)
        "forgotten": _dust(size,Color(0.78,0.79,0.95,0.15),-12.0)
        "ten_years": _years(size)
        "festival": _dust(size,Color(1.0,0.78,0.48,0.36),-8.0)
        "lighthouse": _beacon(size)

func _meteor(size: Vector2) -> void:
    var t: float=clampf(elapsed/4.8,0.0,1.0)
    var head: Vector2=Vector2(size.x*1.1,-size.y*0.2).lerp(Vector2(size.x*0.59,size.y*0.48),t)
    for i in range(4,0,-1):
        var tail: Vector2=head+Vector2(70.0+float(i)*34.0,-65.0-float(i)*15.0)
        draw_line(head,tail,Color(0.65,0.30,0.59,0.12),float(i)*4.0,true)
    draw_circle(head,25.0,Color(0.47,0.10,0.22,0.12))
    draw_circle(head,9.0,Color(0.045,0.024,0.069))
    draw_arc(head,12.0,0.0,TAU,32,Color(0.91,0.38,0.53,0.83),2.0,true)
    _dust(size,Color(0.88,0.43,0.73,0.24),13.0)

func _lamps(size: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.01,0.09,0.16))
    var spots: Array[Vector2]=[Vector2(0.19,0.55),Vector2(0.31,0.43),Vector2(0.48,0.51),Vector2(0.68,0.44),Vector2(0.81,0.62)]
    for i in range(spots.size()):
        var strength: float=0.04 if elapsed>0.6+float(i)*0.65 else 0.72
        var p: Vector2=spots[i]*size
        draw_circle(p,19.0,Color(1.0,0.74,0.42,strength*0.11))
        draw_circle(p,4.0,Color(1.0,0.81,0.51,strength))

func _dust(size: Vector2,color: Color,vertical_speed: float) -> void:
    for i in range(stars.size()):
        var p: Vector2=stars[i]*size
        p.y=fposmod(p.y+elapsed*vertical_speed*(1.0+float(i%4)*0.25),size.y)
        p.x=fposmod(p.x+sin(elapsed+float(i)*1.3)*6.0,size.x)
        draw_circle(p,0.9+float(i%3)*0.6,color)

func _years(size: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color(0.29,0.21,0.12,0.07))
    var x: float=fposmod(elapsed*38.0+size.x*0.2,size.x)
    draw_colored_polygon(PackedVector2Array([Vector2(x-150,0),Vector2(x+10,0),Vector2(x+270,size.y),Vector2(x+80,size.y)]),Color(1.0,0.84,0.58,0.07))
    _dust(size,Color(1.0,0.88,0.65,0.18),-5.0)

func _beacon(size: Vector2) -> void:
    var p: Vector2=Vector2(size.x*0.64,size.y*0.36)
    var shift: float=sin(elapsed*0.44)*size.x*0.08
    draw_colored_polygon(PackedVector2Array([p,p+Vector2(-size.x*0.32+shift,size.y*0.38),p+Vector2(-size.x*0.16+shift,size.y*0.40)]),Color(1.0,0.87,0.61,0.07))
    draw_circle(p,10.0,Color(1.0,0.89,0.61,0.24))
