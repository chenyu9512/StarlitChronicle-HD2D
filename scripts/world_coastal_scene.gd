extends Node2D
## A7-A9: per-map authored art, animation, nonblocking exploration props.
## Coordinates reuse WorldGeography. Quest/exit collision remains authoritative.
const PATH: String = "res://data/levels/v4/coastal_scenery.json"
const ART: String = "res://assets/art/exteriors/coast_final_pass/"
const TILE: int = 32
const ACCEPTED: Array[String] = [
    "tide_pool","dune_grass","fish_net_stand","harbor_crane",
    "tide_cliff","cave_stalactite","cave_crystal","cave_altar",
    "sea_bridge","quest_glow"
]
var map_id: String = ""
var authored_sprites: Dictionary = {}
var tidal_sprites: Array[Sprite2D] = []
var animated_phase: float = 0.0
var water_count: int = 0
var wave_timer: float = 0.0
var cavern_grade: CanvasModulate
var cavern_lights: Array[PointLight2D] = []
var surface_detail: TileMapLayer
var detail_count: int = 0
var shoreline_count: int = 0

func configure(map_key: String, layout: Dictionary) -> void:
    map_id = map_key
    if not map_id in ["map_coast_01","map_coast_02","map_coast_03","map_coast_04"]:
        return
    if not FileAccess.file_exists(PATH):
        return
    var all: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not all is Dictionary:
        return
    var region: Dictionary = all.get(map_id,{})
    for item in region.get("scenery",[]):
        if not item is Dictionary:
            continue
        var id: String = str(item.get("id",""))
        var asset: String = str(item.get("asset",""))
        var point: Array = item.get("cell",[])
        if id.is_empty() or authored_sprites.has(id) or asset not in ACCEPTED or point.size()!=2:
            continue
        var sprite := _sprite(asset,Vector2i(int(point[0]),int(point[1])))
        if sprite==null:
            continue
        sprite.name=id
        var layer: String=str(item.get("layer","furniture"))
        sprite.z_index = -3 if layer=="floor" else (2 if layer=="background" else 3)
        var offset: Array=item.get("offset",[])
        if offset.size()==2:
            sprite.offset=Vector2(float(offset[0]),float(offset[1]))
        add_child(sprite)
        authored_sprites[id]=sprite
        if asset=="tide_pool":
            tidal_sprites.append(sprite)
    # The wave effect samples actual physical water cells, never invents water
    # or turns author-painted bridges back into blocked water.
    var mask: Dictionary = layout.get("water_mask",{})
    var selected: int = 0
    for tile in mask.keys():
        var point: Vector2i=tile
        if (point.x*17+point.y*23)%41!=0 or selected>=24:
            continue
        var wave := _sprite("tide_pool",point)
        if wave==null:
            break
        wave.name="AnimatedSurf%d" % selected
        wave.scale=Vector2(0.44,0.29)
        wave.z_index=-3
        wave.modulate.a=0.28
        add_child(wave)
        tidal_sprites.append(wave)
        selected+=1
    water_count=selected
    _install_surface_detail(layout)
    if map_id=="map_coast_04":
        _make_cavern_lighting()

func _install_surface_detail(layout: Dictionary) -> void:
    # One atlas layer instead of hundreds of nodes. No collision writes.
    var theme: String="coastal"
    if map_id=="map_coast_02":
        theme="harbor"
    elif map_id=="map_coast_04":
        theme="cavern"
    var file: String=ART+theme+"_detail_atlas.svg"
    if not ResourceLoader.exists(file):
        return
    var tiles:=TileSet.new()
    tiles.tile_size=Vector2i(TILE,TILE)
    var atlas:=TileSetAtlasSource.new()
    atlas.texture=load(file)
    atlas.texture_region_size=Vector2i(TILE,TILE)
    for y in range(8):
        for x in range(8):
            atlas.create_tile(Vector2i(x,y))
    tiles.add_source(atlas,0)
    surface_detail=TileMapLayer.new()
    surface_detail.name="ShorelineAndSurfaceDetails"
    surface_detail.tile_set=tiles
    surface_detail.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    surface_detail.z_index=-4
    add_child(surface_detail)
    var ground: Dictionary=layout.get("tiles",{})
    var water: Dictionary=layout.get("water_mask",{})
    var collision: Dictionary=layout.get("blocked",{})
    var seed: int=map_id.hash()
    for raw in ground.keys():
        var cell: Vector2i=raw
        if water.has(cell):
            continue
        var shore: int=-1
        if water.has(cell+Vector2i.LEFT):
            shore=0
        elif water.has(cell+Vector2i.RIGHT):
            shore=1
        elif water.has(cell+Vector2i.UP):
            shore=2
        elif water.has(cell+Vector2i.DOWN):
            shore=3
        if shore>=0:
            surface_detail.set_cell(cell,0,Vector2i(shore,4))
            shoreline_count+=1
            detail_count+=1
            continue
        var variant: int=posmod(cell.x*37+cell.y*71+seed,100)
        var ground_atlas: Vector2i=ground[cell]
        var row: int=-1
        if map_id=="map_coast_04":
            if ground_atlas.y==3 and variant<28:
                row=2
            elif collision.has(cell) and variant<20:
                row=3
            elif variant<10:
                row=5
            elif variant<14:
                row=6
        elif ground_atlas.y==3 and variant<22:
            row=2
        elif ground_atlas.y==1 and variant<17:
            row=1
        elif ground_atlas.y==5 and variant<13:
            row=0 if variant<7 else 1
        elif collision.has(cell) and variant<13:
            row=3
        elif variant<4:
            row=7
        if row>=0:
            surface_detail.set_cell(cell,0,Vector2i(posmod(cell.x*11+cell.y*7+seed,8),row))
            detail_count+=1

func _make_cavern_lighting() -> void:
    cavern_grade=CanvasModulate.new()
    cavern_grade.name="TidalCavernBlueGrade"
    cavern_grade.color=Color("a0b0bc")
    add_child(cavern_grade)
    var glow: String="res://assets/art/interiors/morning_dew_inn/light_pool.svg"
    if not ResourceLoader.exists(glow):
        return
    for entry in ["cave_relic","cave_boss_arena","cave_beacon"]:
        if not authored_sprites.has(entry):
            continue
        var lamp:=PointLight2D.new()
        lamp.name="CaveGlow_"+entry
        lamp.texture=load(glow)
        lamp.position=authored_sprites[entry].position
        lamp.texture_scale=2.15
        lamp.energy=1.05
        lamp.color=Color("b6d9e5") if entry!="cave_boss_arena" else Color("e9c998")
        add_child(lamp)
        cavern_lights.append(lamp)

func _sprite(asset: String,cell: Vector2i) -> Sprite2D:
    var file: String=ART+asset+".svg"
    if not ResourceLoader.exists(file):
        return null
    var sprite:=Sprite2D.new()
    sprite.texture=load(file)
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position=Vector2(float(cell.x)*TILE+16.0,float(cell.y)*TILE+16.0)
    return sprite

func _process(delta: float) -> void:
    if map_id.is_empty():
        return
    animated_phase+=delta
    for i in range(tidal_sprites.size()):
        var wave: Sprite2D=tidal_sprites[i]
        wave.offset.x=2.0*sin(animated_phase*1.6+float(i)*0.79)
        if wave.name.begins_with("AnimatedSurf"):
            wave.modulate.a=0.19+0.10*(0.5+0.5*sin(animated_phase*2.2+float(i)))
