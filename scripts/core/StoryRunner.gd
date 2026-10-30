# res://scripts/core/StoryRunner.gd
class_name StoryRunnerSystem
extends Node

signal chapter_started(chapter_id: String, stage_id: String)
signal stage_advanced(chapter_id: String, new_stage_id: String, objective_type: String)
signal optional_scene_available(scene_data: Dictionary)
signal choice_reaction_triggered(chapter_id: String, choice_key: String, reaction_lines: Array)
signal world_diff_applied(chapter_id: String, diff_id: String)
signal flashback_sandbox_toggled(is_active: bool, era_id: String)
signal ending_resolved(ending_code: String, epilogue_data: Dictionary)

enum PartyMemberState {
	UNMET,
	RECORD_ONLY,      # 仅档案/文本提及（如第23/24/43章的维莎）
	ACQUAINTED,       # 剧情相识/同行对话，不可参战（如第7章雷索、第32-33章玄璃）
	GUEST_SUPPORT,    # 临时支援/向导，不可自由编队（如第8章雷索、第27章伊泽）
	PROTECTED_CHILD,  # 受照护儿童（第39-48章诺依）
	ACTIVE_PARTY      # 正式入队可编队参战
}

const STAGES: Array[String] = ["opening", "investigate", "crisis", "resolve"]

var current_chapter_num: int = 1
var current_chapter_id: String = "ch001"
var current_stage_index: int = 0

# 双轨选择旗标统计（用于结局A/B/C与后日谈分支）
var story_flags: Dictionary = {}
var listen_hear_score: int = 0
var act_protect_score: int = 0

# 世界持久变化层（记录每章 resolve 后的地图可视变化）
var active_world_diffs: Dictionary = {}

# 伙伴状态表与羁绊阶梯（0:相识, 1:信任, 2:并肩, 3:家人/浪漫）
var roster_states: Dictionary = {
	"protagonist": PartyMemberState.ACTIVE_PARTY,
	"lanyin": PartyMemberState.ACTIVE_PARTY,
	"shuoxian": PartyMemberState.UNMET,
	"leiso": PartyMemberState.UNMET,
	"tifa": PartyMemberState.UNMET,
	"ize": PartyMemberState.UNMET,
	"xuanli": PartyMemberState.UNMET,
	"noe": PartyMemberState.UNMET,
	"visha": PartyMemberState.UNMET,
}

var bond_ranks: Dictionary = {
	"lanyin": 0, "shuoxian": 0, "leiso": 0, "tifa": 0,
	"ize": 0, "xuanli": 0, "noe": 0, "visha": 0
}
var romance_partner: String = "" # 可为空，全员不恋爱亦可完整达成结局C

# 现世队伍快照（用于第19-21章回忆篇挂起与恢复）
var _saved_present_Snapshot: Dictionary = {}
var is_in_flashback_sandbox: bool = false

# 关键跨时代唯一物品状态（第39章诺依母亲旧车票 -> 第54章收入纪念册）
var persistent_key_items: Dictionary = {
	"item_noe_mother_ticket": {
		"acquired": false,
		"mother_name_inscribed": true, # 第39章登场时即写有母亲姓名并与井壁围裙呼应
		"archived_in_memorial_book": false
	}
}

# 收集品：12张失落航页（严格独立于第26章主线证据）
var collected_lost_pages: Array[String] = []
var mother_lamps_rekindled_by_shared_witness: int = 0


func start_chapter(chapter_num: int, chapter_payload: Dictionary) -> void:
	current_chapter_num = chapter_num
	current_chapter_id = "ch%03d" % chapter_num
	current_stage_index = 0
	
	_enforce_v21_roster_timeline(chapter_num, "opening")
	_check_flashback_sandbox_entry(chapter_num)
	
	emit_signal("chapter_started", current_chapter_id, STAGES[0])
	_mount_optional_scenes(chapter_payload.get("optional_scenes", []))


func advance_stage(chapter_payload: Dictionary) -> void:
	var current_stage_name: String = STAGES[current_stage_index]
	
	# 第21章特殊正典防呆锁：crisis结束进入抉择前，必须先从十年前药房切回现世营火旁
	if current_chapter_num == 21 and current_stage_name == "crisis":
		_exit_flashback_sandbox_to_present_campfire()
	
	if current_stage_index < STAGES.size() - 1:
		current_stage_index += 1
		var next_stage: String = STAGES[current_stage_index]
		_enforce_v21_roster_timeline(current_chapter_num, next_stage)
		
		var stage_data: Dictionary = _get_stage_data(chapter_payload, next_stage)
		emit_signal("stage_advanced", current_chapter_id, next_stage, stage_data.get("objective_type", "reach"))
		
		if next_stage == "resolve":
			_apply_chapter_resolve_world_diffs(current_chapter_num)
			if is_in_flashback_sandbox:
				_exit_flashback_sandbox_to_present_campfire()


# 支持仓库既有 scenes 列表与编译索引 stages；不假定主数据已有 stages。
func _get_stage_data(chapter_payload: Dictionary, stage_id: String) -> Dictionary:
	var stages = chapter_payload.get("stages", {})
	if stages is Dictionary and stages.has(stage_id):
		return stages[stage_id]
	for scene in chapter_payload.get("scenes", []):
		if not scene is Dictionary:
			continue
		if str(scene.get("id", "")) != "%s.%s" % [current_chapter_id, stage_id]:
			continue
		var data: Dictionary = scene.duplicate(true)
		var objectives = data.get("objectives", [])
		if objectives is Array and not objectives.is_empty() and objectives[0] is Dictionary:
			data["objective_type"] = str(objectives[0].get("type", "reach"))
		return data
	return {}


func record_chapter_choice(choice_branch: String, chapter_payload: Dictionary) -> void:
	# 同章只接受第一次合法选择，避免重载、回放或重复交互累计两次分值。
	if not choice_branch in ["listen", "hear", "act", "protect"]:
		return
	for branch in ["listen", "hear", "act", "protect"]:
		if story_flags.get("flag.%s.%s" % [current_chapter_id, branch], false):
			return
	var flag_key := "flag.%s.%s" % [current_chapter_id, choice_branch]
	story_flags[flag_key] = true
	
	if choice_branch in ["listen", "hear"]:
		listen_hear_score += 1
	elif choice_branch in ["act", "protect"]:
		act_protect_score += 1
	
	# 立即触发 choice_reactions.json 中的伙伴与环境即时反馈
	for reaction in chapter_payload.get("choice_reactions", []):
		if reaction.get("choice") == choice_branch or reaction.get("flag") == flag_key:
			emit_signal("choice_reaction_triggered", current_chapter_id, choice_branch, reaction.get("lines", []))


func _enforce_v21_roster_timeline(ch_num: int, stage_id: String) -> void:
	# 朔弦：第2章相识，第3章正式入队
	if ch_num == 2:
		roster_states["shuoxian"] = PartyMemberState.ACQUAINTED
	elif ch_num >= 3:
		roster_states["shuoxian"] = PartyMemberState.ACTIVE_PARTY

	# 雷索：第7章相识，第8章灰鹰商道临时支援，第9章 resolve 后正式入队
	if ch_num == 7:
		roster_states["leiso"] = PartyMemberState.ACQUAINTED
	elif ch_num == 8:
		roster_states["leiso"] = PartyMemberState.GUEST_SUPPORT
	elif (ch_num == 9 and stage_id == "resolve") or ch_num > 9:
		roster_states["leiso"] = PartyMemberState.ACTIVE_PARTY

	# 缇珐：第13章登场，第14章入队
	if ch_num == 13:
		roster_states["tifa"] = PartyMemberState.ACQUAINTED
	elif ch_num >= 14:
		roster_states["tifa"] = PartyMemberState.ACTIVE_PARTY

	# 伊泽：第22章严禁登场；第27章向导支援；第28章断歌礁 resolve 正式入队
	if ch_num == 22:
		roster_states["ize"] = PartyMemberState.UNMET
	elif ch_num == 27:
		roster_states["ize"] = PartyMemberState.GUEST_SUPPORT
	elif (ch_num == 28 and stage_id == "resolve") or ch_num > 28:
		roster_states["ize"] = PartyMemberState.ACTIVE_PARTY

	# 玄璃：第32-34章 crisis 前为非战斗同伴；第34章无名剧场 resolve 写下名字后正式入队
	if ch_num in [32, 33] or (ch_num == 34 and stage_id != "resolve"):
		roster_states["xuanli"] = PartyMemberState.ACQUAINTED
	elif (ch_num == 34 and stage_id == "resolve") or ch_num > 34:
		roster_states["xuanli"] = PartyMemberState.ACTIVE_PARTY

	# 诺依：第39-48章受照护儿童；第49章十二年后成年转为可操作主角
	if ch_num >= 39 and ch_num <= 48:
		roster_states["noe"] = PartyMemberState.PROTECTED_CHILD
		persistent_key_items["item_noe_mother_ticket"]["acquired"] = true
	elif ch_num >= 49:
		roster_states["noe"] = PartyMemberState.ACTIVE_PARTY
		if ch_num == 54 and stage_id == "resolve":
			# 第54章直接读取第39章同一张旧车票状态收入纪念册，不生成新身世设定
			persistent_key_items["item_noe_mother_ticket"]["archived_in_memorial_book"] = true

	# 维莎：第23/24/43章仅档案线索；第58章 resolve 正式入队
	if ch_num in [23, 24, 43]:
		roster_states["visha"] = PartyMemberState.RECORD_ONLY
	elif (ch_num == 58 and stage_id == "resolve") or ch_num > 58:
		roster_states["visha"] = PartyMemberState.ACTIVE_PARTY


func _check_flashback_sandbox_entry(ch_num: int) -> void:
	if ch_num in [19, 20, 21]:
		is_in_flashback_sandbox = true
		_saved_present_Snapshot = roster_states.duplicate(true)
		var era_label := "ten_years_ago" if ch_num in [19, 21] else "seven_years_ago"
		emit_signal("flashback_sandbox_toggled", true, era_label)


func _exit_flashback_sandbox_to_present_campfire() -> void:
	if is_in_flashback_sandbox:
		is_in_flashback_sandbox = false
		roster_states = _saved_present_Snapshot.duplicate(true)
		emit_signal("flashback_sandbox_toggled", false, "present_campfire")


func _mount_optional_scenes(scenes: Array) -> void:
	for s in scenes:
		emit_signal("optional_scene_available", s)


func _apply_chapter_resolve_world_diffs(ch_num: int) -> void:
	var diff_map := {
		1: "diff_ch001_village_lantern_and_salt_receipt",
		3: "diff_ch003_sea_cave_tide_bridge_locked",
		6: "diff_ch006_tide_song_lamp_rekindled",
		7: "diff_ch007_back_alley_lamp_and_daily_medicine_board",
		8: "diff_ch008_old_inn_first_window_and_price_board",
		11: "diff_ch011_bridge_pedestrian_white_line",
		13: "diff_ch013_mine_shaft_pending_verification_tags",
		31: "diff_ch031_sundial_street_clock_advanced_one_tick",
		36: "diff_ch036_mirror_capital_dynamic_shadows_enabled",
		38: "diff_ch038_archive_pending_confirmation_shelf",
	}
	if diff_map.has(ch_num):
		var diff_id: String = diff_map[ch_num]
		if active_world_diffs.get(diff_id, false):
			return
		active_world_diffs[diff_id] = true
		emit_signal("world_diff_applied", current_chapter_id, diff_id)


func try_set_romance(character_id: String) -> bool:
	# 硬编码铁律：诺依固定为受收养/监护的下一代角色，严禁开启恋爱分支
	if character_id == "noe":
		push_warning("[Canon Guardrail] 诺依为受监护下一代角色，已硬编码锁定无恋爱分支。")
		return false
	if bond_ranks.has(character_id) and roster_states.get(character_id, PartyMemberState.UNMET) == PartyMemberState.ACTIVE_PARTY and bond_ranks[character_id] >= 3:
		romance_partner = character_id
		return true
	return false


func evaluate_final_ending() -> String:
	# 第72章三结局判定器：
	# 结局C（群灯共生/分担制度）需满足：承担代价 + 建立分散守灯制度 + 收集足够历史见证（非强制全恋爱）
	var has_shared_institution: bool = story_flags.get("flag.ch071.shared_stewardship", false)
	var has_sufficient_witness: bool = (mother_lamps_rekindled_by_shared_witness >= 6 and collected_lost_pages.size() >= 8)
	var accepted_cost: bool = story_flags.get("flag.ch072.accept_shared_cost", false)
	
	var ending_code := "ENDING_A"
	if has_shared_institution and has_sufficient_witness and accepted_cost:
		ending_code = "ENDING_C"
	elif act_protect_score > listen_hear_score:
		ending_code = "ENDING_B"
	
	emit_signal("ending_resolved", ending_code, {
		"romance_partner": romance_partner,
		"lost_pages_count": collected_lost_pages.size(),
		"world_diffs_count": active_world_diffs.size()
	})
	return ending_code