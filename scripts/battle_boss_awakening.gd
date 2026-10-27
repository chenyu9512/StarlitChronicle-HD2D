extends Control
## A16 actual six-frame transparent battle overlay for boss phase transitions.
## Render-only: does not mutate health, targeting, turn queue, saves or rewards.
const SHEET: String = "res://assets/art/battle/a16/boss_awakening_6f.svg"
const Art = preload("res://scripts/c_art_overrides.gd")
const CHAPTER_SHEETS: Dictionary = {
    2: "res://assets/art/b03/boss_motion/ch002_phase_6f.svg",
    3: "res://assets/art/b03/boss_motion/ch003_phase_6f.svg",
    4: "res://assets/art/b03/boss_motion/ch004_phase_6f.svg",
    5: "res://assets/art/b03/boss_motion/ch005_phase_6f.svg",
    6: "res://assets/art/b03/boss_motion/ch006_phase_6f.svg"
}
const FRAME: int = 192
const FRAMES: int = 6
const DURATION: float = 0.96

var subject: Control
var aura: Sprite2D
var atlas: AtlasTexture
var chapter: int = 2
var reduced_motion: bool = false
var active_phase: bool = false
var elapsed: float = 0.0
var displayed_frame: int = -1
var frame_switches: int = 0
var tint: Color = Color("d4b6fb")
var selected_art_sheet: String = SHEET

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_process(true)

func configure(target: Control, boss_chapter: int, motion_reduced: bool = false) -> void:
    subject=target
    chapter=boss_chapter
    reduced_motion=motion_reduced
    var tints: Dictionary={
        2:"c8a6f4",3:"91d7f1",4:"e4b18f",5:"edc38c",6:"f4dcac"
    }
    tint=Color(str(tints.get(chapter,"edd1a6")))
    if aura!=null:
        aura.queue_free()
    aura=Sprite2D.new()
    aura.name="SixFrameBossAwakening"
    aura.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
    atlas=AtlasTexture.new()
    # Historical SVG animation sheets were removed on Main2. A single
    # redirected 48/64px third-party pose is NOT an authored 6x192 strip.
    var texture: Texture2D = Art.texture(SHEET)
    if texture != null and texture.get_size() != Vector2(FRAME * FRAMES, FRAME):
        texture = null
    selected_art_sheet = SHEET if texture != null else ""
    var authored: String = str(CHAPTER_SHEETS.get(chapter, ""))
    if not authored.is_empty():
        var candidate: Texture2D = Art.texture(authored)
        if candidate != null and candidate.get_size() == Vector2(FRAME * FRAMES, FRAME):
            texture = candidate
            selected_art_sheet = authored
    if texture!=null:
        atlas.atlas=texture
        atlas.region=Rect2(0,0,FRAME,FRAME)
        aura.texture=atlas
    aura.modulate.a=0.0
    add_child(aura)
    _follow_subject()

func _follow_subject() -> void:
    if not is_instance_valid(subject) or not is_instance_valid(aura):
        return
    aura.position=subject.position+subject.size*0.5
    # Keep actual stage coordinates synchronized with the art portrait.
    var reference: float=minf(subject.size.x,subject.size.y)
    aura.scale=Vector2.ONE*clampf(reference/220.0,0.60,1.75)

func awaken() -> void:
    if not is_instance_valid(aura) or atlas == null or atlas.atlas == null:
        return
    active_phase=true
    elapsed=0.0
    displayed_frame=-1
    frame_switches=0
    _advance(0.0)

func _advance(step: float) -> void:
    if not active_phase:
        return
    elapsed+=maxf(0.0,step)
    var progress: float=clampf(elapsed/DURATION,0.0,1.0)
    var next_frame: int=3 if reduced_motion else mini(int(progress*float(FRAMES)),FRAMES-1)
    if next_frame!=displayed_frame:
        displayed_frame=next_frame
        atlas.region=Rect2(float(next_frame*FRAME),0.0,float(FRAME),float(FRAME))
        frame_switches+=1
    var opacity: float=(1.0-progress)*0.78
    aura.modulate=Color(tint.r,tint.g,tint.b,opacity)
    if progress>=1.0:
        active_phase=false
        aura.modulate.a=0.0

func _process(delta: float) -> void:
    _follow_subject()
    _advance(clampf(delta,0.0,0.12))
