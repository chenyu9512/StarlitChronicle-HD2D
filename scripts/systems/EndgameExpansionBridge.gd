extends Node
## Live V3 adapter for the third endgame batch. Chapter content remains canonical.
## Does not synthesize battle rewards, completion flags or romance/combat bonuses.
const Evacuation = preload("res://scripts/mechanics/Act08EvacuationController.gd")
const NoeTransition = preload("res://scripts/systems/NoeTransitionAndLeadershipSystem.gd")
const QuestLore = preload("res://scripts/systems/SideQuestsAndLoreLoader.gd")
const FinaleMechanics = preload("res://scripts/mechanics/Act10To12EndgameMechanics.gd")
const REGISTRY_PATH := "res://story/runtime/endgame_expansion_registry.json"
const RESCUE_ACTION_PATH: String = "res://story/runtime/act08_rescue_actions.json"
const EVACUATION_TIME_LIMIT := 600.0
const TICKET_ID := "ch039.noe_mothers_ticket"

signal evacuation_expired(reason: String)

var evacuation
var noe
var quests
var finale
var registry_loaded: bool = false
var rescue_actions: Dictionary = {}
var evacuation_combat_receipts: Dictionary = {}
var current_chapter: int = 0
var ticket_source_verified: bool = false
var errors: Array[String] = []

func _ready() -> void:
    evacuation = Evacuation.new()
    add_child(evacuation)
    evacuation.evacuation_failed.connect(func(reason: String) -> void: evacuation_expired.emit(reason))
    noe = NoeTransition.new()
    add_child(noe)
    quests = QuestLore.new()
    add_child(quests)
    finale = FinaleMechanics.new()
    add_child(finale)

func load_registry() -> bool:
    errors.clear()
    var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
    if not (source is Dictionary):
        errors.append("Endgame registry missing or malformed")
        return false
    var modules: Variant = source.get("modules", null)
    if not (modules is Dictionary):
        errors.append("Endgame registry lacks module paths")
        return false
    for module_id in ["act08_evacuation", "noe_leadership_transition", "side_quests_and_lore", "postbattle_finale"]:
        var path: String = str(modules.get(module_id, ""))
        if not path.begins_with("res://scripts/") or not ResourceLoader.exists(path):
            errors.append("Missing registered module: " + module_id)
    if not errors.is_empty():
        return false
    var action_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RESCUE_ACTION_PATH))
    if not (action_data is Dictionary) or not (action_data.get("objectives",{}) is Dictionary):
        errors.append("Chapter 47 authored rescue actions missing")
        return false
    rescue_actions = (action_data.get("objectives",{}) as Dictionary).duplicate(true)
    for squad_id in Evacuation.OBJECTIVES:
        for objective in Evacuation.OBJECTIVES[squad_id]:
            if str(objective).ends_with("_encounter_won"):
                continue
            var item: Variant = rescue_actions.get(str(objective),{})
            if not (item is Dictionary) or str(item.get("correct","")).is_empty()                     or not (item.get("options",[]) is Array) or (item.get("options",[]) as Array).size() < 2:
                errors.append("Incomplete authored rescue action: " + str(objective))
    if not errors.is_empty():
        return false
    var outcome: Dictionary = quests.load_canonical_resources()
    if not outcome.get("success", false):
        errors.append("Canonical side-quest/lore data invalid: " + str(outcome.get("reason", "unknown")))
    registry_loaded = errors.is_empty()
    return registry_loaded

func bind_progress(progress) -> bool:
    if not registry_loaded and not load_registry():
        return false
    errors.clear() # Each save slot is an independent binding.
    current_chapter = int(progress.chapter)
    var saved: Variant = progress.rpg.get("endgame_expansion", {})
    if not (saved is Dictionary):
        errors.append("Saved endgame extension must be an object")
        return false
    var noe_saved: Variant = saved.get("noe", {})
    var quests_saved: Variant = saved.get("quests", {})
    var finale_saved: Variant = saved.get("finale", {})
    if not (noe_saved is Dictionary) or not (quests_saved is Dictionary) or not (finale_saved is Dictionary):
        errors.append("Saved endgame module state invalid")
        return false
    # Reset each rebinding; a failed restore never carries state from a previous slot.
    ticket_source_verified = false
    noe.is_adult_noe_playable = false
    noe.leadership_handover_phase = 0
    noe.chapter39_ticket = {}
    noe.memorial_finalized = false
    noe.memorial_archive_step = 0
    quests.unlocked_lore_documents.clear()
    quests.reset_bonds()
    finale.reset_for_save_binding()
    if not noe_saved.is_empty() and not noe.restore_state(noe_saved):
        errors.append("Invalid adult-Noe save state")
        return false
    if not quests_saved.is_empty() and not quests.restore_state(quests_saved):
        errors.append("Invalid side-quest/lore save state")
        return false
    if not finale_saved.is_empty() and not finale.restore_state(finale_saved):
        errors.append("Invalid saved finale evidence state")
        return false
    var evacuation_saved: Variant = saved.get("evacuation", {})
    var combat_saved: Variant = saved.get("evacuation_combat_receipts", {})
    if not (evacuation_saved is Dictionary):
        errors.append("Invalid saved evacuation field")
        return false
    if not (combat_saved is Dictionary):
        errors.append("Invalid saved rescue combat receipts")
        return false
    evacuation_combat_receipts = (combat_saved as Dictionary).duplicate(true)
    evacuation.reset()
    if current_chapter == 47:
        var expected_id: String = "ch047"
        var saved_stage: String = str(evacuation_saved.get("chapter_id", ""))
        if saved_stage == expected_id:
            if not evacuation.restore_state(evacuation_saved):
                errors.append("Invalid evacuation checkpoint")
                return false
        elif saved_stage not in ["", "ch046"]:
            errors.append("Unexpected evacuation checkpoint stage")
            return false
        elif not evacuation.begin_evacuation(expected_id, EVACUATION_TIME_LIMIT):
            errors.append("Evacuation initialization failed")
            return false
    # The original text shows Noe holding the single ticket in chapter 39;
    # migrate old V3 saves by provenance rather than inventing a second item.
    ticket_source_verified = ensure_ticket_provenance(progress)
    quests.sync_companion_bonds(progress.flags)
    if current_chapter >= 49:
        _try_start_adult_noe(progress.flags)
    _reconcile_finale(progress)
    return true

func ensure_ticket_provenance(progress: Object) -> bool:
    # A chapter flag alone is NOT evidence of possession. Never manufacture
    # Noe's ticket for an old save. The source must be the actual authored
    # chapter-39 investigation recorded in the V3 chapter completion commit.
    if progress == null or not bool(progress.flags.get("story.ch039.done",false)):
        return false
    var ledger: Dictionary = progress.rpg.get("canonical_item_provenance_v1",{})
    var source: Variant = ledger.get(TICKET_ID,{})
    if not (source is Dictionary):
        return false
    var ticket: Dictionary = source as Dictionary
    if str(ticket.get("id","")) != TICKET_ID             or str(ticket.get("source_scene","")) != "ch039.investigate"             or not bool(ticket.get("acquired",false))             or not bool(ticket.get("mother_name_inscribed",false)):
        return false
    if not noe.chapter39_ticket.is_empty():
        ticket_source_verified = noe.chapter39_ticket == ticket
        return ticket_source_verified
    ticket_source_verified = noe.capture_chapter39_ticket(ticket,progress.flags)
    return ticket_source_verified

func _try_start_adult_noe(story_flags: Dictionary) -> void:
    if not noe.is_adult_noe_playable:
        noe.trigger_twelve_years_timeskip(story_flags)

func _has_player_sequence(progress: Object, id: String, required: Array) -> bool:
    if progress == null or not bool(progress.flags.get("mechanic."+id+".ready",false)):
        return false
    var all_saved: Variant = progress.rpg.get("chapter_mechanics_v2",{})
    if not (all_saved is Dictionary):
        return false
    var raw: Variant = (all_saved as Dictionary).get(id,{})
    if not (raw is Dictionary) or not bool((raw as Dictionary).get("done",false)):
        return false
    # A generic 'done' bit alone does not prove which choices were made.
    var receipts: Variant = (raw as Dictionary).get("completed_actions",[])
    return receipts is Array and receipts == required

func _reconcile_finale(progress: Object) -> bool:
    if finale == null or progress == null:
        return false
    var flags: Dictionary = progress.flags
    var changed: bool = false
    if _has_player_sequence(progress,"ch058",[
            "verify_visha_archive","safeguard_witness","plan_human_override"]):
        var override: Dictionary = finale.install_visha_human_override_formula(flags)
        changed = bool(override.get("changed",false)) or changed
    if _has_player_sequence(progress,"ch059",[
            "consult_volunteers","audit_supply","draft_rotational_charter"]):
        var charter: Dictionary = finale.sign_rotational_lantern_charter(flags)
        changed = bool(charter.get("changed",false)) or changed
    if _has_player_sequence(progress,"ch064",[
            "align_solar_ring","align_civic_ring","align_mother_ring"]):
        for ring_index in range(3):
            var ring: Dictionary = finale.calibrate_sky_rail_ring(ring_index,flags)
            changed = bool(ring.get("changed",false)) or changed
    if _has_player_sequence(progress,"ch071",[
            "verify_childhood","hold_mutual_testimony","reject_hessian_monopoly"]):
        # The last receipt must be ch071.battle_won from actual settlement,
        # never the sequence itself, a cinematic event or ch072 flags.
        for stage in range(3):
            var phase: Dictionary = finale.execute_hessian_final_encounter_step(flags)
            if not bool(phase.get("success",false)):
                break
            changed = bool(phase.get("changed",false)) or changed
    return changed

func after_scene_committed(progress: Object) -> Dictionary:
    if not registry_loaded or progress == null:
        return {"success":false,"reason":"bridge_not_ready"}
    var flags: Dictionary = progress.flags
    var changed: bool = quests.sync_companion_bonds(flags)
    if bool(flags.get("story.ch039.done",false)) and noe.chapter39_ticket.is_empty():
        changed = ensure_ticket_provenance(progress) or changed
    if current_chapter >= 49 and bool(flags.get("ch049.started",false)) and not noe.is_adult_noe_playable:
        changed = bool(noe.trigger_twelve_years_timeskip(flags).get("success",false)) or changed
    # The chapter-54 memorial no longer finalizes from story flags.
    # A physically reached memorial marker plus three deliberate player
    # decisions are required, with the original ch039 ticket checked.
    changed = _reconcile_finale(progress) or changed
    return {"success":true,"changed":changed}
func eligible_interactions() -> Array[String]:
    var ids: Array[String] = []
    if not registry_loaded:
        return ids
    if current_chapter == 47 and not evacuation.finished:
        ids.append("evac:command")
        for squad in Evacuation.OBJECTIVE_MARKERS:
            for marker_id in Evacuation.OBJECTIVE_MARKERS[squad]:
                ids.append(str(marker_id))
    if current_chapter in [52,53,54]:
        ids.append("endgame:handover")
    if current_chapter == 54:
        ids.append("endgame:memorial")
    for lore_id in quests.lore_ids_for_chapter(current_chapter):
        ids.append("lore:" + lore_id)
    return ids
func interact(target: String, story_flags: Dictionary, action_id: String = "") -> Dictionary:
    if not registry_loaded:
        return {"success": false, "changed": false, "message": "终局扩展未能读取，当前事件不可进行。"}
    if current_chapter == 47 and target.begins_with("evac:"):
        if evacuation.failed and target == "evac:command":
            evacuation.reset()
            var restart_ok: bool = evacuation.begin_evacuation("ch047", EVACUATION_TIME_LIMIT)
            if restart_ok:
                # This is a new actual evacuation run, not a replay of the
                # previous three squad victories or their objective receipts.
                var prefix: String = "ch047."
                for key in evacuation_combat_receipts.keys():
                    if str(key).begins_with(prefix):
                        evacuation_combat_receipts.erase(key)
            return {"success": restart_ok, "changed": restart_ok,
                "restarted": restart_ok,
                "message": "撤离方案已重新部署。" if restart_ok else "重启失败。"}
        if not evacuation.running:
            return {"success": false, "changed": false, "message": "撤离已经结束，不能再次执行。"}
        if not bool(story_flags.get("ch047.decision_made",false)):
            return {"success":false,"changed":false,"message":"先完成第47章撤离现场抉择。"}
        if target == "evac:command":
            var keys: Array = ["EAST_GATE_LEISO", "SOUTH_GATE_SHUOXIAN", "WEST_GATE_TIFA"]
            var next_index: int = (keys.find(evacuation.active_controlled_squad) + 1) % keys.size()
            var squad_id: String = str(keys[next_index])
            evacuation.switch_controlled_squad(squad_id)
            return {"success": true, "changed": true, "message": "已切换小队：" + _team_label(squad_id)}
        var squad: String = ""
        for team in Evacuation.OBJECTIVE_MARKERS:
            if target in Evacuation.OBJECTIVE_MARKERS[team]:
                squad = str(team)
                break
        if squad.is_empty():
            return {"success": false, "changed": false, "message": "未知撤离目标。"}
        if evacuation.active_controlled_squad != squad:
            return {"success": false, "changed": false, "message": "请到指挥台切换到" + _team_label(squad)}
        var done: Array = evacuation.squad_statuses[squad]["completed_objectives"]
        var objectives: Array = evacuation.OBJECTIVES[squad]
        if done.size() >= objectives.size():
            return {"success": false, "changed": false, "message": _team_label(squad) + "已完成撤离。"}
        var objective_id: String = str(objectives[done.size()])
        if target != evacuation.current_objective_marker(squad):
            return {"success":false,"changed":false,"message":"请先完成本队前一个可达的救援点。"}
        if not bool(story_flags.get("ch047.evidence",false)):
            return {"success":false,"changed":false,"message":"请先调查第47章城门危机线索。"}
        if objective_id.ends_with("_encounter_won"):
            # One generic main-story Boss flag is not proof of three different
            # rescue encounters. Only first_act's settled live combat callback
            # is allowed to confirm this objective.
            return {"success":true,"changed":false,"start_encounter":true,
                "squad_id":squad,"message":_team_label(squad) + "：守军阻拦，请进入真实战斗。"}
        var authored: Dictionary = rescue_actions.get(objective_id,{})
        if authored.is_empty():
            return {"success":false,"changed":false,"message":"本队救援动作数据缺失。"}
        if action_id.is_empty():
            return {"success":true,"changed":false,"needs_choice":true,
                "choice_data":{"prompt":str(authored.get("prompt","请确认现场安全行动。")),
                    "options":(authored.get("options",[]) as Array).duplicate(true)},
                "message":_team_label(squad)}
        if action_id != str(authored.get("correct","")):
            return {"success":false,"changed":false,"message":"此操作无法保障居民安全，请重新调查。"}
        var result: Dictionary = evacuation.confirm_objective(squad,objective_id)
        return {"success":bool(result.get("success",false)),
            "changed":bool(result.get("success",false)),
            "message":_team_label(squad) + "：救援操作已确认（%d%%）" % int(result.get("progress",0))}
    if target == "endgame:memorial" and current_chapter == 54:
        if not ticket_source_verified:
            return {"success":false,"changed":false,
                "message":"第39章旧车票来源无法通过V3账本核实，旧版本归档标签不作为有效证明。请保留此旧档记录，不能自动合成车票。"}
        if noe.memorial_finalized:
            return {"success":true,"changed":false,
                "message":"第54章纪念册已归档：原始旧车票与见证者记录完整留存。"}
        if not bool(story_flags.get("ch054.battle_won",false))                 or not bool(story_flags.get("ch054.decision_made",false)):
            return {"success":false,"changed":false,
                "message":"请先亲自完成第54章真实Boss战及正典抉择。"}
        if noe.leadership_handover_phase != 3:
            return {"success":false,"changed":false,
                "message":"纪念册必须等三次交接会议真正完成后才能归档。"}
        if action_id.is_empty():
            var page: Dictionary = noe.memorial_prompt()
            if bool(page.get("done",false)):
                return {"success":true,"changed":false,"message":str(page.get("message","纪念册已归档。"))}
            return {"success":true,"changed":false,"needs_choice":true,
                "choice_data":{"prompt":str(page.get("prompt","纪念册调查")),
                    "options":(page.get("options",[]) as Array).duplicate(true)}}
        var archived: Dictionary = noe.advance_memorial_archive(action_id,story_flags)
        return {"success":bool(archived.get("success",false)),
            "changed":bool(archived.get("changed",false)),
            "message":str(archived.get("message",
                "纪念册调查条件不满足：" + str(archived.get("reason","unknown"))))}
    if target == "endgame:handover" and current_chapter in [52, 53, 54]:
        var expected_step: int = current_chapter - 51
        if not noe.is_adult_noe_playable:
            return {"success": false, "changed": false, "message": "诺依成年操作权尚未开启。"}
        if expected_step == 1 and not story_flags.get("story.ch051.done", false):
            return {"success": false, "changed": false, "message": "前代英雄尚未重聚。"}
        if expected_step == 2 and not story_flags.get("story.ch052.done", false):
            return {"success": false, "changed": false, "message": "协作前置剧情尚未完成。"}
        if not bool(story_flags.get("ch%03d.decision_made" % current_chapter,false)):
            return {"success":false,"changed":false,"message":"必须先完成本章抉择，交接会议才开放。"}
        if action_id.is_empty():
            var session_names: Array[String] = [
                "旧英雄重聚：核对职责与未解的损失",
                "新旧两代共同制定营地工作分配",
                "诺依主持交接，前代英雄作为顾问签署共识"
            ]
            return {"success":true,"changed":false,"needs_choice":true,
                "choice_data":{"prompt":session_names[expected_step - 1],
                    "options":[
                        {"id":"review_joint_record","label":"共同核对证词、职责和各方同意后记录本阶段"},
                        {"id":"postpone","label":"暂缓交接，继续与现场人员沟通"}
                    ]}}
        if action_id != "review_joint_record":
            return {"success":false,"changed":false,
                "message":"本阶段尚未取得明确同意，交接记录保持原状。"}
        var outcome: Dictionary = noe.execute_leadership_handover_step(expected_step,true,story_flags)
        return {"success":bool(outcome.get("success",false)),
            "changed":bool(outcome.get("success",false)),
            "message":str(outcome.get("description",outcome.get("reason","交接条件不足")))}
    return {"success": false, "changed": false, "message": "此处暂没有可触发的终局事件。"}

func confirm_real_encounter(squad_id: String, chapter_number: int, transaction_id: String) -> Dictionary:
    # Called ONLY after BattleV3Settlement persisted an actual non-boss win.
    if not registry_loaded or current_chapter != chapter_number or chapter_number != 47             or transaction_id.is_empty() or not evacuation.running             or squad_id != evacuation.active_controlled_squad:
        return {"success":false,"reason":"invalid_live_rescue_context"}
    var objectives: Array = Evacuation.OBJECTIVES.get(squad_id,[])
    var done: Array = evacuation.squad_statuses.get(squad_id,{}).get("completed_objectives",[])
    if done.size() >= objectives.size() or not str(objectives[done.size()]).ends_with("_encounter_won"):
        return {"success":false,"reason":"rescue_battle_not_expected"}
    var receipt_key: String = "ch%03d.%s" % [chapter_number,squad_id]
    if evacuation_combat_receipts.has(receipt_key):
        return {"success":false,"reason":"rescue_encounter_already_recorded"}
    var completed: Dictionary = evacuation.confirm_objective(squad_id,str(objectives[done.size()]))
    if not bool(completed.get("success",false)):
        return completed
    evacuation_combat_receipts[receipt_key] = transaction_id
    return {"success":true,"changed":true,"message":_team_label(squad_id)+"：实际战斗胜利，撤离路线安全。"}

func _team_label(squad_id: String) -> String:
    match squad_id:
        "EAST_GATE_LEISO": return "东门·雷索/岚音"
        "SOUTH_GATE_SHUOXIAN": return "南门·朔弦/诺依"
        "WEST_GATE_TIFA": return "西门·缇珐"
    return squad_id

func chapter_gate_message() -> String:
    if current_chapter == 54 and ticket_source_verified and not noe.memorial_finalized:
        if noe.leadership_handover_phase < 3:
            return "第54章必须先在现场完成三场实际交接会议，再整理纪念册。"
        return "第54章需要亲自前往纪念册桌，核对原始旧车票、证词来源并完成归档。"
    if current_chapter != 47:
        return ""
    if evacuation.failed:
        return "西门防线超时，请重新部署，不能跳过撤离。"
    if not evacuation.finished:
        return "请完成东门伤员、南门儿童、西门抢修的六项现场决策与三场真实守卫战。"
    return ""
func summary() -> String:
    if not registry_loaded:
        return ""
    if current_chapter == 47:
        var team: String = evacuation.active_controlled_squad
        return "【三门撤离】%s · %s · %d秒" % [
            _team_label(team),evacuation.current_objective_text(team),ceili(evacuation.seconds_remaining)]
    if current_chapter >= 49 and current_chapter <= 54:
        return "【十二年后】" + ("成年诺依 · 交接%d/3" % noe.leadership_handover_phase if noe.is_adult_noe_playable else "等待正典章节开启")
    return ""
func export_state() -> Dictionary:
    return {
        "evacuation": evacuation.export_state(),
        "evacuation_combat_receipts": evacuation_combat_receipts.duplicate(true),
        "noe": noe.export_state(),
        "quests": quests.export_state(),
        "finale": finale.export_state()
    }
