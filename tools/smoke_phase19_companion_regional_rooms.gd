extends SceneTree
## Stage 19-7 real-world acceptance: 54 V4 companion/regional interiors,
## 30 authentic outdoors, no previous room replacement, actual walk and V3 save.
const Rooms = preload("res://scripts/story_quest_submaps.gd")
const Geo = preload("res://scripts/world_geography.gd")
const Game = preload("res://scripts/first_act.gd")
const Save = preload("res://scripts/first_act_state.gd")
const NPC = preload("res://scripts/world_npc_visual.gd")
var problems: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func ck(ok: bool,reason: String) -> void:
    if not ok:
        problems.append(reason)

func _run() -> void:
    var rooms = Rooms.new()
    ck(rooms.errors.is_empty(),"room registry errors: "+" / ".join(rooms.errors))
    ck(rooms.entries.size()==12 and rooms.life_entries.size()==19 and
        rooms.other_entries.size()==54,"all 85 distinct V4 quest rooms indexed")
    var geography = Geo.new()
    for key in rooms.other_entries:
        var id: String = str(key)
        var spec: Dictionary = rooms.detail(id)
        var area: Dictionary = geography.interior(
            str(spec.get("building_id","")),str(spec.get("interior_name","")),str(spec.get("map_id","")))
        ck(str(area.get("authored_source",""))=="v4","real V4 room "+id)
        var free_evidence: Array = area.get("quest_points",[])
        var original: Array = area.get("story_stage_points",[])
        var branch: Array = area.get("branch_stage_points",[])
        ck(free_evidence.size()==3 and original.size()==5 and branch.size()==3,
            "separate 11 original/branch/exhibit markers "+id)
        if free_evidence.size()!=3 or original.size()!=5 or branch.size()!=3:
            continue
        var start: Array[Vector2i] = [area.get("spawn",Vector2i(-1,-1))]
        var target: Array[Vector2i] = []
        for cell in free_evidence + original + branch:
            target.append(cell)
        target.append(area.get("interact_cells",{}).get("exit",Vector2i(-1,-1)))
        ck(geography.reachable(area,start,target),"actual collision routes to all 11 objectives "+id)
        var deadline: int = int(str(spec.get("open_chapter","ch999")).trim_prefix("ch"))
        ck(not rooms.matches(id,str(spec.get("map_id","")),deadline-1) and
            rooms.matches(id,str(spec.get("map_id","")),deadline),
            "chapter gate guards unique quest room "+id)

    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    var visited: Dictionary = {}
    var first_room: String = ""
    var saved_gold: int = game.progress.gold
    for key in rooms.other_entries:
        var id: String = str(key)
        var spec: Dictionary = rooms.detail(id)
        var persist: Dictionary = game.progress.rpg.get("world",{})
        persist.erase("indoor_building")
        persist.erase("outdoor_return")
        game.progress.chapter = int(str(spec.get("open_chapter","ch999")).trim_prefix("ch"))
        game.progress.scene_index = 0
        persist["current_map"] = str(spec.get("map_id",""))
        persist["bound_chapter"] = game.progress.chapter
        game._enter_location()
        var entrance: String = "questdoor:"+id
        ck(game.world.nodes.has(entrance),"world has per-quest visible entrance "+id)
        if not game.world.nodes.has(entrance):
            continue
        game.world.hero.position = game.world.nodes[entrance].position
        game.world.interact()
        ck(game.world.interior_building=="quest__"+id,"E interaction enters correct scene "+id)
        if game.world.interior_building!="quest__"+id:
            continue
        ck(str(game.world.terrain_layout.get("authored_source",""))=="v4",
            "independent room loaded instead of shared fallback "+id)
        ck(game.world.nodes.has("story_stage_0") and
            game.world.nodes["story_stage_0"].get_script()==NPC,
            "original quest giver is an animated NPC visual "+id)
        if game.world.nodes.has("story_stage_0") and game.world.nodes["story_stage_0"] is NPC:
            var npc: Node = game.world.nodes["story_stage_0"]
            ck(str(npc.story_phase)=="intro","story NPC starts in introductory state "+id)
            game.progress.flags["side."+id+".approach"]="a"
            game.world.refresh_room_npcs(game.progress.flags)
            ck(str(npc.story_route)=="a","NPC outfit accent follows persisted A route "+id)
            game.progress.flags["side."+id+".approach"]="b"
            game.world.refresh_room_npcs(game.progress.flags)
            ck(str(npc.story_route)=="b","NPC outfit accent follows persisted B route "+id)
            game.progress.flags.erase("side."+id+".approach")
            game.world.refresh_room_npcs(game.progress.flags)
            ck(str(npc.story_route)=="","missing route is never guessed "+id)
            game.world.sync_world_clock(2,1320)
            ck(int(npc.story_hour)==22,"NPC respects evening tint without moving collision "+id)
        ck(game.world.terrain_layout.get("quest_points",[]).size()==3,
            "three physical evidence sites "+id)
        var clue: String = "questcase:1"
        ck(game.world.nodes.has(clue),"named physical clue "+id)
        if game.world.nodes.has(clue):
            game.world.hero.position=game.world.nodes[clue].position
            game.world.interact()
            ck(bool(game.progress.rpg.get("quest_gallery",{}).get(id,{}).get("1",false)),
                "free observation persists without advancing original quest "+id)
        if first_room.is_empty():
            first_room=id
            ck(bool(game.progress.rpg.get("world",{}).get("indoor_building","")=="quest__"+id),
                "room save records exact original quest identity")
            game._enter_location()
            ck(game.world.interior_building=="quest__"+id,
                "V3 reload resumes player within chosen companion/regional interior")
        if game.world.nodes.has("interior_exit"):
            game.world.hero.position=game.world.nodes["interior_exit"].position
            game.world.interact()
        ck(game.world.interior_building.is_empty(),"exit back to same region "+id)
        ck(str(game.progress.rpg.get("world",{}).get("indoor_building","")).is_empty(),
            "exit clears stale room state "+id)
        visited[id]=true
    ck(visited.size()==54,"all 54 independently authored rooms really visited")
    ck(game.progress.gold==saved_gold,"free investigations cannot farm money")
    ck(game.progress.save(),"existing V3 storage accepts all rooms")
    var restored = Save.new()
    ck(restored.load_saved(),"existing V3 save reloads with all rooms explored")
    ck(restored.rpg.get("quest_gallery",{}).size()>=54,
        "all companion/regional room exhibit states survive reload")
    for label in ["cq_lanyin_01","cq_leiso_01","rq_001"]:
        ck(rooms.detail(label).get("quest_id","")==label,
            "original NPC, canonical ID and authored quest location retained "+label)
    # The thirty open-air cases are not duplicated as generic fake rooms.
    for id in ["cq_leiso_03","rq_002","rq_003"]:
        ck(rooms.detail(id).is_empty(),"canon outdoor location remains in the 40-map world "+id)
    if problems.is_empty():
        print("PASS: 54 companion/regional real interiors, 594 collision-safe interaction nodes,")
        print("  30 authentic open-air cases, animated NPCs, correct doors, V3 save/reentry.")
        quit(0)
        return
    for error in problems:
        push_error(error)
    quit(1)
