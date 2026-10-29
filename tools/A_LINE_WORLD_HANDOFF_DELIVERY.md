# A线交付：战斗 ↔ 世界探索状态交接

> 更新：2026-10-26。此文档仅证明已提交代码和静态审计；**Godot 4.7.2运行结果待A/B/C/D统一验收**。禁止将未运行的脚本声称通过。

## 1. 已实施（A线独占范围）

| 文件 | 内容 |
| --- | --- |
| scripts/battle_world_handoff.gd | 统一开战准入检查、战前快照、唯一结算、战后坐标/朝向恢复、战败阻挡出生点螺旋搜索、队友回位、步行距离冷却 |
| scripts/first_act_battle.gd | 可选prepare_world_handoff() / handoff_to_world()接口、FirstAct宿主自动捕获世界、completed前自动恢复、last_world_handoff_result；保留66 Boss非致命结局和原有奖励信号 |
| tools/smoke_a_line_world_handoff.gd | 随机/剧情准入，室内/城镇/对话/过场拒绝，防重复开战和结算，朝向/地图保存，障碍避让，跨地图返回，Boss结局和原控制器自动接入 |
| scripts/encounter_registry.gd | 原有63怪/66 Boss目录及数值不受本次交接改动影响 |

自动接入只发生在Battle的父节点具有现有FirstAct战斗完成处理函数时；独立测试Battle可使用显式API。交接脚本不修改角色HP/MP、XP、金币、职业经验、任务旗标或存档文件，避免双重结算。

## 2. 审计发现（有源码依据）

- scripts/first_act_world.gd::_physics_process 已经按「非室内、非settlement、章节≥2、角色实际移动」累计随机遇敌；地图一旦build()，encounter_meter重设0且阈值重抽。因此现有普通建筑往返存在过快重启遇敌计量的体验风险。
- scripts/first_act.gd::_start_battle 防止已有battle对象时重复创建；但只靠对象存在并不足以处理完整的对话/切地图/已结算Boss守卫。
- scripts/first_act.gd::_random_encounter 当前只识别no_encounters开关，需要D线使用A线准入接口进行二次防护。
- scripts/first_act.gd::_battle_finished 原有失败恢复只尝试terrain_layout.spawn一个格子；如已被占用，则保留原位。A线在completed信号前先找可行替代格，确保原有受保护控制器能够看到安全坐标。
- 同一函数在失败时把encounter_meter设为-380；A线更长的DEFEAT_GRACE_PIXELS可能被覆盖。请D线按以下补丁处理。
- 已有战斗结束的UI、活动状态和音频还原由共享控制器负责；A线不擅自解锁world.locked，避免对话、菜单及剧情过场中出现额外输入。
- 原有Boss的last_boss_settlement属于战斗对象；现有第一幕控制器在记录前置battle=null。D线应在清除引用前读取此字段。

## 3. 状态交接契约（供D线直接使用）

使用：const BattleWorldHandoff = preload("res://scripts/battle_world_handoff.gd")

开战前（**world.locked被随机遇敌信号置为true不是busy条件**）：

```gdscript
var ctx: Dictionary = {
    "chapter": progress.chapter,
    "already_battling": is_instance_valid(battle),
    "busy": busy,  # 不使用world.locked，随机遇敌触发前它已经为true
    "dialogue_open": paused_for_dialogue or ui.dialog_layer.visible,
    "cinematic": cinematic != null and cinematic.is_playing(),
    "transitioning": false,  # D线接入自己的SceneTransition真实状态
    "player_valid": is_instance_valid(world.hero),
    "settlement": bool(world.map_profile.get("settlement", false)),
    "interior_building": world.interior_building,
    "no_encounters": no_encounters,
    "boss_resolved": bool(progress.flags.get("ch%03d.battle_won" % progress.chapter,false)),
    "trigger_id": str(_current_scene().get("encounter",{}).get("enemy_id","boss.ch%03d" % progress.chapter))
}
var check := BattleWorldHandoff.eligible("boss" if is_boss else "random", ctx)
if not bool(check.get("ok",false)):
    if not is_boss:
        world.locked = false
    return
```

此准入检查应位于scripts/first_act.gd::_start_battle状态切换之前；随机遭遇信号已将world.locked设true，要在拒绝后按照控制器busy状态恢复锁。对于剧情Boss，只允许通过有效剧情触发ID进入；其他UI事件不能伪造Boss模式。不要将已完成Boss旗标当作所有Boss的全局唯一键——大型章节存在同章多Boss，须由D线核对实际encounter_id及正典剧情旗标。

Battle显式接口（如D线使用自己的控制器）：

```gdscript
var prepared: Dictionary = battle.prepare_world_handoff(world,ctx,is_boss)
# 在battle.start(progress,chapter,is_boss)之前调用；准备失败不得开始战斗。
# 对现有FirstAct宿主，Battle.start()在未配置显式交接时自动捕获。
# 之后battle.completed发出前会自动restore到世界。
var snapshot: Dictionary = battle.world_handoff.checkpoint()
# 若有必要持久化战前位置，由D线在世界存档中保存snapshot；
# 完成回调成功后再移除临时battle checkpoint。
```

恢复结果：

```gdscript
# 在 _battle_finished 开头，battle=null之前：
var handoff_result: Dictionary = battle.last_world_handoff_result.duplicate(true)
var settlement: String = battle.last_boss_settlement
# handoff_result字段：ok,victory,mode,boss_settlement,restored,same_map,
# relocated,cooldown_distance,audio_cue,resume_world,save_required
# 若 restored=true 且 !won，禁止再把角色强制放回被阻挡的spawn点；
# 若 restored=false，保持控制锁并提供已验证安全据点的地图回退。
# 将boss_settlement记录到GameEvents，以便B线非致命剧情分支消费。
```

场景切换保护：

```gdscript
# 在world.leave_building()成功、world.enter_building()成功，
# _enter_location()完成，以及_travel_to()的world.spawn_from_exit()之后：
BattleWorldHandoff.grant_exploration_grace(world,520.0)
# 重要：必须在world.build()之后调用，因为build会清零计量。
```

输入/音乐：恢复坐标后，仍由D线调用现有_return_to_world()统一计算busy、world.locked、ui和atlas；C线音频桥使用handoff_result.audio_cue与地图/室内状态重新同步，不能由A线绕过控制器强制启用输入。

## 4. 风险与限制

1. **未运行Godot编译器**，全部回归脚本仅已写入仓库；此批不能标为运行PASS。
2. 自动接入只覆盖FirstAct类型宿主。全游戏其他战斗调用者必须显式使用prepare_world_handoff/handOff_to_world，或由D线添加对应接线。
3. world._physics_process的原始遇敌事件、建筑入口、地图build重置、失败经济结算均在受保护文件中；相关硬守卫和走出房门冷却仍待D线集成。
4. 地图变化时胜利不会把角色拉回旧地图；角色失败安全格搜索需后续Godot检查所有40地图的阻挡布局。
5. 缓存仅存入Battle对象，不自动持久化到磁盘。需要D线在战斗开始前写入临时世界快照并在最终存档时原子清理。
6. Boss叙事非致命结局仅透传原有settlement；不重写66场Boss专属剧情判定。
7. A线无权单独声称音乐切回正确、UI已重启或72章实机通关——这些依赖D线的共享控制器与最终Godot运行。

## 5. 一次性联合验收命令

```sh
godot --headless --path . --script res://tools/smoke_a_line_world_handoff.gd
godot --headless --path . --script res://tools/smoke_encounter_architecture.gd
godot --headless --path . --script res://tools/smoke_first_act_flow.gd
godot --headless --path . --script res://tools/smoke_a_line_contracts.gd
godot --headless --path . --script res://tools/smoke_a_line_live_bosses.gd
godot --headless --path . --script res://tools/smoke_a_line_chapter_encounters.gd
```

测试矩阵还应覆盖：连续两次encounter_requested、Boss胜利后再摸事件、门内暂停、菜单打开、过场转场、四人队伍、同章双Boss、所有地图出生点被占、旧存档恢复、退出建筑后8秒内不重复遇敌、真实完整音频恢复。

**状态：A线独占代码已实现并提交；D线共享入口联调与全量Godot验收待完成。**
