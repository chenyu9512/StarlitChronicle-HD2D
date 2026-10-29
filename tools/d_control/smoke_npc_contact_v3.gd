extends SceneTree
## Real B NPC readonly-preview -> D V3 commit -> reload, no simulated story rewards.
const State = preload("res://scripts/first_act_state.gd")
const Town = preload("res://scripts/world_town_life.gd")
const Contact = preload("res://scripts/d_world_interaction/npc_v3_contact.gd")
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func ck(ok: bool, title: String) -> void:
    if not ok:
        failures.append(title)
func _run() -> void:
    var sandbox: String = "user://d_b_npc_contact_%d" % OS.get_process_id()
    ck(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))==OK,
        "isolated user path unavailable")
    var town = Town.new()
    var residents: Array = town.residents_for_map("map_coast_01")
    ck(not residents.is_empty(), "No canonical town residents")
    if residents.is_empty():
        quit(1)
        return
    var id: String = str(residents[0].get("id",""))
    var region: String = str(residents[0].get("region_id",""))
    var map_id: String = str(residents[0].get("map_id",""))
    ck(map_id=="map_coast_01", "B map filter mismatched actual resident")
    var player = State.new()
    player.save_path = sandbox+"/npc.json"
    player.backup_path = sandbox+"/npc.backup.json"
    var clock: Dictionary = {"minutes":480}
    var original: Dictionary = player._pack().duplicate(true)
    var wrong: Dictionary = Contact.converse(player,town,id,region,"map_coast_02",clock)
    ck(str(wrong.get("reason",""))=="npc_wrong_map", "Off-map NPC allowed to talk")
    ck(player._pack()==original, "Invalid NPC talk changed player state")
    player.save_path = sandbox+"/no-such-folder/npc.json"
    var failed: Dictionary = Contact.converse(player,town,id,region,map_id,clock)
    ck(str(failed.get("reason",""))=="save_failed", "Failed first contact persisted")
    ck(player._pack()==original, "Failed NPC save changed first talk eligibility")
    player.save_path = sandbox+"/npc.json"
    var first: Dictionary = Contact.converse(player,town,id,region,map_id,clock)
    ck(bool(first.get("applied",false)) and bool(first.get("ok",false)),
        "First NPC dialogue receipt not committed")
    ck(player.rpg.get("talked_to",{}).has(id), "B talked_to missing")
    ck(player.rpg.get("d_reward_receipts_v1",{}).get("consumed",{}).has(
        "b.npc.first."+id), "D NPC receipt missing")
    var repeat: Dictionary = Contact.converse(player,town,id,region,map_id,clock)
    ck(bool(repeat.get("repeated",false)) and not bool(repeat.get("applied",false)),
        "Second NPC talk counted as first")
    var loaded = State.new()
    loaded.save_path = player.save_path
    loaded.backup_path = player.backup_path
    ck(loaded.load_saved(), "NPC first contact could not reload")
    var resuming: Dictionary = Contact.converse(loaded,town,id,region,map_id,clock)
    ck(bool(resuming.get("repeated",false)) and not bool(resuming.get("preview",{}).get("first",true)),
        "NPC repeated dialog after reload is incorrectly first")
    var next_map: Array = town.residents_for_map("map_coast_02")
    for record in next_map:
        ck(str(record.get("map_id",""))=="map_coast_02", "Wrong city returned NPC")
    for name in ["npc.json","npc.json.tmp","npc.backup.json","npc.backup.json.tmp"]:
        var path: String = sandbox+"/"+name
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
    if failures.is_empty():
        print("PASS: D/B map-scoped NPC preview and exactly-once first contact across save failure and reload")
        quit(0)
        return
    for issue in failures:
        push_error(issue)
    quit(1)
