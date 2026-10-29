extends RefCounted
## Shared art direction for every catalog skill and the five authored First Act bosses.
## Presentation metadata only: never adjusts damage, turns, equipment or saves.
const ELEMENT_COLORS: Dictionary = {
    "光":"ffd68e", "水":"80c9f9", "雷":"f7dd84",
    "影":"bd91eb", "火":"ff9469", "风":"8bdfc2",
    "冰":"a6e6ff", "自然":"9de0a2", "圣":"fff1b9"
}
const BOSS_STYLE: Dictionary = {
    2: {"title":"雾潮寄生体", "theme":"暗潮侵蚀", "color":"af83df", "motif":"shadow"},
    3: {"title":"潮痕守卫", "theme":"古阵解放", "color":"85cefa", "motif":"tide"},
    4: {"title":"灰帷水手", "theme":"灰帷追击", "color":"e8b08b", "motif":"slash"},
    5: {"title":"缚潮古兽", "theme":"星锁震荡", "color":"efb76b", "motif":"sigil"},
    6: {"title":"潮歌守门人", "theme":"归航共鸣", "color":"ffdfaa", "motif":"halo"}
}

static func boss_style(chapter: int) -> Dictionary:
    return (BOSS_STYLE.get(chapter, {"title":"遗迹守卫","theme":"星影觉醒","color":"e8b586","motif":"sigil"}) as Dictionary).duplicate(true)

static func signature(skill: Dictionary) -> Dictionary:
    var identity: String = str(skill.get("fx_key",skill.get("id","")))
    if identity.is_empty():
        identity = str(skill.get("name","starlit"))
    var seed: int = int(identity.hash()) & 0x7fffffff
    var tier: int = clampi(int(skill.get("tier",1)),1,7)
    var element: String = str(skill.get("element","光"))
    return {
        "seed":seed, "tier":tier, "element":element,
        "color":Color(str(ELEMENT_COLORS.get(element,"ffe0b0"))),
        "rays":5+seed%8, "rings":1+int(float(seed)/7.0)%3,
        "spin":-1.0 if seed%2==0 else 1.0,
        "twist":float(seed%37)/37.0*TAU,
        "scope":clampf(0.76+float(tier)*0.09,0.8,1.45)
    }

static func skill_catalog_valid(entries: Array) -> bool:
    var unique: Dictionary = {}
    for item in entries:
        if not item is Dictionary:
            return false
        var skill: Dictionary = item
        var key: String = str(skill.get("fx_key",""))
        if key.is_empty() or unique.has(key):
            return false
        unique[key] = true
        if not ELEMENT_COLORS.has(str(skill.get("element",""))):
            return false
        if int(skill.get("tier",0)) < 1 or int(skill.get("tier",0)) > 7:
            return false
    return not entries.is_empty()
