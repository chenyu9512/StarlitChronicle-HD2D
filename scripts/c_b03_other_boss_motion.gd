extends "res://scripts/c_b03_fog_tide_body_motion.gd"
## C2.3b: all four separate B03 bosses share tested state timing and scene handoff,
## but each has its own chapter-unique high-resolution source and new SVG art.
## No character swap, no damage/loot/save changes.
const STYLES: Dictionary = {
    3: {"name":"TidemarkSentinelArt", "tint":"b3e1ec"},
    4: {"name":"AshveilSailorArt", "tint":"efc4b2"},
    5: {"name":"BoundTideBeastRelease", "tint":"f3d29d"},
    6: {"name":"TidesongGatekeeperArt", "tint":"d1e8d9"}
}
const SHARED_SHADER: String = "res://assets/shaders/c23_b03_chapter_body_warp.gdshader"

func configure(target: TextureRect, chapter: int, motion_reduced: bool = false) -> bool:
    if not STYLES.has(chapter):
        return false
    permitted_chapter = chapter
    art_directory = "res://assets/art/b03/boss_motion/c23_ch%03d/" % chapter
    shader_path = SHARED_SHADER
    effect_label = str((STYLES[chapter] as Dictionary).get("name", "C23ChapterArt"))
    if not super.configure(target,chapter,motion_reduced):
        return false
    shader_material.set_shader_parameter("chapter_style",chapter)
    if is_instance_valid(effect):
        var tint: Color = Color(str((STYLES[chapter] as Dictionary).get("tint","ffffff")))
        effect.modulate = Color(tint.r,tint.g,tint.b,effect.modulate.a)
    return true
