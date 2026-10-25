extends Node2D
## Native drawn roof/building painter. No third-party franchise assets.
## Each town shares the same doorway and collision footprint from WorldGeography.
const TILE: float = 32.0
var purpose: String = "house"
var title: String = ""
var biome: String = "coastal"
var cells: Vector2i = Vector2i(8,6)
var facade: Sprite2D
var exterior_identity: String = ""

func setup(kind: String,building_name: String,dimensions: Vector2i,area: String,map_key: String = "") -> void:
    purpose = kind
    title = building_name
    biome = area
    cells = dimensions
    exterior_identity=map_key+"#"+kind
    # The original painter remains the compatibility fallback for other biomes.
    var file: String = "res://assets/art/exteriors/coast_final_pass/%s_%s.svg" % [map_key,kind]
    if ResourceLoader.exists(file):
        facade=Sprite2D.new()
        facade.name="AuthoredFacade"
        facade.texture=load(file)
        facade.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        facade.scale=Vector2(float(cells.x)*TILE/256.0,float(cells.y)*TILE/192.0)
        facade.z_index=3
        add_child(facade)
    queue_redraw()

func _palette() -> Dictionary:
    var wall: Color = Color("c5b093")
    var roof: Color = Color("456f83")
    var trim: Color = Color("e9d39e")
    match biome:
        "volcanic":
            wall=Color("aa826b")
            roof=Color("694955")
            trim=Color("e3aa6c")
        "highland":
            wall=Color("a7a79a")
            roof=Color("5b6770")
        "archipelago":
            wall=Color("d7bba0")
            roof=Color("397c92")
        "mistforest":
            wall=Color("b4bdc4")
            roof=Color("665a83")
        "badlands":
            wall=Color("bba585")
            roof=Color("625d52")
        "celestial":
            wall=Color("d8d1d1")
            roof=Color("8b80b5")
        "metropolis":
            wall=Color("b4a7ac")
            roof=Color("6b6175")
            trim=Color("f0c791")
    match purpose:
        "inn": roof=roof.lightened(0.13)
        "smith": roof=roof.darkened(0.30)
        "guild": roof=roof.darkened(0.08)
        "shrine": roof=Color("7797ae")
        "shop": roof=Color("b7745e")
    return {"wall":wall,"roof":roof,"trim":trim}

func _draw() -> void:
    if is_instance_valid(facade):
        return
    var palette: Dictionary = _palette()
    var w: float = float(cells.x)*TILE
    var h: float = float(cells.y)*TILE
    var shadow := Color(0.03,0.07,0.12,0.45)
    var roof: Color = palette["roof"]
    var trim: Color = palette["trim"]
    var wall: Color = palette["wall"]
    var left: float = -w/2.0
    var top: float = -h/2.0
    draw_rect(Rect2(left+12,top+32,w-16,h-12),shadow,true)
    draw_rect(Rect2(left+13,top+27,w-26,h-24),wall.darkened(0.19),true)
    draw_rect(Rect2(left+17,top+24,w-34,h-30),wall,true)
    for row in range(3):
        var yy: float = top+48.0+float(row)*30.0
        draw_line(Vector2(left+18,yy),Vector2(left+w-17,yy),wall.darkened(0.13),1.0)
    # Wide roof silhouette: sloped polygon, contrasting ridgeline and shingle strokes.
    var roof_poly: PackedVector2Array = PackedVector2Array([
        Vector2(left-5,top+28),Vector2(left+w/2.0,top-22),
        Vector2(left+w+5,top+28),Vector2(left+w-10,top+76),
        Vector2(left+10,top+76)
    ])
    draw_colored_polygon(roof_poly,roof)
    draw_polyline(PackedVector2Array([roof_poly[0],roof_poly[1],roof_poly[2]]),trim,3.0,true)
    draw_line(Vector2(left+10,top+74),Vector2(left+w-10,top+74),roof.darkened(0.35),3.0)
    for row in range(3):
        for col in range(maxi(3,int(cells.x))):
            var xx: float = left+20.0+float(col)*float((w-40.0)/float(maxi(3,int(cells.x))))
            var yy: float = top+21.0+float(row)*16.0+absf(xx)*0.08
            draw_line(Vector2(xx,yy),Vector2(xx+12,yy-1),roof.lightened(0.18 if (row+col)%2==0 else 0.05),1.1)
    # Three-dimensional porch with a highlighted physical doorway.
    var doorway: Rect2 = Rect2(-18,top+h-54,36,46)
    draw_rect(Rect2(doorway.position-Vector2(3,4),doorway.size+Vector2(6,4)),trim,true)
    draw_rect(doorway,Color("263f4c"),true)
    draw_rect(Rect2(doorway.position+Vector2(4,3),Vector2(28,37)),Color("704d38"),true)
    draw_circle(doorway.position+Vector2(25,24),2.5,Color("e4c27b"))
    for side in [-1,1]:
        var window_x: float = float(side)*(w/2.0-45.0)-12.0
        var window: Rect2 = Rect2(window_x,top+h-75,26,24)
        draw_rect(window,trim,true)
        draw_rect(window.grow(-3.0),Color("557d88"),true)
        draw_line(window.position+Vector2(13,3),window.position+Vector2(13,21),trim,2.0)
    # Functional visual markers distinguish market, forge, inn and shrine at a glance.
    var sigil_pos: Vector2 = Vector2(0,top+38)
    match purpose:
        "inn":
            draw_circle(sigil_pos,16.0,Color("f5d7a0"))
            draw_circle(sigil_pos+Vector2(4,-3),11.5,roof)
        "shop":
            draw_colored_polygon(PackedVector2Array([sigil_pos+Vector2(-18,8),sigil_pos+Vector2(18,8),sigil_pos+Vector2(10,-12),sigil_pos+Vector2(-10,-12)]),Color("f9dcaa"))
            for i in range(4):
                draw_line(sigil_pos+Vector2(-12+i*8,-9),sigil_pos+Vector2(-12+i*8,7),Color("cb8064"),2.0)
        "guild":
            draw_colored_polygon(PackedVector2Array([sigil_pos+Vector2(0,-16),sigil_pos+Vector2(14,-3),sigil_pos+Vector2(0,17),sigil_pos+Vector2(-14,-3)]),trim)
            draw_line(sigil_pos+Vector2(0,-11),sigil_pos+Vector2(0,10),roof.darkened(0.3),3)
        "smith":
            draw_rect(Rect2(sigil_pos-Vector2(16,5),Vector2(32,10)),Color("e0a768"),true)
            draw_line(sigil_pos+Vector2(-4,-17),sigil_pos+Vector2(10,-4),trim,5)
        "shrine":
            draw_circle(sigil_pos,16,trim)
            for i in range(8):
                var a: float = TAU*float(i)/8.0
                draw_line(sigil_pos+Vector2(cos(a),sin(a))*10.0,sigil_pos+Vector2(cos(a),sin(a))*16.0,Color.WHITE,2.2)
        _:
            draw_colored_polygon(PackedVector2Array([sigil_pos+Vector2(0,-12),sigil_pos+Vector2(12,0),sigil_pos+Vector2(0,12),sigil_pos+Vector2(-12,0)]),trim)
