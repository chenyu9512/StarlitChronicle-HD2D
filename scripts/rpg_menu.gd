extends CanvasLayer
## 手机和桌面通用的大功能栏：十二个栏目均提供有用的数据或操作。
signal closed()
signal replay_ending_requested(id: String)
signal branch_event_requested(event_id: String)
signal branch_navigation_requested(event_id: String)
signal travel_requested(map_id: String)
signal map_requested()
signal save_slot_requested(slot: int)
signal load_slot_requested(slot: int)
signal housing_purchase_requested()
signal housing_open_requested()
signal visual_quality_changed(level: int)
const Core = preload("res://scripts/rpg_core.gd")
const ArtAssets = preload("res://scripts/art_assets.gd")
const CArtOverrides = preload("res://scripts/c_art_overrides.gd")
const CArtItemIcons = preload("res://scripts/c_art_item_icons.gd")
const CArtNavigationIcons = preload("res://scripts/c_art_navigation_icons.gd")
const CArtUIFrame = preload("res://scripts/c_art_ui_frame.gd")
const Ambient = preload("res://scripts/chapter_ambient.gd")
const WorldDiscoveries = preload("res://scripts/world_discoveries.gd")
const WorldDungeonPuzzles = preload("res://scripts/world_dungeon_puzzles.gd")
const WorldTownEcology = preload("res://scripts/world_town_ecology.gd")
const WorldFieldEcology = preload("res://scripts/world_field_ecology.gd")
const SECTIONS: Array[String] = ["队伍","背包","武器","防具","技能","职业","任务","剧情后续","地区探索","图鉴","商店","锻造","结局档案","冒险履历","存档管理","家园","设置"]
const NAV_GROUPS: Dictionary = {
    "冒险": ["任务","剧情后续","地区探索","冒险履历"],
    "伙伴": ["队伍","职业","技能"],
    "装备": ["背包","武器","防具","商店","锻造"],
    "收藏": ["图鉴","结局档案"],
    "生活": ["家园"],
    "系统": ["存档管理","设置"]
}
var manager
var save_state
var root: Control
var content: VBoxContainer
var footer: Label
var title: Label
var current: String = "队伍"
var member: String = ""
var encyclopedia: String = "monsters"
var quest_filter: String = "全部"
var quest_page: int = 0
var branch_page: int = 0
var active_group: String = "伙伴"
var section_tabs: HBoxContainer
var branch_runtime
var chapter_details
var discovery_catalog = WorldDiscoveries.new()
var dungeon_puzzle_catalog = WorldDungeonPuzzles.new()
var town_ecology_catalog = WorldTownEcology.new()
var field_ecology_catalog = WorldFieldEcology.new()
var world_router
var game_events
var slot_service
var housing

func _ready() -> void:
    layer = 46
    chapter_details = Ambient.new()
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    var shadow := ColorRect.new()
    shadow.color = Color(0.015,0.032,0.055,0.97)
    shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(shadow)
    var panel := PanelContainer.new()
    panel.anchor_left = 0.03
    panel.anchor_right = 0.97
    panel.anchor_top = 0.03
    panel.anchor_bottom = 0.97
    panel.add_theme_stylebox_override("panel", CArtUIFrame.panel_frame())
    root.add_child(panel)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation",7)
    panel.add_child(body)
    var headline := HBoxContainer.new()
    body.add_child(headline)
    title = Label.new()
    title.text = "✦ 星灯纪行  ·  功能手册"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size",24)
    title.add_theme_color_override("font_color",Color("e6c47d"))
    headline.add_child(title)
    _button(headline,"退出",func() -> void: close_menu())
    var groups := HBoxContainer.new()
    groups.add_theme_constant_override("separation",7)
    body.add_child(groups)
    for key in NAV_GROUPS.keys():
        var group_id: String = str(key)
        _button(groups,"◆ " + group_id,func() -> void: _select_group(group_id),14)
    var tab_scroll := ScrollContainer.new()
    tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tab_scroll.custom_minimum_size.y = 52
    body.add_child(tab_scroll)
    section_tabs = HBoxContainer.new()
    section_tabs.add_theme_constant_override("separation",7)
    tab_scroll.add_child(section_tabs)
    _select_group(active_group)
    var scroller := ScrollContainer.new()
    scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(scroller)
    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation",7)
    scroller.add_child(content)
    footer = Label.new()
    footer.custom_minimum_size.y = 26
    footer.add_theme_color_override("font_color",Color("e6c47d"))
    footer.add_theme_font_size_override("font_size",16)
    body.add_child(footer)
    root.hide()

func _button(where: Node, caption: String, callback: Callable, size: int = 17) -> void:
    var b := Button.new()
    b.text = caption
    b.icon = CArtNavigationIcons.icon_for(caption)
    b.expand_icon = false
    b.custom_minimum_size.y = 43
    b.add_theme_font_size_override("font_size",size)
    where.add_child(b)
    b.pressed.connect(callback)

func _icon_button(where: Node, caption: String, id: String, callback: Callable, size: int = 17) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size.y = 43
    button.add_theme_font_size_override("font_size", size)
    button.icon = CArtItemIcons.texture_for(id)
    button.expand_icon = false
    where.add_child(button)
    button.pressed.connect(callback)

func _select_group(group_id: String) -> void:
    if not NAV_GROUPS.has(group_id):
        return
    active_group = group_id
    for existing in section_tabs.get_children():
        section_tabs.remove_child(existing)
        existing.queue_free()
    for entry in NAV_GROUPS[group_id]:
        var section: String = str(entry)
        _button(section_tabs,section,func() -> void: render(section),15)
    if manager != null and save_state != null:
        render(str(NAV_GROUPS[group_id][0]))

func _label(text_value: String, bigger: bool = false) -> void:
    var l := Label.new()
    l.text = text_value
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size",22 if bigger else 16)
    if bigger:
        l.add_theme_color_override("font_color",Color("e6c47d"))
    content.add_child(l)

func show_menu(core, state) -> void:
    manager = core
    save_state = state
    if member.is_empty() and not state.actors.is_empty():
        member = str(state.actors[0].get("id",""))
    root.show()
    render(current)

func close_menu() -> void:
    if root.visible:
        root.hide()
        closed.emit()

func _unhandled_input(event: InputEvent) -> void:
    if root.visible and event.is_action_pressed("ui_cancel"):
        close_menu()
        get_viewport().set_input_as_handled()

func _apply(message: String) -> void:
    save_state.save()
    render(current)
    footer.text = message

func _apply_visual_quality(level: int) -> void:
    # Save first; never show a quality setting as persisted when its write fails.
    var setting: Dictionary = save_state.rpg.get("settings",{})
    var previous: Variant = setting.get("visual_quality",1)
    var was_defined: bool = setting.has("visual_quality")
    var requested: int = clampi(level,0,2)
    setting["visual_quality"] = requested
    save_state.rpg["settings"] = setting
    if not save_state.save():
        if was_defined:
            setting["visual_quality"] = previous
        else:
            setting.erase("visual_quality")
        footer.text = "画质设置保存失败，已保留原配置。"
        return
    visual_quality_changed.emit(requested)
    render("设置")
    footer.text = "画质已更新并保存。切换地图时仍沿用这一档位。"


func _choose(pid: String) -> void:
    member = pid
    render(current)

func _select_actor() -> void:
    var h := HBoxContainer.new()
    content.add_child(h)
    for actor in save_state.actors:
        var pid: String = str(actor.get("id",""))
        _button(h,("▶ " if pid == member else "") + str(actor.get("name",pid)),func() -> void: _choose(pid),14)

func _icon_label(label_text: String, id: String) -> void:
    var image: Texture2D = CArtItemIcons.texture_for(id)
    if image == null:
        _label(label_text)
        return
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    content.add_child(row)
    var icon_rect := TextureRect.new()
    icon_rect.texture = image
    icon_rect.custom_minimum_size = Vector2(30, 30)
    icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    row.add_child(icon_rect)
    var caption := Label.new()
    caption.text = label_text
    caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    caption.add_theme_font_size_override("font_size", 16)
    row.add_child(caption)

func _branch_page(delta: int) -> void:
    branch_page = maxi(0,branch_page + delta)
    render("剧情后续")

func _filter_quest(value: String) -> void:
    quest_filter = value
    quest_page = 0
    render("任务")

func _page_quest(delta: int) -> void:
    quest_page = maxi(0, quest_page + delta)
    render("任务")

func render(section: String) -> void:
    if manager == null or save_state == null:
        return
    current = section
    title.text = "✦ 星灯纪行 · " + active_group + " / " + section
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    footer.text = "金币 %d G  ·  Lv/装备/职业/任务变更自动保存" % int(save_state.gold)
    match section:
        "队伍":
            _label("伙伴编成 · 最多4位出战",true)
            for actor in save_state.actors:
                var pid: String = str(actor.get("id",""))
                var stats: Dictionary = manager.gear_stats(pid)
                var actor_row := HBoxContainer.new()
                actor_row.add_theme_constant_override("separation", 12)
                content.add_child(actor_row)
                var head_path: String = ArtAssets.party_head(pid)
                if not head_path.is_empty():
                    var head := TextureRect.new()
                    head.texture = CArtOverrides.texture(head_path)
                    head.custom_minimum_size = Vector2(64, 64)
                    head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                    head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                    head.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
                    actor_row.add_child(head)
                var summary := VBoxContainer.new()
                summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                actor_row.add_child(summary)
                var stats_label := Label.new()
                stats_label.text = "%s %s Lv.%d  HP %d/%d  MP %d/%d  攻%d  防%d" % ["●" if manager.is_active(pid) else "○",str(actor.get("name","")),int(actor.get("level",1)),int(actor.get("hp",0)),int(stats.get("max_hp",0)),int(actor.get("mp",0)),int(stats.get("max_mp",0)),int(stats.get("attack",0)),int(stats.get("defense",0))]
                stats_label.add_theme_font_size_override("font_size", 16)
                summary.add_child(stats_label)
                _button(summary,"变更 %s 出战状态" % str(actor.get("name","")),func() -> void: _apply(manager.toggle_party(pid)),14)
        "背包":
            _label("背包 · 选择道具使用对象",true)
            _select_actor()
            for key in save_state.inventory.keys():
                var item_id: String = str(key)
                if manager.count(item_id) < 1:
                    continue
                var text_value: String = "%s ×%d" % [manager.display_name(item_id),manager.count(item_id)]
                if not manager.entry("items",item_id).is_empty():
                    _icon_button(content,"使用 · "+text_value,item_id,func() -> void: _apply(manager.use_item(item_id,member)))
                else:
                    _icon_label("装备 · "+text_value,item_id)
        "武器","防具":
            _label("可装备的道具与部位",true)
            _select_actor()
            var slots: Dictionary = save_state.rpg["equipment"].get(member,{})
            for slot in Core.SLOTS:
                if (section == "武器" and slot != "weapon") or (section == "防具" and slot == "weapon"):
                    continue
                var equipped: String = str(slots.get(slot,""))
                _label("%s：%s" % [slot,"（空）" if equipped.is_empty() else manager.display_name(equipped)])
                if not equipped.is_empty():
                    _button(content,"卸下 "+manager.display_name(equipped),func() -> void: _apply(manager.unequip(member,slot)))
            var table: String = "weapons" if section == "武器" else "armor"
            for object in manager.records(table):
                var item_id: String = str(object.get("id",""))
                if manager.count(item_id) < 1:
                    continue
                var slot: String = "weapon" if table == "weapons" else str(object.get("slot",""))
                _icon_button(content,"装备 "+str(object.get("name",item_id))+"  [库存 %d]" % manager.count(item_id),item_id,func() -> void: _apply(manager.equip(member,slot,item_id)))
        "技能":
            _label("职业技能 · 专精8阶可继承该职业的初阶技",true)
            _select_actor()
            for record in manager.skills(member):
                _icon_label("◆ %s  MP %d  %s" % [str(record.get("name","")),int(record.get("mp_cost",0)),str(record.get("description",""))],str(record.get("id","")))
        "职业":
            _label("二十职业转职 · 保留经验、熟练度与已继承技能",true)
            _select_actor()
            var current_job: String = str(save_state.rpg["jobs"].get(member,"swordsman"))
            var current_rank: Dictionary = manager.job_record(member,current_job)
            _label("当前职业："+manager.job_name(current_job)+" · 熟练 %d阶 / 8阶 · %d职业经验" % [int(current_rank.get("rank",1)),int(current_rank.get("xp",0))])
            _label("基础职业随时可转；第13章起通过熟练度解锁高级职业，第49章起可解锁终阶职业。")
            _label("角色定位：" + str(manager.jobs.get(current_job,{}).get("role","冒险")) + " · 职业增益随熟练度阶段成长。")
            _label("熟练8阶后永久保留该职业的1～3阶技能；受角色等级限制。不适用武器会自动归还背包。")
            for job in manager.jobs.keys():
                var job_id: String = str(job)
                var row: Dictionary = manager.jobs[job]
                var reason: String = manager.job_unlock_reason(member,job_id)
                if reason.is_empty():
                    _button(content,"%s / 熟练%d阶 / %s" % [str(row.get("name",job_id)),manager.job_rank(member,job_id),str(row.get("role",""))],func() -> void: _apply(manager.change_job(member,job_id)),15)
                else:
                    _label("🔒 "+str(row.get("name",job_id))+" · "+reason)
        "剧情后续":
            _label("支线后续 · 已完成委托的A/B独立回访",true)
            _label("只出现当前存档已选路线且满足章节条件的事件。此为第19阶段临时游玩入口，后续会改为地图NPC/物件触发。")
            if branch_runtime == null or not branch_runtime.errors.is_empty():
                _label("剧情扩展数据尚未加载。")
            else:
                var available: Array = branch_runtime.eligible_events(1000)
                _label("目前可触发 %d 场；翻页不会跳过剧情顺序。" % available.size())
                var field_archive: Dictionary = save_state.rpg.get("branch_story",{}).get("field_log",{})
                if not field_archive.is_empty():
                    _label("现场调查档案 · 已记录 %d 场（只保存实际完成的步骤）" % field_archive.size(),true)
                    var recent: Array = field_archive.keys()
                    recent.reverse()
                    for journal_index in range(mini(4,recent.size())):
                        var journal_id: String = str(recent[journal_index])
                        var journal_event: Dictionary = branch_runtime.get_event(journal_id)
                        var journal_lines: Array = journal_event.get("dialogue",[])
                        var notes: Array = field_archive[journal_id]
                        _label("%s · %d/3线索" % [str(journal_event.get("title",journal_id)),notes.size()])
                        for note in notes:
                            var index: int = int(note.get("step",-1))
                            if index>=0 and index<journal_lines.size():
                                _label("  %s · %s" % [["证言","证物","记录"][clampi(index,0,2)],str(journal_lines[index].get("text","")).left(48)])
                branch_page = clampi(branch_page,0,maxi(0,(available.size()-1)/8))
                for index in range(branch_page*8,mini(available.size(),(branch_page+1)*8)):
                    var row: Dictionary = available[index]
                    var event_id: String = str(row.get("id",""))
                    var heading: String = "%s · %s" % [str(row.get("region","伙伴尾声")),str(row.get("title",""))]
                    _label(heading)
                    var actions := HBoxContainer.new()
                    content.add_child(actions)
                    _button(actions,"地图追踪",func() -> void: branch_navigation_requested.emit(event_id),14)
                    _button(actions,"回顾对白",func() -> void: branch_event_requested.emit(event_id),14)
                var pagination := HBoxContainer.new()
                content.add_child(pagination)
                _button(pagination,"上一页",func() -> void: _branch_page(-1),14)
                _button(pagination,"下一页",func() -> void: _branch_page(1),14)
        "任务":
            _label("主线 · 第%d章 %s" % [save_state.chapter,manager.chapter_name(save_state.chapter)],true)
            _label("任务进度按对话、线索和战斗实体事件写入，不接受无条件直接领取奖励。")
            var current_side: Dictionary = manager.available_story_side(save_state.chapter)
            if not current_side.is_empty():
                var count: int = manager.story_side_stage(str(current_side.get("id","")))
                var total: int = current_side.get("stages",[]).size()
                _label("【世界支线】%s · 阶段 %d/%d" % [str(current_side.get("title","")),count + 1,total])
                _label("请前往地图蓝色标记互动，完成实地调查。")
            _label("世界委托选择：失落航页12条、同伴48条、地区36条，共96条分类型委托；另有24条人生支线。")
            var filters := HBoxContainer.new()
            content.add_child(filters)
            for category in ["全部","航页","同伴","地区","人生"]:
                var group: String = category
                _button(filters,group,func() -> void: _filter_quest(group),13)
            var selectable: Array = []
            for quest in manager.available_story_side_list(save_state.chapter):
                var kind: String = str(quest.get("type",""))
                var type_label: String = "航页" if kind == "lost_page" else ("同伴" if kind == "companion" else ("地区" if kind == "regional_v2" else "人生"))
                if quest_filter == "全部" or quest_filter == type_label:
                    selectable.append(quest)
            var start_at: int = quest_page * 10
            var end_at: int = mini(start_at + 10,selectable.size())
            _label("筛选：%s · 可接取 %d 条 · 第%d页" % [quest_filter,selectable.size(),quest_page+1])
            for n in range(start_at,end_at):
                var task: Dictionary = selectable[n]
                var task_id: String = str(task.get("id",""))
                var stage_no: int = manager.story_side_stage(task_id)
                _button(content,("▶ " if str(save_state.rpg.get("selected_story_quest","")) == task_id else "◇ ") + str(task.get("title","")) + " · %d/%d" % [stage_no + 1,(task.get("stages",[]) as Array).size()],func() -> void: _apply(manager.select_story_side(task_id)),14)
            if quest_page > 0:
                _button(content,"◀ 上一页",func() -> void: _page_quest(-1))
            if end_at < selectable.size():
                _button(content,"下一页 ▶",func() -> void: _page_quest(1))
            var shown: int = 0
            for quest in manager.records("quests"):
                var chapter_value: Variant = quest.get("chapter", null)
                if chapter_value == null:
                    continue
                if not (chapter_value is int or chapter_value is float):
                    push_warning("任务章节格式无效：" + str(quest.get("id", "")))
                    continue
                if int(chapter_value) > save_state.chapter:
                    continue
                _label(("✓ " if save_state.rpg["quests"].has(str(quest.get("id",""))) else "◇ ")+str(quest.get("name",""))+" "+str(quest.get("objective","")))
                shown += 1
                if shown >= 30:
                    break
        "地区探索":
            _label("第%d章 · 场景调查与居民见证" % save_state.chapter,true)
            var acquired: int = 0
            for place in discovery_catalog.maps.keys():
                for event in discovery_catalog.entries(str(place)):
                    if bool(save_state.flags.get(discovery_catalog.flag(str(place),str(event.get("id",""))),false)):
                        acquired += 1
            _label("世界探索档案 · %d / 120 处" % acquired,true)
            var solved_total: int = 0
            for dungeon_id in dungeon_puzzle_catalog.maps.keys():
                if bool(dungeon_puzzle_catalog.snapshot(save_state,str(dungeon_id)).get("claimed",false)):
                    solved_total += 1
            _label("独立地下城机关 · %d / 8" % solved_total)
            var finished_communities: int = 0
            for town_id in town_ecology_catalog.towns.keys():
                if town_ecology_catalog.completion_count(save_state,str(town_id))==3:
                    finished_communities += 1
            _label("特色城镇生活 · %d / 11" % finished_communities)
            var finished_fields: int=0
            for field_id in field_ecology_catalog.maps.keys():
                if field_ecology_catalog.completed(save_state,str(field_id))==4:
                    finished_fields+=1
            _label("21区独立野外生态 · %d / 21" % finished_fields)
            if world_router != null:
                var location: String = world_router.current_map()
                var dungeon_spec: Dictionary = dungeon_puzzle_catalog.config(location)
                if not dungeon_spec.is_empty():
                    var cleared: bool = bool(dungeon_puzzle_catalog.snapshot(save_state,location).get("claimed",false))
                    _label(("✓ " if cleared else "◇ ")+str(dungeon_spec.get("title","古代机关"))+(" · 已解开" if cleared else " · 尚未解开"))
                    if not cleared:
                        _label(str(dungeon_spec.get("hint","")))
                var neighborhood: Dictionary = town_ecology_catalog.config(location)
                if not neighborhood.is_empty():
                    var progress_count: int = town_ecology_catalog.completion_count(save_state,location)
                    _label("本地社区 · "+str(neighborhood.get("activity","街区活动"))+" · %d/3" % progress_count,true)
                    var hour: int = int(float(save_state.rpg.get("game_clock",{}).get("minutes",480))/60.0)
                    var done_state: Dictionary = town_ecology_catalog.progress(save_state,location)
                    for entry in town_ecology_catalog.entries(location):
                        var completed: bool = bool(done_state.get(str(entry.get("id","")),false))
                        var available: bool = town_ecology_catalog.is_open(entry,hour)
                        _label(("✓ " if completed else "◇ ")+str(entry.get("district","街区"))+" · "+str(entry.get("title","社区活动"))+(" · 已记录" if completed else (" · 营业中" if available else " · 非活动时间")))
                var field_spec: Dictionary=field_ecology_catalog.config(location)
                if not field_spec.is_empty():
                    _label("野外挑战 · "+str(field_spec.get("identity","地区探查"))+" · %d / 4" % field_ecology_catalog.completed(save_state,location),true)
                    var field_progress: Dictionary=field_ecology_catalog.snapshot(save_state,location)
                    for site in field_ecology_catalog.sites(location):
                        var site_id: String=str(site.get("id",""))
                        var cleared: bool=bool(field_progress.get({"trial":"trial","gather":"harvested","passage":"passage","cache":"claimed"}.get(site_id,""),false))
                        _label(("✓ " if cleared else "◇ ")+str(site.get("title","野外地点"))+(" · 已记录" if cleared else " · 尚未发现"))
                    _button(content,"打开当前区域地图，寻找环境线索",func() -> void: map_requested.emit(),15)
                var local_events: Array = discovery_catalog.entries(location)
                if not local_events.is_empty():
                    var done: int = 0
                    for event in local_events:
                        var complete: bool = bool(save_state.flags.get(discovery_catalog.flag(location,str(event.get("id",""))),false))
                        if complete:
                            done += 1
                        _label(("✓ " if complete else "◇ ") + str(event.get("name","地区线索")) + (" · 已记录" if complete else " · 尚未调查"))
                        if complete:
                            _label(str(event.get("text","")))
                    var area_record: Dictionary = discovery_catalog.maps.get(location,{})
                    _label("当前地区：%s · %d / %d" % [str(area_record.get("name",location)),done,local_events.size()])
                    _button(content,"打开当前区域地图，寻找未调查地点",func() -> void: map_requested.emit(),15)
            if save_state.chapter < 1:
                _label("童年序章结束后，每章开放两处独立调查物件及一段隐藏证言。")
            else:
                for item in chapter_details.objects(save_state.chapter):
                    var flag: String = str(item.get("investigation_flag",""))
                    var completed: bool = bool(save_state.flags.get(flag,false))
                    _label(("✓ " if completed else "◇ ")+str(item.get("name","区域物件"))+" · "+("已记录" if completed else "可到地图现场调查"))
                    if completed:
                        _label(str(item.get("description","")))
                var midpoint_flag: String = "explore.ch%03d.midpoint" % save_state.chapter
                _label(("✓ " if bool(save_state.flags.get(midpoint_flag,false)) else "◇ ")+"中段证言：需先记录两处物件")
                var npc: Dictionary = chapter_details.npc_state(save_state.chapter,2,save_state.flags)
                if not npc.is_empty():
                    _label("在地居民：" + str(npc.get("speaker","")) + " · " + str(npc.get("text","")))
        "图鉴":
            _label("图鉴 · "+encyclopedia,true)
            var bar := HBoxContainer.new()
            content.add_child(bar)
            for category in ["characters","monsters","story_bosses","bosses","items","weapons","armor","regions"]:
                var cat: String = category
                _button(bar,cat,func() -> void:
                    encyclopedia = cat
                    render("图鉴")
                ,13)
            var secret: bool = encyclopedia in ["monsters","story_bosses"]
            var unlocked: int = 0
            for row in manager.records(encyclopedia):
                var item_id: String = str(row.get("id",""))
                if secret:
                    var seen: Dictionary = manager.codex_record(encyclopedia,item_id)
                    if not bool(seen.get("seen",false)):
                        _label("◇ ？？？ · 尚未遭遇")
                        continue
                    unlocked += 1
                    _label("◆ %s · 已解决%d次" % [str(row.get("name",item_id)),int(seen.get("resolved",0))])
                else:
                    if encyclopedia in ["items", "weapons", "armor"]:
                        _icon_label("◇ "+str(row.get("name",""))+" / "+item_id, item_id)
                    else:
                        _label("◇ "+str(row.get("name",""))+" / "+item_id)
            if secret:
                _label("已发现 %d/%d 种；亲自遭遇后才解锁档案。" % [unlocked,manager.records(encyclopedia).size()])
        "商店":
            _label("商店：购买 / 出售",true)
            _label("第%d章商品档次：1～%d阶（最高10阶随主线开放）" % [save_state.chapter,manager.market_tier()])
            for cat in ["items","weapons","armor"]:
                for entry in manager.records(cat):
                    var key: String = str(entry.get("id",""))
                    var price: int = int(entry.get("buy_price",entry.get("price",0)))
                    if price <= 0 or not manager.shop_available(entry):
                        continue
                    _icon_button(content,"买 "+str(entry.get("name",""))+"  "+str(price)+"G",key,func() -> void: _apply(manager.buy(key)),14)
            _label("出售背包",true)
            for key in save_state.inventory.keys():
                var id: String = str(key)
                if manager.count(id) > 0:
                    _icon_button(content,"出售 "+manager.display_name(id),id,func() -> void: _apply(manager.sell(id)),14)
        "锻造":
            _label("锻造：2把同型武器 + 金币 → 下一阶",true)
            var possible: bool = false
            for entry in manager.records("weapons"):
                var id: String = str(entry.get("id",""))
                if manager.count(id) >= 2:
                    possible = true
                    _icon_button(content,"锻造 "+str(entry.get("name",id)),id,func() -> void: _apply(manager.forge(id)))
            if not possible:
                _label("收集两把相同武器后，这里会显示可操作配方。")
        "结局档案":
            _label("命运之书 · 已解锁结局",true)
            var archive: Dictionary = save_state.rpg.get("ending_archive", {})
            for ending_id in ["A","B","C"]:
                var eid: String = str(ending_id)
                var ending_name: String = {"A":"守灯之世","B":"无灯之晨","C":"万家星灯"}[eid]
                if bool(archive.get(eid, false)):
                    _button(content,"▶ 回放 %s · %s" % [eid,ending_name],func() -> void: replay_ending_requested.emit(eid))
                else:
                    _label("🔒 %s · %s（未解锁）" % [eid,ending_name])
            _label("结局的四段完整后日谈会在第72章的最终抉择后保存，可在此回放。")
        "冒险履历":
            _label("旅程记录 / 探索成就",true)
            if game_events != null:
                _label("第%d天 · %s · %s" % [int(save_state.rpg["game_clock"].get("day",1)),game_events.time_label(),game_events.phase()])
                var badges: Dictionary = save_state.rpg.get("achievements",{})
                for item in badges:
                    if bool(badges[item]):
                        _label("★ " + str(item))
                var history: Array = game_events.history()
                _label("最近事件（最多160条历史记录）",true)
                for idx in range(history.size()-1,maxi(-1,history.size()-16),-1):
                    var item: Dictionary = history[idx]
                    _label("第%d章 · %s" % [int(item.get("chapter",0)),str(item.get("kind",""))])
        "存档管理":
            _label("多档位存档 · 3个独立手动槽位",true)
            if slot_service != null:
                for slot in range(1,4):
                    var n: int = slot
                    var info: Dictionary = slot_service.summary(n)
                    _label("槽位 %d：%s" % [n,("第%d章 / %dG" % [int(info.get("chapter",0)),int(info.get("gold",0))]) if bool(info.get("exists",false)) else "空槽位"])
                    _button(content,"写入存档 %d" % n,func() -> void: save_slot_requested.emit(n))
                    if bool(info.get("exists",false)):
                        _button(content,"载入存档 %d" % n,func() -> void: load_slot_requested.emit(n))
                _label("主游戏仍自动保存到原V3路径；手动档槽位拥有独立备份。")
        "家园":
            _label("星灯旅人之家 · 居所与装饰",true)
            if housing == null or world_router == null:
                _label("房屋系统尚未载入。")
            else:
                var location: Dictionary = world_router.profile()
                if not housing.owned():
                    _label("在城镇购买地契，得到一间10×7室内房屋，附赠床和仓库箱。")
                    _label("地契价格：160G · 当前金币 %dG" % save_state.gold)
                    if housing.can_access(location) and save_state.chapter >= 1:
                        _button(content,"在当前城镇购买住宅",func() -> void: housing_purchase_requested.emit())
                    else:
                        _label("请前往开放的城镇住宅区。")
                else:
                    _label("房屋等级：%d · 所属地区：%s" % [int(housing.data().get("tier",0))+1,str(housing.data().get("region_id",""))])
                    _label("家具 %d/%d · 仓库 %d/%d" % [(housing.data()["placed"] as Array).size(),housing.capacity(),housing.warehouse_total(),housing.warehouse_capacity()])
                    _label("墙面："+str(housing.data().get("wall",""))+" / 地板："+str(housing.data().get("floor","")))
                    if housing.can_access(location) and str(location.get("region_id","")) == str(housing.data().get("region_id","")):
                        _button(content,"进入住宅 · 布置家具 / 储存 / 休息",func() -> void: housing_open_requested.emit())
                    else:
                        _label("返回住宅所属地区的城镇，才能进入房屋。")
                    _label("20种家具、10×7房间、四级升级、摆放收回、换装、仓库和床铺休息。")
        "设置":
            _label("游戏难度与个人配置",true)
            _label("当前难度："+str(save_state.rpg["settings"].get("difficulty","标准")))
            for level in ["休闲","标准","挑战"]:
                var value: String = level
                _button(content,"战斗难度： "+value,func() -> void:
                    save_state.rpg["settings"]["difficulty"] = value
                    _apply("难度设为 "+value+"，下次进入战斗后生效。")
                )
            _label("当前画质："+["省电","标准","高清"][clampi(int(save_state.rpg["settings"].get("visual_quality",1)),0,2)],true)
            for quality in range(3):
                var q: int=quality
                _button(content,"画质： "+["省电","标准","高清"][q],func() -> void:
                    _apply_visual_quality(q)
                )
            _label("省电：减少天气和水面动画，简化室内灯光；标准：平衡性能；高清：完整动态光影。")
            _label("休闲：敌方攻击72% · 标准：正常 · 挑战：敌方攻击138%。")
            _label("全篇战斗与技能遵循同一数值规则；第5、6章剧情胜利条件不受难度变化影响。")
            _button(content,"立即保存",func() -> void: _apply("已写入存档。" if save_state.save() else "存档写入失败。"))
            _label("金手指入口：右上角星星连点5次，或PC按F10。密码9169。")
            _label("当前进度含：队伍、职业、武器防具、库存、任务、地图与章节。")
