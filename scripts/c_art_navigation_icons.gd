extends RefCounted
const RuntimeArt = preload("res://scripts/c_art_runtime.gd")
## Actual RPG menu-navigation use of the existing Owlish single-icon PNG set.
## One consistent 32px pixel-art family across all 17 real navigation tabs.
const Art = preload("res://scripts/c_art_overrides.gd")
const ROOT: String = "res://assets/art/external/cc0_named_v1/icons/owlish_icons/base/"
const TAB_ICONS: Dictionary = {
    "队伍":"brave", "背包":"pouch", "武器":"sword",
    "防具":"shield", "技能":"special", "职业":"staff",
    "任务":"scroll", "剧情后续":"letter", "地区探索":"eye",
    "图鉴":"book", "商店":"shop", "锻造":"hammer",
    "结局档案":"cosmos", "冒险履历":"quill", "存档管理":"save",
    "家园":"tent", "设置":"clock",
    "伙伴":"brave", "探索":"eye", "系统":"save", "生活":"shop",
    "退出":"cancel"
}
static var _cache: Dictionary = {}

static func icon_for(label: String) -> Texture2D:
    var key: String = label.trim_prefix("◆ ").strip_edges()
    if not TAB_ICONS.has(key):
        return null
    var filename: String = str(TAB_ICONS[key])
    if not _cache.has(filename):
        var path: String = ROOT + "icon_owlish_icons_" + filename + ".png"
        var tex: Texture2D = RuntimeArt.texture_path(path)
        if tex == null or tex.get_width() < 16 or tex.get_width() > 64 or tex.get_height() < 16 or tex.get_height() > 64:
            return null
        _cache[filename] = tex
    return _cache[filename] as Texture2D
