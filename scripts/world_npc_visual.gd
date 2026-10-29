extends Sprite2D
const ArtAssets = preload("res://scripts/art_assets.gd")
const CharacterMotion = preload("res://scripts/c_character_motion.gd")
const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
## Small original top-down citizen silhouette; role palette conveys information.
var motion = CharacterMotion.new()
var reduced_motion: bool = false
var life_action: String = "observe"
var life_timer: float = 0.0
var gaze_tick: float = 0.0
var talking: bool = false
var role: String = "lore"
var citizen_name: String = ""
var tone: Color = Color("749eab")
var base_hour: int = 8
var label: Label
var artwork: Sprite2D
var idle_elapsed: float = 0.0
var gesture_clock: float = 0.0
var blink_phase: float = 0.0
var animation_redraws: int = 0
var base_art_offset: float = -21.0
var story_phase: String = "intro"
var story_route: String = ""
var story_hour: int = 12

func apply_story_presentation(phase: String, route: String, minutes: int) -> void:
    # Visual state only; original dialogue/choice flags and identity are untouched.
    if role != "quest":
        return
    story_phase = phase if phase in ["intro","investigate","community","revisit","resolved"] else "intro"
    story_route = route if route in ["a","b"] else ""
    story_hour = posmod(floori(float(minutes) / 60.0),24)
    match story_phase:
        "intro": tone = Color("b9a482")
        "investigate": tone = Color("789da6")
        "community": tone = Color("84aa83")
        "revisit": tone = Color("9791c4")
        "resolved": tone = Color("9ebf98")
    if story_route == "a":
        tone = tone.lerp(Color("7cd5ca"),0.35)
    elif story_route == "b":
        tone = tone.lerp(Color("eac282"),0.35)
    modulate = Color("b9c0dc") if story_hour<6 or story_hour>=20 else Color.WHITE
    queue_redraw()

func _process(delta: float) -> void:
    motion.reduced_motion = reduced_motion
    motion.advance(delta, Vector2.ZERO)
    idle_elapsed += delta
    life_timer += delta
    gaze_tick += delta
    if gaze_tick >= (0.52 if reduced_motion else 0.28) and not talking:
        gaze_tick = 0.0
        # No authoritative NPC location change; visual head tracks nearby actors.
        for visitor in get_tree().get_nodes_in_group("c_visual_actor"):
            if not visitor is Node2D or not is_instance_valid(visitor):
                continue
            var distance: Vector2 = (visitor as Node2D).global_position - global_position
            if distance.length_squared() <= 62.0 * 62.0:
                motion.face_vector(distance)
                queue_redraw()
                break
    if life_timer >= 4.2 and not talking:
        life_timer = fmod(life_timer, 4.2)
        var cycle: int = posmod(int(idle_elapsed / 4.2) + citizen_name.hash(), 4)
        match role:
            "shop": life_action = ["sort_goods", "wave", "observe", "rest"][cycle]
            "craft": life_action = ["work", "rest", "observe", "work"][cycle]
            "quest": life_action = ["observe", "wave", "rest", "observe"][cycle]
            _: life_action = ["observe", "rest", "look_around", "observe"][cycle]
    blink_phase=fposmod(idle_elapsed+float(posmod(role.hash(),7))*0.37,3.9)
    if is_instance_valid(artwork):
        # Still portrait identities stay intact: only subtle vertical breathing.
        artwork.position.y = base_art_offset if reduced_motion else base_art_offset + 0.8 * sin(idle_elapsed * 1.6 + float(posmod(role.hash(), 8)))
        artwork.position.x = motion.visual_offset().x
    else:
        # Regulate CPU and redraw rate; only original fallback silhouettes need
        # procedural hand/work/blink posing. No per-frame texture allocations.
        gesture_clock+=delta
        if gesture_clock >= (0.28 if reduced_motion else 0.12):
            gesture_clock = 0.0
            animation_redraws+=1
            queue_redraw()

## Presentation calls only. Resident positions, quest flags and dialogue text never change.
func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    motion.reduced_motion = value

func set_motion(delta: float, direction: Vector2) -> void:
    motion.advance(delta, direction)
    queue_redraw()

func face_player(world_point: Vector2) -> void:
    talking = true
    motion.start_talking(to_local(world_point))
    life_action = "talk"
    life_timer = 0.0
    queue_redraw()

func end_conversation() -> void:
    talking = false
    life_action = "observe"
    queue_redraw()

func perform_life_action(action: String) -> void:
    if action not in ["sort_goods", "wave", "observe", "work", "sweep", "rest", "look_around", "talk"]:
        return
    life_action = action
    life_timer = 0.0
    motion.gesture()
    queue_redraw()

func setup(info: Dictionary) -> void:
    role=str(info.get("role","lore"))
    citizen_name=str(info.get("name","旅人"))
    match role:
        "shop": tone=Color("ca9568")
        "craft": tone=Color("9a8dac")
        "quest": tone=Color("d4bd72")
        "rumor": tone=Color("b59079")
        _: tone=Color("70aa9b")
    if label==null:
        label=Label.new()
        label.position=Vector2(-46,-55)
        label.custom_minimum_size.x=94
        label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size",12)
        label.add_theme_color_override("font_color",Color("fff1d2"))
        label.add_theme_color_override("font_shadow_color",Color("0a1d2d"))
        label.add_theme_constant_override("shadow_offset_x",1)
        label.add_theme_constant_override("shadow_offset_y",2)
        add_child(label)
    label.text=citizen_name
    # Only the 35 approved B02 NPC fullbody sheets are used as still overworld figures.
    # Coast residents without authored B02 art keep their silhouette fallback.
    var art_path: String = ArtAssets.npc_fullbody(str(info.get("id", "")))
    if not art_path.is_empty() and ResourceLoader.exists(art_path):
        artwork = Sprite2D.new()
        artwork.texture = ArtOverrides.texture(art_path)
        var dimensions: Vector2 = artwork.texture.get_size()
        var factor: float = minf(56.0 / maxf(dimensions.y, 1.0), 38.0 / maxf(dimensions.x, 1.0))
        artwork.scale = Vector2(factor, factor)
        artwork.position = Vector2(0, -21)
        artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        add_child(artwork)
    queue_redraw()

func _draw() -> void:
    draw_circle(Vector2(0,8),10.0,Color(0.01,0.03,0.05,0.35))
    if artwork != null:
        _draw_activity_mark()
        if role == "quest":
            draw_colored_polygon(PackedVector2Array([Vector2(-6,-51),Vector2(0,-57),Vector2(6,-51),Vector2(0,-45)]),Color("ffe38f"))
        return
    draw_rect(Rect2(-7,-7,6,17),tone.darkened(0.35),true)
    draw_rect(Rect2(1,-7,6,17),tone.darkened(0.36),true)
    draw_colored_polygon(PackedVector2Array([Vector2(-12,-20),Vector2(12,-20),Vector2(10,-5),Vector2(-10,-5)]),tone)
    var working: float = 0.0 if reduced_motion else sin(idle_elapsed * 2.6 + float(posmod(role.hash(), 6)))
    var lift: float = working * 6.5 if life_action in ["work", "sort_goods", "wave", "sweep"] else working * 2.0
    draw_line(Vector2(-12,-17),Vector2(-16,-7-lift),tone.lightened(0.11),5)
    draw_line(Vector2(12,-17),Vector2(16,-7+lift*0.55),tone.lightened(0.11),5)
    if role=="craft":
        # Forging hammer follows the work arm, and never changes NPC position.
        var tool_tip:=Vector2(-18,-17-lift)
        draw_line(Vector2(-16,-8-lift),tool_tip,Color("8b6f62"),3)
        draw_line(tool_tip+Vector2(-6,-2),tool_tip+Vector2(6,-2),Color("c3c8bf"),4)
    elif role=="shop":
        var wave_hand:=Vector2(-16,-7-lift)
        draw_circle(wave_hand,3.0,Color("efc7a0"))
    draw_circle(Vector2(0,-26),9.0,Color("e5b796"))
    draw_rect(Rect2(-9,-36,18,6),Color("3d4b57"),true)
    if blink_phase>0.14:
        draw_circle(Vector2(-3,-27),1.0,Color("253747"))
        draw_circle(Vector2(3,-27),1.0,Color("253747"))
    else:
        draw_line(Vector2(-5,-27),Vector2(-2,-27),Color("253747"),1)
        draw_line(Vector2(2,-27),Vector2(5,-27),Color("253747"),1)
    _draw_activity_mark()
    if role=="quest":
        # A small sash/eye variation reflects chapter and A/B state, not a
        # claim to bespoke costumes or hand-authored animation frames.
        var sash: Color = Color("78cab5") if story_route=="a" else (Color("d9b77c") if story_route=="b" else tone.lightened(0.15))
        draw_line(Vector2(-8,-18),Vector2(9,-7),sash,3)
        if story_phase=="investigate":
            draw_line(Vector2(-6,-32),Vector2(-1,-33),Color("40392e"),1.5)
            draw_line(Vector2(1,-33),Vector2(6,-32),Color("40392e"),1.5)
        elif story_phase in ["resolved","community"]:
            draw_arc(Vector2(0,-23),3.0,0.15,PI-0.15,8,Color("694c46"),1.2)
        elif story_phase=="revisit":
            draw_circle(Vector2(11,-34),3.0,Color("b4a4ff"))
        var pulse: float=0.76+0.22*(0.5+0.5*sin(idle_elapsed*3.0))
        draw_colored_polygon(PackedVector2Array([Vector2(-6,-48),Vector2(0,-54),Vector2(6,-48),Vector2(0,-42)]),Color(1.0,0.90,0.55,pulse))

func _draw_activity_mark() -> void:
    ## Tiny original drawn prop gestures; static B02 portraits are NOT relabeled as sprites.
    var rhythm: float = 0.0 if reduced_motion else sin(idle_elapsed * 3.0) * 3.0
    if life_action in ["sort_goods", "work"]:
        draw_rect(Rect2(Vector2(-19, -6 + rhythm), Vector2(7, 5)), Color("d7bd85"))
        draw_line(Vector2(-19, -4 + rhythm), Vector2(-12, -4 + rhythm), Color("87684f"), 1.0)
    elif life_action == "wave":
        draw_line(Vector2(12, -15), Vector2(16 + rhythm, -28), Color("efc6a0"), 2.0)
    elif life_action == "sweep":
        draw_line(Vector2(15, -9), Vector2(22 + rhythm, 12), Color("a07c58"), 2.0)
    elif life_action == "rest":
        draw_circle(Vector2(18, -27), 2.2, Color(0.91, 0.84, 0.73, 0.65))
    elif life_action == "talk":
        draw_arc(Vector2(15, -43), 4.0, -PI * 0.8, PI * 0.8, 10, Color("e9d7ac"), 1.5)
