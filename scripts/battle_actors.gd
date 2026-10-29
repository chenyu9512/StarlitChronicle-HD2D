extends Control
## Presentation-only party actors. Real portraits, deterministic motion, no turn/HP writes.
const MAX_VISIBLE: int = 4
const CArtOverrides = preload("res://scripts/c_art_overrides.gd")
const GROUND_ART: String = "res://assets/art/battle/a15/actor_footing.svg"
const CAST_ART: String = "res://assets/art/battle/a15/casting_sigil.svg"
const ATTACK_DURATION: float = 0.36
const CAST_DURATION: float = 0.50
const HIT_DURATION: float = 0.34
const ACTION_FRAME_SIZE: int = 96
const ACTION_FRAMES: int = 6
const MOTION_DIR: String = "res://assets/art/battle/a16/motion_"

var reduced_motion: bool = false
var avatars: Dictionary = {}
var elapsed: float = 0.0
var motion_sheets: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    for pose in ["attack","guard","heal","hit"]:
        var motion_file: String=MOTION_DIR+pose+"_6f.svg"
        if ResourceLoader.exists(motion_file):
            motion_sheets[pose]=CArtOverrides.texture(motion_file)
    set_process(true)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _layout_actors()

func configure(actors: Array, active_ids: Array = []) -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    avatars.clear()
    var selected: Array[Dictionary] = []
    for item in actors:
        if not item is Dictionary:
            continue
        var member: Dictionary = item
        var id: String = str(member.get("id",""))
        if id.is_empty() or (not active_ids.is_empty() and id not in active_ids):
            continue
        selected.append(member)
        if selected.size() >= MAX_VISIBLE:
            break
    for index in range(selected.size()):
        var member: Dictionary = selected[index]
        var id: String = str(member.get("id",""))
        var art: String = _resolve_art(id)
        var footing := Sprite2D.new()
        footing.name="GroundShadow_%s" % id
        footing.texture=CArtOverrides.texture(GROUND_ART)
        footing.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        footing.z_index=0
        add_child(footing)
        var sigil := Sprite2D.new()
        sigil.name="CastCircle_%s" % id
        sigil.texture=CArtOverrides.texture(CAST_ART)
        sigil.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        sigil.z_index=0
        sigil.modulate.a=0.0
        add_child(sigil)
        var portrait := TextureRect.new()
        portrait.name = "Actor_%s" % id
        portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        portrait.texture = CArtOverrides.texture(art) if not art.is_empty() else null
        add_child(portrait)
        var motion := Sprite2D.new()
        motion.name="ActionFlipbook_%s" % id
        motion.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        var motion_atlas:=AtlasTexture.new()
        if motion_sheets.has("attack"):
            motion_atlas.atlas=motion_sheets["attack"]
        motion_atlas.region=Rect2(0,0,ACTION_FRAME_SIZE,ACTION_FRAME_SIZE)
        motion.texture=motion_atlas
        motion.modulate.a=0.0
        add_child(motion)
        avatars[id] = {
            "node":portrait,"footing":footing,"sigil":sigil,
            "motion":motion,"motion_atlas":motion_atlas,
            "motion_kind":"","motion_frame":-1,
            "index":index,"count":selected.size(),
            "base":Vector2.ZERO,"clock":0.0,"action":"idle","action_time":0.0,
            "hit_time":0.0,"victory_time":0.0,"fallen":int(member.get("hp",0)) <= 0
        }
    _layout_actors()

func _resolve_art(actor_id: String) -> String:
    var folder: String = "res://assets/art/b02/characters/main/%s/" % actor_id
    for file in ["fullbody_rgba.png","dialogue_192x240.png","head_160x160.png"]:
        if CArtOverrides.exists(folder + file):
            return folder + file
    var legacy: Dictionary = {
        "char_wayfarer":"leon","char_tidecaller":"lanyin",
        "char_seeker":"shuoxian","char_vanguard":"chengzhou"
    }
    if legacy.has(actor_id):
        var path: String = "res://assets/art/characters/%s/battle.png" % str(legacy[actor_id])
        if CArtOverrides.exists(path):
            return path
    return ""

func _layout_actors() -> void:
    if avatars.is_empty():
        return
    var canvas: Vector2 = size
    if canvas.x < 100.0 or canvas.y < 100.0:
        canvas = get_viewport_rect().size
    var count: int = avatars.size()
    var width: float = clampf(canvas.x * 0.105,74.0,125.0) if count <= 2 else clampf(canvas.x * 0.084,62.0,94.0)
    var height: float = width * 1.45
    for id in avatars.keys():
        var entry: Dictionary = avatars[id]
        var index: int = int(entry["index"])
        var portrait: TextureRect = entry["node"]
        if not is_instance_valid(portrait):
            continue
        portrait.size = Vector2(width,height)
        portrait.pivot_offset = portrait.size * 0.5
        var xpos: float = canvas.x * 0.075 + float(index % 2) * width * 0.89
        var ypos: float = canvas.y * (0.33 if index < 2 else 0.40) + float(index % 2) * 15.0
        entry["base"] = Vector2(xpos,ypos)
        var footing: Sprite2D=entry["footing"]
        footing.position=Vector2(xpos+width*0.5,ypos+height*0.94)
        footing.scale=Vector2(width*1.65/320.0,width*0.50/112.0)
        var sigil: Sprite2D=entry["sigil"]
        sigil.position=Vector2(xpos+width*0.5,ypos+height*0.67)
        sigil.scale=Vector2.ONE*(width/115.0)
        avatars[id] = entry

func actor_point(actor_id: String) -> Vector2:
    if avatars.has(actor_id):
        var entry: Dictionary = avatars[actor_id]
        var sprite: TextureRect = entry["node"]
        if is_instance_valid(sprite):
            return Vector2(entry["base"]) + sprite.size * 0.5
    var canvas: Vector2 = size if size.x >= 100.0 else get_viewport_rect().size
    return Vector2(canvas.x * 0.28,canvas.y * 0.48)

func play_action(actor_id: String, action: String) -> void:
    if not avatars.has(actor_id):
        return
    var entry: Dictionary = avatars[actor_id]
    if bool(entry["fallen"]):
        return
    entry["action"] = action
    entry["action_time"] = CAST_DURATION if action in ["skill","heal","charge","special"] else ATTACK_DURATION
    avatars[actor_id] = entry

func play_victory() -> void:
    for id in avatars.keys():
        var entry: Dictionary = avatars[id]
        if not bool(entry.get("fallen",false)):
            entry["victory_time"] = 1.0
            entry["action"] = "victory"
            avatars[id] = entry

func _draw() -> void:
    for id in avatars.keys():
        var entry: Dictionary = avatars[id]
        var sprite: TextureRect = entry["node"]
        if not is_instance_valid(sprite):
            continue
        var center: Vector2 = Vector2(entry["base"])+Vector2(sprite.size.x*0.5,sprite.size.y+7)
        var opacity: float = 0.20 if bool(entry["fallen"]) else 0.40
        draw_set_transform(center,0.0,Vector2(1.6,0.28))
        draw_circle(Vector2.ZERO,24.0,Color(0.0,0.025,0.08,opacity))
        draw_set_transform(Vector2.ZERO)

func play_hit(actor_id: String, fallen: bool = false) -> void:
    if not avatars.has(actor_id):
        return
    var entry: Dictionary = avatars[actor_id]
    entry["hit_time"] = HIT_DURATION
    entry["fallen"] = fallen
    avatars[actor_id] = entry

func update_party(actors: Array) -> void:
    for item in actors:
        if not item is Dictionary:
            continue
        var id: String = str(item.get("id",""))
        if not avatars.has(id):
            continue
        var entry: Dictionary = avatars[id]
        entry["fallen"] = int(item.get("hp",0)) <= 0
        avatars[id] = entry

func _process(delta: float) -> void:
    var dt: float = minf(maxf(delta,0.0),0.1)
    elapsed += dt
    for id in avatars.keys():
        var entry: Dictionary = avatars[id]
        var sprite: TextureRect = entry["node"]
        if not is_instance_valid(sprite):
            continue
        entry["clock"] = float(entry["clock"]) + dt
        entry["action_time"] = maxf(0.0,float(entry["action_time"]) - dt)
        entry["hit_time"] = maxf(0.0,float(entry["hit_time"]) - dt)
        entry["victory_time"] = maxf(0.0,float(entry.get("victory_time",0.0)) - dt)
        var offset := Vector2.ZERO
        var sizing: float = 1.0
        var falling: bool = bool(entry["fallen"])
        if not reduced_motion and not falling:
            offset.y = -2.5 * sin(float(entry["clock"]) * 2.3 + float(entry["index"]))
            var action_time: float = float(entry["action_time"])
            if action_time > 0.0:
                var duration: float = CAST_DURATION if str(entry["action"]) in ["skill","heal","charge","special"] else ATTACK_DURATION
                var intensity: float = sin(PI * (1.0 - action_time / duration))
                if str(entry["action"]) in ["attack","special"]:
                    offset.x += 42.0 * intensity
                    offset.y -= 13.0 * intensity
                elif str(entry["action"]) in ["skill","heal","charge"]:
                    offset.y -= 16.0 * intensity
                    sizing += 0.075 * intensity
                elif str(entry["action"]) == "guard":
                    offset.x -= 7.0 * intensity
                    sizing -= 0.06*intensity
            if float(entry.get("victory_time",0.0)) > 0.0:
                var cheer: float = sin(float(entry["victory_time"])*TAU*2.0)
                offset.y -= absf(cheer)*16.0
                sizing += 0.035*absf(cheer)
            if float(entry["hit_time"]) > 0.0:
                offset.x += 8.0 * sin(float(entry["hit_time"]) * 80.0)
        sprite.position = Vector2(entry["base"]) + offset
        sprite.scale = Vector2(sizing,sizing)
        var lean: float = 0.0
        if falling and not reduced_motion:
            lean = 0.15
        elif not reduced_motion and float(entry["action_time"]) > 0.0 and str(entry["action"]) in ["attack","special"]:
            var action_duration: float = CAST_DURATION if str(entry["action"])=="special" else ATTACK_DURATION
            lean = -0.16*sin(PI*(1.0-float(entry["action_time"])/action_duration))
        sprite.rotation = lean
        if falling:
            sprite.modulate = Color(0.54,0.59,0.73,0.65)
        elif float(entry["hit_time"]) > 0.0:
            sprite.modulate = Color(1.0,0.58,0.57,1.0)
        else:
            sprite.modulate = Color.WHITE
        var footing: Sprite2D=entry["footing"]
        var sigil: Sprite2D=entry["sigil"]
        footing.modulate.a=0.32 if falling else 0.84
        var cast_left: float=float(entry["action_time"])
        var casting: bool=not falling and cast_left>0.0 and str(entry["action"]) in ["skill","heal","charge","special"]
        if casting:
            var strength: float=clampf(cast_left/CAST_DURATION,0.0,1.0)
            sigil.modulate=Color("9fe0d7") if str(entry["action"])=="heal" else Color("f5d6a2")
            sigil.modulate.a=(0.22+0.56*sin(PI*(1.0-strength))) if not reduced_motion else 0.38
            if not reduced_motion:
                sigil.rotation+=dt*0.82
        else:
            sigil.modulate.a=0.0
        # Real six-frame motion overlays, keyed to the existing animation
        # timers. Portrait identities and battle commands stay untouched.
        var motion_sprite: Sprite2D=entry["motion"]
        var motion_atlas: AtlasTexture=entry["motion_atlas"]
        var visual_kind: String=""
        var remaining: float=0.0
        var duration: float=0.0
        if float(entry["hit_time"])>0.0:
            visual_kind="hit"
            remaining=float(entry["hit_time"])
            duration=HIT_DURATION
        elif not falling and float(entry["action_time"])>0.0:
            var move_name: String=str(entry["action"])
            visual_kind="guard" if move_name=="guard" else ("attack" if move_name in ["attack","special"] else "heal")
            remaining=float(entry["action_time"])
            duration=CAST_DURATION if move_name in ["skill","heal","charge","special"] else ATTACK_DURATION
        if not visual_kind.is_empty() and motion_sheets.has(visual_kind):
            var motion_frame: int=3 if reduced_motion else mini(int((1.0-clampf(remaining/duration,0.0,1.0))*float(ACTION_FRAMES)),ACTION_FRAMES-1)
            if visual_kind!=str(entry["motion_kind"]):
                motion_atlas.atlas=motion_sheets[visual_kind]
                entry["motion_kind"]=visual_kind
                entry["motion_frame"]=-1
            if motion_frame!=int(entry["motion_frame"]):
                motion_atlas.region=Rect2(motion_frame*ACTION_FRAME_SIZE,0,ACTION_FRAME_SIZE,ACTION_FRAME_SIZE)
                entry["motion_frame"]=motion_frame
            motion_sprite.position=sprite.position+Vector2(sprite.size.x*0.55,sprite.size.y*0.52)
            motion_sprite.scale=Vector2.ONE*(sprite.size.x/105.0)
            motion_sprite.modulate.a=0.48 if reduced_motion else 0.88
        else:
            motion_sprite.modulate.a=0.0
        avatars[id] = entry
