extends SceneTree
## V3 genuine-data smoke: test authored layer import, distinct area geometry,
## walkable roads, quest markers, editor overrides and retention of V2 towns.
const Levels = preload("res://scripts/world_level_v3.gd")
const Geography = preload("res://scripts/world_geography.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(value: bool, why: String) -> void:
    if not value:
        errors.append(why)

func _run() -> void:
    var source = Levels.new()
    var geo = Geography.new()
    verify(source.problems.is_empty(),"V3 level content validation failed: "+str(source.problems))
    verify(geo.faults.is_empty(),"V3 geography preflight failed: "+str(geo.faults))
    var examined: int = 0
    var overworld: int = 0
    var changed: int = 0
    var seen_geometry: Dictionary = {}
    var distinct_sizes: Dictionary = {}
    var distinct_layouts: Dictionary = {}
    for id in geo.zones.keys():
        var zone: Dictionary = geo.zone(str(id))
        if not bool(zone.get("playable",false)):
            continue
        examined += 1
        var authored: Dictionary = source.level(str(id))
        verify(not authored.is_empty(),"No editable V3 record for "+str(id))
        var dimensions: Array = authored.get("size",[])
        verify(dimensions.size()==2 and int(dimensions[0])>=72 and int(dimensions[1])>=48,"Invalid authored V3 map dimensions: "+str(id))
        var footprint_key: String = str(dimensions)
        verify(not distinct_sizes.has(footprint_key),"Duplicate authored map dimensions: "+str(id))
        distinct_sizes[footprint_key] = true
        verify(authored.get("expansion_nodes",[]).size()>=2,"Missing authored sector expansion: "+str(id))
        var layout_key: String = str([authored.get("roads",[]),authored.get("obstacles",[]),authored.get("waterways",[])])
        verify(not distinct_layouts.has(layout_key),"Duplicate authored geometry: "+str(id))
        distinct_layouts[layout_key]=true
        verify(authored.get("roads",[]).size()>=2,"Missing independent authored road network: "+str(id))
        var current: Dictionary = geo.layout(str(id),3)
        var previous: Dictionary = geo.layout(str(id),61)
        verify(current.get("blocked",{})==previous.get("blocked",{}),"Layout changed on chapter reload: "+str(id))
        var initial: Vector2i = current.get("spawn",Vector2i.ZERO)
        var story_routes: Dictionary=geo.resolve_story_targets(current,geo._anchors())
        var missing_stops: Array=story_routes.get("missing",[])
        if not missing_stops.is_empty():
            print("MAP LINK DIAGNOSTIC ",str(id)," missing=",missing_stops,
                " spawn=",initial," blocked_spawn=",(current.get("blocked",{}) as Dictionary).has(initial))
        verify(missing_stops.is_empty()
            and geo.reachable(current,[initial],story_routes.get("points",[])),
            "Physically reachable story interactions missing: "+str(id))
        for gate in current.get("gates",[]):
            verify(geo.reachable(current,[current.get("spawn",Vector2i.ZERO)],[gate.get("cell",Vector2i.ZERO)]),"Map gate inaccessible: "+str(id))
        if bool(zone.get("settlement",false)) or str(zone.get("archetype",""))=="dungeon":
            var custom: Dictionary = authored.duplicate(true)
            # Exercise a legitimately editable exposed tile, not a spawn,
            # gate, essential story anchor or solid authored house facade.
            var editable: Vector2i=Vector2i(-1,-1)
            var extent: Vector2i=current.get("size",Vector2i(72,48))
            for y in range(5,extent.y-5):
                if editable.x>=0:
                    break
                for x in range(5,extent.x-5):
                    var cell:=Vector2i(x,y)
                    if cell.distance_to(initial)<5.0 or (current.get("blocked",{}) as Dictionary).has(cell):
                        continue
                    if bool(zone.get("settlement",false)) and geo._inside_town_building(cell,zone):
                        continue
                    if cell in geo._anchors():
                        continue
                    var is_gate: bool=false
                    for gate in current.get("gates",[]):
                        if cell==gate.get("cell",Vector2i(-1,-1)):
                            is_gate=true
                            break
                    if not is_gate:
                        editable=cell
                        break
            verify(editable.x>=0,"No editable open ground in "+str(id))
            if editable.x<0:
                continue
            custom["paint_overrides"] = [{"cell":[editable.x,editable.y],"row":4,"blocked":true}]
            geo.authored.levels[str(id)] = custom
            var edited: Dictionary = geo.layout(str(id),3)
            if str(id) in ["map_coast_01","map_coast_04","map_city_01"]:
                print("V3_PATCH_TRACE ",str(id)," cell=",editable,
                    " authored_patches=",geo.authored.level(str(id)).get("paint_overrides",[]),
                    " actual_tile=",edited.get("tiles",{}).get(editable,Vector2i(-1,-1)),
                    " actual_blocked=",edited.get("blocked",{}).has(editable),
                    " inside_roof=",geo._inside_town_building(editable,zone))
            verify(edited.get("tiles",{}).get(editable,Vector2i.ZERO).y==4,
                "Town/dungeon V3 paint override did not reach real ground: "+str(id))
            verify(edited.get("blocked",{}).has(editable),
                "Town/dungeon V3 collision edit did not reach real ground: "+str(id))
            geo.authored.levels[str(id)] = authored
            continue
        overworld += 1
        var footprint: String = str((current.get("blocked",{}) as Dictionary).hash())
        verify(not seen_geometry.has(footprint),"Two separate wilderness maps have identical collision fingerprints: "+str(id))
        seen_geometry[footprint] = true
        var patch: Dictionary = authored.duplicate(true)
        patch["paint_overrides"] = [{"cell":[26,27],"row":4,"blocked":true}]
        patch["collision_overrides"] = [{"cell":[27,27],"blocked":false}]
        var tiles: Dictionary = current["tiles"].duplicate()
        var walls: Dictionary = current["blocked"].duplicate()
        var features: Array[Dictionary] = []
        source.apply(patch,tiles,walls,features)
        verify(walls.has(Vector2i(26,27)),"Hand-authored collision patch was not applied: "+str(id))
        verify(not walls.has(Vector2i(27,27)),"Collision erase patch was not applied: "+str(id))
        verify(tiles[Vector2i(26,27)].y==4,"Hand-painted tile row was ignored: "+str(id))
        verify(current.get("tiles",{}).size()==int(dimensions[0])*int(dimensions[1]),"Terrain has missing cells: "+str(id))
        changed += 1
    # Map V4 compatibility regression: test the FULL layout pipeline (rather
    # than only Levels.apply) across all three playable map archetypes. An
    # automatic route to the spawn or a gate must not erase the artist's last
    # explicit cell edit. Changes are temporary and never saved to disk.
    for id in ["map_coast_01","map_coast_03","map_coast_04"]:
        var original: Dictionary = source.level(id)
        var patch: Dictionary = original.duplicate(true)
        var water: Array = (patch.get("waterways",[]) as Array).duplicate(true)
        water.append({"id":"qa-v4-water","width":1,"points":[[66,36],[67,36]],"tile_row":6})
        patch["waterways"] = water
        var rocks: Array = (patch.get("obstacles",[]) as Array).duplicate(true)
        rocks.append({"id":"qa-v4-cliff","width":1,"points":[[66,32],[67,32]],"tile_row":2})
        patch["obstacles"] = rocks
        patch["paint_overrides"] = [{"cell":[10,23],"row":4,"blocked":true}]
        patch["collision_overrides"] = [{"cell":[4,24],"blocked":true}]
        geo.authored.levels[id] = patch
        var active: Dictionary = geo.layout(id,3)
        verify((active.get("blocked",{}) as Dictionary).has(Vector2i(10,23)),"Map V4 lost final spawn collision edit: "+id)
        verify(active.get("tiles",{}).get(Vector2i(10,23),Vector2i.ZERO).y==4,"Map V4 lost final spawn paint edit: "+id)
        verify((active.get("blocked",{}) as Dictionary).has(Vector2i(4,24)),"Map V4 lost final gate collision edit: "+id)
        verify((active.get("blocked",{}) as Dictionary).has(Vector2i(66,32)),"Map V4 lost cliff collision: "+id)
        # The existing coast road includes a tidal channel at this cell;
        # authored water (later layer) legitimately supersedes cliff art there.
        if id != "map_coast_03":
            verify(active.get("tiles",{}).get(Vector2i(66,32),Vector2i.ZERO).y==2,"Map V4 lost cliff surface: "+id)
        verify((active.get("blocked",{}) as Dictionary).has(Vector2i(66,36)),"Map V4 lost water collision: "+id)
        verify((active.get("water_mask",{}) as Dictionary).has(Vector2i(66,36)),"Map V4 lost water rendering mask: "+id)
        # A hand-authored bridge removes the water overlay in map and renderer.
        patch["collision_overrides"] = [{"cell":[4,24],"blocked":true},{"cell":[66,36],"blocked":false}]
        var bridged: Dictionary = geo.layout(id,3)
        verify(not (bridged.get("blocked",{}) as Dictionary).has(Vector2i(66,36)),"Map V4 manual bridge is still blocked: "+id)
        verify(not (bridged.get("water_mask",{}) as Dictionary).has(Vector2i(66,36)),"Map V4 bridge is still rendered as water: "+id)
        geo.authored.levels[id] = original
    verify(examined==40,"Missing forty playable V3 datasets")
    verify(distinct_sizes.size()==40 and distinct_layouts.size()==40,"Forty world layouts must have unique size and geometry signatures")
    verify(overworld==21,"Expected 21 wilderness/route/landmark regions after eleven towns and eight dungeons")
    if errors.is_empty():
        print("PASS: %d standalone authorable V3 definitions, %d distinct wilderness collision layouts, all quest/gate paths, independent editor collision patches" % [examined,overworld])
        quit(0)
    else:
        for error in errors:
            push_error(error)
        quit(1)
