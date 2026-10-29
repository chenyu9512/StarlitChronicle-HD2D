extends SceneTree
## Real V3 file writes in a throwaway sandbox. Must never touch user saves.
## Covers the exact evidence/choice/tracker methods used by first_act.gd.
const State = preload("res://scripts/first_act_state.gd")
const Evidence = preload("res://scripts/story_evidence_puzzles.gd")
const Transaction = preload("res://scripts/d_world_interaction/story_evidence_transaction.gd")
var failures: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    if not ok:
        failures.append(description)

func _run() -> void:
    var sandbox: String="user://smoke_evidence_tx_%d" % OS.get_process_id()
    var absolute: String=ProjectSettings.globalize_path(sandbox)
    if DirAccess.make_dir_recursive_absolute(absolute)!=OK:
        push_error("Could not prepare evidence transaction QA sandbox")
        quit(1)
        return
    var puzzle=Evidence.new()
    _check(puzzle.errors.is_empty(),"Evidence catalog is not valid")

    var state=State.new()
    state.save_path=sandbox+"/state.json"
    state.backup_path=sandbox+"/backup.json"
    _check(state.save(),"Cannot create initial safe V3 save")
    var first: Dictionary=Transaction.observe(state,"sq_page_01",0)
    _check(bool(first.get("ok",false)) and bool(first.get("changed",false)),
        "First observation not committed")
    var repeated: Dictionary=Transaction.observe(state,"sq_page_01",0)
    _check(bool(repeated.get("ok",false)) and not bool(repeated.get("changed",true)),
        "Repeated observation should be read-only")
    _check(bool(Transaction.observe(state,"sq_page_01",1).get("ok",false)),
        "Second observation not committed")
    _check(puzzle.can_attempt(state.rpg,"sq_page_01"),"Saved evidence did not unlock deduction")
    var wrong: Dictionary=Transaction.answer(state,puzzle,"sq_page_01","option_0",1)
    _check(bool(wrong.get("ok",false)) and
        not bool((wrong.get("outcome",{}) as Dictionary).get("result",{}).get("solved",true)),
        "Wrong option must record an unsuccessful attempt")
    var solved: Dictionary=Transaction.answer(state,puzzle,"sq_page_01","option_1",1)
    _check(bool(solved.get("ok",false)) and puzzle.solved(state.rpg,"sq_page_01"),
        "Correct option was not durably solved")
    var after_solved: Dictionary=state._pack().duplicate(true)
    var no_duplicate: Dictionary=Transaction.answer(state,puzzle,"sq_page_01","option_1",1)
    _check(bool(no_duplicate.get("ok",false)) and
        not bool(no_duplicate.get("changed",true)) and state._pack()==after_solved,
        "Solved deduction was modified a second time")
    _check(bool(Transaction.track(state,"branch_example").get("ok",false)),
        "Tracked event not saved")
    var reader=State.new()
    reader.save_path=state.save_path
    reader.backup_path=state.backup_path
    _check(reader.load_saved(),"Could not load durable evidence save")
    _check(puzzle.solved(reader.rpg,"sq_page_01") and
        str(reader.rpg.get("tracked_branch_event",""))=="branch_example",
        "Solved evidence or tracking disappeared on reload")

    var broken=State.new()
    broken.save_path=sandbox+"/missing_folder/state.json"
    broken.backup_path=sandbox+"/missing_folder/backup.json"
    var before: Dictionary=broken._pack().duplicate(true)
    _check(not bool(Transaction.observe(broken,"sq_page_01",0).get("ok",true)),
        "Unwritable evidence record unexpectedly committed")
    _check(broken._pack()==before,"Failed clue save left a phantom observation")
    broken.rpg["quest_gallery"]={"sq_page_01":{"0":true,"1":true}}
    before=broken._pack().duplicate(true)
    _check(not bool(Transaction.answer(broken,puzzle,"sq_page_01","option_1",1).get("ok",true)),
        "Unwritable deduction unexpectedly committed")
    _check(broken._pack()==before and not puzzle.solved(broken.rpg,"sq_page_01"),
        "Failed deduction save leaked attempts or solution state")
    _check(not bool(Transaction.track(broken,"branch_example").get("ok",true)),
        "Unwritable branch tracking unexpectedly committed")
    _check(broken._pack()==before,"Failed branch tracking changed live state")
    _check(not bool(Transaction.observe(broken,"sq_page_01",4).get("ok",true)),
        "Out-of-range evidence index was accepted")
    _check(broken._pack()==before,"Rejected evidence index changed live state")

    for file in [state.save_path,state.backup_path,
            state.save_path+".tmp",state.backup_path+".tmp"]:
        if FileAccess.file_exists(file):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
    DirAccess.remove_absolute(absolute)
    if failures.is_empty():
        print("PASS Act-I evidence: atomic gallery, deductions and tracking; replay; three failed-save rollbacks")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
