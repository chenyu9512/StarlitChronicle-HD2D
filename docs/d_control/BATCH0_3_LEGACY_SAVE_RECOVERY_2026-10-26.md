# D线 Batch 0.3：V1/V2/V3读档与章节故障恢复交付（2026-10-26）

**截至本报告审计代码main SHA：** `07b4bf67174e300343d7d92840a8e8edf91866a5`。**GATE: SOURCE_INTEGRATED, ENGINE_NOT_VERIFIED, BATCH_0_FAIL。** 不准进入Batch 1。

## 直接修改main的实际代码

1. `scripts/d_world_interaction/v3_progress_transition.gd`：新增纯V3状态过渡事务。保存修改前 `_pack().duplicate(true)`，变更操作无UI/外部副作用，`save()` 失败即 `restore_snapshot`；成功才向宿主返回结果。
2. `scripts/first_act.gd`：正式控制器的序章9步跨章、主线场景+危机线索、章节结算（招募队员、角色恢复、任务与章节旗标）、第72章最后一段/结局选择/后日谈/档案、旧结局标记迁移均增加失败回滚，不再在失败时误提示已推进。手动存档载入后须先持久化主V3，保存失败恢复进入槽位前快照，保持原玩家运行环境；手动槽位写入失败恢复临时修改的检查点。
3. `scripts/game_state.gd`：原V1 `user://starlit_save_v1.json` 不再直接截断覆盖；先写 `.tmp` 并重新解析校验，复制旧有效快照至 `.bak`，重命名提交。V1读取在主文件无效时尝试备份。**仍是V1独立存档，不会自动映射成72章V3；不伪造迁移结果。**
4. `scripts/first_act_state.gd`：V3保存/恢复入口增加损坏数据严格验证，拒绝不合理场景索引、非数值角色字段、非法装备库存值，拒绝后原状态保持不变，继续使用已有主文件+backup回退。
5. `tools/d_control/smoke_batch03_legacy_and_checkpoint_recovery.gd`：增加隔离 `user://d_batch03_recovery_<pid>/` 环境的Godot测试，覆盖V3损坏恢复及角色类型拒绝、章节事务save失败与重试、V1原子备份恢复、B线V1/V2向后读取与隔离、手动槽位备份回退。**测试脚本已创建但尚未真实执行。**

## 源码范围与初步静态检查

- 本轮检查7个相关GDScript源码；36个直接preload路径均存在（static only）。
- 控制器 `_advance_scene` / `_complete_chapter` 均返回布尔并通过 `V3ProgressTransition.commit` 提交；结局和旧旗标迁移使用相同逻辑。
- `game_state.gd` 已移除原 `FileAccess.open(SAVE_PATH, FileAccess.WRITE)` 原地截断；具有V1备份读取路径。
- 源码中仍有约27处其它无条件 `_save_progress()` / `progress.save()` 调用点（包括非任务地图、商店、场景、补给等），尚非所有可写操作都具备完整回滚。**因此不得称已清零所有P0。**

## 真实Godot验收状态

当前执行环境没有Godot 4.7.2二进制文件，本轮未运行GDScript解析器、真实游玩、动态故障注入或Actions当前SHA流水线；之前Actions绿色运行属于旧SHA。

待A/B/C共享资源冻结后，D读取最终main SHA，一次性执行以下本批及前批回归，并保存退出码与原始日志：

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/d_control/smoke_batch03_legacy_and_checkpoint_recovery.gd
godot --headless --path . --script res://tools/d_control/smoke_batch02_quest_and_b_outbox.gd
godot --headless --path . --script res://tools/d_control/smoke_live_battle_v3_transaction.gd
godot --headless --path . --script res://tools/smoke_b_story_transactions.gd
godot --headless --path . --script res://tools/smoke_first_three_playable.gd
godot --headless --path . --script res://tools/smoke_first_act_flow.gd
```

## P0阻塞与后续路径

- #10：历史Battle/Quest奖励接口已源码事务化，章节/旧结局/手动槽位回滚已补；**仍需真实运行与其它经济/非剧情入口save失败审计**，不得关闭。
- #11：B story outbox->V3->B ACK消费代码已在Batch 0.2提供；**正式first_act游戏没有实际挂载B独立story_runtime，不能谎称剧情双域exactly-once已打通**，旧B V1不会凭空补奖励。
- #4：最新版Godot 4.7.2编译、控制器玩家路径和异常退出/战败撤退复现尚未得到真实日志。
- P1：`game_events.record` 多数仍是V3写盘后内存增量，不具备和领取奖励同快照提交；需要后续统一事件账本。
- P1：某些非关键路径仍在忽略 `_save_progress` 返回值，实际优先级需经更广泛 QA 细分。
- Batch 0.4的真实Godot总验收**未执行**；保持Batch 0 = FAIL，不进入Batch 1。
