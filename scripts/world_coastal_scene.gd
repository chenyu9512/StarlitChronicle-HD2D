extends Node2D
const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
const TilePool = preload("res://scripts/world_tileset_pool.gd")
const CoastPainter = preload("res://scripts/c_coastal_painter.gd")
const AllocatedDecor = preload("res://scripts/c_live_coast_dressing.gd")
const Act01Art = preload("res://scripts/c_act01_production_registry.gd")
## A7-A9: per-map authored art, animation, nonblocking exploration props.
## Coordinates reuse WorldGeography. Quest/exit collision remains authoritative.
const PATH: String = "res://data/levels/v4/coastal_scenery.json"
const ART: String = "res://assets/art/exteriors/coast_final_pass/"
const TILE: int = 32
const ACCEPTED: Array[String] = [
    "tide_pool","dune_grass","fish_net_stand","harbor_crane",
    "tide_cliff","cave_stalactite","cave_crystal","cave_altar",
    "sea_bridge","quest_glow",
    "saltwind_oak","sea_wind_pine","dune_shrub",
    "cave_foreground_column","cave_hanging_ledge",
    "tide_lighthouse_landmark"
]
var map_id: String = ""
var authored_sprites: Dictionary = {}
var tidal_sprites: Array[Sprite2D] = []
var animated_phase: float = 0.0
var water_count: int = 0
var wave_timer: float = 0.0
var cavern_grade: CanvasModulate
var cavern_lights: Array[PointLight2D] = []
var lighthouse_light: PointLight2D
var light_clock: int = 720
var light_quality: int = 1
var surface_detail: TileMapLayer
var allocated_dressing: Node2D
var illustrated_dressing: Node2D
var reflection_material: ShaderMaterial
var detail_count: int = 0
var shoreline_count: int = 0
var depth_stage: Node2D
var foreground_sprites: Dictionary = {}
var wind_sway_sprites: Array[Sprite2D] = []
var reflections: Array[Sprite2D] = []
var reflection_frames: Array[AtlasTexture] = []
var reflection_count: int = 0
var reflection_frame: int = -1

func configure(map_key: String, layout: Dictionary, sort_host: Node2D = null) -> void:
    map_id = map_key
    depth_stage = sort_host
    if not Act01Art.has_map(map_id):
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
        var layer: String=str(item.get("layer","furniture"))
        var cell: Vector2i=Vector2i(int(point[0]),int(point[1]))
        if layer=="vegetation":
            cell=_safe_vegetation_cell(cell,layout)
            if cell.x<0:
                push_warning("Coastal tree omitted: no clear verge for "+id)
                continue
        var sprite := _sprite(asset,cell)
        if sprite==null:
            continue
        sprite.name=id
        sprite.set_meta("art_kind",asset)
        var art_scale: float = clampf(float(item.get("scale",1.0)),0.25,2.5)
        sprite.scale = Vector2.ONE * art_scale
        var depth_sorted: bool=layer in ["vegetation","foreground"] and is_instance_valid(depth_stage)
        # For depth props, the scene root is y-sorted with the hero. Do not
        # move the footpoint when adding a tall canopy: use Sprite2D.offset.
        sprite.z_index=3 if depth_sorted else (-3 if layer=="floor" else (2 if layer=="background" else 3))
        var offset: Array=item.get("offset",[])
        if offset.size()==2:
            sprite.offset=Vector2(float(offset[0]),float(offset[1]))
        if depth_sorted:
            depth_stage.add_child(sprite)
            foreground_sprites[id]=sprite
            if layer=="vegetation":
                wind_sway_sprites.append(sprite)
        else:
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
    _install_water_reflections(mask)
    _install_surface_detail(layout)
    allocated_dressing = AllocatedDecor.new()
    allocated_dressing.name = "CuratedCArtV7Decor"
    add_child(allocated_dressing)
    allocated_dressing.configure(map_id, layout)
    if map_id in ["map_coast_01","map_coast_02"]:
        illustrated_dressing = CoastPainter.new()
        illustrated_dressing.name = "OriginalCoastalDressing"
        add_child(illustrated_dressing)
        illustrated_dressing.configure(map_id, layout, depth_stage)
    if map_id=="map_coast_04":
        _make_cavern_lighting()
    elif map_id=="map_coast_05":
        _install_lighthouse_light()

## Keep a tree trunk outside houses, door approaches and painted road.
## The canopy can overlap scenery behind it through Y sorting, but its root
## never appears in the middle of a shop, quest path or indoor doorway.
func set_clock(minutes: int) -> void:
    light_clock = posmod(minutes,1440)
    _apply_lighthouse_light()
    if is_instance_valid(illustrated_dressing):
        illustrated_dressing.set_clock(minutes)
    if is_instance_valid(allocated_dressing):
        allocated_dressing.set_clock(minutes)

func set_visual_quality(level: int) -> void:
    var q: int=clampi(level,0,2)
    light_quality = q
    _apply_lighthouse_light()
    if is_instance_valid(illustrated_dressing):
        illustrated_dressing.set_visual_quality(q)
    if is_instance_valid(allocated_dressing):
        allocated_dressing.set_visual_quality(q)
    for reflection in reflections:
        reflection.visible=q>0
    for wave in tidal_sprites:
        wave.visible=q>0
    # Keep a readable cavern on low settings while limiting costly local
    # illumination. Existing three authored light nodes retain their positions.
    for index in range(cavern_lights.size()):
        cavern_lights[index].visible=index < (1 if q==0 else (2 if q==1 else 3))
    set_process(q>0)

func _safe_vegetation_cell(wanted: Vector2i,layout: Dictionary) -> Vector2i:
    var extent: Vector2i=layout.get("size",Vector2i(72,48))
    var blocks: Dictionary=layout.get("blocked",{})
    var ground: Dictionary=layout.get("tiles",{})
    var buildings: Array=layout.get("zone",{}).get("buildings",[])
    for radius in range(10):
        for dy in range(-radius,radius+1):
            for dx in range(-radius,radius+1):
                if absi(dx)+absi(dy)!=radius:
                    continue
                var p: Vector2i=wanted+Vector2i(dx,dy)
                if p.x<3 or p.y<3 or p.x>=extent.x-3 or p.y>=extent.y-3 or blocks.has(p):
                    continue
                var paint: Vector2i=ground.get(p,Vector2i.ZERO)
                if paint.y==3:
                    continue
                var beside_house: bool=false
                for raw in buildings:
                    if not raw is Dictionary:
                        continue
                    var pos: Array=raw.get("pos",[])
                    var size: Array=raw.get("size",[])
                    var door: Array=raw.get("door",[])
                    if pos.size()!=2 or size.size()!=2:
                        continue
                    var center: Vector2i=Vector2i(int(pos[0]),int(pos[1]))
                    var half: Vector2i=Vector2i(int(size[0])/2,int(size[1])/2)
                    if abs(p.x-center.x)<=half.x+1 and abs(p.y-center.y)<=half.y+1:
                        beside_house=true
                        break
                    if door.size()==2 and p.distance_squared_to(Vector2i(int(door[0]),int(door[1]))+Vector2i.DOWN)<16:
                        beside_house=true
                        break
                if beside_house:
                    continue
                return p
    return Vector2i(-1,-1)

func _install_water_reflections(mask: Dictionary) -> void:
    var file: String=ART+"sea_glimmer_4f.svg"
    if not ResourceLoader.exists(file):
        return
    var atlas_texture: Texture2D=ArtOverrides.texture(file)
    if atlas_texture==null:
        return
    for frame in range(4):
        var piece:=AtlasTexture.new()
        piece.atlas=atlas_texture
        piece.region=Rect2(frame*64,0,64,32)
        reflection_frames.append(piece)
    # Sampling exclusively from the authoritative water mask, limited to 32
    # GPU sprites so mobile memory/render cost does not scale with map size.
    for raw in mask.keys():
        var cell: Vector2i=raw
        if posmod(cell.x*29+cell.y*17+19,43)!=0 or reflection_count>=32:
            continue
        var reflection:=Sprite2D.new()
        reflection.name="WaterReflection_%d" % reflection_count
        reflection.texture=reflection_frames[reflection_count%4]
        reflection.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        if reflection_material == null:
            var shader_file: String="res://assets/shaders/coastal_reflection.gdshader"
            if ResourceLoader.exists(shader_file):
                reflection_material=ShaderMaterial.new()
                reflection_material.shader=load(shader_file)
        if reflection_material != null:
            reflection.material=reflection_material
        reflection.position=Vector2(float(cell.x)*TILE+16.0,float(cell.y)*TILE+16.0)
        reflection.scale=Vector2(0.58,0.67)
        reflection.z_index=-3
        reflection.modulate.a=0.41
        add_child(reflection)
        reflections.append(reflection)
        reflection_count+=1

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
    var atlas_paths: Array[String]=[file]
    var tiles: TileSet=TilePool.shared(atlas_paths)
    if tiles==null:
        return
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

## The lighthouse lamp is an authored light source, not a quest-complete flag.
## Its brightness changes with the clock; the story director still owns whether
## the great beacon can be formally relit.
func _install_lighthouse_light() -> void:
    if not authored_sprites.has("lighthouse_landmark"):
        return
    var texture_path: String = "res://assets/art/interiors/morning_dew_inn/light_pool.svg"
    var texture: Texture2D = ArtOverrides.texture(texture_path)
    if texture == null:
        return
    lighthouse_light = PointLight2D.new()
    lighthouse_light.name = "CoastalLighthouseSignal"
    lighthouse_light.texture = texture
    lighthouse_light.texture_scale = 2.25
    lighthouse_light.shadow_enabled = false
    lighthouse_light.color = Color("ffe6a6")
    lighthouse_light.position = (authored_sprites["lighthouse_landmark"] as Sprite2D).position + Vector2(0,-165)
    add_child(lighthouse_light)
    _apply_lighthouse_light()

func _apply_lighthouse_light() -> void:
    if not is_instance_valid(lighthouse_light):
        return
    var strength: float = 0.0
    if light_clock >= 1140 or light_clock < 330:
        strength = 1.0
    elif light_clock >= 1020:
        strength = float(light_clock - 1020) / 120.0
    elif light_clock < 420:
        strength = float(420 - light_clock) / 90.0
    lighthouse_light.visible = light_quality > 0 and strength > 0.02
    lighthouse_light.energy = strength * (0.65 if light_quality == 1 else 0.95)

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
        lamp.texture=ArtOverrides.texture(glow)
        lamp.position=authored_sprites[entry].position
        lamp.texture_scale=2.15
        lamp.energy=1.05
        lamp.color=Color("b6d9e5") if entry!="cave_boss_arena" else Color("e9c998")
        add_child(lamp)
        cavern_lights.append(lamp)

func _sprite(asset: String,cell: Vector2i) -> Sprite2D:
    var file: String=Act01Art.sprite_path(map_id, asset)
    if file.is_empty() or not ResourceLoader.exists(file):
        return null
    var sprite:=Sprite2D.new()
    sprite.texture=ArtOverrides.texture(file)
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
    # Small rotational sway around ground footpoints; no collision/movement.
    for i in range(wind_sway_sprites.size()):
        var plant: Sprite2D=wind_sway_sprites[i]
        plant.rotation=0.010*sin(animated_phase*0.84+float(i)*1.15)
    var frame: int=posmod(int(animated_phase*5.0),4)
    if frame!=reflection_frame and reflection_frames.size()==4:
        reflection_frame=frame
        for i in range(reflections.size()):
            reflections[i].texture=reflection_frames[(frame+i)%4]
    for i in range(cavern_lights.size()):
        cavern_lights[i].energy=1.05*(0.96+0.04*sin(animated_phase*1.7+float(i)*2.4))
