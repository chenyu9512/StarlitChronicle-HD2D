# D线 Batch 0 P0 工程整合审计与本次交付（2026-10-26）

- 本报告再次读取的共享代码审计基线：`5cebf66e873d8ed71a953f8a26c777c593f61fef`。
- 只操作 `main`，无新分支、无PR、无强推；与A/B/C并行更新产生的GitHub 409冲突已按安全规则拒绝后重新读取main。
- **Batch 0状态：FAIL（P0未关闭）；Godot 4.7.2本SHA完整验收：NOT_VERIFIED；Batch 1不开放。**
- 历史成功 `actions/runs/40274482154` 属于旧SHA `6c32e274...`，不是本批结果。

## 真正的主入口风险

正式入口为 `project.godot -> scenes/first_act.tscn -> scripts/first_act.gd`。
`first_act.gd::_battle_finished` 先修改经验、金币、职业经验、掉落、图鉴、Boss标记和场景索引，再调用 `_save_progress()` 且忽略失败返回值。任务 `side_complete`、`_apply_effects`、`rpg_core.gd::record_quest/advance_story_side` 有同类型风险。P0尚未通过故障注入闭环，不能因V3 `save()` 已支持临时文件与备份，就宣称调用方已具备事务原子性。

`scripts/story_runtime.gd` 当前主要由 `story_theater.gd` 使用；该剧场包含显式模拟胜负按钮，**不是可玩主线的Boss验收路径**。B线修复的独立剧情存档必须单独评估，不能用独立剧场替代主入口。

## 分线交付

- A：`1c95471c` 交付 `battle_reward_transaction.gd`、战斗ID和世界失败恢复接口；`e8c47fe9`补专项测试。正式 `first_act.gd` 尚未整合交易。
- B：`12f871ab` 修复独立 `story_runtime.gd` 的atomic存储、内存回滚和持久outbox；`bf1e1d2c`补故障注入脚本；`22177504`提高旧档恢复校验。待D对接V3消费收据。
- C：视觉和音轨适配、素材清理持续提交；本批编译及正式视听验收未完成。
- D：`3cc7b71f` 提交 `scripts/d_world_interaction/v3_reward_ledger.gd`，`607f7f41` 提交 `tools/d_control/smoke_v3_reward_ledger.gd`。**两者是独立可测试组件，尚未由正式游戏调用，不能当作P0已修复。**

A的 `battle_reward_transactions` 和D的 `d_reward_receipts_v1` 仍为两个不同账本提案；共享代码接线前须确定唯一的权威支付账本或兼容映射，严禁两个独立支付消费者重复发奖。

## 继续阻塞的P0

1. [#10](https://github.com/chenyu9512/StarlitChronicle-HD2D/issues/10)：主游戏V3战斗、Boss/任务奖励原子结算与读档幂等，保存失败恢复完整内存状态且不能提前解锁世界。
2. [#11](https://github.com/chenyu9512/StarlitChronicle-HD2D/issues/11)：B outbox->V3 消费->B ACK 的跨文件重放/确认、旧V1/V2/V3恢复与断点注入。
3. [#4](https://github.com/chenyu9512/StarlitChronicle-HD2D/issues/4)：当前SHA获得真实Godot 4.7.2 Import/编译、专项Smoke与整批QA；需有执行runner/steps/日志证据。
4. A/B/C共享代码改造的冻结承诺、主世界流程断电恢复、战败/撤退/异常退出完整证据仍缺。

## Batch 0冻结后验收命令

```sh
python -m unittest discover -s tools/d_control -p 'test_*.py' -v
python tools/d_control/audit.py --root . --strict
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --editor --quit
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/d_control/smoke_v3_reward_ledger.gd
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/d_control/smoke_atomic_story_save.gd
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/smoke_a_line_reward_transactions.gd
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/smoke_b_story_transactions.gd
```

以上为**待执行**项目，不是本轮执行日志。待A/B/C显式停止共享文件写入后，D重新读取HEAD/锁定文件，再接线、故障注入、用当前提交SHA执行一次完整Core Validation；PASS前不得推进Batch 1。
