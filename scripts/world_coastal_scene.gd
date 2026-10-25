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
