extends Control
## Lightweight 2D battle presentation. Visual-only: never changes HP, turns or rewards.
## Works in the GL Compatibility renderer without shaders, particles or new textures.
const IDLE_FRAME_SIZE: int = 128
const IDLE_FRAME_COUNT: int = 4
const MAX_EFFECTS: int = 48
const IDLE_STEP: float = 0.22

var effects: Array[Dictionary] = []
var reduced_motion: bool = false
var _enemy_sprite: TextureRect
var _idle_atlas: AtlasTexture
var _idle_clock: float = 0.0
var _idle_frame: int = -1
var _hit_timer: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func bind_enemy(sprite: TextureRect, art: String, is_boss: bool) -> void:
    _enemy_sprite = sprite
    _idle_atlas = null
    _idle_clock = 0.0
    _idle_frame = -1
    _hit_timer = 0.0
    if not is_boss and not art.is_empty():
        var path: String = "res://assets/art/monsters/coast/%s/idle_4frames.png" % art
        if ResourceLoader.exists(path):
            var sheet: Texture2D = load(path) as Texture2D
            if sheet != null and sheet.get_width() >= IDLE_FRAME_SIZE * IDLE_FRAME_COUNT and sheet.get_height() >= IDLE_FRAME_SIZE:
                _idle_atlas = AtlasTexture.new()
                _idle_atlas.atlas = sheet
                _set_idle_frame(0)
                sprite.texture = _idle_atlas
    if is_instance_valid(sprite):
        sprite.pivot_offset = sprite.size * 0.5
        sprite.scale = Vector2.ONE
        sprite.rotation = 0.0
        sprite.modulate = Color.WHITE

func _set_idle_frame(index: int) -> void:
    if _idle_atlas == null or _idle_frame == index:
        return
    _idle_frame = index
    _idle_atlas.region = Rect2(index * IDLE_FRAME_SIZE, 0, IDLE_FRAME_SIZE, IDLE_FRAME_SIZE)

func _process(delta: float) -> void:
    var step: float = minf(delta, 0.1)
    _idle_clock += step
    _hit_timer = maxf(0.0, _hit_timer - step)
    if is_instance_valid(_enemy_sprite):
        _enemy_sprite.pivot_offset = _enemy_sprite.size * 0.5
        if reduced_motion:
            _enemy_sprite.scale = Vector2.ONE
            _enemy_sprite.rotation = 0.0
        else:
            if _idle_atlas != null:
                _set_idle_frame(int(_idle_clock / IDLE_STEP) % IDLE_FRAME_COUNT)
            var breathe: float = 1.0 + 0.012 * sin(_idle_clock * 2.6)
            _enemy_sprite.scale = Vector2(breathe, breathe)
            _enemy_sprite.rotation = 0.008 * sin(_idle_clock * 1.7) + (0.043 * sin(_hit_timer * 85.0) if _hit_timer > 0.0 else 0.0)
        _enemy_sprite.modulate = Color(1.0, 0.67, 0.67, 1.0) if _hit_timer > 0.0 else Color.WHITE
    if effects.is_empty():
        return
    for i in range(effects.size() - 1, -1, -1):
        var effect: Dictionary = effects[i]
        effect["age"] = float(effect["age"]) + step
        if float(effect["age"]) >= float(effect["duration"]):
            effects.remove_at(i)
        else:
            effects[i] = effect
    queue_redraw()

func _emit(kind: String, position: Vector2, color: Color, duration: float = 0.4, label: String = "") -> void:
    if reduced_motion and kind != "text":
        return
    if effects.size() >= MAX_EFFECTS:
        effects.remove_at(0)
    effects.append({"kind":kind, "position":position, "color":color, "age":0.0, "duration":maxf(duration,0.05), "label":label})
    queue_redraw()

func _element_color(element: String) -> Color:
    match element:
        "火", "炎", "fire": return Color("ff905d")
        "冰", "霜", "ice": return Color("9ddaff")
        "雷", "光", "thunder": return Color("f9df80")
        "风", "wind": return Color("8be5cc")
        "水", "water": return Color("78baff")
        "暗", "影", "dark": return Color("bf9bff")
        "自然", "nature": return Color("9ddc8b")
        "圣", "holy": return Color("fff3bb")
        "土", "earth": return Color("d7ad75")
        _: return Color("ffe3a4")

func play_attack(target: Vector2, damage: int) -> void:
    _hit_timer = 0.23
    _emit("slash",target,Color("fff0c8"),0.26)
    _emit("sparks",target,Color("ffc36d"),0.43)
    _emit("text",target + Vector2(0,-44),Color("fff2d8"),0.70,str(damage))

func play_spell(origin: Vector2, target: Vector2, element: String, damage: int, area: bool = false) -> void:
    var color: Color = _element_color(element)
    _emit("rune",origin,color,0.53)
    _emit("beam",(origin+target)*0.5,color,0.40)
    _emit("burst",target,color,0.54 if area else 0.42)
    _emit("text",target + Vector2(0,-50),color,0.78,str(damage))
    _hit_timer = 0.22

## 63 skills reuse nine distinct elemental motifs plus job signature and tier accents.
## Presentation dispatch is data-driven from each skill's element/job_id/fx_key/tier.
func play_skill(origin: Vector2, target: Vector2, skill: Dictionary, damage: int = 0, area: bool = false) -> void:
    var element: String = str(skill.get("element","光"))
    var job: String = str(skill.get("job_id",""))
    var tier: int = clampi(int(skill.get("tier",1)),1,7)
    var color: Color = _element_color(element)
    var motif: String = "star"
    match element:
        "火": motif = "flame"
        "冰": motif = "frost"
        "雷": motif = "lightning"
        "水": motif = "tide"
        "风": motif = "gust"
        "影", "暗": motif = "shadow"
        "自然": motif = "leaf"
        "圣": motif = "halo"
        "光": motif = "star"
    _emit("rune",origin,color,0.32 + 0.035 * float(tier))
    _emit(motif,target,color,0.42 + 0.042 * float(tier))
    if job in ["wayfarer","seeker","vanguard"]:
        _emit("slash",target,color,0.30)
    elif job in ["tidecaller","navigator","mirrorweaver"]:
        _emit("rune",target,color,0.44)
    elif job in ["smith","alchemist","cantor"]:
        _emit("sparks",target,color,0.45)
    if area:
        _emit("shockwave",target,color,0.55)
    if tier >= 5:
        _emit("sparkle",target,color,0.65)
    if damage > 0:
        _emit("text",target + Vector2(0,-50),color,0.75,str(damage))
        _hit_timer = 0.22

func play_heal(target: Vector2, name: String = "恢复") -> void:
    _emit("rune",target,Color("76efb7"),0.58)
    _emit("sparkle",target,Color("a5ffe0"),0.75)
    _emit("text",target + Vector2(0,-32),Color("a5ffe0"),0.85,name)

func play_guard(target: Vector2) -> void:
    _emit("shield",target,Color("96c8ff"),0.73)

func play_charge(target: Vector2) -> void:
    _emit("rune",target,Color("fce28a"),0.67)
    _emit("sparkle",target,Color("ffe8a5"),0.76)

func play_special(target: Vector2, damage: int = 0) -> void:
    _emit("rune",target,Color("ffe6a8"),0.54)
    _emit("burst",target,Color("fff1ca"),0.72)
    if damage > 0:
        _emit("text",target + Vector2(0,-51),Color("fff2d8"),0.82,str(damage))
    _hit_timer = 0.20

func play_status(target: Vector2, damage: int, kind: String = "持续伤害") -> void:
    _emit("burst",target,Color("ae92df"),0.44)
    _emit("text",target + Vector2(0,-48),Color("e2b8ff"),0.72,"%s -%d" % [kind,damage])

func play_enemy_attack(origin: Vector2, target: Vector2, damage: int) -> void:
    _emit("beam",(origin+target)*0.5,Color("f89c91"),0.32)
    _emit("slash",target,Color("ff9e9a"),0.33)
    _emit("text",target + Vector2(0,-30),Color("ffbcb4"),0.78,"-%d HP" % damage)

func play_phase(target: Vector2) -> void:
    _emit("shockwave",target,Color("f8bd80"),0.86)
    _emit("rune",target,Color("f9d99d"),0.90)
    _emit("text",target + Vector2(0,-65),Color("ffe4a5"),1.0,"第二阶段")

func play_victory(target: Vector2) -> void:
    _emit("sparkle",target,Color("fff0a6"),1.05)
    _emit("shockwave",target,Color("ffebb3"),0.76)

func _draw() -> void:
    for effect in effects:
        var life: float = clampf(float(effect["age"]) / float(effect["duration"]),0.0,1.0)
        var opacity: float = 1.0 - life
        var center: Vector2 = effect["position"]
        var ink: Color = effect["color"]
        ink.a *= opacity
        var radius: float = 24.0 + 56.0 * life
        match str(effect["kind"]):
            "slash":
                draw_line(center + Vector2(-53,32) * (0.55 + life), center + Vector2(53,-32) * (0.55 + life),ink,7.0 * opacity + 1.0,true)
                draw_line(center + Vector2(-28,-35) * (0.55 + life),center + Vector2(28,35) * (0.55 + life),ink,3.0 * opacity + 1.0,true)
            "sparks", "sparkle", "burst":
                var count: int = 12 if str(effect["kind"]) == "burst" else 8
                for i in range(count):
                    var angle: float = TAU * float(i) / float(count) + float(i % 3) * 0.18
                    var direction: Vector2 = Vector2(cos(angle),sin(angle))
                    var spot: Vector2 = center + direction * radius * (0.65 if i % 2 == 0 else 1.0)
                    draw_circle(spot,maxf(1.0,(4.5 if i % 3 == 0 else 3.0) * opacity),ink)
                if str(effect["kind"]) == "burst":
                    draw_arc(center,radius * 0.7,0.0,TAU,40,ink,3.5 * opacity + 0.5,true)
            "rune":
                draw_arc(center,radius,0.0,TAU,48,ink,3.0 * opacity + 0.5,true)
                draw_arc(center,radius*0.7,0.0,TAU,40,ink,1.8,true)
                for i in range(6):
                    var angle: float = float(i) * TAU / 6.0 + life
                    var pt: Vector2 = center + Vector2(cos(angle),sin(angle)) * radius
                    draw_circle(pt,3.5 * opacity + 0.5,ink)
            "shield":
                draw_arc(center,radius*0.85,PI*0.15,PI*0.85,30,ink,5.0*opacity+1.0,true)
                draw_arc(center,radius*0.85,PI*1.15,PI*1.85,30,ink,5.0*opacity+1.0,true)
                draw_line(center+Vector2(0,-radius),center+Vector2(0,radius),ink,2.0*opacity+0.5,true)
            "beam":
                var length: float = 88.0 * (1.0 - life*0.35)
                draw_line(center+Vector2(-length,-length*0.33),center+Vector2(length,length*0.33),ink,7.0*opacity+0.5,true)
            "shockwave":
                draw_arc(center,radius*1.5,0.0,TAU,56,ink,6.0*opacity+0.5,true)
                draw_arc(center,radius*1.1,0.0,TAU,48,ink,2.0*opacity+0.5,true)
            "flame":
                for i in range(6):
                    var dx: float = float(i - 3) * 15.0
                    var base: Vector2 = center + Vector2(dx,20.0 * life)
                    draw_line(base+Vector2(0,16),base+Vector2(6,-radius * (1.15 if i % 2 == 0 else 0.8)),ink,7.0*opacity+0.7,true)
                    draw_circle(base+Vector2(6,-radius * 0.7),maxf(1.0,5.0*opacity),ink)
            "frost":
                for i in range(6):
                    var angle: float = float(i)*TAU/6.0
                    var dir: Vector2 = Vector2(cos(angle),sin(angle))
                    draw_line(center,center+dir*radius,ink,3.0*opacity+0.5,true)
                    var tip: Vector2 = center+dir*radius*0.68
                    draw_line(tip,tip+dir.rotated(0.72)*radius*0.24,ink,2.0*opacity+0.5,true)
                    draw_line(tip,tip+dir.rotated(-0.72)*radius*0.24,ink,2.0*opacity+0.5,true)
            "lightning":
                for i in range(3):
                    var x: float = (float(i)-1.0)*25.0
                    var points: PackedVector2Array = PackedVector2Array([
                        center+Vector2(x-20,-radius),center+Vector2(x+14,-radius*0.28),
                        center+Vector2(x-9,radius*0.05),center+Vector2(x+22,radius)
                    ])
                    draw_polyline(points,ink,4.0*opacity+0.7,true)
            "tide":
                for i in range(3):
                    var wave_y: float = float(i-1)*20.0
                    draw_arc(center+Vector2(0,wave_y),radius*0.8,PI*0.05,PI*0.96,32,ink,3.5*opacity+0.5,true)
                    draw_arc(center+Vector2(0,wave_y),radius*0.8,PI*1.05,PI*1.96,32,ink,2.1*opacity+0.4,true)
            "gust":
                for i in range(4):
                    var shift: float = float(i-2)*16.0
                    draw_arc(center+Vector2(shift,0),radius*0.8,PI*0.95,PI*1.92,30,ink,3.0*opacity+0.5,true)
            "shadow":
                draw_circle(center,radius*0.62,Color(0.26,0.14,0.38,0.32*opacity))
                draw_arc(center,radius,PI*0.25,TAU*0.91,40,ink,5.0*opacity+0.4,true)
            "leaf":
                for i in range(8):
                    var angle: float = float(i)*TAU/8.0+life*1.2
                    var pos: Vector2 = center+Vector2(cos(angle),sin(angle))*radius*0.83
                    draw_line(pos-Vector2(8,5),pos+Vector2(8,-5),ink,4.0*opacity+0.6,true)
            "halo":
                draw_arc(center,radius,0,TAU,48,ink,5.0*opacity+0.8,true)
                draw_arc(center,radius*0.58,0,TAU,48,ink,2.0*opacity+0.4,true)
            "star":
                for i in range(10):
                    var angle: float = TAU*float(i)/10.0
                    var dir: Vector2 = Vector2(cos(angle),sin(angle))
                    draw_line(center+dir*radius*0.30,center+dir*radius*(1.15 if i%2 == 0 else 0.75),ink,3.0*opacity+0.4,true)
            "text":
                var font: Font = ThemeDB.fallback_font
                var label: String = str(effect.get("label",""))
                draw_string(font,center+Vector2(0,-life*52.0),label,HORIZONTAL_ALIGNMENT_CENTER,150,24,ink)
