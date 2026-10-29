extends SceneTree
## Batch 0.2: real FirstActState V3 + B story V2, isolated user:// sandbox.
## No game victory is simulated; these are transaction and fault-injection tests.
const State = preload("res://scripts/first_act_state.gd")
const Core = preload("res://scripts/rpg_core.gd")
const QuestTx = preload("res://scripts/d_world_interaction/quest_v3_settlement.gd")
const BRuntime = preload("res://scripts/story_runtime.gd")
const BConsumer = preload("res://scripts/d_world_interaction/b_story_reward_consumer.gd")

class FixtureCatalog:
    extends RefCounted
    var prologue: Dictionary = {"scenes":[{"id":"d_b_qa_scene",
        "effects":[{"type":"grant","xp":24,"gold":11}]}]}
    func get_chapter(_id: String) -> Dictionary:
        return {}

var faults: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, label: String) -> void:
    if not ok:
        faults.append(label)

func _run() -> void:
    var sandbox: String = "user://d_batch02_quest_%d" % OS.get_process_id()
    var base: String = ProjectSettings.globalize_path(sandbox)
    if DirAccess.make_dir_recursive_absolute(base) != OK:
        push_error("Unable to create isolated V3+B test sandbox")
        quit(1)
        return
    var state = State.new()
    state.save_path = sandbox + "/v3.json"
    state.backup_path = sandbox + "/v3.backup.json"
    state.chapter = 1
    var core = Core.new()
    core.bind(state)
    var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/first_act_side_quests.json"))
    check(catalog is Dictionary, "Local quest source missing")
    var local: Dictionary = {}
    if catalog is Dictionary:
        local = (catalog.get("quests",[]) as Array)[0]
    var start_snapshot: Dictionary = state._pack().duplicate(true)
    state.save_path = sandbox + "/missing/v3.json"
    var accept_failed: Dictionary = QuestTx.settle_local_stage(state,1,local,"accepted")
    check(str(accept_failed.get("reason",""))=="save_failed" and state._pack()==start_snapshot,
        "Local accepted flag did not rollback")
    state.save_path = sandbox + "/v3.json"
    var accepted: Dictionary = QuestTx.settle_local_stage(state,1,local,"accepted")
    check(bool(accepted.get("applied",false)), "Local acceptance not durable")
    var acceptance_repeat: Dictionary = QuestTx.settle_local_stage(state,1,local,"accepted")
    check(bool(acceptance_repeat.get("repeated",false)), "Acceptance callback not idempotent")
    var before_find: Dictionary = state._pack().duplicate(true)
    state.save_path = sandbox + "/missing/v3.json"
    var find_failed: Dictionary = QuestTx.settle_local_stage(state,1,local,"found")
    check(str(find_failed.get("reason",""))=="save_failed" and state._pack()==before_find,
        "Local found flag did not rollback")
    state.save_path = sandbox + "/v3.json"
    check(bool(QuestTx.settle_local_stage(state,1,local,"found").get("applied",false)),
        "Found stage was not durable")
    var before: Dictionary = state._pack().duplicate(true)
    state.save_path = sandbox + "/missing/v3.json"
    var failed_local: Dictionary = QuestTx.settle_local(state,core,1,local)
    check(str(failed_local.get("reason","")) == "save_failed", "Local failure did not stop reward")
    check(state._pack() == before, "Failed local quest leaked gold, XP or flag")
    state.save_path = sandbox + "/v3.json"
    var local_ok: Dictionary = QuestTx.settle_local(state,core,1,local)
    check(bool(local_ok.get("applied",false)), "Local quest did not persist")
    var paid_gold: int = state.gold
    var repeat_local: Dictionary = QuestTx.settle_local(state,core,1,local)
    check(bool(repeat_local.get("repeated",false)) and state.gold == paid_gold,
        "Local callback paid twice")
    var reload = State.new()
    reload.save_path = state.save_path
    reload.backup_path = state.backup_path
    check(reload.load_saved(), "V3 local quest save cannot reload")
    var reload_core = Core.new()
    reload_core.bind(reload)
    var reload_repeat: Dictionary = QuestTx.settle_local(reload,reload_core,1,local)
    check(bool(reload_repeat.get("repeated",false)) and reload.gold==paid_gold,
        "Local quest repaid after restart")

    # Authored scene grants use a durable receipt independent of scene UI retries.
    var authored_scene: Dictionary = {"id":"d_qa_scene",
        "effects":[{"type":"set_flag","key":"d.qa.scene.done","value":true},
                   {"type":"grant","xp":14,"gold":9}]}
    var scene_before: Dictionary = reload._pack().duplicate(true)
    reload.save_path = sandbox + "/missing/scene.json"
    var scene_failed: Dictionary = QuestTx.settle_scene_effects(reload,authored_scene)
    check(str(scene_failed.get("reason",""))=="save_failed", "Scene grant accepted failed save")
    check(reload._pack()==scene_before, "Failed scene effect leaked flags or gold")
    reload.save_path = sandbox + "/v3.json"
    var scene_ok: Dictionary = QuestTx.settle_scene_effects(reload,authored_scene)
    check(bool(scene_ok.get("applied",false)), "Scene reward not persisted")
    var scene_gold: int = reload.gold
    var scene_replay: Dictionary = QuestTx.settle_scene_effects(reload,authored_scene)
    check(bool(scene_replay.get("repeated",false)) and reload.gold==scene_gold,
        "Duplicate scene callback paid twice")
    var original: Dictionary = reload._pack().duplicate(true)
    reload.save_path = sandbox + "/missing/catalog.json"
    var failed_catalog: String = reload_core.record_quest("quest_main_001")
    check(failed_catalog.begins_with("任务奖励未保存"), "Catalog quest save failure reported success")
    check(reload._pack() == original, "Failed catalog quest mutated player progress")
    reload.save_path = sandbox + "/v3.json"
    var recorded: String = reload_core.record_quest("quest_main_001")
    check(recorded.begins_with("已记录任务完成"), "Catalog quest did not commit")
    var catalog_gold: int = reload.gold
    check(reload_core.record_quest("quest_main_001") == "奖励已经领取。" and reload.gold==catalog_gold,
        "Catalog quest paid twice")

    var q: Dictionary = {}
    for candidate in reload_core.narrative_side_quests:
        if str(candidate.get("id","")) == "sq_page_01":
            q = candidate
            break
    check(not q.is_empty(), "Canonical original side quest unavailable")
    reload.chapter = 5
    reload.flags["story.ch005.done"] = true
    var stage_before: Dictionary = reload._pack().duplicate(true)
    reload.save_path = sandbox + "/missing/stage.json"
    var failed_stage: String = reload_core.advance_story_side(q)
    check(failed_stage.begins_with("委托存档失败"), "Story stage accepted failed disk write")
    check(reload._pack() == stage_before, "Failed story stage leaked flags or progress")
    reload.save_path = sandbox + "/v3.json"
    var stage_success: String = reload_core.advance_story_side(q)
    check(stage_success.begins_with("已完成委托阶段"), "Story stage failed to commit")
    check(int(reload.rpg.get("narrative_side",{}).get("sq_page_01",0))==1,
        "Saved story stage position incorrect")
    check(reload.rpg.get("d_reward_receipts_v1",{}).get("consumed",{}).has(
        "d.quest.story.sq_page_01.stage.0"), "Story stage receipt absent")

    # Real B StoryRuntime emits only an outbox; D then owns V3 payout.
    var b = BRuntime.new()
    b.catalog = FixtureCatalog.new()
    b.loaded = true
    b.current_chapter_id = "prologue"
    b.current_chapter = b.catalog.prologue
    b.save_path = sandbox + "/story.json"
    b._finish_scene()
    var eid: String = "b.story.scene.d_b_qa_scene.reward.0"
    check(b.pending_reward_receipts().has(eid), "B scene did not durably queue payout")
    var payload: Dictionary = b.pending_reward_receipts().get(eid,{})
    var player = State.new()
    player.save_path = sandbox + "/b_v3.json"
    player.backup_path = sandbox + "/b_v3.backup.json"
    var player_core = Core.new()
    player_core.bind(player)
    var baseline: Dictionary = player._pack().duplicate(true)
    player.save_path = sandbox + "/missing/b_v3.json"
    var no_v3: Dictionary = BConsumer.consume_one(b,player,player_core,payload)
    check(not bool(no_v3.get("ok",false)), "B ACK without durable V3 transfer")
    check(player._pack()==baseline and b.pending_reward_receipts().has(eid),
        "B outbox or V3 mutated after failed transfer")
    player.save_path = sandbox + "/b_v3.json"
    b.save_path = sandbox + "/missing/story.json"
    var ack_failed: Dictionary = BConsumer.consume_one(b,player,player_core,payload)
    check(bool(ack_failed.get("v3_saved",false)) and not bool(ack_failed.get("acknowledged",true)),
        "B ACK fault was not reported")
    check(b.pending_reward_receipts().has(eid), "Failed B ACK discarded pending reward")
    var once_gold: int = player.gold
    check(once_gold == int(baseline.get("gold",0))+11, "B V3 payout not durably credited")
    var restarted = State.new()
    restarted.save_path = player.save_path
    restarted.backup_path = player.backup_path
    check(restarted.load_saved(), "B V3 receipt not recoverable")
    var restarted_core = Core.new()
    restarted_core.bind(restarted)
    b.save_path = sandbox + "/story.json"
    var replay: Dictionary = BConsumer.consume_one(b,restarted,restarted_core,payload)
    if not bool(replay.get("ok",false)) or not bool(replay.get("repeated",false)):
        print("D_B_V3_REPLAY_DIAGNOSTIC response=",replay,
            " persisted_journal=",restarted.rpg.get("d_reward_receipts_v1",{}),
            " queued=",b.pending_reward_receipts().get(eid,{}))
    check(bool(replay.get("ok",false)) and bool(replay.get("repeated",false)),
        "B replay did not use durable V3 receipt")
    check(bool(replay.get("acknowledged",false)) and restarted.gold == once_gold,
        "B retry double-paid or failed to ACK")
    check(b.pending_reward_receipts().is_empty(), "B outbox not drained after ACK")
    var forged: Dictionary = payload.duplicate(true)
    forged["gold"] = 99999
    check(not bool(BConsumer.consume_one(b,restarted,restarted_core,forged).get("ok",true)),
        "Stale or forged B payload accepted")
    # Cleanup stays inside a process-local test folder; never default player V3.
    for name in ["v3.json","v3.json.tmp","v3.backup.json","v3.backup.json.tmp",
        "story.json","story.json.tmp","story.json.bak","story.json.bak.tmp",
        "b_v3.json","b_v3.json.tmp","b_v3.backup.json","b_v3.backup.json.tmp"]:
        var file_path: String = sandbox + "/" + name
        if FileAccess.file_exists(file_path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
    DirAccess.remove_absolute(base)
    if faults.is_empty():
        print("PASS: D Batch 0.2 local/catalog/story V3 rollback and B outbox replay/ACK")
        quit(0)
    else:
        for fault in faults:
            push_error(fault)
        quit(1)
