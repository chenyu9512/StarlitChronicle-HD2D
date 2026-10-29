extends Control
## Independent visual actors for multi-enemy formations. No changes to combat data.
const ArtAssets = preload("res://scripts/art_assets.gd")
const CMonsterMotion = preload("res://scripts/c_coast_monster_motion.gd")
const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
const FRAME_SIZE: int = 128
const FRAME_COUNT: int = 4
const FRAME_INTERVAL: float = 0.22
const MAX_VISIBLE: int = 3
const GROUND_ART: String = "res://assets/art/battle/a15/enemy_footing.svg"
const BOSS_ART: String = "res://assets/art/battle/a15/boss_footing.svg"

var slots: Dictionary = {}
var elapsed: float = 0.0
var reduced_motion: bool = false
var active_index: int = 0
var _size_cached: Vector2 = Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func configure(units: Array, chapter: int, boss: bool = false) -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    slots.clear()
    elapsed = 0.0
    active_index = 0
    for index in range(mini(units.size(),MAX_VISIBLE)):
        var enemy: Dictionary = units[index]
        var footing := Sprite2D.new()
        footing.name="FoeFooting_%d" % index
        footing.texture=ArtOverrides.texture(BOSS_ART if boss else GROUND_ART)
        footing.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        footing.z_index=0
        add_child(footing)
        var sprite := TextureRect.new()
        sprite.name = "Enemy_%d" % index
        sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
        sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        var art_path: String = ArtAssets.battle_image(enemy,boss,chapter)
        if ResourceLoader.exists(art_path):
            sprite.texture = ArtOverrides.texture(art_path)
        var atlas: AtlasTexture
        var action_sheets: Dictionary = {}
        var art: String = str(enemy.get("art",""))
        if not boss and not art.is_empty():
            action_sheets = CMonsterMotion.sheets(art)
            if not action_sheets.is_empty():
                atlas = AtlasTexture.new()
                atlas.atlas = action_sheets["idle"]
                atlas.region = Rect2(0,0,FRAME_SIZE,FRAME_SIZE)
                sprite.texture = atlas
        if atlas == null and not boss and not art.is_empty():
            var sheet_path: String = "res://assets/art/monsters/coast/%s/idle_4frames.png" % art
            if ResourceLoader.exists(sheet_path):
                var sheet: Texture2D = ArtOverrides.texture(sheet_path)
                if sheet != null and sheet.get_width() >= FRAME_SIZE*FRAME_COUNT and sheet.get_height() >= FRAME_SIZE:
                    atlas = AtlasTexture.new()
                    atlas.atlas = sheet
                    atlas.region = Rect2(0,0,FRAME_SIZE,FRAME_SIZE)
                    sprite.texture = atlas
        add_child(sprite)
        slots[index] = {"node":sprite,"footing":footing,"atlas":atlas,"base":Vector2.ZERO,
            "hit":0.0,"attack":0.0,"dying":0.0,"dead":false,"frame":0,"phase":0.17*float(index),"action_sheets":action_sheets,
            "motion_species":"" if boss else art}
    _layout()

func _layout() -> void:
    if slots.is_empty():
        return
    var canvas: Vector2 = size
    if canvas.x < 100.0:
        canvas = get_viewport_rect().size
    var count: int = slots.size()
    var width: float = clampf(canvas.x * (0.145 if count <= 2 else 0.12),112.0,183.0)
    var height: float = minf(canvas.y*0.34,210.0)
    var span: float = width * (1.28 if count <= 2 else 1.12)
    var first_x: float = canvas.x*0.52 - float(count-1)*span*0.5-width*0.5
    for index in slots.keys():
        var entry: Dictionary = slots[index]
        var sprite: TextureRect = entry["node"]
        if not is_instance_valid(sprite):
            continue
        sprite.size = Vector2(width,height)
        sprite.pivot_offset = sprite.size*0.5
        entry["base"] = Vector2(first_x+float(index)*span,canvas.y*0.235+(16.0 if index%2 == 1 else 0.0))
        var footing: Sprite2D=entry["footing"]
        footing.position=Vector2(entry["base"])+Vector2(width*0.5,height*0.93)
        footing.scale=Vector2(width*1.35/320.0,width*0.53/116.0)
        slots[index] = entry
    _size_cached = canvas

func point(index: int) -> Vector2:
    if slots.has(index):
        var entry: Dictionary = slots[index]
        var sprite: TextureRect = entry["node"]
        if is_instance_valid(sprite):
            return Vector2(entry["base"])+sprite.size*0.5
    return Vector2(size.x*0.5,size.y*0.4)

func focus(index: int) -> void:
    active_index = index

func attack(index: int) -> void:
    if not slots.has(index):
        return
    var entry: Dictionary = slots[index]
    if bool(entry["dead"]):
        return
    entry["attack"] = 0.27
    slots[index] = entry

func hit(index: int, defeated: bool = false) -> void:
    if not slots.has(index):
        return
    var entry: Dictionary = slots[index]
    entry["hit"] = 0.23
    if defeated:
        entry["dying"] = 0.48
    slots[index] = entry

func sync(units: Array) -> void:
    for index in slots.keys():
        if index >= units.size():
            continue
        var entry: Dictionary = slots[index]
        if int((units[index] as Dictionary).get("hp",0)) <= 0 and not bool(entry["dead"]) and float(entry["dying"]) <= 0.0:
            entry["dying"] = 0.48
        slots[index] = entry

func _process(delta: float) -> void:
    var dt: float = clampf(delta,0.0,0.1)
    elapsed += dt
    if _size_cached != size and size.x >= 100:
        _layout()
    for index in slots.keys():
        var entry: Dictionary = slots[index]
        var sprite: TextureRect = entry["node"]
        if not is_instance_valid(sprite):
            continue
        entry["hit"] = maxf(0.0,float(entry["hit"])-dt)
        entry["attack"] = maxf(0.0,float(entry["attack"])-dt)
        if float(entry["dying"]) > 0.0:
            entry["dying"] = maxf(0.0,float(entry["dying"])-dt)
            if float(entry["dying"]) <= 0.0:
                entry["dead"] = true
        var atlas: AtlasTexture = entry["atlas"]
        var action_sheets: Dictionary = entry.get("action_sheets", {})
        if atlas != null and not action_sheets.is_empty():
            var pose: String = "idle"
            var duration: float = 0.0
            var remaining: float = 0.0
            if bool(entry["dead"]) or float(entry["dying"]) > 0.0:
                pose = "defeat"
                duration = 0.48
                remaining = float(entry["dying"])
            elif float(entry["hit"]) > 0.0:
                pose = "hit"
                duration = 0.23
                remaining = float(entry["hit"])
            elif float(entry["attack"]) > 0.0:
                pose = "attack"
                duration = 0.27
                remaining = float(entry["attack"])
            var count: int = CMonsterMotion.frame_count(pose)
            var motion_frame: int = 0
            if pose == "idle":
                motion_frame = 1 if reduced_motion else int((elapsed + float(entry["phase"])) / FRAME_INTERVAL) % count
            elif bool(entry["dead"]):
                motion_frame = count - 1
            elif reduced_motion:
                motion_frame = 0
            elif duration > 0.0:
                motion_frame = clampi(floori((1.0 - remaining / duration) * float(count)), 0, count - 1)
            atlas.atlas = action_sheets[pose]
            atlas.region = Rect2(motion_frame * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
            entry["frame"] = motion_frame
        elif atlas != null and not reduced_motion and not bool(entry["dead"]):
            var next_frame: int = int((elapsed+float(entry["phase"]))/FRAME_INTERVAL)%FRAME_COUNT
            if int(entry["frame"]) != next_frame:
                atlas.region = Rect2(next_frame*FRAME_SIZE,0,FRAME_SIZE,FRAME_SIZE)
                entry["frame"] = next_frame
        var breathing: float = 1.0 if reduced_motion else 1.0+0.016*sin(elapsed*2.6+float(index))
        var selected: bool = index == active_index
        var scale_value: float = breathing*(1.05 if selected else 0.98)
        sprite.scale = Vector2(scale_value,scale_value)
        sprite.position = Vector2(entry["base"])
        # Reset the previous frame's species tilt before deciding whether
        # motion is allowed. The player may switch accessibility mid-battle.
        sprite.rotation = 0.0
        if not reduced_motion:
            sprite.position.y += 3.0*sin(elapsed*2.1+float(index))
            if float(entry["hit"]) > 0.0:
                sprite.position.x += sin(float(entry["hit"])*85.0)*8.0
            if float(entry["attack"]) > 0.0:
                sprite.position.x -= 28.0*sin(PI*(1.0-float(entry["attack"])/0.27))
        # Nine canonical coastal portraits currently lack their retired
        # authored four-pose SVG sheets. Preserve the actual species PNG and
        # apply identity-specific, low-cost motion to the same TextureRect.
        # This is visible gameplay motion, NOT replacement frame artwork.
        # If genuine action atlases are installed later, they take priority.
        if not reduced_motion and action_sheets.is_empty() and not bool(entry["dead"]) and float(entry["dying"]) <= 0.0:
            var species: String = str(entry.get("motion_species",""))
            var t: float = elapsed+float(entry["phase"])
            match species:
                "salt_slime":
                    var squash: float = sin(t*4.0)
                    sprite.scale.x *= 1.0 + 0.026*squash
                    sprite.scale.y *= 1.0 - 0.027*squash
                "fog_crab":
                    sprite.position.x += 5.0*sin(t*2.9)
                    sprite.rotation = 0.013*sin(t*3.8)
                "sand_lizard":
                    sprite.position.x += 3.5*sin(t*3.3)
                    sprite.rotation = 0.018*sin(t*3.7)
                "tide_ghost":
                    sprite.position.y -= 5.0+3.0*sin(t*1.6)
                    sprite.rotation = 0.011*sin(t*1.3)
                "white_seabird":
                    sprite.position.y -= 8.0+4.0*sin(t*4.3)
                    sprite.rotation = 0.027*sin(t*4.3)
                "shell_hermit":
                    sprite.scale.y *= 1.0-0.018*maxf(0.0,sin(t*2.0))
                    sprite.position.x += 2.0*sin(t*1.8)
                "salt_wolf":
                    sprite.position.y += 2.6*sin(t*3.5)
                    sprite.rotation = 0.015*sin(t*2.4)
                "star_ray":
                    sprite.position.y -= 6.0+2.8*sin(t*2.1)
                    sprite.position.x += 3.5*cos(t*1.2)
                "tide_guardian":
                    sprite.rotation = 0.009*sin(t*1.1)
                    sprite.scale.y *= 1.0+0.014*sin(t*1.9)
        var fade: float = minf(1.0,float(entry["dying"])/0.48) if float(entry["dying"]) > 0.0 else (0.0 if bool(entry["dead"]) else 1.0)
        if float(entry["dying"]) > 0.0 and not reduced_motion:
            sprite.position.y -= 18.0*(1.0-fade)
            sprite.scale *= Vector2(1.0+0.06*(1.0-fade),1.0-0.14*(1.0-fade))
        if float(entry["hit"]) > 0.0:
            sprite.modulate = Color(1.0,0.58,0.58,fade)
        else:
            sprite.modulate = Color(1.0,1.0,1.0,fade if selected else fade*0.83)
        var footing: Sprite2D=entry["footing"]
        footing.modulate.a=fade*(0.92 if selected else 0.42)
        if float(entry["attack"])>0.0:
            footing.modulate=Color("ffb8a1") if not reduced_motion else Color.WHITE
            footing.modulate.a=fade*0.75
        else:
            footing.modulate=Color.WHITE
            footing.modulate.a=fade*(0.92 if selected else 0.42)
        slots[index] = entry
