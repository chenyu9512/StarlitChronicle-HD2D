extends Node2D
const CVisual = preload("res://scripts/c_visual_design.gd")
## Lightweight dynamic day/night/weather composition for the active map only.
## No external effects library; visuals are authored Godot primitives.
var map_pixels: Vector2=Vector2(72.0*32.0,48.0*32.0)
var day: int = 1
var minutes: int = 480
var climate: String = "coastal"
var map_id: String = ""
var weather: String = "clear"
var phase: float = 0.0
var reduced_motion: bool = false
var animation_step: float = 0.15
var visual_quality: int = 1
var world_epoch: String = "present"

func set_world_epoch(epoch: String) -> void:
    # HD-2D presentation only: no collisions, chapter flags or loot mutate.
    var allowed: Array[String] = ["present","mirror","chronicle_corridor","historical","black_star","twelve_years_later"]
    world_epoch = epoch if epoch in allowed else "present"
    queue_redraw()

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    animation_step = 0.40 if value else 0.15
    queue_redraw()

func set_visual_quality(level: int) -> void:
    # Weather identity never changes with graphics quality; only drawing cost.
    visual_quality = clampi(level,0,2)
    set_reduced_motion(visual_quality == 0)

var hero: Node2D

func configure(map_key: String,biome: String,extent: Vector2i = Vector2i(72,48)) -> void:
    map_id=map_key
    climate=biome
    map_pixels=Vector2(extent)*32.0
    _choose_weather()
    queue_redraw()

func set_clock(day_number: int,clock_minutes: int) -> void:
    var next_day: int=maxi(1,day_number)
    var next_minutes: int=posmod(clock_minutes,1440)
    var change: bool = next_day!=day or abs(next_minutes-minutes)>=8
    var reset_weather: bool = next_day!=day
    day=next_day
    minutes=next_minutes
    if reset_weather:
        _choose_weather()
    if change:
        queue_redraw()

func _choose_weather() -> void:
    var index: int=abs((map_id+str(day)).hash())%10
    match climate:
        "coastal","archipelago":
            weather="rain" if index in [0,1,2] else ("mist" if index in [3,4] else "clear")
        "mistforest":
            weather="mist" if index<6 else ("rain" if index<8 else "clear")
        "volcanic","badlands":
            weather="ash" if index<5 else "clear"
        "highland":
            weather="rain" if index<3 else ("mist" if index==3 else "clear")
        _:
            weather="mist" if index==0 else "clear"

func _process(delta: float) -> void:
    if weather in ["rain","ash"]:
        phase+=delta
        if phase >= animation_step:
            phase = fmod(phase, animation_step)
            queue_redraw()

func _draw() -> void:
    var hour: float=15.0 if world_epoch=="mirror" else float(minutes)/60.0
    var tint: Color=Color(CVisual.INK.r,CVisual.INK.g,CVisual.INK.b,0.0)
    if hour>=20.0 or hour<5.0:
        tint.a=0.45
    elif hour>=18.0:
        tint.a=0.20+(hour-18.0)*0.12
    elif hour<7.0:
        tint.a=0.33-(hour-5.0)*0.16
    elif hour>=16.0:
        tint=Color(0.48,0.28,0.14,0.055+(hour-16.0)*0.045)
    if tint.a>0.0:
        draw_rect(Rect2(Vector2.ZERO,map_pixels),tint,true)
    # Three-realm contrast and disaster/reconstruction are separate from weather.
    # Keep subtle overlays so painted scenery and readable NPCs remain primary.
    var epoch_tints: Dictionary = {
        "mirror":Color(0.92,0.87,1.0,0.075),
        "chronicle_corridor":Color(0.39,0.45,0.57,0.17),
        "historical":Color(0.51,0.51,0.55,0.11),
        "black_star":Color(0.13,0.17,0.27,0.20),
        "twelve_years_later":Color(0.57,0.49,0.39,0.07)
    }
    if epoch_tints.has(world_epoch):
        draw_rect(Rect2(Vector2.ZERO,map_pixels),epoch_tints[world_epoch],true)
    if weather=="mist":
        draw_rect(Rect2(Vector2.ZERO,map_pixels),Color(0.59,0.7,0.77,0.09),true)
    if hero==null or not is_instance_valid(hero):
        return
    if weather in ["rain","ash"]:
        var center: Vector2=hero.position
        var speed: float=phase*43.0
        var particle_budget: int = 16 if visual_quality==0 else (36 if visual_quality==1 else 62)
        for index in range(particle_budget):
            var code: int=abs((index*7321+day*917+map_id.hash())%65535)
            var origin: Vector2=center+Vector2(float(code%760)-380.0,float((code/97)%540)-270.0)+Vector2(-speed,speed)
            if weather=="rain":
                draw_line(origin,origin+Vector2(-4,13),Color(0.66,0.82,0.96,0.34),1.3)
            else:
                draw_circle(origin,1.6,Color(0.85,0.64,0.47,0.23))
