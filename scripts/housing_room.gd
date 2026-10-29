extends CanvasLayer
## 玩家家园的可操作房间：10x7格家具摆放、商店、仓库、休息与装修。
signal closed()
signal changed(message: String)
var housing
var progress
var rpg_core
var root: Control
var backdrop_panel: PanelContainer
var tiles: GridContainer
var list: VBoxContainer
var info: Label
var selected: String = ""
var mode: String = "摆放"
var resident_tile: Vector2i = Vector2i(4,5)

func _ready() -> void:
    layer = 52
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.015,0.03,0.06,0.97)
    root.add_child(shade)
    var frame := PanelContainer.new()
    backdrop_panel = frame
    frame.anchor_left = 0.02
    frame.anchor_right = 0.98
    frame.anchor_top = 0.03
    frame.anchor_bottom = 0.97
    var style := StyleBoxFlat.new()
    style.bg_color = Color("142638")
    style.border_color = Color("e5c57b")
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(13)
    frame.add_theme_stylebox_override("panel",style)
    root.add_child(frame)
    var v := VBoxContainer.new()
    frame.add_child(v)
    var heading := HBoxContainer.new()
    v.add_child(heading)
    var title := Label.new()
    title.text = "✦ 星灯旅人之家 · 家园布置"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size",23)
    heading.add_child(title)
    _button(heading,"离开房屋",func() -> void: close_house())
    info = Label.new()
    info.add_theme_font_size_override("font_size",16)
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(info)
    var main := HBoxContainer.new()
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(main)
    var room := VBoxContainer.new()
    room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main.add_child(room)
    var row := HBoxContainer.new()
    room.add_child(row)
    _button(row,"自由行走",func() -> void: _mode("行走"))
    _button(row,"摆放",func() -> void: _mode("摆放"))
    _button(row,"收回",func() -> void: _mode("收回"))
    _button(row,"在家休息",func() -> void: _result(housing.rest()))
    tiles = GridContainer.new()
    tiles.columns = 10
    tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tiles.size_flags_vertical = Control.SIZE_EXPAND_FILL
    room.add_child(tiles)
    var bar := ScrollContainer.new()
    bar.custom_minimum_size.x = 300
    bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_child(bar)
    list = VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.add_child(list)
    root.hide()

func _button(where: Node, title: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = title
    b.custom_minimum_size.y = 34
    b.add_theme_font_size_override("font_size",15)
    where.add_child(b)
    b.pressed.connect(callback)
    return b

func open_house(service, state, core = null) -> void:
    housing = service
    progress = state
    rpg_core = core
    selected = ""
    mode = "行走"
    resident_tile = Vector2i(4,5)
    root.show()
    render()

func close_house() -> void:
    if root.visible:
        root.hide()
        closed.emit()

func _unhandled_input(event: InputEvent) -> void:
    if root.visible and mode == "行走":
        var direction: Vector2i = Vector2i.ZERO
        if event.is_action_pressed("move_up"): direction = Vector2i.UP
        elif event.is_action_pressed("move_down"): direction = Vector2i.DOWN
        elif event.is_action_pressed("move_left"): direction = Vector2i.LEFT
        elif event.is_action_pressed("move_right"): direction = Vector2i.RIGHT
        if direction != Vector2i.ZERO:
            walk(direction)
            get_viewport().set_input_as_handled()
            return
        if event.is_action_pressed("interact"):
            inspect_furniture()
            get_viewport().set_input_as_handled()
            return
    if root.visible and event.is_action_pressed("ui_cancel"):
        close_house()
        get_viewport().set_input_as_handled()

func walk(direction: Vector2i) -> bool:
    if mode != "行走" or direction.length_squared() != 1:
        return false
    var target: Vector2i = resident_tile + direction
    if target.x < 0 or target.y < 0 or target.x >= housing.WIDTH or target.y >= housing.HEIGHT:
        return false
    if not housing.at(target.x,target.y).is_empty():
        info.text = "前面摆放着家具，可先走到旁边调查。"
        return false
    resident_tile = target
    render()
    return true

func inspect_furniture() -> void:
    for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
        var coord: Vector2i = resident_tile + delta
        var furniture: Dictionary = housing.at(coord.x,coord.y)
        if furniture.is_empty():
            continue
        var entry: Dictionary = housing.item(str(furniture.get("id","")))
        var effect: String = str(entry.get("effect",""))
        match effect:
            "rest":
                _result(housing.rest())
                return
            "storage":
                info.text = "储物柜：请使用右侧的物品存入/取出操作。"
                return
            "cook":
                info.text = "灶台：右侧已列出制作食谱。"
                return
            "craft":
                info.text = "星纹锻台：右侧列出可锻造武器。"
                return
            "light":
                info.text = "星灯温柔地照亮房间。"
                return
        info.text = "查看：" + str(entry.get("name","家具"))
        return
    info.text = "附近没有可以调查的家具。"

func _mode(value: String) -> void:
    mode = value
    render()

func _result(message: String) -> void:
    progress.save()
    changed.emit(message)
    render()
    info.text = message + " · " + info.text

func _click(x: int,y: int) -> void:
    if mode == "行走":
        info.text = "自由行走中：WASD移动，E调查邻近家具；点选「摆放」进入装修。"
    elif mode == "收回":
        _result(housing.remove_at(x,y))
    elif not selected.is_empty():
        _result(housing.place(selected,x,y))
    else:
        info.text = "请先从右侧选中一件库存家具，再点击地板格子。"

func _pick(id: String) -> void:
    selected = id
    mode = "摆放"
    render()

func _store(id: String, deposit: bool) -> void:
    _result(housing.deposit(id) if deposit else housing.withdraw(id))

func _recolor(part: String,palette: String) -> void:
    _result(housing.recolor(part,palette))

func render() -> void:
    if housing == null:
        return
    info.text = "住宅 Lv.%d · 可摆 %d件 · 当前 %d件 · 金币 %dG · 仓库 %d/%d · %s" % [int(housing.data().get("tier",0))+1,housing.capacity(),(housing.data()["placed"] as Array).size(),progress.gold,housing.warehouse_total(),housing.warehouse_capacity(),mode]
    for child in tiles.get_children():
        child.queue_free()
        tiles.remove_child(child)
    var wall: String = str(housing.data().get("wall","海砂白"))
    var wall_colors: Dictionary = {"海砂白":Color("243747"),"星夜蓝":Color("152846"),"银镜灰":Color("343b43"),"森林青":Color("1b3b38")}
    var room_style: StyleBoxFlat = backdrop_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
    room_style.bg_color = wall_colors.get(wall,Color("243747"))
    backdrop_panel.add_theme_stylebox_override("panel",room_style)
    var floor: String = str(housing.data().get("floor","橡木棕"))
    var palette: Dictionary = {"橡木棕":Color("836c54"),"海盐灰":Color("7a8187"),"赤炉红":Color("9f6455"),"天轨紫":Color("74749b")}
    var base: Color = palette.get(floor,Color("836c54"))
    if housing.has_effect("light"):
        base = base.lightened(0.15)
    for y in range(housing.HEIGHT):
        for x in range(housing.WIDTH):
            var xx: int = x
            var yy: int = y
            var occupied: Dictionary = housing.at(x,y)
            var caption: String = "·"
            if mode == "行走" and Vector2i(x,y) == resident_tile:
                caption = "人"
            elif not occupied.is_empty():
                caption = str(housing.item(str(occupied.get("id",""))).get("glyph","◆"))
            elif y == housing.HEIGHT-1 and x in [4,5]:
                caption = "门"
            var b := _button(tiles,caption,func() -> void: _click(xx,yy))
            b.custom_minimum_size = Vector2(44,49)
            var style := StyleBoxFlat.new()
            style.bg_color = base.lightened(0.14 if (x+y)%2==0 else 0.04)
            style.border_color = Color("c9bb9a") if y == 0 else Color("3c4853")
            style.set_border_width_all(1)
            b.add_theme_stylebox_override("normal",style)
    for child in list.get_children():
        child.queue_free()
        list.remove_child(child)
    var subtitle := Label.new()
    subtitle.text = "家具库存 / 装修与生活"
    subtitle.add_theme_font_size_override("font_size",19)
    list.add_child(subtitle)
    for id in housing.data()["stock"]:
        if housing.stock(str(id)) < 1:
            continue
        var item: Dictionary = housing.item(str(id))
        _button(list,"摆放 %s ×%d" % [str(item.get("name",id)),housing.stock(str(id))],func() -> void: _pick(str(id)))
    _button(list,"升级房屋",func() -> void: _result(housing.upgrade()))
    for part in ["wall","floor"]:
        var choices: Array = ["海砂白","星夜蓝","银镜灰","森林青"] if part == "wall" else ["橡木棕","海盐灰","赤炉红","天轨紫"]
        for color in choices:
            var p: String = str(part)
            var c: String = str(color)
            if str(housing.data().get(p,"")) != c:
                _button(list,("墙面 " if p=="wall" else "地板 ")+c,func() -> void: _recolor(p,c))
    var shop := Label.new()
    shop.text = "家具店（购入后放置）"
    list.add_child(shop)
    for id in housing.goods:
        var entry: Dictionary = housing.goods[id]
        if int(entry.get("price",0)) == 0 or int(entry.get("tier",0)) > int(housing.data().get("tier",0)):
            continue
        var key: String = str(id)
        _button(list,"%s  %dG" % [str(entry.get("name",key)),int(entry.get("price",0))],func() -> void: _result(housing.buy_furniture(key)))
    if housing.has_effect("craft") and rpg_core != null:
        var smith := Label.new()
        smith.text = "星纹锻台 / 同阶武器进阶"
        list.add_child(smith)
        for weapon_id in progress.inventory.keys():
            var weapon: String = str(weapon_id)
            if rpg_core.count(weapon) >= 2 and not rpg_core.entry("weapons",weapon).is_empty():
                _button(list,"锻造 "+rpg_core.display_name(weapon),func() -> void: _result(rpg_core.forge(weapon)))
    if housing.has_effect("cook"):
        var cooking := Label.new()
        cooking.text = "星灯厨房 / 烹饪食谱"
        list.add_child(cooking)
        for formula in housing.recipes:
            var fid: String = str(formula.get("id",""))
            var recipe_name: String = str(formula.get("name",""))
            var price: int = int(formula.get("gold",0))
            _button(list,"%s · 制作费 %dG" % [recipe_name,price],func() -> void: _result(housing.cook(fid)))
    var storage := Label.new()
    storage.text = "住宅仓库 / 存入一件"
    list.add_child(storage)
    for id in progress.inventory.keys():
        var key: String = str(id)
        if int(progress.inventory[id]) > 0:
            _button(list,"存入 %s ×%d" % [key,int(progress.inventory[id])],func() -> void: _store(key,true))
    for id in housing.data()["warehouse"].keys():
        var key: String = str(id)
        _button(list,"取出 %s ×%d" % [key,int(housing.data()["warehouse"][id])],func() -> void: _store(key,false))
