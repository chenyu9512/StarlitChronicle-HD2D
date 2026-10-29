extends RefCounted
## Branch-only third-party artwork resolver; project-created originals are not used.
## No quest/save data or script execution is stored here.

## Explicit local Pixel Fantasy presentation pack; original texture paths and
## legacy save IDs remain unchanged. Only approved, known official runtime slots.
const PIXEL_LOCAL_SWITCH: String = "res://assets/art/local_themes/pixel_fantasy_v1/active.json"
const PIXEL_LOCAL_ROOT: String = "res://assets/art/local_themes/pixel_fantasy_v1/props/"
const PIXEL_ALLOWED_FILES: Dictionary = {
    "res://assets/art/runtime/act01_global_v14/props/prop_cottage.png": "cottage.png",
    "res://assets/art/runtime/act01_global_v14/props/prop_well.png": "well.png",
    "res://assets/art/runtime/act01_global_v14/props/prop_fish_stall.png": "fish_stall.png",
    "res://assets/art/runtime/act01_global_v14/scenery/scenery_tide_lighthouse_landmark.png": "lighthouse.png",
    "res://assets/art/runtime/act01_semantic_v17/harbor_crane.png": "harbor_crane.png",
    "res://assets/art/runtime/act01_hd2d_v18/props/market-stall.png": "market_stall.png"
}

static func pixel_fantasy_texture(path: String) -> Texture2D:
    if not PIXEL_ALLOWED_FILES.has(path) or not TerrainAtlas.pixel_theme_ready():
        return null
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PIXEL_LOCAL_SWITCH))
    if not raw is Dictionary or str(raw.get("schema", "")) != "starlit.pixel_fantasy.local.v1" or not bool(raw.get("enabled", false)):
        return null
    var filename: String = str(PIXEL_ALLOWED_FILES[path])
    var candidate: String = PIXEL_LOCAL_ROOT + filename
    if not ResourceLoader.exists(candidate):
        return null
    return ResourceLoader.load(candidate) as Texture2D

const CATALOG_PATH: String = "res://data/assets/c_art_catalog.json"
const ACT01_SLOTS: String = "res://data/assets/c_act01_extra_art_slots_v10.json"
const SETTINGS: String = "user://c_art_overrides.cfg"
const ASSET_DIR: String = "user://c_art_replacements"
const PACK_INDEX: String = "res://data/assets/c_art_packs.json"
const RUNTIME_INDEX: String = "res://data/assets/c_art_runtime_registry_v1.json"
const TerrainAtlas = preload("res://scripts/world_terrain_atlas_registry.gd")
const ThemeV2 = preload("res://scripts/c_art_theme_v2.gd")
const Generated = preload("res://scripts/global_generated_art_v3.gd")
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
static var _third_party_paths: Dictionary = {}
static var _third_party_index_loaded: bool = false

static func _load() -> void:
    if _config != null:
        return
    _config = ConfigFile.new()
    var status: Error = _config.load(SETTINGS)
    if status != OK and status != ERR_FILE_NOT_FOUND:
        push_warning("Art overrides config unreadable; third-party art baseline remains.")
        _config = ConfigFile.new()
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
    _catalog = raw if raw is Dictionary else {}
    for value in _catalog.get("assets", []):
        if value is Dictionary and str(value.get("path", "")).begins_with("res://assets/"):
            _entries[str(value["path"])] = value
    # Explicit new first-act runtime art is appended without rewriting the
    # large legacy catalog or altering any existing canonical resource ID.
    if FileAccess.file_exists(ACT01_SLOTS):
        var extension: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACT01_SLOTS))
        if extension is Dictionary:
            for value in extension.get("assets", []):
                if not value is Dictionary:
                    continue
                var path: String = str(value.get("path", ""))
                if not path.begins_with("res://assets/art/") or path.contains("..") or _entries.has(path):
                    continue
                if not ResourceLoader.exists(path):
                    continue
                _entries[path] = value
                (_catalog["assets"] as Array).append(value)
            _catalog["count"] = (_catalog["assets"] as Array).size()
    # Approved migration targets may come from the tiny legacy assets/props/
    # tree, which was not guaranteed to be present in the large art gallery.
    # Register ONLY the six reviewed slots; never auto-publish arbitrary paths.
    _ensure_later_uploaded_slots()
    _read_pack_index(PACK_INDEX)
    _read_pack_index(USER_PACK_INDEX)
    # Later uploaded user art is the default for fresh installations.
    # An explicitly chosen local theme remains untouched.
    _active_pack_id = str(_config.get_value("packs", "active", "original"))
    if _active_pack_id != "original" and (not _packs.has(_active_pack_id) or bool((_packs.get(_active_pack_id, {}) as Dictionary).get("disabled", false))):
        _active_pack_id = "original"
        _config.set_value("packs", "active", "original")
        _config.save(SETTINGS)

## Confirmed legacy targets for the first later-uploaded prop migration.
## These are catalog slots, not new art or a request to mutate original files.
static func _ensure_later_uploaded_slots() -> void:
    var approved: Array[String] = [
        "res://assets/art/props/coast/rock.png",
        "res://assets/art/props/coast/well.png",
        "res://assets/art/props/coast/barrel.png",
        "res://assets/art/props/coast/star_lantern.png",
        "res://assets/props/well.png",
        "res://assets/props/lamp.png",
    ]
    for target in approved:
        if _entries.has(target):
            continue
        var original: Texture2D = original_texture(target)
        if original == null:
            push_warning("Approved later-upload slot has no runtime baseline: " + target)
            continue
        var record: Dictionary = {
            "path": target,
            "name": target.get_file().get_basename(),
            "category": "环境道具",
            "atlas": false,
            "description": "后期上传素材替换入口（旧纹理仅作兼容回退）",
            "status": "uploaded_migration_pending_godot_qa"
        }
        _entries[target] = record
        if _catalog.has("assets") and _catalog["assets"] is Array:
            (_catalog["assets"] as Array).append(record)
    if _catalog.has("assets") and _catalog["assets"] is Array:
        _catalog["count"] = (_catalog["assets"] as Array).size()

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

## Branch-only redirect. Original visual contents have been removed; even
## historical res:// art slot names resolve to later uploaded third-party PNG.
## Shared-terrain DLC slots accept sources that need 32px semantic re-atlasing
## by WorldTilesetPool. Raw source dimensions are not the final 256px atlas.
static func _shared_terrain_slot(path: String) -> bool:
    return TerrainAtlas.group_slots("terrain_ground").has(path) or TerrainAtlas.group_slots("terrain_water").has(path)

## Only reviewed object-for-object redirects are used at runtime.
## Historical bulk migration rows are evidence, NOT permission to map a palm
## to cherry blossoms or a portrait to an unrelated idle NPC frame.
static func third_party_source(path: String) -> String:
    if not _third_party_index_loaded:
        _third_party_index_loaded = true
        if FileAccess.file_exists(RUNTIME_INDEX):
            var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUNTIME_INDEX))
            if raw is Dictionary and str(raw.get("schema", "")) == "starlit.c.art_runtime_registry.v1":
                var approved: Dictionary = raw.get("verified_legacy_redirects", {})
                for old_path in approved.keys():
                    var target: String = str(approved[old_path])
                    if str(old_path).begins_with("res://assets/") and not str(old_path).contains("..") and target.begins_with("res://assets/art/external/cc0_named_v1/") and not target.contains(".."):
                        _third_party_paths[str(old_path)] = target
    return str(_third_party_paths.get(path, path))

static func original_texture(path: String) -> Texture2D:
    var replacement: Texture2D = Generated.legacy_texture(path)
    if replacement != null:
        return replacement
    # Direct physically present canonical files outrank any legacy redirect.
    var resolved: String = path if ResourceLoader.exists(path) else third_party_source(path)
    if not resolved.begins_with("res://") or not ResourceLoader.exists(resolved):
        return null
    return ResourceLoader.load(resolved) as Texture2D

static func texture(path: String) -> Texture2D:
    var replacement: Texture2D = Generated.legacy_texture(path)
    if replacement != null:
        return replacement
    _load()
    # Candidate source filename is NOT an approved combat boss identity.
    if path.begins_with("res://assets/art/runtime/act01_global_v14/boss_candidates/"):
        return null
    var pixel_fantasy: Texture2D = pixel_fantasy_texture(path)
    if pixel_fantasy != null:
        return pixel_fantasy
    if ThemeV2.is_active():
        var selected: Texture2D = ThemeV2.texture_for_path(path)
        if selected != null:
            return selected
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
        # Curated V2 semantic theme is a complete presentation layer. Do not
        # mix it with legacy per-path DLC; personal overrides above stay first.
        var selected_theme: Texture2D = ThemeV2.texture_for_path(path)
        if selected_theme != null:
            return selected_theme
        if not ThemeV2.is_active() and _active_pack_id != "original" and _packs.has(_active_pack_id):
            var mappings: Dictionary = _packs[_active_pack_id].get("mappings", {})
            if mappings.has(path):
                if _cache.has(path):
                    return _cache[path] as Texture2D
                var candidate: String = str(mappings[path])
                var proposed: Texture2D = null
                if candidate.begins_with("res://assets/art/") and candidate != path and candidate == third_party_source(path):
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
                    if (actual == expected if bool(slot.get("atlas", false)) else ratio_ok) or (_active_pack_id == "shared_terrain" and _shared_terrain_slot(path) and actual.x >= 32 and actual.y >= 32) or (_active_pack_id.begins_with("user_") and _shared_terrain_slot(path) and actual == Vector2i(256,256)):
                        # This batch contains 32px user-uploaded pixel props mapped
                        # onto some historical 96px Sprite2D slots. Scale the image
                        # itself with nearest-neighbor sampling: never alter geometry,
                        # collisions, animation atlases, or any other DLC pack.
                        if _active_pack_id == "uploaded_later_v1" and not bool(slot.get("atlas", false)) and actual != expected:
                            var sampled: Image = proposed.get_image()
                            if sampled != null and not sampled.is_empty():
                                sampled.resize(expected.x, expected.y, Image.INTERPOLATE_NEAREST)
                                proposed = ImageTexture.create_from_image(sampled)
                        _cache[path] = proposed
                        if candidate.begins_with(PACK_ROOT + "/"):
                            _shared_pack_images[candidate] = proposed
                        return proposed
    # The first-act semantic manifest includes actual runtime files absent
    # from the old asset-gallery catalog. These must route through V2 too;
    # otherwise changing the global theme silently leaves default pixels.
    # Registered slots already handled personal overrides and V2 above.
    if ThemeV2.is_active() and not _entries.has(path):
        var runtime_theme_texture: Texture2D = ThemeV2.texture_for_path(path)
        if runtime_theme_texture != null:
            return runtime_theme_texture
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
    return _revision + ThemeV2.revision()

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
        var quarantined: bool = location == PACK_INDEX and bool(entry.get("disabled",false))
        var accepted: Dictionary = {}
        for map in entry.get("mappings", []):
            if not map is Dictionary:
                continue
            var target: String = str(map.get("target", ""))
            var source: String = str(map.get("source", ""))
            if not _entries.has(target):
                continue
            # Main2 intentionally removed canonical original PNGs, but the
            # DLC may reference those historical slot names. Accept sources
            # when their third-party migration physically resolves instead
            # of silently dropping the whole terrain theme.
            if source.begins_with("res://assets/art/") and original_texture(source) != null:
                accepted[target] = source
            elif location == USER_PACK_INDEX and source.begins_with(PACK_ROOT + "/") and not source.contains("..") and FileAccess.file_exists(source):
                accepted[target] = source
        if not accepted.is_empty() or quarantined:
            _packs[id] = {
                "id": id,
                "name": str(entry.get("name", id)).substr(0, 60),
                "mappings": accepted,
                "user_pack": location == USER_PACK_INDEX,
                "disabled": quarantined,
                "disabled_reason": str(entry.get("disabled_reason","")) if quarantined else ""
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
            "user_pack": bool(pack.get("user_pack", false)),
            "disabled": bool(pack.get("disabled",false)),
            "disabled_reason": str(pack.get("disabled_reason",""))})
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
    if bool((_packs[id] as Dictionary).get("disabled",false)):
        return {"ok":false,"id":id,"usable":0,"fallback":0,
            "message":str(_packs[id].get("disabled_reason","素材语义错配已隔离。"))}
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
        if (match_size if atlas else ratio_ok) or (id == "shared_terrain" and _shared_terrain_slot(slot) and actual.x >= 32 and actual.y >= 32) or (id.begins_with("user_") and _shared_terrain_slot(slot) and actual == Vector2i(256,256)):
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
    return _active_pack_id != "original" and _packs.has(_active_pack_id) and not bool((_packs[_active_pack_id] as Dictionary).get("disabled",false)) and (_packs[_active_pack_id].get("mappings", {}) as Dictionary).has(path)

static func activate_pack(id: String) -> bool:
    _load()
    if id != "original" and not _packs.has(id):
        return false
    if id != "original" and bool((_packs[id] as Dictionary).get("disabled",false)):
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
    var shared_dimensions: Dictionary = {}
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
        # A terrain family expands into 10-11 targets but references one PNG.
        # Validate each target's atlas size without decoding that PNG again.
        if bool(row.get("_shared", false)) and shared_saved.has(relative):
            # Group slots are logical 8x8 terrain atlases. The migrated
            # baseline can be a 32/48px external source PNG, while a user's
            # complete two-image DLC must already be genuine 256x256 atlases.
            # Do not compare the new shared atlas to a deleted old file size.
            if not _shared_terrain_slot(target) or shared_dimensions[relative] != Vector2i(256,256):
                _rollback_dlc_files(installed)
                return {"ok": false, "message": "共享图集必须为256×256：" + target}
            mappings.append({"target": target, "source": str(shared_saved[relative])})
            seen[target] = true
            continue
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
        var terrain_family: bool = bool(row.get("_shared", false))
        if terrain_family and (not _shared_terrain_slot(target) or dimensions != Vector2i(256,256)):
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "地形组DLC要求256×256八乘八图集：" + target}
        if not terrain_family and bool((_entries[target] as Dictionary).get("atlas", false)) and dimensions != original_size:
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "图集必须保持原尺寸：" + target}
        if not terrain_family and dimensions != original_size:
            var ratio: float = float(dimensions.x) / float(dimensions.y) / (float(original_size.x) / float(original_size.y))
            if absf(ratio - 1.0) > 0.12:
                _rollback_dlc_files(installed)
                return {"ok": false, "message": "图片比例不匹配：" + target}
            image.resize(original_size.x, original_size.y, Image.INTERPOLATE_LANCZOS)
        if image.get_format() != Image.FORMAT_RGBA8:
            image.convert(Image.FORMAT_RGBA8)
        var is_shared: bool = bool(row.get("_shared", false))
        var destination: String = folder + "/" + (relative.sha256_text() if is_shared else target.sha256_text()) + ".png"
        # Shared groups save and decode once; all other target IDs have unique PNGs.
        if image.save_png(destination) != OK:
            _rollback_dlc_files(installed)
            return {"ok": false, "message": "DLC图片保存失败。"}
        installed.append(destination)
        if is_shared:
            shared_saved[relative] = destination
            shared_dimensions[relative] = dimensions
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
