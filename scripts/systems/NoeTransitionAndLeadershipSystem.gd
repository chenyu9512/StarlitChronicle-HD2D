class_name NoeTransitionAndLeadershipSystem
extends Node
## 第49–54章代际交接。状态由正式剧情旗标驱动；不得伪造第39章旧车票。

signal twelve_years_time_skipped(new_era_label: String)
signal leadership_transition_progress(step_index: int, description: String)
signal memorial_book_finalized(ticket_item_state: Dictionary)

const ERA_LABEL := "TWELVE_YEARS_LATER_POST_WAR"
var is_adult_noe_playable: bool = false
var leadership_handover_phase: int = 0
var chapter39_ticket: Dictionary = {}
var memorial_finalized: bool = false
var memorial_archive_step: int = 0

func trigger_twelve_years_timeskip(story_flags: Dictionary) -> Dictionary:
    if not story_flags.get("story.ch048.done", false) or not story_flags.get("ch049.started", false):
        return {"success": false, "reason": "chapter_49_not_started"}
    if is_adult_noe_playable:
        return {"success": false, "reason": "already_transitioned"}
    is_adult_noe_playable = true
    twelve_years_time_skipped.emit(ERA_LABEL)
    return {"success": true, "era": ERA_LABEL, "active_pov": "诺依"}

func execute_leadership_handover_step(step: int, confirmed_by_old_heroes: bool, story_flags: Dictionary) -> Dictionary:
    if not is_adult_noe_playable or not confirmed_by_old_heroes:
        return {"success": false, "reason": "no_valid_handover_consent"}
    if step != leadership_handover_phase + 1 or step < 1 or step > 3:
        return {"success": false, "reason": "invalid_step_order"}
    if step == 3 and (not story_flags.get("ch054.decision_made", false) or not story_flags.get("ch054.battle_won", false)):
        return {"success": false, "reason": "chapter_54_outcome_pending"}
    var descriptions := {
        1: "旧英雄重聚与职责盘点",
        2: "新旧两代共同制定营地职责分工",
        3: "成年诺依主导公开分工，旧英雄正式转为协作顾问"
    }
    leadership_handover_phase = step
    leadership_transition_progress.emit(step, descriptions[step])
    return {"success": true, "phase": leadership_handover_phase, "description": descriptions[step]}

func capture_chapter39_ticket(ticket_item_data: Dictionary, story_flags: Dictionary) -> bool:
    # 必须从原有存档/物品账本读取同一遗物；不在这里合成新车票。
    if not story_flags.get("story.ch039.done", false):
        return false
    if not ticket_item_data.get("acquired", false) or not ticket_item_data.get("mother_name_inscribed", false):
        return false
    if str(ticket_item_data.get("id", "")).is_empty():
        return false
    if not chapter39_ticket.is_empty():
        return chapter39_ticket == ticket_item_data
    chapter39_ticket = ticket_item_data.duplicate(true)
    return true

func memorial_prompt() -> Dictionary:
    if memorial_finalized:
        return {"done":true,"message":"纪念册已完成归档。旧车票作为单一原件保存，未复制或消耗。"}
    match memorial_archive_step:
        0:
            return {"prompt":"纪念册 · 第一页：核对旧车票。请确认文物来源。",
                "options":[
                    {"id":"verify_original_ticket","label":"核对第39章原始调查的车票与母亲留下的姓名"},
                    {"id":"invent_replica","label":"用一张新车票替代来源不明的旧车票"}
                ]}
        1:
            return {"prompt":"纪念册 · 第二页：怎样收录见证者的不同记忆？",
                "options":[
                    {"id":"retain_witness_sources","label":"分别记录证词来源与见证时间，保留差异"},
                    {"id":"merge_unverified","label":"将矛盾证词重写成单一结论"}
                ]}
        2:
            return {"prompt":"纪念册 · 最后一页：成年诺依准备将旧车票归档。",
                "options":[
                    {"id":"place_original_ticket","label":"亲手将同一张原始旧车票放入纪念册，保留所有权记录"},
                    {"id":"discard_original","label":"销毁车票，仅留下无来源的誊本"}
                ]}
    return {}

func advance_memorial_archive(action_id: String, story_flags: Dictionary) -> Dictionary:
    if memorial_finalized or memorial_archive_step < 0 or memorial_archive_step > 2:
        return {"success":false,"reason":"memorial_already_finished_or_invalid"}
    if not is_adult_noe_playable or leadership_handover_phase != 3:
        return {"success":false,"reason":"leadership_handover_incomplete"}
    if not bool(story_flags.get("ch054.battle_won",false))             or not bool(story_flags.get("ch054.decision_made",false)):
        return {"success":false,"reason":"ch054_real_battle_and_choice_required"}
    if chapter39_ticket.is_empty():
        return {"success":false,"reason":"original_ch039_ticket_missing"}
    var expected: Array[String] = ["verify_original_ticket","retain_witness_sources","place_original_ticket"]
    if action_id != expected[memorial_archive_step]:
        return {"success":false,"reason":"source_or_archive_procedure_not_verified"}
    if memorial_archive_step == 2:
        var finalized: Dictionary = finalize_noe_memorial_book(chapter39_ticket,story_flags)
        if not bool(finalized.get("success",false)):
            return finalized
    memorial_archive_step += 1
    return {"success":true,"changed":true,"done":memorial_finalized,
        "step":memorial_archive_step,
        "message":"诺依已完成纪念册调查 %d/3。%s" % [memorial_archive_step,
            "原始旧车票已归档。" if memorial_finalized else "请继续核对下一页。"]}

func finalize_noe_memorial_book(ticket_item_data: Dictionary, story_flags: Dictionary) -> Dictionary:
    if memorial_finalized or not is_adult_noe_playable:
        return {"success": false, "reason": "not_ready_or_already_finalized"}
    if not story_flags.get("ch054.battle_won", false):
        return {"success": false, "reason": "chapter_54_battle_pending"}
    if chapter39_ticket.is_empty() or ticket_item_data != chapter39_ticket:
        return {"success": false, "reason": "chapter_39_ticket_identity_mismatch"}
    memorial_finalized = true
    memorial_book_finalized.emit(chapter39_ticket.duplicate(true))
    return {"success": true, "ticket_id": str(chapter39_ticket["id"])}

func export_state() -> Dictionary:
    return {
        "is_adult_noe_playable": is_adult_noe_playable,
        "leadership_handover_phase": leadership_handover_phase,
        "chapter39_ticket": chapter39_ticket.duplicate(true),
        "memorial_finalized": memorial_finalized,
        "memorial_archive_step": memorial_archive_step
    }

func restore_state(data: Dictionary) -> bool:
    var phase: int = int(data.get("leadership_handover_phase", -1))
    var ticket: Variant = data.get("chapter39_ticket", null)
    if phase < 0 or phase > 3 or not (ticket is Dictionary):
        return false
    if not data.get("is_adult_noe_playable", false) and phase > 0:
        return false
    if data.get("memorial_finalized", false) and ticket.is_empty():
        return false
    var saved_step: int = int(data.get("memorial_archive_step",3 if bool(data.get("memorial_finalized",false)) else 0))
    if saved_step < 0 or saved_step > 3:
        return false
    if bool(data.get("memorial_finalized",false)) and saved_step != 3:
        return false
    if saved_step > 0 and (ticket.is_empty() or not bool(data.get("is_adult_noe_playable",false)) or phase != 3):
        return false
    is_adult_noe_playable = bool(data.get("is_adult_noe_playable", false))
    leadership_handover_phase = phase
    chapter39_ticket = ticket.duplicate(true)
    memorial_finalized = bool(data.get("memorial_finalized", false))
    memorial_archive_step = saved_step
    return true
