# res://scripts/mechanics/Act01Mechanics.gd
class_name Act01MechanicsController
extends Node

# --- 第3章：断桅海蚀洞三座潮汐机关状态 ---
signal tide_water_level_changed(new_level: String)
signal rotary_bridge_locked(is_locked: bool)
signal guardian_power_cut(is_cut: bool)
signal boss_ch003_pacified(method: String)

var valve_1_depressurized: bool = false
var valve_2_wedge_inserted: bool = false
var valve_3_guardian_shutoff: bool = false
var boss_ch003_chest_lamp_blinking: bool = false
var boss_ch003_is_pacified: bool = false

# --- 第5章：鲸骨浅滩缚潮古兽拆锁战状态 ---
signal fisherman_red_flag_warned(Incoming_wave_dir: String)
signal ancient_beast_back_exposed(is_exposed: bool)
signal star_lock_dismantled(locks_remaining: int)

var beast_star_locks_remaining: int = 3
var boss_ch005_is_complete: bool = false
var beast_back_vulnerable: bool = false
var star_vein_glowing_hazard: bool = false


# ==========================================
# 第3章：断桅海蚀洞机关与潮痕守卫 (boss.ch003)
# ==========================================
func operate_sea_cave_mechanism(mechanism_index: int, has_stone_wedge: bool = false) -> String:
	match mechanism_index:
		1:
			if valve_1_depressurized:
				return "1号潮汐阀已经泄压。"
			valve_1_depressurized = true
			emit_signal("tide_water_level_changed", "LOW_TIDE_SAFE")
			return "1号潮汐阀已泄压：海蚀洞水位下降，露出2号转桥基座。"
		2:
			if valve_2_wedge_inserted:
				return "2号转桥已经固定。"
			if not valve_1_depressurized:
				return "水位过高，无法接近2号转桥基座！需先操作1号泄压阀。"
			if not has_stone_wedge:
				return "转桥随暗流摆动，需要放入石楔固定。"
			valve_2_wedge_inserted = true
			emit_signal("rotary_bridge_locked", true)
			return "2号转桥已用石楔锁死，通往3号中枢的栈道已连通。"
		3:
			if valve_3_guardian_shutoff:
				return "3号守卫供能回路已经关闭。"
			if not valve_2_wedge_inserted:
				return "转桥尚未固定，无法抵达3号守卫控制闸。"
			valve_3_guardian_shutoff = true
			emit_signal("guardian_power_cut", true)
			return "3号控制闸已拉下：潮痕守卫的外部供能回路已切断。"
	return ""


# The *physical*, reachable cave devices are the V7 map_coast_04 controls.
# Their authored order is b (middle) -> a (left) -> c (right).
# Rehydrate the tactical readiness from the persisted V7 sequence; never
# invent a stone wedge, completion flag or a second reward ledger.
func restore_from_cave_snapshot(snapshot: Dictionary) -> void:
	var stage: int = clampi(int(snapshot.get("index", 0)), 0, 3)
	valve_1_depressurized = stage >= 1
	valve_2_wedge_inserted = stage >= 2
	valve_3_guardian_shutoff = stage >= 3


func on_boss_ch003_pre_attack_telegraph() -> void:
	# 已完成非暴力结算后不再开放新交互窗口。
	if boss_ch003_is_pacified:
		return
	boss_ch003_chest_lamp_blinking = true


func execute_boss_ch003_tactical_action(action_type: String, has_half_badge: bool) -> Dictionary:
	if boss_ch003_is_pacified:
		return {"success": false, "msg": "守卫已经停止追踪，不能重复结算。"}
	if not boss_ch003_chest_lamp_blinking:
		return {"success": false, "msg": "守卫正处于高频警戒状态，需等待其胸口灯闪烁停顿时行动！"}
	
	match action_type:
		"PULL_BACK_ALLY":
			boss_ch003_chest_lamp_blinking = false
			return {"success": true, "msg": "趁守卫胸口灯闪烁停顿，成功将受困同伴拉离潮汐冲击区！"}
		"SHOW_CROOKED_TREE_BADGE":
			if has_half_badge:
				boss_ch003_is_pacified = true
				boss_ch003_chest_lamp_blinking = false
				emit_signal("boss_ch003_pacified", "BADGE_RECOGNIZED")
				return {"success": true, "msg": "出示半枚歪树船徽！潮痕守卫识别出旧船员信物，停止了追踪指令。"}
			return {"success": false, "msg": "尚未在机关齿轮中取得半枚歪树船徽。"}
	return {"success": false, "msg": "未知战术动作"}


# ==========================================
# 第5章：鲸骨浅滩·缚潮古兽 (boss.ch005) 拆锁战
# ==========================================
func trigger_fisherman_red_flag_warning() -> void:
	if boss_ch005_is_complete:
		return
	star_vein_glowing_hazard = true
	emit_signal("fisherman_red_flag_warned", "STAR_VEIN_SURGE")


func trigger_shuoxian_double_whistle() -> String:
	if boss_ch005_is_complete:
		return "三处星纹锁已解开，古兽已经离开战场。"
	if beast_back_vulnerable and not star_vein_glowing_hazard:
		return "古兽背部已经露出，抓紧时机拆下未发亮的星纹锁。"
	# 朔弦吹响两声短哨，引导古兽转身露出脊背星纹锁，同时避开星纹发亮处
	beast_back_vulnerable = true
	star_vein_glowing_hazard = false
	emit_signal("ancient_beast_back_exposed", true)
	return "朔弦吹响两声海猎短哨！缚潮古兽循声侧转，脊背未发亮的星纹锁扣暴露了出来！"


func attempt_dismantle_star_lock(targeted_glowing_spot: bool) -> Dictionary:
	if boss_ch005_is_complete or beast_star_locks_remaining <= 0:
		return {"success": false, "battle_complete": false, "msg": "锁扣已全部拆解，结算不可重复触发。"}
	if not beast_back_vulnerable:
		return {"success": false, "damage_taken": 15, "msg": "古兽正面甲壳坚硬，需先由朔弦吹哨引导其转身！"}
	if targeted_glowing_spot or star_vein_glowing_hazard:
		return {"success": false, "damage_taken": 30, "msg": "警告：触碰了正在发亮的星纹过载区，遭到潮汐反冲！必须避开发亮处拆锁！"}
	
	beast_star_locks_remaining = max(0, beast_star_locks_remaining - 1)
	beast_back_vulnerable = false
	emit_signal("star_lock_dismantled", beast_star_locks_remaining)
	
	if beast_star_locks_remaining == 0:
		boss_ch005_is_complete = true
		return {"success": true, "battle_complete": true, "msg": "三处星纹锁全部安全拆解！缚潮古兽摆脱了强制束缚，缓缓潜回外海深水区。"}
	return {"success": true, "battle_complete": false, "msg": "成功拆解一处星纹锁！剩余锁扣：%d" % beast_star_locks_remaining}