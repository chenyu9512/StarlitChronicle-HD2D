# 《星灯纪行》D线 Batch 0.2 — 剧情/任务奖励V3事务整合（2026-10-26）

审计基线 `6a419c0260c1f4a6e0bf2957f0d2427083e42266`；仅向 `main` 直接提交，无分支、PR、强制推送。**代码集成状态：SOURCE_INTEGRATED；真实Godot 4.7.2：NOT_VERIFIED；Batch 0总体：FAIL；严禁进入Batch 1。**

## 本次新增及修改

- `scripts/d_world_interaction/quest_v3_settlement.gd`：D线集中交易入口。章节本地支线接取、调查、完成奖励；原任务目录登记；36+84条正典世界支线的五阶段状态、分支及最后奖励；72章正式主线场景的flags/grant/time_skip均通过 `v3_reward_ledger.gd` 的一次V3原子保存。事件ID使用 `d.quest.local.<id>.*`、`d.quest.catalog.<id>`、`d.quest.story.<id>.stage.<n>`、`d.story.scene.<id>.effects`。旧档已完成的本地支线、任务登记和世界支线不推断未发奖，不自动重新支付。
- `scripts/first_act.gd`：`side_accept`、`side_found`、`side_complete`、`_finish_story_side`、`_apply_effects` 接入上述事务。事务失败返回可重试世界交互，不提前显示奖励成功，不直接调用 `give_rewards`。主线序章、开场、线索、危机和解决共5个场景效果调用点增加save失败阻断。
- `scripts/rpg_core.gd`：`record_quest` 将任务ID及奖励归入一个V3快照；`advance_story_side` 包裹原阶段逻辑，失败回滚选项旗标、阶段及经济值。原变更算法移动到仅供事务调用的 `_advance_story_side_uncommitted`；不改任务正典数据。
- `scripts/d_world_interaction/b_story_reward_consumer.gd`：为B `story_runtime.gd` 的 `reward_outbox` 新增显式消费者 `consume_one/drain_pending`。验证消息ID、完整payload和经济字段，先将消费ID与XP、金币及航页旗标落入权威V3，成功后才调用B `acknowledge_reward`。B ACK失败会保留outbox，重启重放命中V3回执后绝不重发。
- `tools/d_control/smoke_batch02_quest_and_b_outbox.gd`：使用真实 `FirstActState` V3和B故事运行器，以进程专属 `user://` 路径进行存档失败、接取/调查/领取重试、场景奖励重复调用、原任务与五阶段、B消费者V3失败、B ACK失败和重启重放测试。它是**待执行测试脚本，不是已执行PASS**。

## 关键静态证据

- 读取序章 + 12幕剧情数据：共72个正式剧情 `grant` 效果，302个 `set_flag`，1个 `time_skip`；效果处理器显式支持全部出现的类型（未发现当前作者数据中的未知效果类型）。
- B正典36条基础剧情支线都有XP和金币，其中12条带 `lost_page`；36地区+48同伴文本目录尚未直接携带同样的 `rewards` 字段；消费者只处理实际B outbox，不会凭数据登记伪造奖励。
- 对5个本次关键源码/测试文件进行静态直接preload存在性检查，没有发现缺失路径；`first_act.gd`五处调用均有失败处理；`rpg_core.gd`两类原奖励入口已由D事务封装。
- 未运行Godot解析器、引擎Smoke、真实玩家操作或完整GitHub Actions，不能判定运行PASS。

## 剩余P0 / P1

- P0 #10：战斗和任务奖励已在源码中接线，但当前main SHA没有Godot 4.7.2的完整编译和故障注入证据；`first_act.gd::_advance_scene/_complete_chapter` 和其他不属于本批任务的可变状态路径仍会忽略保存失败，需继续审计。
- P0 #11：B outbox->V3->B ACK **消费协议与代码实现已交付**，但正式主游戏 `first_act.gd` 目前不运行B独立 `story_runtime.gd`，不得把独立故事剧场映射成正式可玩Boss/任务流程；跨两存档真实断电恢复在Godot中未执行。若B模块将来被实际挂载，需由D唯一绑定消费端，防止与主任务直接路径双发。
- P0 #4：当前提交SHA没有引擎验收记录。
- P1：完成后发出的 `game_events.record()` 可能在第一个V3事务提交后才进入内存，不属于本轮同一快照；商城、地图发现、地形生态等其他经济入口未全部事务化。
- P1：剧情效果已持久化后，随后的章节索引迁移仍可能单独保存失败；虽然事件ID阻止重复经济收益，但章节位置失败回滚、UI过渡仍需故障注入补齐。

## 批次验收入口（尚未运行）

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/d_control/smoke_batch02_quest_and_b_outbox.gd
godot --headless --path . --script res://tools/smoke_b_story_transactions.gd
godot --headless --path . --script res://tools/d_control/smoke_live_battle_v3_transaction.gd
godot --headless --path . --script res://tools/smoke_story_side_quests.gd
godot --headless --path . --script res://tools/smoke_first_three_playable.gd
```

批次未冻结时不以旧绿色Actions作为当前SHA结果。A/B/C最终交付冻结，D重新取HEAD后统一执行Godot 4.7.2验收；未获得实际日志前 Batch 0 = FAIL。
