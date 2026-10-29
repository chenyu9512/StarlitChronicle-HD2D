@tool
extends EditorPlugin
## One editor-facing entry point for review, verified import, switching and rollback.
## The game runtime still owns DLC validation; no res:// runtime art is overwritten.
const Pipeline = preload("res://addons/starlit_art_pipeline/pipeline.gd")
const Themes = preload("res://scripts/c_art_theme_v2.gd")
const UNDO_FILE := "user://starlit_art_pipeline_undo.cfg"

var _dock: VBoxContainer
var _controls: VBoxContainer
var _root: LineEdit
var _report_path: LineEdit
var _status: RichTextLabel
var _folder_dialog: EditorFileDialog
var _import_dialog: EditorFileDialog
var _theme_picker: OptionButton
var _ai_scope: OptionButton
var _ai_limit: SpinBox
var _ai_quality: OptionButton
var _ai_reference: LineEdit
var _ai_pid: int = -1

func _enter_tree() -> void:
    _dock = VBoxContainer.new()
    _dock.name = "星灯美术生产线"
    _dock.custom_minimum_size = Vector2(325, 390)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size.y = 220
    _dock.add_child(scroll)
    _controls = VBoxContainer.new()
    _controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_controls)
    var title := Label.new()
    title.text = "星灯纪行 · 美术生产与一键替换"
    title.add_theme_font_size_override("font_size", 16)
    _controls.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "素材审阅 → 发布体检 → 完整导入 → 游戏替换\n保留原图 / 原地图 / 战斗 / 存档，随时切回"
    _controls.add_child(subtitle)

    var label := Label.new()
    label.text = "素材根目录（默认项目内 res://）"
    _controls.add_child(label)
    var root_row := HBoxContainer.new()
    _root = LineEdit.new()
    _root.text = "res://"
    _root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root_row.add_child(_root)
    var browse := Button.new()
    browse.text = "选目录"
    browse.pressed.connect(_browse)
    root_row.add_child(browse)
    _controls.add_child(root_row)

    var csv_label := Label.new()
    csv_label.text = "V5审核CSV（复用结果，不重新全盘扫描）"
    _controls.add_child(csv_label)
    _report_path = LineEdit.new()
    _report_path.text = Pipeline.V5_CSV
    _controls.add_child(_report_path)
    _add_button("① 增量转换与集中预览", _start)
    _add_button("打开集中审核画廊", _open_preview)
    _add_button("② 检查109项：显示逐项阻断原因", _audit)
    _add_button("打开发布门禁报告", _open_gate)
    _add_button("③ 一键构建 + 安装 + 切换完整主题", _build_install_activate)
    _add_button("导入其他已完成的109槽位DLC", _browse_pack)

    var separator := HSeparator.new()
    _controls.add_child(separator)
    var theme_label := Label.new()
    theme_label.text = "已安装主题 · 只显示完整主题"
    _controls.add_child(theme_label)
    _theme_picker = OptionButton.new()
    _theme_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _controls.add_child(_theme_picker)
    _add_button("刷新主题 / 检查当前状态", _refresh_themes)
    _add_button("切换到所选主题", _activate_selected)
    _add_button("撤销上次切换", _undo)
    _add_button("退出完整主题，恢复原有美术", _restore_original)
    var art_heading := Label.new()
    art_heading.text = "高清2D美术生成器 · 高品质工作流"
    _controls.add_child(art_heading)
    var model_tip := Label.new()
    model_tip.text = "程序绘制仅供占位。高画质需要显式选择模型生成；\n不会自动覆盖正式游戏资源。"
    model_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _controls.add_child(model_tip)
    _add_button("④ V4.1精细素材+法线贴图+SVG（离线）", _generate_global_art_v3)
    _add_button("⑤ 全游戏高画质生成任务清单（不调用API）", _export_model_briefs)
    var settings_row := HBoxContainer.new()
    _ai_scope = OptionButton.new()
    for scope in ["bosses", "characters", "maps", "interiors", "props", "monsters", "npcs", "terrain", "ui", "all"]:
        _ai_scope.add_item(scope)
    _ai_scope.tooltip_text = "选择本次精修资产类别；all 为全游戏批次"
    _ai_scope.select(0)
    settings_row.add_child(_ai_scope)
    _ai_limit = SpinBox.new()
    _ai_limit.min_value = 0
    _ai_limit.max_value = 1000
    _ai_limit.step = 1
    _ai_limit.value = 8
    _ai_limit.tooltip_text = "本次生成张数（0=全部）；每张消耗API额度"
    settings_row.add_child(_ai_limit)
    _ai_quality = OptionButton.new()
    _ai_quality.add_item("xhigh")
    _ai_quality.add_item("max")
    _ai_quality.tooltip_text = "模型渲染品质"
    _ai_quality.select(0)
    settings_row.add_child(_ai_quality)
    _controls.add_child(settings_row)
    var reference_label := Label.new()
    reference_label.text = "身份参考原画目录（可留空；分类/资产ID.png）"
    _controls.add_child(reference_label)
    _ai_reference = LineEdit.new()
    _ai_reference.placeholder_text = "如 res://assets/art/reference_masters"
    _controls.add_child(_ai_reference)
    _add_button("⑥ 按所选范围生成高画质PNG（需要API密钥）", _render_model_art)
    _add_button("刷新高画质生成结果", _check_model_art)
    _add_button("运行游戏检查替换效果", _play_game)

    var warning := Label.new()
    warning.text = "完整主题必须通过109/109内容、身份、尺寸与签收门禁。\n不合格素材只供预览；不自动混合、不覆盖原图。\n安装成功≠画质与地图实机验收通过。"
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _controls.add_child(warning)
    _status = RichTextLabel.new()
    _status.custom_minimum_size = Vector2(290, 135)
    _status.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _status.bbcode_enabled = false
    _dock.add_child(_status)

    _folder_dialog = EditorFileDialog.new()
    _folder_dialog.access = EditorFileDialog.ACCESS_RESOURCES
    _folder_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
    _folder_dialog.title = "选择项目内素材目录"
    _folder_dialog.dir_selected.connect(_on_dir_selected)
    _dock.add_child(_folder_dialog)
    _import_dialog = EditorFileDialog.new()
    _import_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
    _import_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
    _import_dialog.title = "选择完整DLC的art_theme.json"
    _import_dialog.add_filter("*.json", "V2主题JSON")
    _import_dialog.file_selected.connect(_import_pack)
    _dock.add_child(_import_dialog)
    add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
    _refresh_themes()

func _add_button(caption: String, handler: Callable) -> void:
    var button := Button.new()
    button.text = caption
    button.pressed.connect(handler)
    _controls.add_child(button)

func _exit_tree() -> void:
    if _dock != null:
        remove_control_from_docks(_dock)
        _dock.queue_free()
        _dock = null

func _browse() -> void:
    _folder_dialog.popup_centered_ratio(0.72)

func _on_dir_selected(path: String) -> void:
    _root.text = path

func _browse_pack() -> void:
    _import_dialog.popup_centered_ratio(0.72)

func _import_pack(path: String) -> void:
    var result: Dictionary = Themes.install_pack(path)
    if not bool(result.get("ok", false)):
        _status.text = "DLC未导入：" + str(result.get("message", "未知错误")) + "\n原主题保持不变。"
        return
    var id: String = str(result.get("id", ""))
    if _switch_to(id):
        _status.text = "外部完整DLC已导入并激活：" + id \
            + "\n原图不覆盖；请运行游戏检查实际场景。"

func _start() -> void:
    _status.text = "正在复用V5数据，生成增量预览；不会修改正式主题。"
    call_deferred("_execute_preview")

func _execute_preview() -> void:
    var result: Dictionary = Pipeline.run(_root.text, _report_path.text)
    if not bool(result.get("ok", false)):
        _status.text = "转换预览未完成：" + str(result.get("error", "未知错误"))
        return
    var stats: Dictionary = result.get("summary", {})
    var inv: Dictionary = result.get("inventory", {})
    _status.text = "预览完成（尚未实际替换）\n" \
        + "项目图片：" + str(inv.get("total", 0)) \
        + "；新增/变化：" + str(inv.get("new_or_changed", 0)) + "\n" \
        + "可预览：" + str(stats.get("PREVIEW_BUILT", 0)) \
        + "；未批准：" + str(stats.get("NOT_APPROVED", 0)) \
        + "；错误身份：" + str(stats.get("BLOCKED_WRONG_OBJECT", 0)) \
        + "\n报告：build/starlit_art_pipeline/review.html"

func _open_local(path: String, missing: String) -> void:
    if not FileAccess.file_exists(path):
        _status.text = missing
        return
    OS.shell_open("file://" + ProjectSettings.globalize_path(path).replace("\\", "/"))

func _open_preview() -> void:
    _open_local(Pipeline.OUT + "/review.html", "没有预览报告，请先运行①。")

func _open_gate() -> void:
    _open_local(Pipeline.OUT + "/release_gate.csv", "没有门禁报告，请先运行②。")

func _audit() -> void:
    _status.text = "正在逐项校验发布门禁（不复制、不安装）。"
    call_deferred("_execute_audit")

func _execute_audit() -> void:
    var gate: Dictionary = Pipeline.audit_complete_dlc(_root.text, _report_path.text)
    if gate.has("error"):
        _status.text = "门禁检查失败：" + str(gate["error"])
        return
    var reason_counts: Dictionary = gate.get("reasons", {})
    var reason_lines: Array[String] = []
    for reason in reason_counts.keys():
        reason_lines.append(str(reason) + " ×" + str(reason_counts[reason]))
    reason_lines.sort()
    _status.text = "可发布：" + str(gate.get("ready", 0)) + "/109；阻断：" \
        + str(gate.get("blocked", 0)) + "/109\n" \
        + "\n".join(PackedStringArray(reason_lines.slice(0, 7))) \
        + "\n完整逐项原因：build/starlit_art_pipeline/release_gate.csv"
    if bool(gate.get("ok", false)):
        _status.text = "109/109项均满足完整主题发布条件。\n点击③即可构建、安装并切换；仍需实机验收。"

func _build_install_activate() -> void:
    _status.text = "正在检查完整主题并构建安全导入包…"
    call_deferred("_execute_install")

func _execute_install() -> void:
    var built: Dictionary = Pipeline.try_build_complete_dlc(_root.text, _report_path.text)
    if not bool(built.get("ok", false)):
        _status.text = "未替换任何正式美术：" + str(built.get("error", "未知错误")) \
            + "\n点击②或查看release_gate.csv定位每个缺口。"
        return
    var target_id: String = str(built.get("id", ""))
    var found: bool = false
    for t in Themes.list_themes():
        if str(t.get("id", "")) == target_id:
            found = true
            break
    if not found:
        var installed: Dictionary = Themes.install_pack(str(built.get("path", "")))
        if not bool(installed.get("ok", false)):
            _status.text = "已构建，但未能安装：" + str(installed.get("message", "")) \
                + "\n原主题未变。"
            return
        target_id = str(installed.get("id", target_id))
    if not _switch_to(target_id):
        _status.text += "\n完整主题未启用；原主题保持不变。"
        return
    _status.text = "完整109槽位已安装并激活：" + target_id \
        + "\n图片位于独立user:// DLC，无原文件覆盖。" \
        + "\n重新运行游戏检查所有地图；美术人工签收仍未完成。"

func _refresh_themes() -> void:
    if _theme_picker == null:
        return
    var selected_id: String = Themes.active_id()
    _theme_picker.clear()
    var index: int = 0
    for theme in Themes.list_themes():
        var id: String = str(theme.get("id", ""))
        _theme_picker.add_item(str(theme.get("name", id)))
        _theme_picker.set_item_metadata(index, id)
        if id == selected_id:
            _theme_picker.select(index)
        index += 1
    if _status != null:
        _status.text = "当前运行主题：" + selected_id \
            + "\n已登记：" + str(index) + " 套；完整导入与正式美术分离。"

func _switch_to(id: String) -> bool:
    var gate: Dictionary = Themes.report(id)
    if not bool(gate.get("ok", false)):
        _status.text = "拒绝切换，主题未通过运行时完整性校验：" + id \
            + "\n" + str(gate.get("missing", [])).substr(0, 480)
        return false
    var previous: String = Themes.active_id()
    if id == previous:
        _refresh_themes()
        return true
    if not Themes.activate(id):
        _status.text = "主题切换失败；原主题仍有效：" + previous
        return false
    var undo := ConfigFile.new()
    undo.set_value("history", "previous", previous)
    if undo.save(UNDO_FILE) != OK:
        push_warning("无法持久化主题切换撤销记录")
    _refresh_themes()
    return true

func _activate_selected() -> void:
    if _theme_picker.selected < 0:
        _status.text = "请先选择一个已安装主题。"
        return
    var id: String = str(_theme_picker.get_selected_metadata())
    if _switch_to(id):
        _status.text = "已切换：" + id + "\n重新运行游戏或重进地图查看实际替换效果。"

func _undo() -> void:
    var history := ConfigFile.new()
    if history.load(UNDO_FILE) != OK:
        _status.text = "没有可撤销的切换记录；可以退出完整主题。"
        return
    var previous: String = str(history.get_value("history", "previous", "original"))
    if _switch_to(previous):
        _status.text = "已撤销上次切换；当前主题：" + Themes.active_id()

func _restore_original() -> void:
    if _switch_to("original"):
        _status.text = "已退出V2完整主题，恢复之前的个人覆盖及兼容美术规则。\n不会删除DLC、源图或存档；请重新运行游戏检查。"

func _generate_global_art_v3() -> void:
    # Editor-only production stage; never replaces any live textures.
    var script_path: String = ProjectSettings.globalize_path("res://tools/global_art_factory_v3.py")
    var project_path: String = ProjectSettings.globalize_path("res://")
    var arguments := PackedStringArray([script_path, "--project", project_path])
    var output: Array = []
    var status: int = OS.execute("python", arguments, output, true)
    if status != 0:
        output.clear()
        status = OS.execute("py", PackedStringArray(["-3", script_path, "--project", project_path]), output, true)
    if status == 0:
        _status.text = "全局候选美术生成完成：res://build/starlit_global_art_factory_v3/candidate_manifest.json\n" + "\n".join(output)
    else:
        _status.text = "美术生成器执行失败（退出码 %d）。请确认已安装Python与Pillow。\n" % status + "\n".join(output)


func _export_model_briefs() -> void:
    var script_path: String = ProjectSettings.globalize_path("res://tools/global_art_ai_provider_v3.py")
    var project_path: String = ProjectSettings.globalize_path("res://")
    var args := PackedStringArray([script_path, "--project", project_path, "--jobs-only"])
    var output: Array = []
    var exit_code: int = OS.execute("python", args, output, true)
    if exit_code != 0:
        output.clear()
        exit_code = OS.execute("py", PackedStringArray(["-3"] + Array(args)), output, true)
    _status.text = ("全游戏高清任务已生成（未调用收费API）：" if exit_code == 0
        else "高清任务生成失败；需 Python 与 Pillow：") + \
        "\nbuild/starlit_global_art_factory_v3/model_sources/render_jobs.jsonl\n" + "\n".join(output)


func _render_model_art() -> void:
    if _ai_pid > 0 and OS.is_process_running(_ai_pid):
        _status.text = "已经有高清生成进程正在运行：PID " + str(_ai_pid)
        return
    if not OS.has_environment("OPENAI_API_KEY"):
        _status.text = "未发现OPENAI_API_KEY。请在启动Godot前配置环境变量；不会发起请求。"
        return
    var script_path: String = ProjectSettings.globalize_path("res://tools/global_art_ai_provider_v3.py")
    var project_path: String = ProjectSettings.globalize_path("res://")
    var scope: String = _ai_scope.get_item_text(_ai_scope.selected)
    var quality: String = _ai_quality.get_item_text(_ai_quality.selected)
    var args := PackedStringArray([script_path, "--project", project_path,
        "--render", "--scope", scope, "--limit", str(int(_ai_limit.value)),
        "--quality", quality])
    var reference_path: String = _ai_reference.text.strip_edges()
    if not reference_path.is_empty():
        if reference_path.begins_with("res://"):
            reference_path = ProjectSettings.globalize_path(reference_path)
        args.append_array(PackedStringArray(["--reference-root", reference_path]))
    _ai_pid = OS.create_process("python", args)
    if _ai_pid <= 0:
        _ai_pid = OS.create_process("py", PackedStringArray(["-3"] + Array(args)))
    if _ai_pid <= 0:
        _status.text = "无法启动 Python 图像生成器；请检查Python和openai、Pillow依赖。"
        return
    _status.text = "已开始真实模型绘制（非程序占位图）：" + scope + \
        " / " + quality + " / 目标张数 " + str(int(_ai_limit.value)) + \
        "\n进程 PID " + str(_ai_pid) + \
        "\n生成PNG在 build/starlit_global_art_factory_v3/model_sources/；完成后点击「刷新高画质生成结果」。"


func _check_model_art() -> void:
    if _ai_pid > 0 and OS.is_process_running(_ai_pid):
        _status.text = "高画质生成仍在执行：PID " + str(_ai_pid)
        return
    var report_path: String = "res://build/starlit_global_art_factory_v3/model_sources/render_report.json"
    if not FileAccess.file_exists(report_path):
        _status.text = "尚无高画质生成结果。先创建任务或启动生成。"
        return
    var obj: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
    if not obj is Dictionary:
        _status.text = "高画质报告损坏或尚未写完。"
        return
    var report: Dictionary = obj
    _status.text = "最近一次模型报告（请核对生成时间）：\n" + "模型：" + str(report.get("model", "")) + \
        "；品质：" + str(report.get("quality", "")) + \
        "\n新生成：" + str(report.get("complete", 0)) + \
        "；复用缓存：" + str(report.get("cached", 0)) + \
        "；失败：" + str((report.get("failures", []) as Array).size()) + \
        "\n图片为待审核候选：build/starlit_global_art_factory_v3/model_sources/\n" + \
        "生成后可以通过全局资产工厂 --source-root 导入，正式游戏资源不自动替换。"

func _play_game() -> void:
    _status.text = "启动当前项目主场景以检查已激活主题。\n仅实际运行和截图能证明画面已替换。"
    EditorInterface.play_main_scene()
