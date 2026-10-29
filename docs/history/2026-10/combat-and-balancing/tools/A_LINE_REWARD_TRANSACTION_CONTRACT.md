# A线 Batch 0：战斗奖励事务与世界恢复交接（D线必接）

记录日期：2026-10-26。A线从 `321949a0943aa5477573d90ce4d81f9b614e5bd4` 起审计，实际主线合入父提交为 `8272d44e4bea1f07bb9f75cb4407ed44b0b1da16`。本文件描述已写入的 A 线 API；Godot 运行验收尚未执行，不宣称 Batch 0 已通过。

## 范围

- `scripts/battle_reward_transaction.gd` 提供 `make_id / valid_id / already_applied / mark_applied`。对旧版 V3 存档零迁移，事务账本保存在 `progress.rpg["battle_reward_transactions"]`。
- `scripts/first_act_battle.gd` 在每次 `start()` 后填充只读使用的 `reward_transaction_id`，并在 `_finish()` 后向 `last_world_handoff_result["reward_transaction_id"]` 暴露同一值。不改动旧 `completed(victory,xp,gold)` 信号。
- Boss 键使用剧情真实 `boss_id`（缺失时以 `encounter_data.enemy_id`、最终以 `boss.chNNN/crisis` 退化）；随机战键是单次战斗创建的 128-bit 随机值。不得在 `_battle_finished` 时重新生成。
- `scripts/battle_world_handoff.gd` 找不到安全出生点时保留 `active=true,settled=true,finished=false`，不改变玩家坐标和遇敌计量，待 D 线重新布置安全入口后可重试 `restore(world)`。

## D线共享控制器的必需改造（A线不擅改 scripts/first_act.gd）

1. 开战前执行 `BattleWorldHandoff.eligible` 并阻止已结算的 `chNNN.battle_won` 或相同 Boss 触发器；D线捕捉真实 `busy / dialogue_open / cinematic / transitioning`。
2. 结算函数 `_battle_finished(won,xp,money)` 在任何 `battle=null` / `queue_free` 操作之前保存 `battle.reward_transaction_id`、`battle.last_world_handoff_result` 和 `battle.last_boss_settlement`。
3. `if won and BattleRewardTransaction.already_applied(progress.rpg, transaction_id):` 直接跳过本次所有奖励、职业经验、掉落、任务旗标和场景推进。**不能只阻止金币/经验，Boss 的场景推进也必须去重。**
4. 对于全新胜利：深复制 `progress._pack()`（同时留存 D线其他运行系统的快照），按旧逻辑发放 XP、金币、职业 XP、掉落、Boss 标志及事件；最后 `mark_applied(progress.rpg,transaction_id,{"chapter":progress.chapter,"xp":xp,"gold":money})`，紧接着保存包含上述全部字段的**同一** V3 快照。失败时恢复所有内存快照，并保持世界输入锁定；切勿在保存失败后发出“已领取”成功提示。
5. 失败与撤退：不登记胜利交易、不发放正向奖励。单独记录败退结果事件。保留老存档下全部 Boss ID、旧标志和旧奖励机制；已胜利 Boss 的旧旗标需要 D线兼容转换为已结算判定。
6. `last_world_handoff_result.resume_world == false` 时，禁止执行 `_return_to_world` 解锁；解决碰撞后重新调用 `battle.handoff_to_world(world)`，成功后才能保存并恢复输入。避免 D 线现有失败流程把安全出生点又覆盖成障碍或将 900px 冷却改回 380px。
7. 任何 Boss 的剧情旗标/奖励保存成功后才允许继续推进故事；存档时保留角色面向和地图位置，避免读档重复触发 Boss。当前 D线 checkpoint 仅保存 `xy`，没有保存朝向，需补入兼容字段。
8. 注意：`progress._pack()` 和 `game_core` 的所有变更必须被视为一个提交单元；仅把账本写入内存**不构成**持久化原子事务。

## 验收

- A线单测入口：`godot --headless --path . -s res://tools/smoke_a_line_reward_transactions.gd`。
- 已有场景交接入口：`godot --headless --path . -s res://tools/smoke_a_line_world_handoff.gd`。
- 在 D线接线前，上述模块只是战斗侧基础设施；**不得宣布“跨存档重复奖励已修复”。**
