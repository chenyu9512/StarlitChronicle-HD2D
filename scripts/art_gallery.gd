extends Control
## Development-only art review. Run scenes/art_gallery.tscn (F6) in Godot.
const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
var art_list: Array = []
var options: OptionButton
var scroll: ScrollContainer
var tiles: GridContainer
var heading: Label
const FILTERS := ["B02 Main", "B02 NPC", "B03 Boss", "Characters", "Coast Backdrops", "Monsters", "Tilesets", "Props"]

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color(0.07, 0.12, 0.19, 1)
    add_child(background)
    var wrap := MarginContainer.new()
    wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    wrap.add_theme_constant_override("margin_left", 24)
    wrap.add_theme_constant_override("margin_right", 24)
    wrap.add_theme_constant_override("margin_top", 18)
    wrap.add_theme_constant_override("margin_bottom", 18)
    add_child(wrap)
    var flow := VBoxContainer.new()
    wrap.add_child(flow)
    heading = Label.new()
    heading.text = "星灯纪行 · 统一美术目录预览"
    heading.add_theme_font_size_override("font_size", 24)
    flow.add_child(heading)
    var note := Label.new()
    note.text = "与首页读取同一份目录；入库不代表正式场景已绑定，静态图不代表行走动画。"
    flow.add_child(note)
    options = OptionButton.new()
    for name in FILTERS:
        options.add_item(name)
    flow.add_child(options)
    scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    flow.add_child(scroll)
    tiles = GridContainer.new()
    tiles.columns = 4
    tiles.add_theme_constant_override("h_separation", 16)
    tiles.add_theme_constant_override("v_separation", 14)
    scroll.add_child(tiles)
    # Developer gallery reuses the same canonical catalog as the home manager.
    art_list = ArtOverrides.list_assets()
    options.item_selected.connect(_render)
    _render(0)

func _render(index: int) -> void:
    for child in tiles.get_children():
        child.queue_free()
    var current: String = FILTERS[index]
    var count: int = 0
    for item in art_list:
        if not (item is Dictionary):
            continue
        var resource_path: String = str(item.get("path", ""))
        var path: String = resource_path.trim_prefix("res://")
        var category: String = str(item.get("category", ""))
        if current == "B02 Main" and not path.begins_with("assets/art/b02/characters/main/"):
            continue
        if current == "B02 NPC" and not path.begins_with("assets/art/b02/characters/npc/"):
            continue
        if current == "B03 Boss" and not path.begins_with("assets/art/b03/"):
            continue
        if current == "Characters" and category not in ["角色与动画", "主角与队友"]:

            continue
        if current == "Coast Backdrops" and not path.contains("/backdrops/"):
            continue
        if current == "Monsters" and category != "怪物":
            continue
        if current == "Tilesets" and not path.contains("/tilesets/"):
            continue
        if current == "Props" and not path.contains("/props/"):
            continue
        var tex: Texture2D = ArtOverrides.texture(resource_path)
        if tex == null:
            continue
        var column := VBoxContainer.new()
        column.custom_minimum_size = Vector2(215, 205)
        tiles.add_child(column)
        var art := TextureRect.new()
        art.texture = tex
        art.custom_minimum_size = Vector2(210, 160)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        column.add_child(art)
        var label := Label.new()
        label.text = str(item.get("name", path.get_file().get_basename()))
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        column.add_child(label)
        count += 1
    heading.text = "星灯纪行 · " + current + " （" + str(count) + "张）"
