# 《星灯纪行》D线A/B/世界正式接入记录（2026-10-26）

**所有开发直接写入main，无分支/PR/强制推送。** 代码与实测需按被测SHA界定；A/B/C并行提交可能推进HEAD。本报告审计时main为 `75a0d4e0760264f4401e346311abb8b62bc31601`。

## 本轮D主控正式改动

1. `scripts/first_act.gd`：战斗每次开始时生成独立的 `battle_defeat_id`，战败走同次尝试ID结算与重复回调幂等，避免同一剧情Boss稳定胜利ID让第二次战败不再扣钱。原先A线Boss胜利的稳定奖励回执仍保持不变。修复 `_battle_finished` 世界恢复分支缩进语法错误并恢复迷雾揭露。主要提交 `0590a83f73970e7ff17749e565d8113272b4d8cf`、`63238a8533177fac9526e0cccbd47b6dadbab5ff`。
2. `scripts/world_fog_v3.gd`：修复地图显示先缓存默认72x48，正式大地图 `configure()` 后读取产生PackedByteArray越界的问题；变更扩展范围时按原宽高逐格重映射已揭露位，损坏数组读取失败时拒绝越界。提交 `d0b6a7f22de5fe6fa2b30e20571c60eab22448e0`。
3. `scripts/d_world_interaction/npc_v3_contact.gd`：D侧消费B线 `world_town_life.preview_talk`只读预览；必须验证NPC确实在该map和region，首次接触 `talked_to` 与 `b.npc.first.<npc_id>` 收据同一次V3保存；失败完整回滚，重进与重复对话不重新记首见事件。提交 `f22c83ece3a2f8dbaef2cecd0c6c782ceb5d0c8f`。
4. `scripts/first_act.gd::_interact` 正式NPC交谈路径改为先保存再展示；一次性`resident_met`仅对真正新成功提交发出。提交 `1b4d7ff3508ac4c514864c490c8faed4bc36f2f1`。
5. `scripts/first_act_world.gd::_spawn_residents/sync_world_clock`：B正典NPC按 `residents_for_map(map_id)` 生成为所属实体地图NPC，不在同一region其它地图重复出现。提交 `cdd67bfece5071a06e2b5772621343e8690838ca`。

## 回归用例

- `tools/smoke_first_three_checkpoints.gd`：改为真实执行 `_start_battle(true)`→`battle._finish(false)`，再验证安全出生点、遭遇宽限、队伍治疗、金币惩罚、Boss标志不误置以及同一Boss第二次尝试的新战败nonce。提交 `78efb718e9f2e4e5e4a2a9dd2254ec0602d07c89`。
- `tools/d_control/smoke_fog_extent_reconfigure.gd`：默认Fog扩展至100x64、112x64，验证已开地图的位重映射、边缘、存档读取与损坏缓存。提交 `aed0b59ddcb051d38e93c582ad599208ff0d2fc0`。
- `tools/d_control/smoke_npc_contact_v3.gd`：真实B正典居民、错地图拦截、保存失败回滚、首次接触V3回执、重复对话与重启持久化。提交 `6f81318e34baaa525b356916849af09b48827ba0`。

## 真实Godot 4.7.2证据与注意

- 第一次本轮引擎运行 `https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40326139702` 证明迷雾尺寸专项通过，同时暴露主控制器旧缩进P0解析错误；已在main纠正，不将该失败解释为其它30+系统全部坏掉。
- 再次完整回归被测SHA `43acfa54117244d96920d8ff34a8eb0bafd0e3de`，Actions: https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40326934762 。
- 在本次回归已取得日志的分组中：`smoke_npc_contact_v3.gd` PASS、`smoke_first_three_checkpoints.gd` PASS、`smoke_all_maps_minimap.gd` PASS、`smoke_fog_extent_reconfigure.gd` 在前一次完整运行PASS；以相应运行完成日志为唯一依据。其它分组状态请以Actions原始job和完整出站统计更新，**绝不提前声称全部通过**。
- 已明确仍存在B线地图/城镇路线可达性、B独立 `smoke_b_story_transactions.gd` 存档恢复，以及C部分图像运行专项等失败。A线Boss胜利/战斗平衡需复测最终main。旧B `story_runtime`是独立剧场，虽然B outbox->V3 ACK消费者已实现，不得说B独立剧场已成为主游戏Boss触发。
- B线居民昼夜动态路径插值/建筑内调查、城镇经济和公会领取，仍需D下批额外整合，**本报告不冒称已接线**。
- `game_events.record`在NPC首次接触V3提交后执行，事件历史可能需要下一次保存才稳定落盘（P1）。

**集成质量门槛：Batch 0仍FAIL。** 当前无零P0的证据，暂不进入Batch 1。

## 最终跨线架构修订：旧探索迷雾已退役

在首次D地图边界修复之后，地图线正式执行了用户指定的「**取消探索迷雾和全球地图，仅保留当前局部地图**」新规范（见 `docs/MAP_LOCAL_ONLY_NO_FOG_2026_10_26.md`）。

- `scripts/world_fog_v3.gd` 后来被地图线从正式main删除。此前D修复的迷雾越界逻辑仅属于**历史提交，已不再是现行玩家路径**；本报告其它段落对该旧模块的陈述只能作为历史记录，不代表当前版本仍启用探索迷雾。
- D线也随之删除了过时的 `tools/d_control/smoke_fog_extent_reconfigure.gd`：不能因为测试引用已经退役的脚本产生Parse Error，就阻止无雾本地地图上线。这不是隐瞒缺陷，新的地图功能由 `tools/smoke_no_fog_local_map.gd` 和当前 `tools/smoke_all_maps_minimap.gd` 验证。
- 本轮后续完整QA测试SHA `43acfa54117244d96920d8ff34a8eb0bafd0e3de` 实际执行81项：**70 PASS / 11 FAIL**；其中一项失败仅因D过时雾测试预加载已删除模块，已在main主动移除此用例；剩余10项须按各线修复。
- 已确认核心D集成真实PASS：`smoke_first_three_checkpoints.gd`、`smoke_npc_contact_v3.gd`、`smoke_all_maps_minimap.gd`。其它10项未通过的运行日志：https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40326934762 。
- **主线/世界接口以当前 `project.godot` 和地图线无雾设计为权威**。不得为通过过时D测试而恢复探索迷雾或世界地图。
