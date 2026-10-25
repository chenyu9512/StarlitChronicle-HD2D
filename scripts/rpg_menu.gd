extends CanvasLayer
## 手机和桌面通用的大功能栏：十二个栏目均提供有用的数据或操作。
signal closed()
signal replay_ending_requested(id: String)
const Core = preload("res://scripts/rpg_core.gd")
const SECTIONS: Array[String] = ["队伍","背包","武器","防具","技能","职业","任务","世界地图","图鉴","商店","锻造","结局档案","设置"]
var manager
var save_state
var root: Control
var content: VBoxContainer
var footer: Label
var title: Label
var current: String = "队伍"
var member: String = ""
var encyclopedia: String = "monsters"

func _ready() -> void:
    layer = 46
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
    var tab_scroll := ScrollContainer.new()
    tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tab_scroll.custom_minimum_size.y = 55
    body.add_child(tab_scroll)
    var tabs := HBoxContainer.new()
    tab_scroll.add_child(tabs)
    for section in SECTIONS:
        var s: String = section
        _button(tabs,s,func() -> void: render(s),14)
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

func render(section: String) -> void:
    if manager == null or save_state == null:
        return
    current = section
    title.text = "✦ 星灯纪行 / " + section
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
            _label("当前职业："+manager.job_name(str(save_state.rpg["jobs"].get(member,""))))
            for job in manager.jobs.keys():
                var job_id: String = str(job)
                var row: Dictionary = manager.jobs[job]
                _button(content,str(row.get("name",job_id))+"  /  "+str(row.get("role","")),func() -> void: _apply(manager.change_job(member,job_id)),15)
        "任务":
            _label("主线 · 第%d章 %s" % [save_state.chapter,manager.chapter_name(save_state.chapter)],true)
            _label("任务进度按对话、线索和战斗实体事件写入，不接受无条件直接领取奖励。")
            var current_side: Dictionary = manager.available_story_side(save_state.chapter)
            if not current_side.is_empty():
                var count: int = manager.story_side_stage(str(current_side.get("id","")))
                var total: int = current_side.get("stages",[]).size()
                _label("【世界支线】%s · 阶段 %d/%d" % [str(current_side.get("title","")),count + 1,total])
                _label("请前往地图蓝色标记互动，完成实地调查。")
            var shown: int = 0
            for quest in manager.records("quests"):
                if int(quest.get("chapter",99)) > save_state.chapter:
                    continue
                _label(("✓ " if save_state.rpg["quests"].has(str(quest.get("id",""))) else "◇ ")+str(quest.get("name",""))+" "+str(quest.get("objective","")))
                shown += 1
                if shown >= 30:
                    break
        "世界地图":
            _label("已发现的区域",true)
            for region in save_state.rpg["regions"].keys():
                _label("◆ "+str(region))
            _label("全游戏包含 %d 项地图设计数据；新地区随剧情解锁。" % manager.records("maps").size())
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
        "设置":
            _label("系统与存档",true)
            _button(content,"立即保存",func() -> void: _apply("已写入存档。" if save_state.save() else "存档写入失败。"))
            _label("金手指入口：右上角星星连点5次，或PC按F10。密码9169。")
            _label("当前进度含：队伍、职业、武器防具、库存、任务、地图与章节。")
