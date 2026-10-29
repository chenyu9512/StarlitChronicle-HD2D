extends RefCounted
## Generates a reproducible human-reviewed art prompt for a catalog entry. No art edits.
const PROFILE_PATH: String = "res://data/assets/c_visual_prompt_profiles.json"
static var _cached: Dictionary = {}
static var _initialized: bool = false

static func profiles() -> Dictionary:
    if not _initialized:
        _initialized = true
        if FileAccess.file_exists(PROFILE_PATH):
            var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
            if parsed is Dictionary:
                _cached = parsed
    return _cached

static func for_asset(entry: Dictionary) -> String:
    if entry.is_empty():
        return ""
    var data: Dictionary = profiles()
    var path: String = str(entry.get("path", ""))
    var category: String = str(entry.get("category", "其他"))
    var categories: Dictionary = data.get("categories", {})
    var targets: Dictionary = data.get("targets", {})
    var dimensions: String = "保持原素材画布尺寸和比例"
    var dims: Variant = entry.get("expected_size", [])
    if dims is Array and dims.size() >= 2 and int(dims[0]) > 0 and int(dims[1]) > 0:
        dimensions = "%d × %d px" % [int(dims[0]), int(dims[1])]
    var parts := PackedStringArray()
    parts.append("《星灯纪行》C线 · 专属美术升级提示词")
    parts.append("资源名称：" + str(entry.get("name", path.get_file())))
    parts.append("原图路径：" + path)
    parts.append("类别：" + category)
    parts.append("【统一风格】" + str(data.get("global", "")))
    parts.append("【分类规范】" + str(categories.get(category, categories.get("其他", ""))))
    if targets.has(path):
        parts.append("【专属要求】" + str(targets[path]))
    parts.append("【目标尺寸】" + dimensions)
    if bool(entry.get("atlas", false)):
        parts.append("【强制图集规则】原始尺寸、行列、方向、帧序、透明区完全一致；禁止重排任何帧。")
    elif path.ends_with(".svg"):
        parts.append("【SVG资源】保持原SVG稿不变，供本机替换时另导出同尺寸透明PNG；如需修改源稿需另行审核。")
    else:
        parts.append("【输出规范】以RGBA PNG交付；保留原素材功能、轮廓、交互范围。")
    if str(entry.get("curation_tier", "")) == "reserve_external":
        parts.append("【候选状态】该素材不等于已接入游戏；重新绘制或上架前核验授权。")
    parts.append("【排除项】" + str(data.get("negative", "")))
    parts.append("【原创性】" + str(data.get("originality", "")))
    parts.append("【验收】必须比对原图尺寸、场景截图、地图可读性、真实动作和设备性能。未通过就保留原图。")
    return "\n\n".join(parts)
