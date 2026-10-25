extends CanvasLayer
## 手机和桌面通用的大功能栏：十二个栏目均提供有用的数据或操作。
signal closed()
signal replay_ending_requested(id: String)
signal travel_requested(map_id: String)
signal map_requested()
signal save_slot_requested(slot: int)
signal load_slot_requested(slot: int)
signal housing_purchase_requested()
signal housing_open_requested()
const Core = preload("res://scripts/rpg_core.gd")
const Ambient = preload("res://scripts/chapter_ambient.gd")
const SECTIONS: Array[String] = ["队伍","背包","武器","防具","技能","职业","任务","世界地图","地区探索","图鉴","商店","锻造","结局档案","冒险履历","存档管理","家园","设置"]
const NAV_GROUPS: Dictionary = {
    "冒险": ["任务","世界地图","地区探索","冒险履历"],
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
var active_group: String = "伙伴"
var section_tabs: HBoxContainer
var chapter_details
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
    var style := StyleBoxFlat.new()
    style.bg_color = Color("0b1c32")
    style.border_color = Color("e6c47d")
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(12)
    panel.add_theme_stylebox_override("panel",style)
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
    b.custom_minimum_size.y = 43
    b.add_theme_font_size_override("font_size",size)
    where.add_child(b)
    b.pressed.connect(callback)

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

func _choose(pid: String) -> void:
    member = pid
    render(current)

func _select_actor() -> void:
    var h := HBoxContainer.new()
    content.add_child(h)
    for actor in save_state.actors:
        var pid: String = str(actor.get("id",""))
        _button(h,("▶ " if pid == member else "") + str(actor.get("name",pid)),func() -> void: _choose(pid),14)

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
                _label("%s %s Lv.%d  HP %d/%d  MP %d/%d  攻%d  防%d" % ["●" if manager.is_active(pid) else "○",str(actor.get("name","")),int(actor.get("level",1)),int(actor.get("hp",0)),int(stats.get("max_hp",0)),int(actor.get("mp",0)),int(stats.get("max_mp",0)),int(stats.get("attack",0)),int(stats.get("defense",0))])
                _button(content,"变更 %s 出战状态" % str(actor.get("name","")),func() -> void: _apply(manager.toggle_party(pid)))
        "背包":
            _label("背包 · 选择道具使用对象",true)
            _select_actor()
            for key in save_state.inventory.keys():
                var item_id: String = str(key)
                if manager.count(item_id) < 1:
                    continue
                var text_value: String = "%s ×%d" % [manager.display_name(item_id),manager.count(item_id)]
                if not manager.entry("items",item_id).is_empty():
                    _button(content,"使用 · "+text_value,func() -> void: _apply(manager.use_item(item_id,member)))
                else:
                    _label("装备 · "+text_value)
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
                _button(content,"装备 "+str(object.get("name",item_id))+"  [库存 %d]" % manager.count(item_id),func() -> void: _apply(manager.equip(member,slot,item_id)))
        "技能":
            _label("等级和职业解锁技能",true)
            _select_actor()
            for record in manager.skills(member):
                _label("◆ %s  MP %d  %s" % [str(record.get("name","")),int(record.get("mp_cost",0)),str(record.get("description",""))])
        "职业":
            _label("二十职业转职（保留经验/装备）",true)
            _select_actor()
            var current_job: String = str(save_state.rpg["jobs"].get(member,"swordsman"))
            var current_rank: Dictionary = manager.job_record(member,current_job)
            _label("当前职业："+manager.job_name(current_job)+" · 熟练 %d阶 / 8阶 · %d职业经验" % [int(current_rank.get("rank",1)),int(current_rank.get("xp",0))])
            _label("基础职业随时可转；第13章起通过熟练度解锁高级职业，第49章起可解锁终阶职业。")
            for job in manager.jobs.keys():
                var job_id: String = str(job)
                var row: Dictionary = manager.jobs[job]
                var reason: String = manager.job_unlock_reason(member,job_id)
                if reason.is_empty():
                    _button(content,"%s / 熟练%d阶 / %s" % [str(row.get("name",job_id)),manager.job_rank(member,job_id),str(row.get("role",""))],func() -> void: _apply(manager.change_job(member,job_id)),15)
                else:
                    _label("🔒 "+str(row.get("name",job_id))+" · "+reason)
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
                if int(quest.get("chapter",99)) > save_state.chapter:
                    continue
                _label(("✓ " if save_state.rpg["quests"].has(str(quest.get("id",""))) else "◇ ")+str(quest.get("name",""))+" "+str(quest.get("objective","")))
                shown += 1
                if shown >= 30:
                    break
        "世界地图":
            _label("世界航路 / 42地图 · 8大地区",true)
            _button(content,"◇ 展开图形世界地图（可触控地区、查看道路）",func() -> void: map_requested.emit(),17)
            if world_router == null:
                _label("地图服务暂未加载。")
            else:
                var current_map: Dictionary = world_router.profile()
                _label("当前位置：" + str(current_map.get("region_name","")) + " / " + str(current_map.get("name","")),true)
                _label("已到访 %d/42 处（含2个旧版地图规划记录）；此页面只允许通过已解锁的相邻出口。" % world_router.visited_count())
                for entry in world_router.neighbors():
                    var target: String = str(entry.get("id",""))
                    if bool(entry.get("unlocked",false)):
                        _button(content,"前往 ◇ "+str(entry.get("name",target)),func() -> void: travel_requested.emit(target),15)
                    else:
                        _label("🔒 尚未解锁 · "+str(entry.get("name",target))+"（需推进该区域剧情）")
                _label("未制作独立场景的地点暂使用可运行的地区风格地图模板，并不会被标记为正式美术已完成。")
        "地区探索":
            _label("第%d章 · 场景调查与居民见证" % save_state.chapter,true)
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
            for category in ["characters","monsters","bosses","items","weapons","armor","regions"]:
                var cat: String = category
                _button(bar,cat,func() -> void:
                    encyclopedia = cat
                    render("图鉴")
                ,13)
            for row in manager.records(encyclopedia):
                _label("◇ "+str(row.get("name",""))+" / "+str(row.get("id","")))
        "商店":
            _label("商店：购买 / 出售",true)
            for cat in ["items","weapons","armor"]:
                for entry in manager.records(cat):
                    var key: String = str(entry.get("id",""))
                    var price: int = int(entry.get("buy_price",entry.get("price",0)))
                    if price <= 0:
                        continue
                    _button(content,"买 "+str(entry.get("name",""))+"  "+str(price)+"G",func() -> void: _apply(manager.buy(key)),14)
            _label("出售背包",true)
            for key in save_state.inventory.keys():
                var id: String = str(key)
                if manager.count(id) > 0:
                    _button(content,"出售 "+manager.display_name(id),func() -> void: _apply(manager.sell(id)),14)
        "锻造":
            _label("锻造：2把同型武器 + 金币 → 下一阶",true)
            var possible: bool = false
            for entry in manager.records("weapons"):
                var id: String = str(entry.get("id",""))
                if manager.count(id) >= 2:
                    possible = true
                    _button(content,"锻造 "+str(entry.get("name",id)),func() -> void: _apply(manager.forge(id)))
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
            _label("休闲：敌方攻击72% · 标准：正常 · 挑战：敌方攻击138%。")
            _label("全篇战斗与技能遵循同一数值规则；第5、6章剧情胜利条件不受难度变化影响。")
            _button(content,"立即保存",func() -> void: _apply("已写入存档。" if save_state.save() else "存档写入失败。"))
            _label("金手指入口：右上角星星连点5次，或PC按F10。密码9169。")
            _label("当前进度含：队伍、职业、武器防具、库存、任务、地图与章节。")
