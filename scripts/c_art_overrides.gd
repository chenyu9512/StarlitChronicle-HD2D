extends RefCounted
## Non-destructive image replacement. Immutable res:// originals, device-local user:// PNG.
## No quest/save data or script execution is stored here.
const CATALOG_PATH: String = "res://data/assets/c_art_catalog.json"
const SETTINGS: String = "user://c_art_overrides.cfg"
const ASSET_DIR: String = "user://c_art_replacements"
const MAX_INPUT_BYTES: int = 24 * 1024 * 1024
const MAX_IMAGE_PIXELS: int = 32 * 1024 * 1024
static var _catalog: Dictionary = {}
static var _entries: Dictionary = {}
static var _config: ConfigFile
static var _cache: Dictionary = {}
static var _revision: int = 0

static func _load() -> void:
    if _config != null:
        return
    _config = ConfigFile.new()
    var status: Error = _config.load(SETTINGS)
    if status != OK and status != ERR_FILE_NOT_FOUND:
        push_warning("Art overrides config was unreadable; original art is preserved.")
        _config = ConfigFile.new()
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
    _catalog = raw if raw is Dictionary else {}
    for value in _catalog.get("assets", []):
        if value is Dictionary and str(value.get("path", "")).begins_with("res://assets/"):
            _entries[str(value["path"])] = value

static func list_assets() -> Array:
    _load()
    return _catalog.get("assets", []).duplicate(true)

static func categories() -> Array:
    _load()
    return _catalog.get("categories", []).duplicate()

static func info(path: String) -> Dictionary:
    _load()
    return _entries.get(path, {}).duplicate(true)

static func has_slot(path: String) -> bool:
    _load()
    return _entries.has(path)

static func has_override(path: String) -> bool:
    _load()
    return _safe_override_file(path) != ""

static func user_note(path: String) -> String:
    _load()
    if not _entries.has(path):
        return ""
    return str(_config.get_value("notes", path, ""))

static func set_note(path: String, note: String) -> bool:
    _load()
    if not _entries.has(path):
        return false
    var value: String = note.strip_edges().substr(0, 180)
    var prior: String = user_note(path)
    _config.set_value("notes", path, value)
    if _config.save(SETTINGS) != OK:
        _config.set_value("notes", path, prior)
        return false
    return true

static func _safe_override_file(path: String) -> String:
    if not _entries.has(path):
        return ""
    var file: String = str(_config.get_value("overrides", path, ""))
    if not file.begins_with(ASSET_DIR + "/") or not file.ends_with(".png"):
        return ""
    if file.contains("..") or not FileAccess.file_exists(file):
        return ""
    return file

static func original_texture(path: String) -> Texture2D:
    if not path.begins_with("res://") or not ResourceLoader.exists(path):
        return null
    return ResourceLoader.load(path) as Texture2D

static func texture(path: String) -> Texture2D:
    _load()
    if _entries.has(path):
        var saved: String = _safe_override_file(path)
        if not saved.is_empty():
            if _cache.has(path):
                return _cache[path] as Texture2D
            var image := Image.new()
            if image.load(saved) == OK and not image.is_empty():
                var replacement := ImageTexture.create_from_image(image)
                _cache[path] = replacement
                return replacement
            push_warning("Art override unreadable; original restored in this session: " + path)
    return original_texture(path)

static func exists(path: String) -> bool:
    return texture(path) != null

static func import_image(path: String, external: String) -> Dictionary:
    _load()
    if not _entries.has(path):
        return {"ok": false, "message": "该素材不在游戏资源目录中。"}
    var ext: String = external.get_extension().to_lower()
    if ext not in ["png", "jpg", "jpeg", "webp"]:
        return {"ok": false, "message": "仅支持 PNG / JPEG / WebP，不能导入脚本或 SVG。"}
    var file: FileAccess = FileAccess.open(external, FileAccess.READ)
    if file == null:
        return {"ok": false, "message": "无法读取选择的图片文件。"}
    if file.get_length() > MAX_INPUT_BYTES or file.get_length() < 16:
        file.close()
        return {"ok": false, "message": "文件大小不符合要求（最大24MB）。"}
    file.close()
    var source: Texture2D = original_texture(path)
    if source == null:
        return {"ok": false, "message": "原始贴图无法读取，本次不允许覆盖。"}
    var image := Image.new()
    var decode: Error = image.load(external)
    if decode != OK or image.is_empty():
        return {"ok": false, "message": "图片解码失败，原图保持不变。"}
    var width: int = image.get_width()
    var height: int = image.get_height()
    if width < 8 or height < 8 or width > 8192 or height > 8192 or width * height > MAX_IMAGE_PIXELS:
        return {"ok": false, "message": "图片像素尺寸超出安全范围。"}
    var original_size: Vector2i = Vector2i(source.get_size())
    if original_size.x <= 0 or original_size.y <= 0:
        return {"ok": false, "message": "原贴图尺寸异常。"}
    var entry: Dictionary = _entries[path]
    if bool(entry.get("atlas", false)):
        if Vector2i(width, height) != original_size:
            return {"ok": false, "message": "动画/图块集需保持原尺寸：%d×%d。" % [original_size.x, original_size.y]}
    elif Vector2i(width, height) != original_size:
        var original_ratio: float = float(original_size.x) / float(original_size.y)
        var new_ratio: float = float(width) / float(height)
        if absf(new_ratio / original_ratio - 1.0) > 0.12:
            return {"ok": false, "message": "图片长宽比与原图差异超过12%，请先裁剪。"}
        image.resize(original_size.x, original_size.y, Image.INTERPOLATE_LANCZOS)
    if image.get_format() != Image.FORMAT_RGBA8:
        image.convert(Image.FORMAT_RGBA8)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ASSET_DIR)) != OK:
        return {"ok": false, "message": "无法创建本机素材目录。"}
    var new_path: String = ASSET_DIR + "/" + path.sha256_text() + "_" + str(Time.get_ticks_usec()) + ".png"
    if image.save_png(new_path) != OK:
        return {"ok": false, "message": "写入新图片失败；原图不变。"}
    var old_file: String = _safe_override_file(path)
    _config.set_value("overrides", path, new_path)
    if _config.save(SETTINGS) != OK:
        if old_file.is_empty():
            _config.erase_section_key("overrides", path)
        else:
            _config.set_value("overrides", path, old_file)
        DirAccess.remove_absolute(ProjectSettings.globalize_path(new_path))
        return {"ok": false, "message": "保存替换映射失败，原配置不变。"}
    _cache.erase(path)
    _cache[path] = ImageTexture.create_from_image(image)
    _revision += 1
    if not old_file.is_empty() and old_file != new_path:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(old_file))
    return {"ok": true, "message": "替换已保存到本机，重新进入场景后全部生效。", "path": new_path}

static func restore(path: String) -> bool:
    _load()
    if not _entries.has(path):
        return false
    var file: String = _safe_override_file(path)
    if file.is_empty():
        return true
    _config.erase_section_key("overrides", path)
    if _config.save(SETTINGS) != OK:
        _config.set_value("overrides", path, file)
        return false
    _cache.erase(path)
    _revision += 1
    DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
    return true

static func revision() -> int:
    return _revision
