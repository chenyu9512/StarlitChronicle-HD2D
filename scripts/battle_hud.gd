extends Control
## Integrated battle art HUD: smooth HP, target focus, boss phases and victory card.
## Entire surface ignores mouse input; underlying command UI remains authoritative.
const ArtDirection = preload("res://scripts/battle_art_direction.gd")
const CVisual = preload("res://scripts/c_visual_design.gd")
const MAX_MONSTERS: int = 3
var enemy_stage
var actor_stage
var boss: bool = false
var chapter: int = 1
var enemy_units: Array[Dictionary] = []
var party_members: Array[Dictionary] = []
var hp_display: Dictionary = {}
var active_target: int = 0
var phase_two: bool = false
var warning: String = ""
var banner: String = ""
var victory: bool = false
var earned_xp: int = 0
var earned_gold: int = 0
var time_s: float = 0.0
var reduced_motion: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func configure(foe_stage, ally_stage, is_boss: bool, chapter_no: int, settings: Dictionary) -> void:
    enemy_stage = foe_stage
    actor_stage = ally_stage
    boss = is_boss
    chapter = chapter_no
    reduced_motion = bool(settings.get("reduced_motion",false))

func sync(units: Array, party: Array, selected: int, second_phase: bool, telegraph: String = "") -> void:
    enemy_units.clear()
    party_members.clear()
    for unit in units:
        if unit is Dictionary:
            enemy_units.append((unit as Dictionary).duplicate(true))
    for member in party:
        if member is Dictionary:
            party_members.append((member as Dictionary).duplicate(true))
    active_target = selected
    phase_two = second_phase
    warning = telegraph
    for index in range(enemy_units.size()):
        var key: String = "enemy_%d" % index
        if not hp_display.has(key):
            hp_display[key] = float(enemy_units[index].get("hp",0))
    for member in party_members:
        var key: String = "actor_"+str(member.get("id",""))
        if not hp_display.has(key):
            hp_display[key] = float(member.get("hp",0))
    queue_redraw()

func show_result(won: bool, xp: int, gold: int) -> void:
    banner = "VICTORY" if won else "DEFEAT"
    victory = won
    earned_xp = maxi(0,xp)
    earned_gold = maxi(0,gold)
    queue_redraw()

func _process(delta: float) -> void:
    var dt: float = clampf(delta,0.0,0.1)
    time_s += dt
    var changed: bool = false
    for index in range(enemy_units.size()):
        var key: String = "enemy_%d" % index
        var goal: float = float(enemy_units[index].get("hp",0))
        var shown: float = float(hp_display.get(key,goal))
        var next: float = goal if reduced_motion else move_toward(shown,goal,maxf(1.0,float(enemy_units[index].get("max_hp",1))*1.9*dt))
        hp_display[key] = next
        changed = changed or not is_equal_approx(shown,next)
    for member in party_members:
        var key: String = "actor_"+str(member.get("id",""))
        var goal: float = float(member.get("hp",0))
        var shown: float = float(hp_display.get(key,goal))
        var next: float = goal if reduced_motion else move_toward(shown,goal,maxf(1.0,float(member.get("max_hp",1))*1.8*dt))
        hp_display[key] = next
        changed = changed or not is_equal_approx(shown,next)
    if changed or not banner.is_empty() or not warning.is_empty():
        queue_redraw()

func _font() -> Font:
    return ThemeDB.fallback_font

func _bar(rect: Rect2, fraction: float, value: float, total: int, accent: Color) -> void:
    draw_rect(Rect2(rect.position-Vector2(2,2),rect.size+Vector2(4,4)), CVisual.RIM)
    draw_rect(rect,CVisual.INK)
    var smoothed: float = clampf(fraction,0.0,1.0)
    draw_rect(Rect2(rect.position,Vector2(rect.size.x*smoothed,rect.size.y)),accent)
    var actual: float = clampf(value/float(maxi(total,1)),0.0,1.0)
    draw_rect(Rect2(rect.position,Vector2(rect.size.x*actual,rect.size.y*0.27)),Color(1,1,1,0.19))

func _draw() -> void:
    var canvas: Vector2 = size
    if canvas.x < 300.0 or canvas.y < 200.0:
        return
    var font: Font = _font()
    if boss and not enemy_units.is_empty():
        var leader: Dictionary = enemy_units[0]
        var width: float = canvas.x*0.39
        var left: float = (canvas.x-width)*0.5
        var bar_y: float = canvas.y*0.208
        var actual: float = float(leader.get("hp",0))
        var total: int = maxi(1,int(leader.get("max_hp",1)))
        var color: Color = Color("f4b87c") if phase_two else Color("82c9ec")
        _bar(Rect2(left,bar_y,width,10),float(hp_display.get("enemy_0",actual))/float(total),actual,total,color)
        draw_string(font,Vector2(left,bar_y-7),"BOSS  ·  "+str(leader.get("name","")),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ffe9cc"))
        draw_string(font,Vector2(left+width,bar_y-7),"%d / %d" % [int(actual),total],HORIZONTAL_ALIGNMENT_RIGHT,115,14,Color("d7e3ed"))
        if phase_two:
            draw_string(font,Vector2(left+width*0.5,bar_y+27),"PHASE II",HORIZONTAL_ALIGNMENT_CENTER,175,15,Color("ffd3a0"))
    else:
        for index in range(mini(enemy_units.size(),MAX_MONSTERS)):
            var foe: Dictionary = enemy_units[index]
            var center: Vector2 = Vector2(canvas.x*0.5,canvas.y*0.27)
            if is_instance_valid(enemy_stage) and enemy_stage.visible:
                center = enemy_stage.point(index)
            var width: float = clampf(canvas.x*0.135,104.0,158.0)
            var bar_y: float = center.y-canvas.y*0.175
            var total: int = maxi(1,int(foe.get("max_hp",1)))
            var hp: float = float(foe.get("hp",0))
            var accent: Color = Color("f9ca84") if index == active_target else Color("82c6d2")
            _bar(Rect2(center.x-width*0.5,bar_y,width,8),float(hp_display.get("enemy_%d"%index,hp))/float(total),hp,total,accent)
            draw_string(font,Vector2(center.x-width*0.5,bar_y-7),
                ("%s  %d/%d" % [str(foe.get("name","敌人")),int(hp),total]),
                HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("fff0d8") if index==active_target else Color("b8d1d5"))
            if index == active_target and hp > 0:
                draw_line(center+Vector2(-11,-canvas.y*0.202),center+Vector2(0,-canvas.y*0.185),Color("ffd38a"),2,true)
                draw_line(center+Vector2(11,-canvas.y*0.202),center+Vector2(0,-canvas.y*0.185),Color("ffd38a"),2,true)
    for member in party_members:
        if not is_instance_valid(actor_stage):
            break
        var id: String = str(member.get("id",""))
        if not actor_stage.avatars.has(id):
            continue
        var center: Vector2 = actor_stage.actor_point(id)
        var total: int = maxi(1,int(member.get("max_hp",1)))
        var hp: float = float(member.get("hp",0))
        var width: float = clampf(canvas.x*0.095,70.0,116.0)
        var y: float = canvas.y*0.574
        _bar(Rect2(center.x-width*0.5,y,width,6),float(hp_display.get("actor_"+id,hp))/float(total),hp,total,Color("86dcb9") if hp/float(total)>0.3 else Color("f09b7e"))
        draw_string(font,Vector2(center.x-width*0.5,y-6),str(member.get("name","")),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e0ecf5"))
    if not warning.is_empty() and banner.is_empty():
        var width: float = canvas.x*0.34
        var warning_x: float = (canvas.x-width)*0.5
        draw_rect(Rect2(warning_x,canvas.y*0.55,width,29),Color(0.29,0.075,0.06,0.87))
        draw_rect(Rect2(warning_x,canvas.y*0.55,width,2),Color("f7aa76"))
        draw_string(font,Vector2(canvas.x*0.5,canvas.y*0.55+20),
            "⚠  "+warning,HORIZONTAL_ALIGNMENT_CENTER,int(width)-12,17,Color("ffdfc2"))
    if not banner.is_empty():
        var box_width: float = canvas.x*0.48
        var center: Vector2 = canvas*0.5
        var height: float = 124
        var origin: Vector2 = center-Vector2(box_width*0.5,height*0.5)
        draw_rect(Rect2(origin-Vector2(2,2),Vector2(box_width+4,height+4)),CVisual.RIM)
        draw_rect(Rect2(origin,Vector2(box_width,height)),CVisual.INK)
        draw_rect(Rect2(origin,Vector2(box_width,3)),Color("f6cd85"))
        draw_rect(Rect2(origin+Vector2(0,height-3),Vector2(box_width,3)),Color("b89558"))
        draw_string(font,center+Vector2(0,-11),banner,HORIZONTAL_ALIGNMENT_CENTER,int(box_width)-24,30,
            Color("ffe8b1") if victory else Color("edafa6"))
        var subtitle: String = "EXP +%d     GOLD +%d" % [earned_xp,earned_gold] if victory else "返回营地重新整备"
        draw_string(font,center+Vector2(0,26),subtitle,HORIZONTAL_ALIGNMENT_CENTER,int(box_width)-24,18,Color("dcebf3"))
