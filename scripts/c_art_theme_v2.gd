@tool
extends RefCounted
## Semantic-first, content-locked art theme resolver. Never touches save games or map cells.
const MANIFEST: String = "res://data/assets/art_theme_v2.json"
const SETTINGS: String = "user://c_art_theme_v2.cfg"
const USER_ROOT: String = "user://c_art_theme_v2"
const USER_INDEX: String = "user://c_art_theme_v2/installed.json"
const MAX_IMPORT_BYTES: int = 24 * 1024 * 1024
static var _loaded: bool = false
static var _themes: Dictionary = {}
static var _config: ConfigFile
static var _active: String = "original"
static var _revision: int = 0
static var _by_path: Dictionary = {}
static var _baseline: Dictionary = {}
static var _cache: Dictionary = {}

static func _ensure() -> void:
    if _loaded:
        return
    _loaded = true
    _config = ConfigFile.new()
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    if raw is Dictionary and str(raw.get("schema", "")) == "starlit.art_theme.v2":
        for item in raw.get("themes", []):
            if not item is Dictionary:
                continue
            var id: String = str(item.get("id", ""))
            if id.is_empty() or _themes.has(id):
                continue
            _themes[id] = item
    _baseline = _themes.get("starlit_hd2d_act01", {})
    # Installed bundles contain images only. Their IDs are completely separate
    # from built-in theme IDs and never execute scripts or rewrite res:// files.
    if FileAccess.file_exists(USER_INDEX):
        var installed: Variant = JSON.parse_string(FileAccess.get_file_as_string(USER_INDEX))
        if installed is Dictionary and str(installed.get("schema", "")) == "starlit.art_theme.installed.v2":
            for item in installed.get("themes", []):
                if not item is Dictionary:
                    continue
                var id: String = str(item.get("id", ""))
                if id.begins_with("user_") and not _themes.has(id):
                    _themes[id] = item
    _config.load(SETTINGS)
    _active = str(_config.get_value("theme", "active", "original"))
    if _active != "original" and not _themes.has(_active):
        _active = "original"
    # Installed legacy full packs may have fewer slots after the official
    # contract gains new visible art. Never silently mix old DLC with new props.
    if _active.begins_with("user_"):
        var expected_slots: Dictionary = _baseline.get("slots", {})
        var selected_slots: Dictionary = (_themes[_active] as Dictionary).get("slots", {})
        if selected_slots.size() != expected_slots.size():
            _active = "original"
            _config.set_value("theme", "active", "original")
            _config.save(SETTINGS)
        else:
            for key in expected_slots.keys():
                if not selected_slots.has(key):
                    _active = "original"
                    _config.set_value("theme", "active", "original")
                    _config.save(SETTINGS)
                    break
    _reindex()
    # An installed full theme can become incomplete between launches (deleted
    # images, changed atlas dimensions, or a corrupt user directory). Reject
    # the entire pack before the first scene is rendered, not one prop at a time.
    if _active.begins_with("user_") and not bool(report(_active).get("ok", false)):
        _rollback_invalid_user_theme("installed DLC failed startup preflight")

static func _rollback_invalid_user_theme(reason: String) -> void:
    if not _active.begins_with("user_"):
        return
    var previous: String = _active
    _active = "original"
    _cache.clear()
    _revision += 1
    _config.set_value("theme", "active", "original")
    if _config.save(SETTINGS) != OK:
        push_warning("V2 DLC rollback could not persist original theme selection")
    push_warning("V2 DLC " + previous + " disabled: " + reason)

static func _reindex() -> void:
    _by_path.clear()
    # Map official canonical runtime URLs to semantic IDs even while a user
    # bundle is active; this redirects the existing scene loaders correctly.
    var slots: Dictionary = _baseline.get("slots", {})
    for key in slots.keys():
        var entry: Dictionary = slots[key]
        var p: String = str(entry.get("source", ""))
        if p.begins_with("res://assets/art/runtime/") and not p.contains(".."):
            _by_path[p] = str(key)

static func list_themes() -> Array[Dictionary]:
    _ensure()
    var result: Array[Dictionary] = [{"id":"original","name":"原始兼容美术","state":"baseline"}]
    for key in _themes.keys():
        var item: Dictionary = _themes[key]
        result.append({"id":str(key),"name":str(item.get("name", key)),"state":str(item.get("state","unreviewed"))})
    return result

## Read-only entries from the ONLY authoritative V2 semantic registry.
static func list_slots() -> Array[Dictionary]:
    _ensure()
    var rows: Array[Dictionary] = []
    var slots: Dictionary = _baseline.get("slots", {})
    var keys: Array = slots.keys()
    keys.sort()
    for key in keys:
        var slot: Dictionary = slots[key]
        rows.append({"id": str(key), "source": str(slot.get("source", "")),
            "category": str(slot.get("category", "unknown")),
            "stage": str(slot.get("stage", "unreviewed")),
            "required": bool(slot.get("required", false))})
    return rows

static func active_id() -> String:
    _ensure()
    return _active

static func is_active() -> bool:
    return active_id() != "original"

static func revision() -> int:
    _ensure()
    return _revision

static func slot_entry(slot_id: String) -> Dictionary:
    _ensure()
    if not _themes.has(_active):
        return {}
    var theme: Dictionary = _themes[_active]
    var aliases: Dictionary = theme.get("aliases", {})
    var target: String = str(aliases.get(slot_id, slot_id))
    return (theme.get("slots", {}) as Dictionary).get(target, {})

static func source_for(slot_id: String) -> String:
    var entry: Dictionary = slot_entry(slot_id)
    var p: String = str(entry.get("source", ""))
    return p if (p.begins_with("res://assets/art/runtime/") or p.begins_with(USER_ROOT + "/user_")) and not p.contains("..") else ""

static func _valid_texture(path: String) -> Texture2D:
    if path.is_empty():
        return null
    if path.begins_with(USER_ROOT + "/user_") and not path.contains(".."):
        var pixels := Image.new()
        if pixels.load(path) != OK or pixels.is_empty():
            return null
        return ImageTexture.create_from_image(pixels)
    if not ResourceLoader.exists(path):
        return null
    return ResourceLoader.load(path) as Texture2D

static func texture(slot_id: String) -> Texture2D:
    _ensure()
    var path: String = source_for(slot_id)
    if path.is_empty():
        return null
    if _cache.has(path):
        return _cache[path] as Texture2D
    var result: Texture2D = _valid_texture(path)
    if _active.begins_with("user_"):
        # Validate on access too: files may be removed or replaced while the
        # game is open. An invalid atlas must never silently mix two themes.
        var active_theme: Dictionary = _themes.get(_active, {})
        var aliases: Dictionary = active_theme.get("aliases", {})
        var resolved_slot: String = str(aliases.get(slot_id, slot_id))
        var baseline_slots: Dictionary = _baseline.get("slots", {})
        var baseline_entry: Dictionary = baseline_slots.get(resolved_slot, {})
        var baseline_texture: Texture2D = _valid_texture(str(baseline_entry.get("source", "")))
        if result == null or baseline_texture == null or Vector2i(result.get_size()) != Vector2i(baseline_texture.get_size()):
            _rollback_invalid_user_theme("missing or incompatible texture: " + resolved_slot)
            return null
    if result != null:
        _cache[path] = result
    return result

static func texture_for_path(path: String) -> Texture2D:
    _ensure()
    if not _by_path.has(path):
        return null
    return texture(str(_by_path[path]))

static func report(id: String) -> Dictionary:
    _ensure()
    if id == "original":
        return {"ok":true,"id":id,"required":0,"present":0,"missing":[],"stage":"baseline"}
    if not _themes.has(id):
        return {"ok":false,"id":id,"message":"未知主题","missing":[]}
    var theme: Dictionary = _themes[id]
    var slots: Dictionary = theme.get("slots", {})
    var missing: Array[String] = []
    var expected_slots: Dictionary = _baseline.get("slots", {})
    if slots.size() != expected_slots.size():
        missing.append("theme contract slot count mismatch: %d/%d" % [slots.size(), expected_slots.size()])
    else:
        for required_slot in expected_slots.keys():
            if not slots.has(required_slot):
                missing.append("theme contract slot missing: " + str(required_slot))
    var required: int = 0
    var present: int = 0
    for key in slots.keys():
        var item: Dictionary = slots[key]
        var p: String = str(item.get("source", ""))
        var mandatory: bool = bool(item.get("required", false))
        if mandatory:
            required += 1
        # An all-or-nothing V2 theme must validate every registered slot.
        # The "required" bit is a gameplay-critical subset, never permission
        # to activate a visually mixed theme with optional slots missing.
        if not (p.begins_with("res://assets/art/runtime/") or p.begins_with(USER_ROOT + "/user_")) or p.contains(".."):
            missing.append(str(key)+": invalid path")
            continue
        var tex: Texture2D = _valid_texture(p)
        if tex == null:
            missing.append(str(key)+": "+p)
            continue
        if tex.get_width() < 8 or tex.get_height() < 8:
            missing.append(str(key)+": bad dimensions")
            continue
        if id.begins_with("user_"):
            var baseline_entry: Dictionary = expected_slots.get(key, {})
            var reference: Texture2D = _valid_texture(str(baseline_entry.get("source", "")))
            if reference == null or Vector2i(tex.get_size()) != Vector2i(reference.get_size()):
                missing.append(str(key)+": changed canvas dimensions")
                continue
        present += 1
    return {"ok":missing.is_empty() and required > 0 and present == slots.size(),"id":id,
        "required":required,"present":present,"total":slots.size(),
        "missing":missing,"stage":str(theme.get("state","unreviewed"))}

static func activate(id: String) -> bool:
    _ensure()
    var status: Dictionary = report(id)
    if not bool(status.get("ok",false)):
        return false
    if id == _active:
        return true
    var previous: String = _active
    _config.set_value("theme", "active", id)
    if _config.save(SETTINGS) != OK:
        _config.set_value("theme", "active", previous)
        return false
    _active = id
    _cache.clear()
    _revision += 1
    _reindex()
    return true

## User V2 themes are full packs, never partial substitutions misrepresented as
## complete styles. Every official semantic slot must be present and share
## pixel dimensions with the approved import contract.
static func install_pack(manifest_file: String) -> Dictionary:
    _ensure()
    if manifest_file.get_extension().to_lower() != "json":
        return {"ok":false,"message":"请选择V2主题JSON文件。"}
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_file))
    if not raw is Dictionary or str(raw.get("schema","")) != "starlit.art_theme.dlc.v2":
        return {"ok":false,"message":"不是完整V2主题包清单。"}
    var given_id: String = str(raw.get("id",""))
    if given_id.is_empty() or given_id.length() > 42:
        return {"ok":false,"message":"主题ID不合法。"}
    for character in given_id:
        if not (character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-"):
            return {"ok":false,"message":"主题ID只允许字母数字、-和_。"}
    var new_id: String = "user_"+given_id
    if _themes.has(new_id):
        return {"ok":false,"message":"主题ID已存在，禁止覆盖当前主题。"}
    var baseline_slots: Dictionary = _baseline.get("slots",{})
    var mappings: Array = raw.get("mappings",[])
    var inputs: Dictionary = {}
    var used_names: Dictionary = {}
    for item in mappings:
        if not item is Dictionary:
            return {"ok":false,"message":"主题资源条目格式错误。"}
        var slot_id: String = str(item.get("slot",""))
        var filename: String = str(item.get("file",""))
        if not baseline_slots.has(slot_id) or inputs.has(slot_id):
            return {"ok":false,"message":"资源槽位未知或重复："+slot_id}
        if filename.is_empty() or filename != filename.get_file() or filename.contains(".."):
            return {"ok":false,"message":"主题文件必须是单层安全文件名。"}
        if filename.get_extension().to_lower() not in ["png","jpg","jpeg","webp"]:
            return {"ok":false,"message":"主题只允许静态安全图片文件。"}
        if used_names.has(filename):
            return {"ok":false,"message":"重复的DLC文件名不可对应多个不同语义槽："+filename}
        used_names[filename] = true
        inputs[slot_id] = filename
    if inputs.size() != baseline_slots.size():
        return {"ok":false,"message":"完整主题需要%d项，实际仅%d项；拒绝半套混合画风。" % [baseline_slots.size(),inputs.size()]}
    var loaded_images: Dictionary = {}
    for key in baseline_slots.keys():
        var filename: String = str(inputs[key])
        var src: String = manifest_file.get_base_dir().path_join(filename)
        var file: FileAccess = FileAccess.open(src,FileAccess.READ)
        if file == null:
            return {"ok":false,"message":"主题文件不存在："+filename}
        var size: int = file.get_length()
        file.close()
        if size < 16 or size > MAX_IMPORT_BYTES:
            return {"ok":false,"message":"主题图片大小超限："+filename}
        var source_img := Image.new()
        if source_img.load(src) != OK or source_img.is_empty():
            return {"ok":false,"message":"主题图片无法解码："+filename}
        var origin: Texture2D = _valid_texture(str(baseline_slots[key].get("source","")))
        if origin == null or Vector2i(source_img.get_size()) != Vector2i(origin.get_size()):
            return {"ok":false,"message":"主题图片尺寸必须等于规范："+str(key)}
        if source_img.get_width() > 8192 or source_img.get_height() > 8192:
            return {"ok":false,"message":"主题图片分辨率超限："+filename}
        loaded_images[key] = src
    var directory: String = USER_ROOT + "/" + new_id
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
        return {"ok":false,"message":"主题存储目录无法创建。"}
    var new_slots: Dictionary = {}
    for key in baseline_slots.keys():
        var filename: String = str(inputs[key])
        var destination: String = directory + "/" + filename
        if DirAccess.copy_absolute(str(loaded_images[key]),ProjectSettings.globalize_path(destination)) != OK:
            _cleanup_failed_pack(directory, new_slots)
            return {"ok":false,"message":"主题文件复制失败；未启用新主题。"}
        var slot: Dictionary = (baseline_slots[key] as Dictionary).duplicate(true)
        slot["source"] = destination
        slot["stage"] = "user_imported_pending_visual_qa"
        new_slots[key] = slot
    var record: Dictionary = {"id":new_id,"name":str(raw.get("name",given_id)).substr(0,60),
        "state":"user_imported_pending_visual_qa","slots":new_slots,
        "aliases":_baseline.get("aliases",{}),"asset_set":"user_full_v2"}
    var saved: Dictionary = {"schema":"starlit.art_theme.installed.v2","themes":[]}
    if FileAccess.file_exists(USER_INDEX):
        var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(USER_INDEX))
        if previous is Dictionary and str(previous.get("schema","")) == "starlit.art_theme.installed.v2":
            saved = previous
    (saved["themes"] as Array).append(record)
    var target: String = USER_INDEX + ".tmp"
    var write: FileAccess = FileAccess.open(target,FileAccess.WRITE)
    if write == null:
        _cleanup_failed_pack(directory, new_slots)
        return {"ok":false,"message":"主题索引写入失败。"}
    write.store_string(JSON.stringify(saved,"  "))
    write.close()
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(target),
            ProjectSettings.globalize_path(USER_INDEX)) != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
        _cleanup_failed_pack(directory, new_slots)
        return {"ok":false,"message":"主题索引提交失败。"}
    _themes[new_id] = record
    return {"ok":true,"id":new_id,"count":new_slots.size(),
        "message":"完整V2主题导入成功；仍需游戏内截图进行美术验收。"}

## Only the uncommitted new pack's files are cleaned; never delete existing DLCs.
static func _cleanup_failed_pack(directory: String, slots: Dictionary) -> void:
    for slot in slots.values():
        var location: String = str((slot as Dictionary).get("source", ""))
        if location.begins_with(directory + "/") and not location.contains(".."):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(location))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
