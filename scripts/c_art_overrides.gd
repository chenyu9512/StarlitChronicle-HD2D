extends RefCounted
## Non-destructive image replacement. Immutable res:// originals, device-local user:// PNG.
## No quest/save data or script execution is stored here.
const CATALOG_PATH: String = "res://data/assets/c_art_catalog.json"
const SETTINGS: String = "user://c_art_overrides.cfg"
const ASSET_DIR: String = "user://c_art_replacements"
const PACK_INDEX: String = "res://data/assets/c_art_packs.json"
const TerrainAtlas = preload("res://scripts/world_terrain_atlas_registry.gd")
const USER_PACK_INDEX: String = "user://c_art_packs/installed.json"
const PACK_ROOT: String = "user://c_art_packs"
const MAX_INPUT_BYTES: int = 24 * 1024 * 1024
const MAX_IMAGE_PIXELS: int = 32 * 1024 * 1024
static var _catalog: Dictionary = {}
static var _entries: Dictionary = {}
static var _config: ConfigFile
static var _cache: Dictionary = {}
## Many regional targets can resolve to one imported image. Reuse the exact Texture2D.
static var _shared_pack_images: Dictionary = {}
static var _revision: int = 0
static var _packs: Dictionary = {}
static var _active_pack_id: String = "original"

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
    _read_pack_index(PACK_INDEX)
    _read_pack_index(USER_PACK_INDEX)
    _active_pack_id = str(_config.get_value("packs", "active", "original"))
    if _active_pack_id != "original" and not _packs.has(_active_pack_id):
        _active_pack_id = "original"

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
        if _active_pack_id != "original" and _packs.has(_active_pack_id):
            var mappings: Dictionary = _packs[_active_pack_id].get("mappings", {})
            if mappings.has(path):
                if _cache.has(path):
                    return _cache[path] as Texture2D
                var candidate: String = str(mappings[path])
                var proposed: Texture2D = null
                if candidate.begins_with("res://assets/art/"):
                    proposed = original_texture(candidate)
                elif candidate.begins_with(PACK_ROOT + "/") and not candidate.contains(".."):
                    if _shared_pack_images.has(candidate):
                        proposed = _shared_pack_images[candidate] as Texture2D
                    else:
                        var image := Image.new()
                        if image.load(candidate) == OK and not image.is_empty():
                            proposed = ImageTexture.create_from_image(image)
                var baseline: Texture2D = original_texture(path)
                if proposed != null and baseline != null:
                    var expected: Vector2i = Vector2i(baseline.get_size())
                    var actual: Vector2i = Vector2i(proposed.get_size())
                    var slot: Dictionary = _entries[path]
                    var ratio_ok: bool = expected.y > 0 and actual.y > 0 and absf(float(actual.x) / float(actual.y) / (float(expected.x) / float(expected.y)) - 1.0) <= 0.12
                    if (actual == expected if bool(slot.get("atlas", false)) else ratio_ok):
                        _cache[path] = proposed
                        if candidate.begins_with(PACK_ROOT + "/"):
                            _shared_pack_images[candidate] = proposed
                        return proposed
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
    var previous: String = str(_config.get_value("overrides", path, ""))
    if previous.is_empty():
        return true
    var file: String = _safe_override_file(path)
    _config.erase_section_key("overrides", path)
    if _config.save(SETTINGS) != OK:
        _config.set_value("overrides", path, previous)
        return false
    _cache.erase(path)
    _revision += 1
    if not file.is_empty():
        DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
    return true

static func revision() -> int:
    return _revision

## DLC theme packs are path mappings over canonical runtime art slots.
## The original files are never overwritten, and no scripts can be loaded.
static func _read_pack_index(location: String) -> void:
    if not FileAccess.file_exists(location):
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(location))
    if not raw is Dictionary:
        return
    for entry in raw.get("packs", []):
        if not entry is Dictionary:
            continue
        var id: String = str(entry.get("id", ""))
        if id.is_empty() or id == "original" or id.contains("/") or id.contains(".."):
            continue
        var accepted: Dictionary = {}
        for map in entry.get("mappings", []):
            if not map is Dictionary:
                continue
            var target: String = str(map.get("target", ""))
            var source: String = str(map.get("source", ""))
            if not _entries.has(target):
                continue
            if source.begins_with("res://assets/art/") and ResourceLoader.exists(source):
                accepted[target] = source
            elif location == USER_PACK_INDEX and source.begins_with(PACK_ROOT + "/") and not source.contains("..") and FileAccess.file_exists(source):
                accepted[target] = source
        if not accepted.is_empty():
            _packs[id] = {
                "id": id,
                "name": str(entry.get("name", id)).substr(0, 60),
                "mappings": accepted,
                "user_pack": location == USER_PACK_INDEX
            }

static func list_packs() -> Array[Dictionary]:
    _load()
    var result: Array[Dictionary] = [{"id": "original", "name": "游戏原版", "count": 0, "user_pack": false}]
    var ids: Array = _packs.keys()
    ids.sort()
    for id in ids:
        var pack: Dictionary = _packs[id]
        result.append({"id": str(id), "name": str(pack.get("name", id)),
            "count": (pack.get("mappings", {}) as Dictionary).size(),
            "user_pack": bool(pack.get("user_pack", false))})
    return result


## Inspect a complete DLC before applying it. Returns effective/invalid slot counts.
## A missing or dimension-incompatible image falls back to the immutable original.
static func pack_report(id: String) -> Dictionary:
    _load()
    if id == "original":
        return {"ok": true, "id": id, "mapped": 0, "usable": 0,
            "fallback": 0, "personal_overrides": 0, "catalog_slots": _entries.size()}
    if not _packs.has(id):
        return {"ok": false, "id": id, "message": "主题包不存在。"}
    var mappings: Dictionary = _packs[id].get("mappings", {})
    var usable: int = 0
    var fallback: int = 0
    var personal: int = 0
    for target in mappings.keys():
        var slot: String = str(target)
        var baseline: Texture2D = original_texture(slot)
        if baseline == null or not _entries.has(slot):
            fallback += 1
            continue
        var source: String = str(mappings[target])
        var proposed: Texture2D = null
        if source.begins_with("res://assets/art/"):
            proposed = original_texture(source)
        elif source.begins_with(PACK_ROOT + "/") and not source.contains(".."):
            var image := Image.new()
            if image.load(source) == OK and not image.is_empty():
                proposed = ImageTexture.create_from_image(image)
        if proposed == null:
            fallback += 1
            continue
        var expected: Vector2i = Vector2i(baseline.get_size())
        var actual: Vector2i = Vector2i(proposed.get_size())
        if expected.x < 1 or expected.y < 1 or actual.x < 1 or actual.y < 1:
            fallback += 1
            continue
        var atlas: bool = bool((_entries[slot] as Dictionary).get("atlas", false))
        var match_size: bool = actual == expected
        var ratio_ok: bool = absf(float(actual.x) * float(expected.y) / (float(actual.y) * float(expected.x)) - 1.0) <= 0.12
        if (match_size if atlas else ratio_ok):
            usable += 1
            if has_override(slot):
                personal += 1
        else:
            fallback += 1
    return {"ok": true, "id": id, "mapped": mappings.size(), "usable": usable,
        "fallback": fallback, "personal_overrides": personal, "catalog_slots": _entries.size()}

static func active_pack() -> String:
    _load()
    return _active_pack_id

static func pack_has_slot(path: String) -> bool:
    _load()
    return _active_pack_id != "original" and _packs.has(_active_pack_id) and (_packs[_active_pack_id].get("mappings", {}) as Dictionary).has(path)

static func activate_pack(id: String) -> bool:
    _load()
    if id != "original" and not _packs.has(id):
        return false
    if id == _active_pack_id:
        return true
    var before: String = _active_pack_id
    _config.set_value("packs", "active", id)
    if _config.save(SETTINGS) != OK:
        _config.set_value("packs", "active", before)
        return false
    _active_pack_id = id
    _cache.clear()
    _shared_pack_images.clear()
    _revision += 1
    return true

## Installs one local DLC JSON manifest. It names existing runtime target slots
## and relative PNG/JPEG/WebP images in the same directory; all images are
## validated and copied into user:// before the pack becomes selectable.
## Format: {"id":"my_pack","name":"...","mappings":[{"target":"res://assets/art/...","file":"images/a.png"}]}
static func install_pack(manifest_file: String) -> Dictionary:
    _load()
    if manifest_file.get_extension().to_lower() != "json":
        return {"ok": false, "message": "请选择DLC素材包的JSON清单。"}
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_file))
    if not raw is Dictionary:
        return {"ok": false, "message": "DLC JSON无效。"}
    var external_id: String = str(raw.get("id", ""))
    if external_id.is_empty() or external_id.length() > 48:
        return {"ok": false, "message": "DLC包ID不能为空且最多48字符。"}
    for character in external_id:
        if not (character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-"):
            return {"ok": false, "message": "DLC包ID只能包含字母、数字、下划线和横线。"}
    var id: String = "user_" + external_id
    if _packs.has(id):
        return {"ok": false, "message": "已有相同DLC，请使用新的版本ID。"}
    var rows: Array = raw.get("mappings", [])
    if rows.is_empty() or rows.size() > 2048:
        return {"ok": false, "message": "DLC必须含1～2048条贴图映射。"}
    # A single 256x256 image can be assigned to all region-equivalent terrain
    # slots. Do not let a malformed group silently replace arbitrary assets.
    var expanded: Array = []
    for row in rows:
        if not row is Dictionary:
            return {"ok": false, "message": "映射行不是对象。"}
        var group_id: String = str(row.get("group", ""))
        if group_id.is_empty():
            expanded.append(row)
            continue
        if row.has("target"):
            return {"ok": false, "message": "地形分组映射不能同时指定target。"}
        var group_slots: Array[String] = TerrainAtlas.group_slots(group_id)
        if group_slots.is_empty():
            return {"ok": false, "message": "不存在的地形分组：" + group_id}
        for slot in group_slots:
            expanded.append({"target": slot, "file": str(row.get("file", "")), "_shared": true})
        if expanded.size() > 2048:
            return {"ok": false, "message": "DLC展开后超过2048个贴图槽位。"}
    var folder: String = PACK_ROOT + "/" + id
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
        return {"ok": false, "message": "无法创建DLC本地目录。"}
    var installed: Array = []
    var mappings: Array = []
    var seen: Dictionary = {}
    var shared_saved: Dictionary = {}
    for row in expanded:
        if not row is Dictionary:
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "映射行不是对象。"}
        var target: String = str(row.get("target", ""))
        var relative: String = str(row.get("file", "")).replace("\\", "/")
        if not _entries.has(target) or seen.has(target):
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "资源ID不存在或重复：" + target}
        if relative.is_empty() or relative.begins_with("/") or relative.contains("..") or relative.contains(":"):
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "DLC图片路径不安全。"}
        if relative.get_extension().to_lower() not in ["png", "jpg", "jpeg", "webp"]:
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "DLC只允许图片文件。"}
        var source_file: String = manifest_file.get_base_dir().path_join(relative)
        var file: FileAccess = FileAccess.open(source_file, FileAccess.READ)
        if file == null or file.get_length() < 16 or file.get_length() > MAX_INPUT_BYTES:
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "图片丢失或大小不合法：" + relative}
        file.close()
        var image := Image.new()
        if image.load(source_file) != OK or image.is_empty():
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "图片解码失败：" + relative}
        var dimensions: Vector2i = Vector2i(image.get_width(), image.get_height())
        if dimensions.x < 8 or dimensions.y < 8 or dimensions.x > 8192 or dimensions.y > 8192 or dimensions.x * dimensions.y > MAX_IMAGE_PIXELS:
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "图片尺寸非法：" + relative}
        var reference: Texture2D = original_texture(target)
        if reference == null:
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "原图不可读取：" + target}
        var original_size: Vector2i = Vector2i(reference.get_size())
        if (bool((_entries[target] as Dictionary).get("atlas", false)) or bool(row.get("_shared", false))) and dimensions != original_size:
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "图集必须保持原尺寸：" + target}
        if dimensions != original_size:
            var ratio: float = float(dimensions.x) / float(dimensions.y) / (float(original_size.x) / float(original_size.y))
            if absf(ratio - 1.0) > 0.12:
                _rollback_dlc_files(installed)
                return {"ok": false, "message": "图片比例不匹配：" + target}
            image.resize(original_size.x, original_size.y, Image.INTERPOLATE_LANCZOS)
        if image.get_format() != Image.FORMAT_RGBA8:
            image.convert(Image.FORMAT_RGBA8)
        var is_shared: bool = bool(row.get("_shared", false))
        var destination: String = folder + "/" + (relative.sha256_text() if is_shared else target.sha256_text()) + ".png"
        # Save an expanded terrain family image only once, not 8-11 duplicates.
        if not (is_shared and shared_saved.has(relative)):
            if image.save_png(destination) != OK:
                _rollback_dlc_files(installed)
                return {"ok": false, "message": "DLC图片保存失败。"}
            installed.append(destination)
            if is_shared:
                shared_saved[relative] = destination
        else:
            destination = str(shared_saved[relative])
        mappings.append({"target": target, "source": destination})
        seen[target] = true
    var saved: Array = []
    for item in _packs.values():
        if not bool(item.get("user_pack", false)):
            continue
        var paths: Array = []
        for slot in item.get("mappings", {}).keys():
            paths.append({"target": slot, "source": item["mappings"][slot]})
        saved.append({"id": item["id"], "name": item["name"], "mappings": paths})
    saved.append({"id": id, "name": str(raw.get("name", external_id)).substr(0, 60), "mappings": mappings})
    var index: FileAccess = FileAccess.open(USER_PACK_INDEX, FileAccess.WRITE)
    if index == null:
        _rollback_dlc_files(installed)
        return {"ok": false, "message": "DLC索引保存失败。"}
    index.store_string(JSON.stringify({"schema":"starlit.c.userpacks.v1","packs":saved}, "  "))
    index.close()
    var lookup: Dictionary = {}
    for row in mappings:
        lookup[str(row["target"])] = str(row["source"])
    _packs[id] = {"id": id, "name": str(raw.get("name", external_id)).substr(0, 60),
        "mappings": lookup, "user_pack": true}
    return {"ok": true, "message": "DLC导入成功，可在主题包列表一键启用。", "pack_id": id, "count": lookup.size()}

static func _rollback_dlc_files(paths: Array) -> void:
    for path in paths:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))

## Remove an installed user DLC (never removes an original or built-in pack).
## Keep the disk manifest authoritative so deactivated packs do not reload.
static func uninstall_pack(id: String) -> bool:
    _load()
    if not _packs.has(id) or not bool(_packs[id].get("user_pack", false)):
        return false
    var was_active: bool = _active_pack_id == id
    if was_active and not activate_pack("original"):
        return false
    var retained: Array = []
    for pack_id in _packs.keys():
        var pack: Dictionary = _packs[pack_id]
        if not bool(pack.get("user_pack", false)) or str(pack_id) == id:
            continue
        var replacements: Array = []
        for target in pack.get("mappings", {}).keys():
            replacements.append({"target": str(target), "source": str(pack["mappings"][target])})
        retained.append({"id": str(pack_id), "name": str(pack.get("name", pack_id)), "mappings": replacements})
    var previous: String = FileAccess.get_file_as_string(USER_PACK_INDEX)
    var file: FileAccess = FileAccess.open(USER_PACK_INDEX, FileAccess.WRITE)
    if file == null:
        if was_active:
            activate_pack(id)
        return false
    file.store_string(JSON.stringify({"schema": "starlit.c.userpacks.v1", "packs": retained}, "  "))
    file.close()
    var folder: String = PACK_ROOT + "/" + id
    for target in _packs[id].get("mappings", {}).keys():
        var source: String = str(_packs[id]["mappings"][target])
        if source.begins_with(folder + "/") and not source.contains(".."):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(source))
    _packs.erase(id)
    _cache.clear()
    _shared_pack_images.clear()
    _revision += 1
    return true

## Restores every runtime slot to the shipped original artwork in one action.
## Notes and installed DLCs remain available. The current savegame is untouched.
static func restore_everything() -> bool:
    _load()
    var previous_pack: String = _active_pack_id
    var saved: Dictionary = {}
    if _config.has_section("overrides"):
        for target in _config.get_section_keys("overrides"):
            saved[str(target)] = str(_config.get_value("overrides", target, ""))
        _config.erase_section("overrides")
    _config.set_value("packs", "active", "original")
    if _config.save(SETTINGS) != OK:
        _config.set_value("packs", "active", previous_pack)
        for target in saved.keys():
            _config.set_value("overrides", target, saved[target])
        return false
    _active_pack_id = "original"
    _cache.clear()
    _shared_pack_images.clear()
    _revision += 1
    for path in saved.values():
        var location: String = str(path)
        if location.begins_with(ASSET_DIR + "/") and not location.contains(".."):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(location))
    return true
