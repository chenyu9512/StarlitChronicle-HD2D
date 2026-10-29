# res://scripts/systems/StarlightJournal.gd
class_name StarlightJournalSystem
extends Node

signal evidence_registered(entry: Dictionary)
signal inference_promoted_to_fact(clue_id: String, merged_fact: Dictionary)
signal object_closeup_requested(item_id: String, hotspot_list: Array)

enum ClueCategory {
	VERIFIED_FACT,      # 【已核实物证】现场观察、拓印比对、双方确认的实物
	PENDING_INFERENCE   # 【待核实推断】单方面传闻、机械记录表象、待交叉验证的怀疑
}

var verified_facts: Dictionary = {}
var pending_inferences: Dictionary = {}

# 预置第一幕至第二幕核心可触摸物证交互配置
const INTERACTIVE_EVIDENCE_DB: Dictionary = {
	"ev_ch001_envelope": {
		"title": "带有海盐结晶的旧信封",
		"chapter": "ch001",
		"hotspots": [
			{"id": "back_salt", "label": "信封背面的蓝染海盐颗粒", "grants_clue": "fact_ch001_blue_salt"},
			{"id": "indent_mark", "label": "信纸下方的村长收据压痕", "grants_clue": "fact_ch001_receipt_indent"}
		]
	},
	"ev_ch003_half_badge": {
		"title": "卡在潮汐齿轮里的半枚歪树船徽",
		"chapter": "ch003",
		"hotspots": [
			{"id": "fracture_edge", "label": "新近断裂的铜茬口", "grants_clue": "fact_ch003_fresh_break"},
			{"id": "crooked_tree", "label": "歪树徽记（与朔弦旧徽记吻合）", "grants_clue": "fact_ch003_shuoxian_ship_match"}
		]
	},
	"ev_ch007_rejected_letters": {
		"title": "三封被退回的求助函",
		"chapter": "ch007",
		"hotspots": [
			{"id": "seal_rubbing", "label": "用薄纸拓印三枚退回印章的缺口", "grants_clue": "fact_ch007_identical_seal_notch"}
		]
	},
	"ev_ch008_caravan_site": {
		"title": "灰鹰商道遇袭现场遗留物",
		"chapter": "ch008",
		"hotspots": [
			{"id": "arrow_shaft", "label": "刻有王都军械库批次号的断箭", "grants_clue": "fact_ch008_armory_serial"},
			{"id": "spilled_powder", "label": "散落的救济站同款止血药粉", "grants_clue": "inf_ch008_relief_station_suspicion"}
		]
	}
}


func inspect_physical_object(evidence_id: String) -> void:
	if not INTERACTIVE_EVIDENCE_DB.has(evidence_id):
		return
	var data: Dictionary = INTERACTIVE_EVIDENCE_DB[evidence_id]
	emit_signal("object_closeup_requested", evidence_id, data["hotspots"])


func register_clue(clue_id: String, title: String, desc: String, category: ClueCategory) -> void:
	var entry := {
		"id": clue_id,
		"title": title,
		"description": desc,
		"category": category
	}
	# 已核实事实不可被后续的待核实推断降级；同一条证据重复登记不重复发信号。
	if category == ClueCategory.PENDING_INFERENCE and verified_facts.has(clue_id):
		return
	if category == ClueCategory.VERIFIED_FACT:
		if verified_facts.get(clue_id, {}) == entry:
			return
		pending_inferences.erase(clue_id)
		verified_facts[clue_id] = entry
	else:
		if pending_inferences.get(clue_id, {}) == entry:
			return
		pending_inferences[clue_id] = entry
	emit_signal("evidence_registered", entry)


func verify_and_resolve_inference(inference_id: String, counter_proof_id: String, resolved_fact_title: String, resolved_desc: String) -> void:
	# 例如第8章：用“药粉批号流向记录”排除对无辜救济站居民的怀疑，转为已核实事实
	if pending_inferences.has(inference_id) and verified_facts.has(counter_proof_id):
		var fact_id: String = inference_id + "_verified"
		if verified_facts.has(fact_id):
			pending_inferences.erase(inference_id)
			return
		pending_inferences.erase(inference_id)
		var fact_entry := {
			"id": inference_id + "_verified",
			"title": resolved_fact_title,
			"description": resolved_desc,
			"category": ClueCategory.VERIFIED_FACT
		}
		verified_facts[fact_entry["id"]] = fact_entry
		emit_signal("inference_promoted_to_fact", inference_id, fact_entry)