extends SceneTree
## C8 shared terrain assets / DLC theme / atlas identity; does not mutate game saves.
const Terrain = preload("res://scripts/world_terrain_atlas_registry.gd")
const Art = preload("res://scripts/c_art_overrides.gd")
const Pool = preload("res://scripts/world_tileset_pool.gd")
const Geog = preload("res://scripts/world_geography.gd")
const Registry = preload("res://scripts/world_registry.gd")
var issues: Array[String] = []

func verify(condition: bool, message: String) -> void:
    if not condition:
        issues.append(message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var original: String = Art.active_pack()
    var first: Array[String] = Terrain.atlas_sources("region_coast","map_coast_01")
    var second: Array[String] = Terrain.atlas_sources("region_city","map_city_01")
    verify(first.size() == 2 and second.size() == 2, "Two canonical terrain sources missing")
    verify(Terrain.group_slots("terrain_ground").size() == 11, "Ground family must include 8 regions, base and 2 authored areas")
    verify(Terrain.group_slots("terrain_water").size() == 10, "Water family must include 8 regions, base and cavern")
    verify(Terrain.group_slots("not_a_group").is_empty(), "Unknown group must fail")
    var registry := Registry.new()
    verify(registry.maps.size() == 42, "Expected 42 configured maps")
    for record in registry.maps.values():
        var map_id: String = str(record.get("id", ""))
        var region_id: String = str(record.get("region_id", ""))
        var pair: Array[String] = Terrain.atlas_sources(region_id,map_id)
        verify(pair.size() == 2, "Missing terrain pair " + map_id)
        for path in pair:
            verify(ResourceLoader.exists(path), "Unresolved atlas " + map_id)
    var geographic := Geog.new()
    var before: Dictionary = geographic.layout("map_coast_01", 1)
    verify(Art.activate_pack("shared_terrain"), "Shared atlas theme unavailable")
    var active_a: TileSet = Pool.shared(Terrain.atlas_sources("region_coast","map_coast_01"))
    var active_b: TileSet = Pool.shared(Terrain.atlas_sources("region_city","map_city_01"))
    verify(active_a != null and active_a == active_b, "Region maps failed to share one TileSet instance")
    verify(Art.pack_report("shared_terrain").get("usable",0) == 19, "Global terrain theme not fully compatible")
    var after: Dictionary = geographic.layout("map_coast_01", 1)
    verify(before.get("blocked", {}) == after.get("blocked", {}), "Terrain theme changed collision")
    verify(before.get("tiles", {}) == after.get("tiles", {}), "Terrain theme changed geometry")
    verify(Art.activate_pack(original), "Could not restore previous DLC theme")
    if issues.is_empty():
        print("SUCCESS: 42 maps, shared 2-atlas terrain, 19 mapped slots, unchanged geometry")
        quit(0)
        return
    for issue in issues:
        push_error(issue)
    quit(1)
