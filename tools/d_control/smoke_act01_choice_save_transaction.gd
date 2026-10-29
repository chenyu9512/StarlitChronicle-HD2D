extends SceneTree
## No player save paths: prove story flags + optional reaction receipt are one
## checkpoint, including a deterministic unwritable-directory rollback.
const State = preload("res://scripts/first_act_state.gd")
const Optional = preload("res://scripts/optional_director.gd")
const Choice = preload("res://scripts/d_world_interaction/act01_choice_transaction.gd")
var failures: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool,reason: String) -> void:
    if not value:
        failures.append(reason)

func _run() -> void:
    var sandbox: String="user://smoke_act01_choice_%d" % OS.get_process_id()
    var root_path: String=ProjectSettings.globalize_path(sandbox)
    if DirAccess.make_dir_recursive_absolute(root_path)!=OK:
        push_error("Cannot create isolated story choice sandbox")
        quit(1)
        return
    var decision: Dictionary={"id":"test_option","sets":{"chapter.test.choice":true}}
    var good=State.new()
    good.chapter=1
    good.save_path=sandbox+"/good.json"
    good.backup_path=sandbox+"/good.bak"
    var director=Optional.new()
    director.bind(good)
    _check(good.save(),"Cannot create initial valid choice save")
    var result: Dictionary=Choice.commit(good,director,decision,"ch001.option_test")
    _check(bool(result.get("ok",false)),"Normal A/B choice was rejected")
    _check(bool(good.flags.get("chapter.test.choice",false)) and
        bool(good.flags.get("ch001.option_test.chosen",false)),
        "A/B flags missing after valid save")
    var reloaded=State.new()
    reloaded.save_path=good.save_path
    reloaded.backup_path=good.backup_path
    _check(reloaded.load_saved(),"Valid A/B choice could not reload")
    _check(bool(reloaded.flags.get("chapter.test.choice",false)) and
        bool(reloaded.flags.get("ch001.option_test.chosen",false)),
        "A/B choice was not durable on disk")

    var failed=State.new()
    failed.chapter=1
    failed.save_path=sandbox+"/does_not_exist/file.json"
    failed.backup_path=sandbox+"/does_not_exist/backup.json"
    var failing_director=Optional.new()
    failing_director.bind(failed)
    var before: Dictionary=failed._pack().duplicate(true)
    var rejected: Dictionary=Choice.commit(failed,failing_director,decision,"ch001.option_test")
    _check(not bool(rejected.get("ok",true)),
        "Choice falsely committed with an unwritable V3 path")
    _check(failed._pack()==before,
        "Failed choice write leaked canonical flags or optional event receipts")
    _check(not bool(failed.flags.get("ch001.option_test.chosen",false)),
        "A/B decision flagged as chosen despite a rejected save")
    var malformed: Dictionary={"id":"test_option","sets":"not_a_dictionary"}
    before=failed._pack().duplicate(true)
    _check(not bool(Choice.commit(failed,failing_director,malformed,"ch001.option_test").get("ok",true)),
        "Malformed option flags were accepted")
    _check(failed._pack()==before,"Malformed choice changed running state")

    for file in [good.save_path,good.backup_path,good.save_path+".tmp",good.backup_path+".tmp"]:
        if FileAccess.file_exists(file):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
    DirAccess.remove_absolute(root_path)
    if failures.is_empty():
        print("PASS Act-I A/B choice: durable flag + follow-up receipt; unreadable storage rollback")
        quit(0)
        return
    for reason in failures:
        push_error(reason)
    quit(1)
