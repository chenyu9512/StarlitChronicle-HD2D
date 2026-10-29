@tool
extends RefCounted
## In-editor batch pipeline. No mutation of game runtime, source images, saves or Git branches.
## A partial Pixel Fantasy theme is NEVER passed to the 109-slot production installer.
const REGISTRY := "res://data/assets/art_theme_v2.json"
## Historical V5 CSV filename is intentionally retained for existing local reports.
const V5_CSV := "res://build/pixel_fantasy_conversion_v5/01_107项接入状态.csv"
const OUT := "res://build/starlit_art_pipeline"
const SAFE_EXT := ["png", "webp", "jpg", "jpeg"]
const PREVIEW_STATES := [
    "SIZE_CONVERSION_REQUIRED", "SCENE_FOOTPRINT_REVIEW_REQUIRED",
    "CROP_AND_IDENTITY_REVIEW_REQUIRED", "TILESET_ASSEMBLY_REQUIRED",
    "MONSTER_ANIMATION_EXTRACTION_REQUIRED"
]

static func _json_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var obj: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return obj if obj is Dictionary else {}

static func _load_rows(path: String) -> Dictionary:
    var fh := FileAccess.open(path, FileAccess.READ)
    if fh == null:
        return {"error": "V5 CSV不存在，请先确认V5转换报告位于项目的build目录：" + path}
    var columns: PackedStringArray = fh.get_csv_line()
    var names: Array[String] = []
    for col in columns:
        names.append(str(col).strip_edges().trim_prefix("\uFEFF"))
    for key in ["slot_id", "approved", "candidate_path", "next_state"]:
        if not names.has(key):
            return {"error": "V5 CSV缺少列：" + key}
    var result: Dictionary = {}
    while not fh.eof_reached():
        var cells: PackedStringArray = fh.get_csv_line()
        if cells.size() != names.size():
            continue
        var row: Dictionary = {}
        for i in range(names.size()):
            row[names[i]] = cells[i]
        var id: String = str(row.get("slot_id", ""))
        if id.is_empty():
            continue
        if result.has(id):
            return {"error": "重复的槽位：" + id}
        result[id] = row
    return {"rows": result}

static func _candidate(root: String, relative: String) -> String:
    var rel: String = relative.replace("\\", "/").strip_edges()
    if rel.is_empty() or rel.begins_with("/") or rel.contains(":"):
        return ""
    for part in rel.split("/"):
        if part in [".", "..", ""]:
            return ""
    if rel.get_extension().to_lower() not in SAFE_EXT:
        return ""
    var prefix: String = root.strip_edges().replace("\\", "/")
    if prefix != "res://":
        prefix = prefix.trim_suffix("/")
    if not prefix.begins_with("res://") or prefix.contains(".."):
        return ""
    var first: String = "res://" + rel if prefix == "res://" else prefix + "/" + rel
    if FileAccess.file_exists(first):
        return first
    # V5 indexed pictures relative to the project, not relative to assets/art.
    var alternate: String = "res://" + rel
    return alternate if FileAccess.file_exists(alternate) else ""

static func _baseline(path: String) -> Texture2D:
    if not path.begins_with("res://assets/art/runtime/") or path.contains(".."):
        return null
    return ResourceLoader.load(path) as Texture2D if ResourceLoader.exists(path) else null

static func _write(path: String, content: String) -> bool:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(content)
    f.close()
    return true

static func _csv(value: String) -> String:
    return "\"" + value.replace("\"", "\"\"") + "\""

static func _preview(image: Image, size: Vector2i, path: String, montage_only: bool) -> bool:
    if image == null or image.is_empty():
        return false
    if image.get_width() > 8192 or image.get_height() > 8192:
        return false
    var copy: Image = image.duplicate()
    if copy.get_format() != Image.FORMAT_RGBA8:
        copy.convert(Image.FORMAT_RGBA8)
    # Tilesets / animation sheets have no approved row or frame semantics:
    # display the source sheet; NEVER turn its first 64 cells into a fake runtime atlas.
    if montage_only:
        var factor: float = minf(1.0, 512.0 / maxf(float(copy.get_width()), float(copy.get_height())))
        if factor < 1.0:
            copy.resize(maxi(1, roundi(copy.get_width() * factor)),
                maxi(1, roundi(copy.get_height() * factor)), Image.INTERPOLATE_NEAREST)
        return copy.save_png(path) == OK
    if size.x < 8 or size.y < 8 or size.x > 4096 or size.y > 4096:
        return false
    var used: Rect2i = copy.get_used_rect()
    if used.size.x == 0 or used.size.y == 0:
        return false
    var trimmed: Image = copy.get_region(used)
    var scale: float = minf(float(size.x) * 0.94 / float(trimmed.get_width()),
        float(size.y) * 0.94 / float(trimmed.get_height()))
    var w: int = clampi(roundi(trimmed.get_width() * scale), 1, size.x)
    var h: int = clampi(roundi(trimmed.get_height() * scale), 1, size.y)
    trimmed.resize(w, h, Image.INTERPOLATE_NEAREST)
    var out: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
    out.fill(Color.TRANSPARENT)
    out.blit_rect(trimmed, Rect2i(0, 0, w, h),
        Vector2i((size.x - w) / 2, maxi(0, size.y - h - roundi(size.y * 0.025))))
    return out.save_png(path) == OK

static func _web_img(path: String, title: String) -> String:
    if path.is_empty():
        return "<div class='missing'>未生成</div>"
    var src: String = path
    if path.begins_with("res://"):
        src = "../../" + path.trim_prefix("res://")
    return "<figure><img loading='lazy' src='" + src.xml_escape() + "'><figcaption>" + title.xml_escape() + "</figcaption></figure>"

static func _html(records: Array) -> String:
    var output: String = "<!doctype html><html lang='zh-CN'><meta charset='utf-8'>" \
        + "<title>星灯纪行·一键美术预览</title><style>body{font:15px system-ui;background:#111923;color:#e9eef5;margin:auto;max-width:1280px;padding:24px}" \
        + "article{border:1px solid #38465c;border-radius:9px;padding:14px;margin:12px 0;background:#1d2835}" \
        + "h1{font-size:24px}h3{margin:0 0 8px;font-size:16px}.muted{color:#b9c6d5}.images{display:flex;flex-wrap:wrap;gap:12px}" \
        + "figure{margin:0;min-width:175px;flex:1 1 28%;max-width:400px}figure img{background:#374253;width:100%;height:260px;object-fit:contain;image-rendering:pixelated}" \
        + "figcaption{text-align:center;margin-top:7px}.missing{color:#e6b87a}</style><h1>星灯纪行 · 美术一键生产线</h1>" \
        + "<p class='muted'>以下均为审阅预览，不是已启用的正式运行纹理。地形语义、怪物动作、场景碰撞、UI结构需专项确认；原运行图片保持不变。</p>"
    for row in records:
        if str(row.get("status", "")) in ["NOT_APPROVED", "BLOCKED_WRONG_OBJECT"]:
            continue
        output += "<article><h3>" + str(row.get("slot", "")).xml_escape() + "</h3><p class='muted'>" \
            + str(row.get("status", "")).xml_escape() + "</p><div class='images'>" \
            + _web_img(str(row.get("candidate", "")), "导入素材") \
            + _web_img(str(row.get("preview", "")), "自动转换预览（未正式发布）") \
            + _web_img(str(row.get("baseline", "")), "当前官方运行素材") + "</div></article>"
    return output + "</html>"


static func _classify(path: String) -> String:
    var p: String = path.to_lower()
    if p.contains("/buildings/"):
        return "建筑"
    if p.contains("/terrain/") or p.contains("/tiles/") or p.contains("/sheets/"):
        return "地形/图集"
    if p.contains("/monsters/") or p.contains("_sheet.png") or p.contains("/slime/"):
        return "怪物/动画待确认"
    if p.contains("/portraits/") or p.contains("/characters/") or p.contains("/sprites/"):
        return "人物"
    if p.contains("/ui/") or p.contains("/icons/") or p.contains("/navigation/") or p.contains("/actions/"):
        return "UI/图标"
    return "未知/待确认"

static func _walk_images(folder: String, paths: Array[String], depth: int = 0) -> void:
    if depth > 12 or paths.size() >= 15000 or FileAccess.file_exists(folder.path_join(".gdignore")):
        return
    var dir: DirAccess = DirAccess.open(folder)
    if dir == null:
        return
    dir.list_dir_begin()
    while true:
        var name: String = dir.get_next()
        if name.is_empty():
            break
        if name.begins_with("."):
            continue
        var child: String = folder.path_join(name)
        if dir.current_is_dir():
            if name in ["build", "runtime", "source_packs", "node_modules", "__pycache__"]:
                continue
            _walk_images(child, paths, depth + 1)
        elif child.get_extension().to_lower() in SAFE_EXT:
            paths.append(child)
            if paths.size() >= 15000:
                break
    dir.list_dir_end()

## One-time inventory, incremental by file modification times on later runs.
## Hints are never auto-approved or substituted into semantic slots.
static func _inventory(source_root: String) -> Dictionary:
    var paths: Array[String] = []
    var root: String = source_root.strip_edges()
    if not root.begins_with("res://") or root.contains(".."):
        return {"total": 0, "new_or_changed": 0, "error": "素材根目录必须位于当前Godot工程内"}
    _walk_images(root, paths)
    paths.sort()
    var existing: Dictionary = _json_file(OUT + "/inventory_cache.json").get("entries", {})
    var updated: Dictionary = {}
    var new_or_changed: int = 0
    var text_csv: String = "path,category,changed,approval\n"
    for path in paths:
        var mtime: int = FileAccess.get_modified_time(path)
        updated[path] = mtime
        var changed: bool = not existing.has(path) or int(existing[path]) != mtime
        if changed:
            new_or_changed += 1
        text_csv += _csv(path) + "," + _csv(_classify(path)) + "," \
            + ("YES" if changed else "NO") + ",NOT_AUTO_APPROVED\n"
    _write(OUT + "/inventory.csv", text_csv)
    _write(OUT + "/inventory_cache.json", JSON.stringify(
        {"schema": "starlit.art_pipeline.inventory.v1", "entries": updated}) + "\n")
    return {"total": paths.size(), "new_or_changed": new_or_changed}

static func run(source_root: String = "res://", csv_path: String = V5_CSV) -> Dictionary:
    var manifest: Dictionary = _json_file(REGISTRY)
    if str(manifest.get("schema", "")) != "starlit.art_theme.v2":
        return {"ok": false, "error": "Main2主题清单无效"}
    var official: Dictionary = {}
    for t in manifest.get("themes", []):
        if t is Dictionary and str(t.get("id", "")) == "starlit_hd2d_act01":
            official = t
            break
    var slots: Dictionary = official.get("slots", {})
    if slots.size() != 109:
        return {"ok": false, "error": "109槽位契约变更：请先核对，不自动混入"}
    var csv: Dictionary = _load_rows(csv_path)
    if csv.has("error"):
        return {"ok": false, "error": str(csv["error"])}
    var rows: Dictionary = csv["rows"]
    if rows.size() != slots.size():
        return {"ok": false, "error": "V5槽位数与官方契约不一致：" + str(rows.size())}
    for key in rows.keys():
        if not slots.has(key):
            return {"ok": false, "error": "V5包含未知槽位：" + str(key)}
        var expected: String = str((slots[key] as Dictionary).get("source", ""))
        var snapshot: String = str((rows[key] as Dictionary).get("baseline_path", ""))
        if not snapshot.is_empty() and expected.trim_prefix("res://") != snapshot:
            return {"ok": false, "error": "本地报告与Main2版本不同：" + str(key)}
    var base_dir: String = ProjectSettings.globalize_path(OUT)
    if DirAccess.make_dir_recursive_absolute(base_dir.path_join("previews")) != OK:
        return {"ok": false, "error": "无法创建预览目录"}
    var inventory: Dictionary = _inventory(source_root)
    var summary: Dictionary = {"NOT_APPROVED": 0, "BLOCKED_WRONG_OBJECT": 0,
        "PREVIEW_BUILT": 0, "SOURCE_MISSING": 0, "BASELINE_MISSING": 0,
        "NEEDS_PRODUCTION_REVIEW": 0}
    var results: Array = []
    var cache: Dictionary = _json_file(OUT + "/cache.json").get("entries", {})
    var fresh_cache: Dictionary = {}
    var keys: Array = slots.keys()
    keys.sort()
    for id in keys:
        var key: String = str(id)
        var r: Dictionary = rows[key]
        var base_path: String = str((slots[key] as Dictionary).get("source", ""))
        var rec: Dictionary = {"slot": key, "baseline": base_path,
            "candidate": "", "preview": "", "status": "", "source_sha256": ""}
        var approved: bool = str(r.get("approved", "")).to_upper() == "YES"
        var role: String = str(r.get("next_state", ""))
        if not approved:
            rec["status"] = "NOT_APPROVED"
        elif role == "WRONG_SEMANTIC_OBJECT_BLOCKED" or str(r.get("asset_role", "")) == "BLOCK_WRONG_OBJECT":
            rec["status"] = "BLOCKED_WRONG_OBJECT"
        elif not role in PREVIEW_STATES:
            rec["status"] = "NEEDS_PRODUCTION_REVIEW"
        else:
            var path: String = _candidate(source_root, str(r.get("candidate_path", "")))
            rec["candidate"] = path
            var baseline_tex: Texture2D = _baseline(base_path)
            if path.is_empty():
                rec["status"] = "SOURCE_MISSING"
            elif baseline_tex == null:
                rec["status"] = "BASELINE_MISSING"
            else:
                var input: Image = Image.new()
                if input.load(path) != OK or input.is_empty():
                    rec["status"] = "SOURCE_MISSING"
                else:
                    var is_sheet: bool = role in ["TILESET_ASSEMBLY_REQUIRED", "MONSTER_ANIMATION_EXTRACTION_REQUIRED"]
                    # Full-screen UI must not be overwritten by a small icon.
                    if key.begins_with("ui.game."):
                        is_sheet = true
                    var dest: String = OUT + "/previews/" + key + ".png"
                    var hash: String = FileAccess.get_sha256(path)
                    var cache_key: String = key + "|" + hash + "|" + str(baseline_tex.get_size()) + "|" + role + "|v1"
                    var cached: bool = str(cache.get(key, "")) == cache_key and FileAccess.file_exists(dest)
                    if cached or _preview(input, Vector2i(baseline_tex.get_size()),
                            ProjectSettings.globalize_path(dest), is_sheet):
                        rec["preview"] = "previews/" + key + ".png"
                        rec["status"] = "PREVIEW_BUILT"
                        rec["source_sha256"] = hash
                        fresh_cache[key] = cache_key
                    else:
                        rec["status"] = "NEEDS_PRODUCTION_REVIEW"
        summary[rec["status"]] = int(summary.get(rec["status"], 0)) + 1
        results.append(rec)
    var out_report: Dictionary = {"schema": "starlit.art_pipeline.preview.v1",
        "total_slots": slots.size(), "summary": summary, "inventory": inventory, "records": results,
        "theme_activated": false, "runtime_changed": false,
        "release_eligible": false,
        "note": "All previews need semantic and gameplay QA; the official 109-slot production theme is untouched."}
    var good: bool = _write(OUT + "/review.json", JSON.stringify(out_report, "  ") + "\n")
    good = _write(OUT + "/review.html", _html(results)) and good
    good = _write(OUT + "/cache.json", JSON.stringify({"schema": "starlit.art_pipeline.cache.v1", "entries": fresh_cache}, "  ") + "\n") and good
    var csv_text: String = "slot,status,candidate,baseline,preview,source_sha256\n"
    for r in results:
        var fields: PackedStringArray = PackedStringArray()
        for column in ["slot", "status", "candidate", "baseline", "preview", "source_sha256"]:
            fields.append(_csv(str(r[column])))
        csv_text += ",".join(fields) + "\n"
    good = _write(OUT + "/review.csv", csv_text) and good
    if not good:
        return {"ok": false, "error": "预览已尝试生成，但报告写入失败"}
    return {"ok": true, "summary": summary, "inventory": inventory, "output": OUT, "built": summary["PREVIEW_BUILT"]}

## Release preflight is read-only. It never treats a resized preview, a
## texture sheet, or an unapproved candidate as a gameplay-ready replacement.
## Every rejection is persisted once, with a concrete reason, for the editor UI.
static func audit_complete_dlc(source_root: String = "res://", csv_path: String = V5_CSV) -> Dictionary:
    var manifest: Dictionary = _json_file(REGISTRY)
    if str(manifest.get("schema", "")) != "starlit.art_theme.v2":
        return {"ok": false, "error": "官方主题清单无效"}
    var slots: Dictionary = {}
    for theme in manifest.get("themes", []):
        if theme is Dictionary and str(theme.get("id", "")) == "starlit_hd2d_act01":
            slots = theme.get("slots", {})
            break
    if slots.size() != 109:
        return {"ok": false, "error": "正式主题槽位契约不等于109；拒绝替换"}
    var parsed: Dictionary = _load_rows(csv_path)
    if parsed.has("error"):
        return {"ok": false, "error": str(parsed["error"])}
    var rows: Dictionary = parsed["rows"]
    if rows.size() != slots.size():
        return {"ok": false, "error": "CSV槽位数量与正式主题不一致：" + str(rows.size()) + "/109"}
    for row_key in rows.keys():
        if not slots.has(row_key):
            return {"ok": false, "error": "CSV包含未知槽位：" + str(row_key)}
    var keys: Array = slots.keys()
    keys.sort()
    var approved_files: Dictionary = {}
    var blockers: Array[Dictionary] = []
    var reasons: Dictionary = {}
    var signature: String = ""
    for id in keys:
        var key: String = str(id)
        var item: Dictionary = slots[key]
        var row: Dictionary = rows.get(key, {})
        var errors: Array[String] = []
        var expected: String = str(item.get("source", ""))
        var snapshot: String = str(row.get("baseline_path", ""))
        if not snapshot.is_empty() and snapshot != expected.trim_prefix("res://"):
            errors.append("V5_BASELINE_OUTDATED")
        if str(row.get("approved", "")).to_upper() != "YES":
            errors.append("NOT_APPROVED")
        if str(row.get("final_visual_approved", "")).to_upper() != "YES":
            errors.append("VISUAL_SIGNOFF_MISSING")
        if str(row.get("next_state", "")) != "READY_FOR_DLC":
            errors.append("NOT_PRODUCTION_READY")
        if str(row.get("asset_role", "")) == "BLOCK_WRONG_OBJECT":
            errors.append("WRONG_SEMANTIC_IDENTITY")
        var source: String = _candidate(source_root, str(row.get("candidate_path", "")))
        if source.is_empty():
            errors.append("SOURCE_MISSING_OR_UNSAFE")
        var reference: Texture2D = _baseline(expected)
        if reference == null:
            errors.append("BASELINE_MISSING")
        var source_image: Image = Image.new()
        if not source.is_empty():
            var file := FileAccess.open(source, FileAccess.READ)
            if file == null or file.get_length() < 16 or file.get_length() > 24 * 1024 * 1024:
                errors.append("SOURCE_FILE_SIZE_INVALID")
            if source_image.load(source) != OK or source_image.is_empty():
                errors.append("IMAGE_DECODE_FAILED")
            elif source_image.get_width() > 8192 or source_image.get_height() > 8192:
                errors.append("IMAGE_TOO_LARGE")
            elif reference != null and Vector2i(source_image.get_size()) != Vector2i(reference.get_size()):
                errors.append("CANVAS_SIZE_MISMATCH")
        if errors.is_empty():
            approved_files[key] = source
            signature += key + "|" + FileAccess.get_sha256(source) + "\n"
        else:
            for reason in errors:
                reasons[reason] = int(reasons.get(reason, 0)) + 1
            blockers.append({"slot": key, "reasons": errors})
    var ready: int = approved_files.size()
    var report: Dictionary = {
        "schema": "starlit.art_pipeline.release_gate.v2",
        "expected": slots.size(), "ready": ready, "blocked": blockers.size(),
        "reason_counts": reasons, "blockers": blockers,
        "release_eligible": blockers.is_empty(), "activated": false
    }
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    _write(OUT + "/release_gate.json", JSON.stringify(report, "  ") + "\n")
    var csv_data: String = "slot,reason\n"
    for blocker in blockers:
        csv_data += _csv(str(blocker["slot"])) + "," + _csv(";".join(PackedStringArray(blocker["reasons"]))) + "\n"
    _write(OUT + "/release_gate.csv", csv_data)
    return {"ok": blockers.is_empty(), "ready": ready, "blocked": blockers.size(),
        "expected": slots.size(), "reasons": reasons, "examples": blockers.slice(0, 12),
        "approved_files": approved_files, "fingerprint": signature.sha256_text().substr(0, 16),
        "report_path": OUT + "/release_gate.json"}

## Produce an immutable, content-addressed V2 pack. The runtime installer owns
## copying to user:// and theme activation; neither step is implicit here.
static func try_build_complete_dlc(source_root: String = "res://", csv_path: String = V5_CSV) -> Dictionary:
    var gate: Dictionary = audit_complete_dlc(source_root, csv_path)
    if not bool(gate.get("ok", false)):
        if gate.has("error"):
            return gate
        return {"ok": false, "error": "完整主题未通过发布门禁：" + str(gate.get("blocked", 0)) + "/109 项不合格，见release_gate.csv",
            "blocked_count": gate.get("blocked", 0), "blocked_examples": gate.get("examples", []),
            "report_path": gate.get("report_path", "")}
    var originals: Dictionary = gate["approved_files"]
    var pack_id: String = "pixel_fantasy_" + str(gate["fingerprint"])
    var dest_dir: String = OUT + "/complete_dlc/" + pack_id
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_dir)) != OK:
        return {"ok": false, "error": "无法创建完整DLC输出目录"}
    var mapping: Array = []
    var keys: Array = originals.keys()
    keys.sort()
    for id in keys:
        var key: String = str(id)
        var img := Image.new()
        if img.load(str(originals[key])) != OK:
            return {"ok": false, "error": "构建时源文件已失效：" + key}
        var filename: String = key + ".png"
        var output: String = dest_dir + "/" + filename
        if img.save_png(ProjectSettings.globalize_path(output)) != OK:
            return {"ok": false, "error": "构建时PNG写入失败：" + key}
        var written := FileAccess.open(output, FileAccess.READ)
        if written == null or written.get_length() < 16 or written.get_length() > 24 * 1024 * 1024:
            return {"ok": false, "error": "构建后的图片超过运行时导入限制：" + key}
        mapping.append({"slot": key, "file": filename})
    var pack: Dictionary = {
        "schema": "starlit.art_theme.dlc.v2", "id": pack_id,
        "name": "Pixel Fantasy 已签收 · " + str(gate["fingerprint"]),
        "mappings": mapping
    }
    var manifest_file: String = dest_dir + "/art_theme.json"
    if not _write(manifest_file, JSON.stringify(pack, "  ") + "\n"):
        return {"ok": false, "error": "完整DLC清单写入失败；没有激活任何主题"}
    return {"ok": true, "id": "user_" + pack_id, "count": mapping.size(),
        "path": manifest_file, "report_path": gate["report_path"],
        "message": "109项完整主题已构建，可经运行时管理器安装、验证并一键激活。"}
