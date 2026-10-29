extends Node2D
## Imported Golden Horizon sprites on real first-act maps. Presentation ONLY.
const MANIFEST: String="res://data/assets/c_act01_hd2d_v18.json"
const ROOT: String="res://assets/art/runtime/act01_hd2d_v18/props/"
const ArtTheme = preload("res://scripts/c_art_theme_v2.gd")
const Overrides = preload("res://scripts/c_art_overrides.gd")
const TILE: int=32
var map_id: String=""
var placed: Dictionary={}
var omitted: Array[String]=[]

func _protected(layout: Dictionary) -> Dictionary:
    var reserved: Dictionary={}
    var spawn: Vector2i=layout.get("spawn",Vector2i(10,23))
    for y in range(-4,5):
        for x in range(-4,5):
            reserved[spawn+Vector2i(x,y)]=true
    for kind in ["features","gates"]:
        for item in layout.get(kind,[]):
            if not item is Dictionary:
                continue
            var anchor: Variant=item.get("cell",null)
            if not anchor is Vector2i:
                continue
            for y in range(-3,4):
                for x in range(-3,4):
                    reserved[anchor+Vector2i(x,y)]=true
    for entry in (layout.get("zone",{}) as Dictionary).get("buildings",[]):
        if not entry is Dictionary:
            continue
        var xy: Array=entry.get("pos",[])
        var size: Array=entry.get("size",[])
        if xy.size()!=2 or size.size()!=2:
            continue
        var center:=Vector2i(int(xy[0]),int(xy[1]))
        var radius:=Vector2i(int(size[0])/2+2,int(size[1])/2+2)
        for y in range(center.y-radius.y,center.y+radius.y+1):
            for x in range(center.x-radius.x,center.x+radius.x+1):
                reserved[Vector2i(x,y)]=true
    return reserved

func _verge(wanted: Vector2i,layout: Dictionary,reserved: Dictionary,used: Dictionary) -> Vector2i:
    var extent: Vector2i=layout.get("size",Vector2i(72,48))
    var ground: Dictionary=layout.get("tiles",{})
    var blocked: Dictionary=layout.get("blocked",{})
    var water: Dictionary=layout.get("water_mask",{})
    # These are individually art-directed coordinates. Previous 10-tile
    # wandering could move a harbor crate into housing, a market stall to a
    # cliff edge, or a shrine into the wrong scene. A genuine cave wall piece
    # has its separate longer anchored-to-rock fallback below.
    var relocation_radius: int=9 if map_id=="map_coast_04" else 7
    for radius in range(relocation_radius+1):
        for y in range(-radius,radius+1):
            for x in range(-radius,radius+1):
                if absi(x)+absi(y)!=radius:
                    continue
                var c: Vector2i=wanted+Vector2i(x,y)
                if c.x<3 or c.y<3 or c.x>=extent.x-3 or c.y>=extent.y-3:
                    continue
                if reserved.has(c) or used.has(c) or blocked.has(c) or water.has(c) or not ground.has(c):
                    continue
                var paint: Vector2i=ground[c]
                # Dungeon rooms are carved as V3 row-5 stone floor and
                # row-3 paths. Excluding both rows made all genuine cave
                # crystal/ruin PNG props impossible to place in the world.
                # The protected-story/exit zones and collision filter above
                # still prevent art from concealing tide valves or gates.
                if paint.y in [3,5] and map_id!="map_coast_04":
                    continue
                var close_road: bool=false
                for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                    if ground.has(c+delta) and (ground[c+delta] as Vector2i).y==3:
                        close_road=true
                        break
                if not close_road:
                    return c
    # The cave's designed corridors are narrow. Rock/ruin decorations should
    # be anchored to pre-existing solid cave walls, not made into false
    # walkable obstructions or placed on the carved player route.
    if map_id=="map_coast_04":
        for radius in range(17):
            for y in range(-radius,radius+1):
                for x in range(-radius,radius+1):
                    if absi(x)+absi(y)!=radius:
                        continue
                    var wall: Vector2i=wanted+Vector2i(x,y)
                    if wall.x<3 or wall.y<3 or wall.x>=extent.x-3 or wall.y>=extent.y-3:
                        continue
                    if reserved.has(wall) or used.has(wall) or water.has(wall):
                        continue
                    if blocked.has(wall) and ground.has(wall):
                        return wall
    return Vector2i(-1,-1)

func configure(map_key: String,layout: Dictionary,depth_host: Node2D) -> void:
    map_id=map_key
    placed.clear()
    omitted.clear()
    if not is_instance_valid(depth_host) or not FileAccess.file_exists(MANIFEST):
        return
    var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    if not data is Dictionary:
        return
    var reserved: Dictionary=_protected(layout)
    var used: Dictionary={}
    for row in data.get("placements",[]):
        if not row is Dictionary or str(row.get("map_id",""))!=map_id:
            continue
        var kind: String=str(row.get("kind",""))
        var source: String=str(row.get("source",""))
        var id: String=str(row.get("id",""))
        var cell_array: Array=row.get("cell",[])
        if id.is_empty() or placed.has(id) or cell_array.size()!=2 or source!=ROOT+kind+".png":
            omitted.append(id)
            continue
        if not ResourceLoader.exists(source):
            omitted.append(id)
            push_warning("V18 missing genuine texture "+source)
            continue
        var tex: Texture2D=Overrides.pixel_fantasy_texture(source)
        if tex==null:
            tex=ArtTheme.texture_for_path(source)
        if tex==null:
            tex=load(source) as Texture2D
        if tex==null or tex.get_width()<32 or tex.get_height()<32:
            omitted.append(id)
            continue
        var wanted:=Vector2i(int(cell_array[0]),int(cell_array[1]))
        var safe: Vector2i=_verge(wanted,layout,reserved,used)
        if safe.x<0:
            omitted.append(id)
            continue
        var sprite:=Sprite2D.new()
        sprite.name="GH18_"+id
        sprite.texture=tex
        sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        var dimensions: Vector2=Vector2(tex.get_size())
        var ratio: float=minf(1.0,minf(float(row.get("max_width",96))/dimensions.x,float(row.get("max_height",100))/dimensions.y))
        sprite.scale=Vector2.ONE*ratio
        sprite.offset=Vector2(0,-dimensions.y*0.5+10.0/maxf(0.001,ratio))
        sprite.position=Vector2(safe*TILE)+Vector2(16,16)
        # Wall-backed cave rock art is scenery BEHIND the hero, not an
        # invisible foreground curtain over the carved story route.
        var wall_backdrop: bool=map_id=="map_coast_04" and layout.get("blocked",{}).has(safe) and kind in ["rock-bank","cliff-ledge"]
        sprite.z_index=1 if wall_backdrop else 3
        sprite.set_meta("wall_backdrop",wall_backdrop)
        sprite.set_meta("art_kind",kind)
        sprite.set_meta("source_path",source)
        sprite.set_meta("map_cell",safe)
        sprite.set_meta("visual_only",true)
        depth_host.add_child(sprite)
        placed[id]=sprite
        used[safe]=true
