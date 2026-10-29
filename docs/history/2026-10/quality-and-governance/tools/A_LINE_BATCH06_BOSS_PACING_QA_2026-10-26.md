# A线 Batch 0.6 — 开篇Boss可读性与真实QA基线修复

## 真实失败证据（历史SHA，非本次提交的PASS）

GitHub Actions `40322238747`（基线 `92ee06ec`）的真实 Godot 4.7.2 四分片日志：
- `smoke_opening_balance.gd`：第2、3章12种种子全部在**第2回合胜利**，低于真实设计的3–20回合预算。玩家直接连续按“特殊”即可跳过第二回合蓄力与第三回合喘息反馈。
- `smoke_battle_v3.gd`：测试先强改 `current_round=3` 却没有重算 `round_boss_intent`，仍拿第一回合缓存判断第三回合预告。这是测试夹具过期，不是要重新开启动态预告造成阶段不一致。
- `smoke_live_boss_matrix.gd`：将“安抚/救援”类正典Boss胜利时保留生命值误判为战斗失败，违反正典的非致命胜利机制。

## 实际改动

1. `battle_boss_mechanics.gd` 尊重作者配置的 `minimum_round`：仅当 `goal=pacify/survive` 时生效；默认 pacify 最早第1回合，与其他22场既有安抚战的历史行为兼容。生存目标保留默认第6回合要求。
2. 正典 `boss.ch002` 与 `boss.ch003` 单独增加 `minimum_round=4`，确保试探→重击→喘息至少完成一个周期才可安抚。这是战斗机制约束，不是捏造胜利或锁定Boss HP。
3. `smoke_a_line_contracts.gd` 增加双队员、四回合特殊行动目标测试，不允许前3回合抢跑；其他Boss机制仍按原契约。
4. `smoke_battle_v3.gd` 在测试构造第三回合时调用真实 `_begin_round()`，然后检查本回合冻结意图与预告。
5. `smoke_live_boss_matrix.gd` 按正典结算类型检查敌方HP：安抚/救援胜利必须非致命，普通击败必须HP归零。仍要求真正的玩家指令、唯一回调及经验收益。

## 验收边界

这些文件是A线专属；不修改D奖励事务、共享V3存档、B正典剧情、美术或程序入口。尚未执行最新SHA Godot，历史 QA 中剩余 `smoke_a_line_live_bosses.gd` 多场高章节Boss数值与测试策略仍失败，不能声称A线所有66场已过。

下一次**整批**运行：

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_a_line_action_integrity.gd
godot --headless --path . --script res://tools/smoke_a_line_contracts.gd
godot --headless --path . --script res://tools/smoke_battle_v3.gd
godot --headless --path . --script res://tools/smoke_opening_balance.gd
godot --headless --path . --script res://tools/smoke_live_boss_matrix.gd
```

**静态修复完成不等于 Godot 通过或商业级战斗完成。**
