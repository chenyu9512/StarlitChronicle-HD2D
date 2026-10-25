extends Node2D
## P4: world-space environmental storytelling in the actual playable prologue map.
## Cosmetic only: never change collision, objective nodes, quest flags or money.
const TILE: float=32.0
const ActorBlocking = preload("res://scripts/prologue_actor_blocking.gd")
var blocking: Node2D
var stage: String="normal"
var scene_index: int=0
var clock: float=0.0
var draw_elapsed: float=0.0
var actor: Node2D
var lamps: Array[Sprite2D]=[]
var originals: Dictionary={}
var weather: Node2D

func bind_world(hero: Node2D,scenery: Node2D,ambience: Node2D) -> void:
    actor=hero
    weather=ambience
    if blocking==null:
        blocking=ActorBlocking.new()
        blocking.name="ActorBlocking"
        add_child(blocking)
    blocking.bind_hero(hero)
    lamps.clear()
    originals.clear()
    if is_instance_valid(scenery):
        for item in scenery.get_children():
            if item is Sprite2D and str(item.get_meta("prop_kind","")) in ["star_lantern","beacon"]:
                lamps.append(item)
                originals[item.get_instance_id()]=item.modulate
    apply("normal",0)

func apply(phase: String,index: int) -> void:
    stage=phase
    scene_index=index
    if is_instance_valid(blocking):
        blocking.apply(phase)
    clock=0.0
    draw_elapsed=0.0
    visible=phase!="normal"
    set_process(visible)
    for item in lamps:
        if not is_instance_valid(item): continue
        var normal: Color=originals.get(item.get_instance_id(),Color.WHITE)
        item.modulate=normal*(0.16 if phase in ["fallen","forgotten"] else 1.0)
    if is_instance_valid(weather):
        weather.modulate=Color(0.65,0.74,0.94) if phase in ["falling","fallen","forgotten"] else Color.WHITE
    queue_redraw()

func _process(delta: float) -> void:
    clock+=minf(delta,0.1)
    draw_elapsed+=delta
    if draw_elapsed>0.045:
        draw_elapsed=0.0
        queue_redraw()

func _draw() -> void:
    if not is_instance_valid(actor) or stage=="normal": return
    var center: Vector2=actor.position
    var bounds: Rect2=Rect2(center-Vector2(650,400),Vector2(1300,800))
    match stage:
        "festival":
            for i in range(19):
                var j: float=float(i)
                var p: Vector2=center+Vector2(sin(j*2.4)*440.0,cos(j*1.7)*290.0-clock*(6.0+float(i%3)))
                draw_circle(p,3.5,Color(1.0,0.78,0.39,0.22+0.12*sin(clock*2.0+j)))
        "falling":
            draw_rect(bounds,Color(0.08,0.04,0.16,0.27))
            var head: Vector2=center+Vector2(500,-360).lerp(Vector2(160,-70),clampf(clock/4.0,0.0,1.0))
            for i in range(5,0,-1):
                draw_line(head,head+Vector2(float(i)*40.0,-float(i)*19.0),Color(0.73,0.26,0.58,0.12),float(i)*3.0,true)
            draw_circle(head,8.0,Color(0.05,0.02,0.07))
            draw_arc(head,11.0,0.0,TAU,28,Color(0.89,0.31,0.52,0.74),2.0,true)
        "fallen":
            draw_rect(bounds,Color(0.035,0.045,0.11,0.32))
            for i in range(25):
                var px: float=float(posmod(i*139+29,1013))-506.0
                var py: float=fposmod(float(i*91)+clock*(13.0+float(i%4)*2.0),700.0)-350.0
                draw_circle(center+Vector2(px,py),1.1,Color(0.86,0.83,0.93,0.25))
        "forgotten":
            draw_rect(bounds,Color(0.13,0.16,0.22,0.19))
            for i in range(18):
                var px: float=float(posmod(i*157+23,1200))-600.0
                var py: float=fposmod(float(i*179)-clock*9.0+2400.0,720.0)-360.0
                draw_circle(center+Vector2(px,py),1.5,Color(0.91,0.85,0.74,0.12))
        "ten_years":
            draw_rect(bounds,Color(0.21,0.13,0.07,0.13))
            for i in range(17):
                var x: float=float(posmod(i*157+47,1150))-575.0
                var y: float=fposmod(float(i*197)-clock*5.0+2100.0,760.0)-380.0
                draw_circle(center+Vector2(x,y),1.0,Color(0.94,0.82,0.64,0.20))
