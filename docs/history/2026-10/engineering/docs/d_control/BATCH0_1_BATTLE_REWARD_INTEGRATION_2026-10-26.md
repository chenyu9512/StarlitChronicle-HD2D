# 《星灯纪行》D线 Batch 0.1 — 正式战斗奖励事务接线交付（2026-10-26）

**审计/写入前main SHA：** `6743c3da1dbbef0e677964d73ea07a6c897f728b`。只提交main，不开分支、不建PR、不强推；本交付没有更改A/B/C独占战斗、剧情或美术模块。

**结论：SOURCE_INTEGRATED / ENGINE_NOT_VERIFIED / BATCH_0_FAIL**。本轮虽已将真实主游戏控制器连接A线ID和D线V3事务，但尚无当前SHA的Godot 4.7.2编译、真实故障注入、完整测试证据；P0 #10、#11、#4不得关闭，Batch 1不得启动。

## 修改文件和作用

1. `scripts/d_world_interaction/battle_v3_settlement.gd`（新增）：A `battle_reward_transaction.gd` 的稳定 `boss:` / `random:` 回执ID作为权威战斗身份，D `v3_reward_ledger.gd` 用同一V3 `save()` 同时持久化真实奖励、掉落、职业成长、Boss旗标、剧情场景推进、A回执及D幂等收据；存档失败时回滚 `progress._pack()` 全快照。
2. `scripts/first_act.gd`：正式 `_battle_finished` 在处理前缓存战斗ID和Boss信息，不再先 `queue_free()`、先 `_advance_scene()` 保存、先派奖然后忽略保存失败。写盘失败/世界安全落点不可用时保留原战斗与交易ID，锁住世界交互并显示重试按钮；成功后才可清理战斗、提示奖励、解除输入锁定。兼容旧V3已胜Boss旗标以禁止重领。
3. `tools/d_control/smoke_live_battle_v3_transaction.gd`（新增）：独立、无玩家文件IO的GDScript测试夹具，覆盖Boss实账/双回执、双回调、重启、旧V3旗标、保存失败回滚、随机遭遇幂等、战败惩罚幂等。**只是待运行脚本，不是已获得PASS**。
4. `tools/smoke_first_three_playable.gd`（扩展）：现有正常指令、第1–3章控制器回归，对真实第2/3章Boss胜利增加A/D两份回执实际持久化断言；仍使用定位脚本缩短探索，不冒充人类连续游玩。

分步提交：
- `36a2b470efb4469a75cb62236d410095cac505dd` 新增事务桥
- `e0b19e6908cdf21421ef57d8f68aa836a3c547c2` 主控制器首轮接线
- `3e9e52d52cc11e5119c23e2000daf1b2aebd96cf` 专项GDScript模拟断电/重复提交脚本
- `623da7b96c492af01b8e0dceaf26b7db1afc2033` 验证旧Boss旗标和动态脚本接口
- `98809d111fe572b0025f6f4b3ac8a7e076deb91c` 保存失败重试保留成功的世界安全落点
- `6e1f6a99d3bd76691f0e8c0a45ad48ad7e64bce2` 测试夹具类型兼容
- `6743c3da1dbbef0e677964d73ea07a6c897f728b` 正常指令Boss测试增加双回执断言

## 已执行的证据等级

- GitHub connector静态检查：6份关键脚本、共32处直接preload路径存在；主游戏控制器已引用A和D事务；`_battle_finished` 中已无原先直接调用 `give_rewards` 或 `_save_progress` 的提前写盘。
- GitHub commits写入成功，已完成SHA追溯。
- 本轮**没有**执行Godot运行时导入/GDScript编译、在引擎中点击重试按钮、完整Boss战、真实文件系统故障注入或Windows/iPhone真机；因此全部为NOT_VERIFIED。

## Godot 4.7.2待执行验收

仅在A/B/C明确冻结、D重新读取最终main SHA后运行以下一批完整验收，并保存每条命令的真实日志：

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/d_control/smoke_v3_reward_ledger.gd
godot --headless --path . --script res://tools/d_control/smoke_live_battle_v3_transaction.gd
godot --headless --path . --script res://tools/smoke_a_line_reward_transactions.gd
godot --headless --path . --script res://tools/smoke_a_line_world_handoff.gd
godot --headless --path . --script res://tools/smoke_first_three_playable.gd
```

验收须包含真实主场景运行的磁盘空间故障注入；故障时金额、职业经验、掉落、Boss flag、scene_index和两份回执必须全部回滚。修复存储后同一战斗ID仅成功提交一次。战败/撤退、安全落点不可用、旧档恢复与异常退出还需实机证据。

## 仍未关闭的风险

- P0 #10：正式游戏已接线，但没有本轮完整Godot和实际主游戏故障注入证据；另有任务 `first_act.gd:side_complete/_apply_effects` 及 `rpg_core.gd:record_quest/advance_story_side` 尚未纳入同级事务，属于后续Batch 0.2/0.3。
- P0 #11：B `reward_outbox` 的持久消费者和B ACK跨V2/V3存档域尚未接线；本轮A/D两份回执同在一个V3保存单元，不能声称完成跨不同文件exactly-once。
- P0 #4：当前SHA没有运行Godot的完整核心校验，先前Actions绿色记录属于旧SHA。
- P1：成功战斗后的 `game_events.record` 是保存后在内存追加的遥测/成就事件，尚未纳入原子快照；若需严格事件历史一致性，应在后续公共事件契约中补持久/投递协议。
- P1：需要实测`_hold_battle_settlement`的新按钮在触屏/键鼠、内存耗尽、读写权限故障时是否可见可用，测试不得伪造战斗胜利。

**Batch 0.1代码交付完成，但验收未通过；禁止据此进入Batch 1。**
