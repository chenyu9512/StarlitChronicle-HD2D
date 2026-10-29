extends SceneTree
## V2.1 offline contracts: evidence inspection, deduplication, chapter 3/5 mechanics,
## and the existing V3 save/reload boundary. Does not claim player-path acceptance.
const JournalScript = preload("res://scripts/systems/StarlightJournal.gd")
const MechanicsScript = preload("res://scripts/mechanics/Act01Mechanics.gd")
const StateScript = preload("res://scripts/first_act_state.gd")
const Transition = preload("res://scripts/d_world_interaction/v3_progress_transition.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    if not ok:
        errors.append(label)

func _run() -> void:
    var journal = JournalScript.new()
    var registered: Array = []
    journal.evidence_registered.connect(func(entry: Dictionary) -> void:
        registered.append(entry.get("id", ""))
    )
    var closeups: Array = []
    journal.object_closeup_requested.connect(func(evidence_id: String, hotspots: Array) -> void:
        closeups.append({"id":evidence_id,"count":hotspots.size()})
    )
    for evidence_id in ["ev_ch001_envelope","ev_ch003_half_badge",
        "ev_ch007_rejected_letters","ev_ch008_caravan_site"]:
        journal.inspect_physical_object(evidence_id)
    _check(closeups.size()==4, "all four physical objects must have interactive hotspot lists")
    _check(closeups[0].get("count",0)==2 and closeups[1].get("count",0)==2,
        "chapter 1 and chapter 3 must have two distinguishable hotspots")
    journal.register_clue("fact_a","A","proof",JournalScript.ClueCategory.VERIFIED_FACT)
    journal.register_clue("fact_a","A","proof",JournalScript.ClueCategory.VERIFIED_FACT)
    journal.register_clue("fact_a","bad","rumor",JournalScript.ClueCategory.PENDING_INFERENCE)
    _check(registered.size()==1, "facts must not be duplicated or downgraded")
    journal.register_clue("inf_a","rumor","pending",JournalScript.ClueCategory.PENDING_INFERENCE)
    journal.verify_and_resolve_inference("inf_a","fact_a","verified","counterproof")
    journal.verify_and_resolve_inference("inf_a","fact_a","verified","counterproof")
    _check(journal.pending_inferences.is_empty(), "resolved inference must leave pending list")
    _check(journal.verified_facts.has("inf_a_verified"), "cross proof must promote a fact")

    var cave = MechanicsScript.new()
    _check(not cave.valve_2_wedge_inserted, "bridge starts locked")
    cave.operate_sea_cave_mechanism(2,true)
    _check(not cave.valve_2_wedge_inserted, "bridge cannot skip valve 1")
    cave.operate_sea_cave_mechanism(1)
    cave.operate_sea_cave_mechanism(2,false)
    _check(not cave.valve_2_wedge_inserted, "bridge requires carried stone wedge")
    cave.operate_sea_cave_mechanism(2,true)
    cave.operate_sea_cave_mechanism(3)
    _check(cave.valve_1_depressurized and cave.valve_2_wedge_inserted
        and cave.valve_3_guardian_shutoff, "three cave gates must complete in order")
    cave.on_boss_ch003_pre_attack_telegraph()
    _check(not bool(cave.execute_boss_ch003_tactical_action(
        "SHOW_CROOKED_TREE_BADGE",false).get("success",false)), "no badge must fail")
    _check(bool(cave.execute_boss_ch003_tactical_action(
        "SHOW_CROOKED_TREE_BADGE",true).get("success",false)), "observed badge can pacify")
    _check(not bool(cave.execute_boss_ch003_tactical_action(
        "SHOW_CROOKED_TREE_BADGE",true).get("success",false)), "pacification is one-shot")

    var beast = MechanicsScript.new()
    _check(not bool(beast.attempt_dismantle_star_lock(false).get("success",false)),
        "no dismantling without exposing the beast back")
    for lock_index in range(3):
        beast.trigger_shuoxian_double_whistle()
        var result: Dictionary = beast.attempt_dismantle_star_lock(false)
        _check(bool(result.get("success",false)), "each lock needs a legitimate action")
        _check(bool(result.get("battle_complete",false)) == (lock_index == 2),
            "battle completes only after third lock")
    _check(beast.boss_ch005_is_complete and beast.beast_star_locks_remaining==0,
        "all three locks must be removed")
    _check(not bool(beast.attempt_dismantle_star_lock(false).get("success",false)),
        "no duplicate battle settlement")

    var saved = StateScript.new()
    saved.save_path = "user://qa_v21_evidence_%s.json" % str(OS.get_process_id())
    saved.backup_path = saved.save_path + ".bak"
    var initial_saved: bool = saved.save()
    _check(initial_saved, "isolated V3 baseline save")
    if initial_saved:
        var result: Dictionary = Transition.commit(saved,func() -> Dictionary:
            saved.rpg["canon_evidence"] = {"ev_ch003_half_badge":{"crooked_tree":true}}
            return {"ok":true}
        )
        _check(bool(result.get("ok",false)), "V3 must durably persist the evidence")
        var restored = StateScript.new()
        restored.save_path = saved.save_path
        restored.backup_path = saved.backup_path
        _check(restored.load_saved(), "V3 evidence save must reload")
        _check(bool(restored.rpg.get("canon_evidence",{}).get(
            "ev_ch003_half_badge",{}).get("crooked_tree",false)),
            "badge proof persists across a real disk reload")
    for file in [saved.save_path,saved.backup_path,saved.save_path+".tmp",
        saved.backup_path+".tmp"]:
        var absolute_path: String = ProjectSettings.globalize_path(file)
        if FileAccess.file_exists(file):
            DirAccess.remove_absolute(absolute_path)
    if errors.is_empty():
        print("PASS V2.1 evidence / isolated mechanics / V3 disk-reload contracts")
        quit(0)
    else:
        for e in errors:
            push_error("FAIL: "+e)
        quit(1)
