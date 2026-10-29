# A线 Batch 0.5 — 战斗行动一致性修复（2026-10-26）

## 问题与正式源码位置

- `scripts/first_act_battle.gd::_act("potion")` 使用 `game_state.heal_member()` 正确恢复生命值，但在动作处理结尾执行 `game_state.actors[hero_turn] = member`，其中 `member` 是治疗前的角色旧字典。因此药草会消耗而刚刚恢复的HP被覆盖。
- 玩家指定 `skill:<id>@<index>` 时，目标索引没有在使用前验证；非法/过期/负数目标可越界访问，或者使技能被错误执行。敌人手选 `#<index>` 的非数字令牌可被解析成0而误选首个敌人。

## 实现

- 成功使用药草后，将治疗过的 `game_state.actors` 保持为真实权威状态，不允许旧的 `member` 再覆盖。
- 技能指令在扣除MP和任何状态变化之前验证目标数字、范围、队友存活与队伍激活条件，错误目标不消耗回合、MP或道具。
- 敌方索引必须是合法整数字符串且仍然存活；不存在隐式将非法值解释为首个敌人的逻辑。
- 不改 `first_act.gd`、D奖励事务、V3持久格式、怪物数值、职业配置、已有行动名称、战斗结果信号。

## 验收证据与范围

`tools/smoke_a_line_action_integrity.gd` 使用真正的 `FirstActBattle` + `RPGCore` + `FirstActState` 实例，不使用无敌参数：检查药草治疗与库存/回合一致、非法治疗对象不得扣MP或跳回合、正确治疗玩家指定的同伴。

脚本已提交但**尚未在Godot 4.7.2引擎执行**。下一次统一批次执行：

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_a_line_action_integrity.gd
godot --headless --path . --script res://tools/smoke_combat_turns.gd
godot --headless --path . --script res://tools/smoke_first_three_playable.gd
```

整批Godot实测及故障注入通过前，不能宣称战斗系统商业级验收完成。
