extends CanvasLayer
## Contextual town facility command panel; works with mouse, gamepad and touch.
signal action_requested(action: String)
signal closed()
const TownEcology = preload("res://scripts/world_town_ecology.gd")
const Act01Journey = preload("res://scripts/world_act01_journey.gd")
const ItemIcons = preload("res://scripts/c_art_item_icons.gd")
const PANEL_BLUE: Color = Color("0c2137")
const WARM_GOLD: Color = Color("e8c67c")
var root: Control
var panel: PanelContainer
var headline: Label
var subtitle: Label
var currency: Label
var choices: VBoxContainer
var feedback: Label
var current_kind: String = ""
var current_region: String = ""
var current_map: String = ""
var ecology = TownEcology.new()
var first_act_journey = Act01Journey.new()
var current_title: String = ""

func _ready() -> void:
    layer = 24
    root = Control.new()
    root.name = "RegionalService"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    var veil := ColorRect.new()
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.color = Color(0.02,0.04,0.07,0.86)
    root.add_child(veil)
    panel = PanelContainer.new()
    panel.anchor_left=0.18
    panel.anchor_right=0.82
    panel.anchor_top=0.11
    panel.anchor_bottom=0.89
    panel.add_theme_stylebox_override("panel",_box_style())
    root.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation",12)
    panel.add_child(column)
    headline=Label.new()
    headline.add_theme_font_size_override("font_size",30)
    headline.add_theme_color_override("font_color",WARM_GOLD)
    column.add_child(headline)
    subtitle=Label.new()
    subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    subtitle.add_theme_font_size_override("font_size",17)
    column.add_child(subtitle)
    currency=Label.new()
    currency.add_theme_font_size_override("font_size",18)
    currency.add_theme_color_override("font_color",Color("f7e0b2"))
    column.add_child(currency)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    choices=VBoxContainer.new()
    choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    choices.add_theme_constant_override("separation",8)
    scroll.add_child(choices)
    feedback=Label.new()
    feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    feedback.add_theme_color_override("font_color",Color("a8d8cf"))
    feedback.add_theme_font_size_override("font_size",16)
    column.add_child(feedback)
    var exit_button := _button("↩ 返回探索",false)
    exit_button.pressed.connect(close_service)
    column.add_child(exit_button)
    root.hide()

func _box_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color=PANEL_BLUE
    style.border_color=WARM_GOLD
    style.set_border_width_all(3)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(20)
    return style

func _button(text_value: String,muted: bool) -> Button:
    var b := Button.new()
    b.text=text_value
    b.custom_minimum_size.y=54
    b.add_theme_font_size_override("font_size",17)
    b.add_theme_color_override("font_color",Color("c4d0d4") if muted else Color("f7e6c4"))
    b.add_theme_stylebox_override("normal",_box_style())
    return b

func _clear() -> void:
    for child in choices.get_children():
        choices.remove_child(child)
        child.queue_free()

func _add_action(text_value: String,action_id: String,enabled: bool = true) -> void:
    var b: Button = _button(text_value,not enabled)
    # These are production shop/forge UI controls, not an art gallery.
    # Keep their canonical item IDs and click actions exactly unchanged.
    if action_id.begins_with("buy:") or action_id.begins_with("sell:") or action_id.begins_with("forge:"):
        var content_id: String = action_id.get_slice(":",1)
        var icon_texture: Texture2D = ItemIcons.texture_for(content_id)
        if icon_texture != null:
            b.icon = icon_texture
            b.add_theme_constant_override("h_separation",12)
            b.set_meta("content_icon_id",content_id)
    b.disabled=not enabled
    b.pressed.connect(func() -> void: action_requested.emit(action_id))
    choices.add_child(b)

func _add_note(text_value: String) -> void:
    var note := Label.new()
    note.text=text_value
    note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size",16)
    choices.add_child(note)

func open_service(kind: String, region_id: String, title: String, state,core,life,map_id: String = "") -> void:
    current_kind=kind
    current_region=region_id
    current_map=map_id
    current_title=title
    feedback.text=""
    root.show()
    refresh(state,core,life)

func refresh(state,core,life,message: String = "") -> void:
    if not root.visible:
        return
    _clear()
    headline.text="✦ "+current_title
    currency.text="持有金币：%d G    药草：%d" % [int(state.gold),int(state.potions)]
    feedback.text=message
    match current_kind:
        "shop":
            subtitle.text="地区补给 · 价格由正式道具表计算。购买将直接写入背包。"
            var goods: Array[String] = life.town_shop_ids(current_region,core)
            var special: String = ecology.specialty_item(current_map,core)
            if not special.is_empty() and not goods.has(special):
                goods.append(special)
                subtitle.text="本地特色物资 · "+str(ecology.config(current_map).get("activity","市场协作"))+"。采用正式道具表价格。"
            for item_id in goods:
                var info: Dictionary = core.entry("items",item_id)
                if info.is_empty():
                    info=core.entry("weapons",item_id)
                var price: int = int(info.get("buy_price",info.get("price",0)))
                var label: String = "%s  ·  %d G" % [str(info.get("name",item_id)),price]
                _add_action(label,"buy:"+item_id,price>0 and state.gold>=price and core.shop_available(info))
            if core.count("item_herb_01")>0:
                _add_action("出售盐露草  ·  回收 4 G","sell:item_herb_01")
        "inn":
            subtitle.text="客栈服务 · 休息恢复队伍生命与魔力，并推进旅途时间。"
            _add_action("入住一晚  ·  30 G  ·  HP / MP 全恢复","rest",int(state.gold)>=30)
        "smith":
            subtitle.text="装备工房 · 同型武器两把合成高一阶武器，使用金币支付工费。"
            var found: int=0
            for item in core.records("weapons"):
                var item_id: String = str(item.get("id",""))
                if core.count(item_id)>=2:
                    found+=1
                    _add_action("锻造 "+str(item.get("name",item_id))+" ×2","forge:"+item_id)
                    if found>=7:
                        break
            if found==0:
                _add_note("当前没有满足条件的同型武器。收集两把后可进行锻造。")
        "guild":
            subtitle.text="冒险者公会 · 每个地区各有一份独立讨伐委托。"
            var contract: Dictionary = life.guild_progress(current_region,state)
            var status: String = str(contract.get("state","available"))
            _add_note("地区讨伐进度：%d / %d" % [int(contract.get("progress",0)),int(contract.get("needed",3))])
            if status=="available":
                _add_action("领取地区讨伐委托（需要3场胜利）","guild")
            elif status=="ready":
                _add_action("提交完成报告并领取金币","guild")
            elif status=="active":
                _add_note("委托进行中。取得三场战斗胜利后回到本地区的公会。")
            else:
                _add_note("这片地区的委托已经完成。")
        "shrine":
            subtitle.text="祈灯祠 · 祈祷恢复队伍状态，原有剧情的选择不会被替代。"
            _add_action("祈灯祝福  ·  20 G  ·  恢复 HP / MP","blessing",int(state.gold)>=20)
        "house":
            subtitle.text="居民住宅 · 住宅系统与原有地契和家具存档共用。"
            _add_action("查看自家房屋与家具","home")
        _:
            subtitle.text="旅途中的生活设施。"
            _add_note("该设施目前不提供购买服务。")
    # Local, contextual story signpost for Act I. This NEVER changes the
    # global map, reveals fog, travels or modifies player quest/save state.
    if int(state.chapter)>=1 and int(state.chapter)<=6 and current_map.begins_with("map_coast_"):
        var direction: Dictionary=first_act_journey.preview(
            int(state.chapter),current_map,state)
        if bool(direction.get("valid",false)):
            _add_note("主线去向 · "+str(direction.get("guidance","")))
    if choices.get_child_count()==0:
        _add_note("当前没有可用指令。")

func is_open() -> bool:
    return root.visible

func close_service() -> void:
    if not root.visible:
        return
    root.hide()
    closed.emit()
