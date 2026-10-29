# 《星灯纪行》2026-10-26 Godot 4.7.2 全量自动冒烟实测报告

**精确被测Git SHA：** `92ee06ec4efdf3ef6c6e646a64af80840f38092a`（只对应这一SHA；此后main上的新提交不自动取得PASS）。  
**执行方式：** GitHub Actions Ubuntu runner，官方Godot 4.7.2，4个并行测试分组；分别执行所有发现的 `tools/**/smoke_*.gd`，不因单项失败中止后续脚本。  
**GitHub证据：** https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40322238747  
**结果：** `61/73` PASS、`12/73` FAIL。**最终放行判定：FAIL，禁止进入Batch 1。**

> 这里的PASS指对应的自动GDScript用例取得正常返回码且没有SCRIPT ERROR，不代表手机真机、人工完整游玩、全部视觉质量或发行Export通过。

## 整体结论

- 4组官方Godot 4.7.2项目导入均成功；全部73项逐一运行完成，且每组对应Actions job日志和JSON工件。
- 核心标准验证在首轮实测Git SHA `e6147ab427c103f90f50376d1fdcd3a3e9bae994` 上成功：内容、剧情、资源验证和Godot导入（https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40320135822）。该首轮随后在旧D回执重放测试失败，未完成全部后续Core步骤。
- D线 `b_story_reward_consumer.gd` 曾因持久V3 JSON的整数读成浮点导致 `event_id_collision`；已在独立main提交修正，第三轮 `smoke_batch02_quest_and_b_outbox.gd` 确认为PASS。
- `smoke_batch03_legacy_and_checkpoint_recovery.gd` 已复测PASS；同时修复了6个本身打印PASS但因 `quit(0)` 后继续落入 `quit(1)` 的误判脚本，第三轮复测均已PASS。
- 当前仍有12项真正需要继续复现/修复/验收的失败，其中“40地图及小地图全覆盖”脚本即使返回0，仍出现 `SCRIPT ERROR` 数组越界，故严格判FAIL。
- 测试运行后，其他线路仍可能继续提交代码，不能以本报告为新提交自动背书；需修复后重新冻结HEAD重跑全部QA。

## 12项未通过用例的分流清单

| 用例 | 责任线 | 主要错误 |
|---|---|---|
| `tools/smoke_a_line_live_bosses.gd` | A 战斗 | boss.ch039–041等难度下真实指令战斗无法清除Boss |
| `tools/smoke_all_maps_minimap.gd` | B/D 地图 | world_fog_v3.gd:69 PackedByteArray访问越界；虽打印PASS并返回0，但出现SCRIPT ERROR |
| `tools/smoke_b_line_integrity.gd` | B 世界 | 多个地区主线/机关门目标不可达 |
| `tools/smoke_b_story_transactions.gd` | B 剧情存档 | 故事V2 reload后待领奖outbox丢失、ACK失败与备份恢复未通过 |
| `tools/smoke_battle_v3.gd` | A 战斗 | Boss特殊攻击未按测试契约发出预警 |
| `tools/smoke_first_three_checkpoints.gd` | D/A 存档与战败 | 失败恢复：安全入口、遭遇宽限、惩罚和队伍状态 |
| `tools/smoke_live_boss_matrix.gd` | A 战斗 | 第12、18、24等章Boss宣布胜利后仍残留HP |
| `tools/smoke_opening_balance.gd` | A 数值 | 第2章多随机种子的战斗回合数不在3–20范围 |
| `tools/smoke_town_direction_v4.gd` | B/C 城镇 | map_forge_01旅馆/商店/工会/锻造/住宅/神殿不可达，以及装饰碰撞 |
| `tools/smoke_town_entrances.gd` | B/C 城镇 | 住宅服务标识不存在 |
| `tools/smoke_world_production.gd` | B 世界 | map_oldland_01建筑不可达与门口阻挡 |
| `tools/smoke_world_v3.gd` | B 世界 | 多地图关键路线断连，城镇门口/机关不可到达 |

## 四分组结果

| 分组 | 执行数 | PASS | FAIL |
|---|---:|---:|---:|
| 0 | 19 | 14 | 5 |
| 1 | 18 | 17 | 1 |
| 2 | 18 | 14 | 4 |
| 3 | 18 | 16 | 2 |
| **合计** | **73** | **61** | **12** |

## 全部73项实测原始退出结论

| 路径 | 状态 | 返回码 | 秒 | 分组 |
|---|---|---:|---:|---:|
| `tools/d_control/smoke_atomic_story_save.gd` | PASS | 0 | 0.17 | 0 |
| `tools/d_control/smoke_batch02_quest_and_b_outbox.gd` | PASS | 0 | 0.45 | 1 |
| `tools/d_control/smoke_batch03_legacy_and_checkpoint_recovery.gd` | PASS | 0 | 0.25 | 2 |
| `tools/d_control/smoke_live_battle_v3_transaction.gd` | PASS | 0 | 0.27 | 3 |
| `tools/d_control/smoke_title_foyer.gd` | PASS | 0 | 0.54 | 0 |
| `tools/d_control/smoke_v3_reward_ledger.gd` | PASS | 0 | 0.16 | 1 |
| `tools/d_control/smoke_world_interaction.gd` | PASS | 0 | 0.26 | 2 |
| `tools/d_control/smoke_world_object_transactions.gd` | PASS | 0 | 0.37 | 3 |
| `tools/smoke_a_line_chapter_encounters.gd` | PASS | 0 | 12.17 | 2 |
| `tools/smoke_a_line_contracts.gd` | PASS | 0 | 0.27 | 3 |
| `tools/smoke_a_line_live_bosses.gd` | FAIL | 1 | 16.38 | 0 |
| `tools/smoke_a_line_reward_transactions.gd` | PASS | 0 | 0.16 | 1 |
| `tools/smoke_a_line_world_handoff.gd` | PASS | 0 | 0.43 | 2 |
| `tools/smoke_a15_visual.gd` | PASS | 0 | 0.54 | 0 |
| `tools/smoke_a16_keyframes.gd` | PASS | 0 | 0.53 | 1 |
| `tools/smoke_all_maps_minimap.gd` | FAIL | 0 | 14.69 | 3 |
| `tools/smoke_architecture.gd` | PASS | 0 | 3.07 | 0 |
| `tools/smoke_art_assets.gd` | PASS | 0 | 0.25 | 1 |
| `tools/smoke_av_event_bridge.gd` | PASS | 0 | 0.15 | 2 |
| `tools/smoke_av_fallback.gd` | PASS | 0 | 0.27 | 3 |
| `tools/smoke_b_line_integrity.gd` | FAIL | 1 | 11.06 | 0 |
| `tools/smoke_b_npc_home_v1.gd` | PASS | 0 | 0.25 | 1 |
| `tools/smoke_b_story_transactions.gd` | FAIL | 1 | 0.15 | 2 |
| `tools/smoke_battle_actors.gd` | PASS | 0 | 0.64 | 3 |
| `tools/smoke_battle_commercial.gd` | PASS | 0 | 0.64 | 0 |
| `tools/smoke_battle_fx.gd` | PASS | 0 | 0.53 | 1 |
| `tools/smoke_battle_v3.gd` | FAIL | 1 | 0.43 | 2 |
| `tools/smoke_branch_story_phase19.gd` | PASS | 0 | 2.61 | 3 |
| `tools/smoke_c_art_overrides.gd` | PASS | 0 | 0.64 | 0 |
| `tools/smoke_c_av_event_router.gd` | PASS | 0 | 0.35 | 1 |
| `tools/smoke_c_character_motion.gd` | PASS | 0 | 0.25 | 2 |
| `tools/smoke_c_town_presentation.gd` | PASS | 0 | 0.36 | 3 |
| `tools/smoke_campaign_72.gd` | PASS | 0 | 50.86 | 0 |
| `tools/smoke_chapter_ambient.gd` | PASS | 0 | 3.23 | 1 |
| `tools/smoke_cinematic_flow.gd` | PASS | 0 | 3.33 | 2 |
| `tools/smoke_coastal_exterior.gd` | PASS | 0 | 2.13 | 3 |
| `tools/smoke_coastal_interiors.gd` | PASS | 0 | 9.20 | 0 |
| `tools/smoke_combat_turns.gd` | PASS | 0 | 0.53 | 1 |
| `tools/smoke_dungeon_puzzles_v7.gd` | PASS | 0 | 2.01 | 2 |
| `tools/smoke_encounter_architecture.gd` | PASS | 0 | 0.64 | 3 |
| `tools/smoke_endings.gd` | PASS | 0 | 3.34 | 0 |
| `tools/smoke_field_ecology_v7.gd` | PASS | 0 | 14.39 | 1 |
| `tools/smoke_first_act_flow.gd` | PASS | 0 | 6.43 | 3 |
| `tools/smoke_first_act.gd` | PASS | 0 | 2.30 | 2 |
| `tools/smoke_first_three_checkpoints.gd` | FAIL | 1 | 5.76 | 0 |
| `tools/smoke_first_three_playable.gd` | PASS | 0 | 4.54 | 1 |
| `tools/smoke_global_rpg_reuse.gd` | PASS | 0 | 0.53 | 2 |
| `tools/smoke_housing_and_combat.gd` | PASS | 0 | 3.17 | 3 |
| `tools/smoke_inn_art.gd` | PASS | 0 | 1.75 | 0 |
| `tools/smoke_legacy_ending.gd` | PASS | 0 | 2.49 | 1 |
| `tools/smoke_live_boss_matrix.gd` | FAIL | 1 | 1.09 | 2 |
| `tools/smoke_map_ui.gd` | PASS | 0 | 1.20 | 3 |
| `tools/smoke_opening_balance.gd` | FAIL | 1 | 2.50 | 0 |
| `tools/smoke_optional_events.gd` | PASS | 0 | 2.31 | 1 |
| `tools/smoke_phase19_companion_regional_rooms.gd` | PASS | 0 | 34.11 | 2 |
| `tools/smoke_phase19_life_rooms.gd` | PASS | 0 | 19.07 | 3 |
| `tools/smoke_phase19_lost_page_puzzles.gd` | PASS | 0 | 2.59 | 0 |
| `tools/smoke_phase19_lost_page_rooms.gd` | PASS | 0 | 9.75 | 1 |
| `tools/smoke_prologue_world_fx.gd` | PASS | 0 | 1.55 | 2 |
| `tools/smoke_rpg_core.gd` | PASS | 0 | 1.67 | 3 |
| `tools/smoke_save_integrity.gd` | PASS | 0 | 0.26 | 0 |
| `tools/smoke_story_side_quests.gd` | PASS | 0 | 2.68 | 1 |
| `tools/smoke_story_world_phase19_2.gd` | PASS | 0 | 7.70 | 2 |
| `tools/smoke_town_direction_v4.gd` | FAIL | 1 | 8.46 | 3 |
| `tools/smoke_town_ecology_v7.gd` | PASS | 0 | 10.60 | 0 |
| `tools/smoke_town_entrances.gd` | FAIL | 1 | 4.62 | 1 |
| `tools/smoke_town_life.gd` | PASS | 0 | 2.85 | 2 |
| `tools/smoke_world_checkpoints.gd` | PASS | 0 | 3.07 | 3 |
| `tools/smoke_world_discoveries.gd` | PASS | 0 | 13.39 | 0 |
| `tools/smoke_world_fog_v3.gd` | PASS | 0 | 1.93 | 1 |
| `tools/smoke_world_production.gd` | FAIL | 1 | 20.33 | 2 |
| `tools/smoke_world_story_interactions.gd` | PASS | 0 | 2.69 | 3 |
| `tools/smoke_world_v3.gd` | FAIL | 1 | 31.89 | 0 |

## 验收边界与下一步

- **P0 世界：** 先修复 `world_fog_v3.gd:69` 数组越界、11个以上地图的任务路线阻断，重点 `map_forge_01` / `map_oldland_01` 的真正可走路径和住宅服务入口。
- **P0 战斗：** 重新检查Boss HP与胜利信号、真实战斗可完成性、开局Boss警告与数值。
- **P0 D/B：** 处理 `smoke_first_three_checkpoints.gd` 的失败恢复，以及 `smoke_b_story_transactions.gd` 剧情存档重载后奖励outbox与备份丢失。
- 每项均需在实际引擎测试中获得PASS；再在A/B/C/D冻结的最终main SHA上执行一次完整自动QA和人工视觉/移动端验收。现阶段 **Batch 0 FAIL / Batch 1 HOLD**。
