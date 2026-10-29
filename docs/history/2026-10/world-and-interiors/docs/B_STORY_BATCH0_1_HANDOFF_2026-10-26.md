# 《星灯纪行》B线 Batch 0 / Batch 1 交付与D线交接（2026-10-26）

## 基线及证据等级

- 读取到的基线 `main`：`dace2e1c943d3d1ebd263d5da2f63b87a169affb`，没有新建分支/PR。
- 本轮修改仅限B负责的独立剧情存档/奖励运行器、B专项回归及本说明。未修改 `first_act.gd`、`first_act_world.gd` 或 D/A/C 共享控制器。
- 原始正典目录未变：72章、40张活动地图、120任务、66Boss、20职业及原有角色ID。本轮没有伪造任何完成旗标、战斗胜利或探索路径。
- **测试等级**：SOURCE_PATCHED（已提交源码）。新增的Godot smoke是待执行的验收脚本，不是已执行日志，不能宣称 Godot 4.7.2 PASS。

## Batch 0：本轮修复

### 独立剧情存档

`scripts/story_runtime.gd` 的持久化调用使用已有 `tools/d_control/atomic_story_save.gd`（临时文件、读回校验、有效主档备份、损坏主档回退）；保留既有 `starlit_story_v1.json` v1/v2读取协议，不覆盖V3主游戏存档。

对话位置、剧情选择、战斗请求/结果、目标进度、场景和独立支线的状态变更均在可持久化成功后继续；失败将该次内存状态恢复到修改前，阻止本次结果信号和新奖励。以B线事件ID作为回执键，不更改正典ID：
- `b.story.scene.<scene_id>.reward.<effect_index>`
- `b.story.quest.<quest_id>.reward`

持久化的 `reward_outbox` 保存完整奖励参数和 `event_id`、`receipt_required`。保存完成后才发 `reward_granted`；未签收事件可以由 `replay_pending_rewards()` 再次发出。消费者 **必须使用幂等账本**，先在自身权威存档内一次性结算奖励和 event_id，再调用 `acknowledge_reward(event_id)`；禁止仅凭内存布尔值发奖。未接入该A/D消费者持久账本前，该接口只提供可恢复的 *at-least-once* 投递，并非跨两个存档的 exactly-once 商业验收。

`pending_reward_receipts()` 提供待处理队列只读快照。旧存档没有 `reward_outbox` 时恢复为空，不给任何老场景补发未记载奖励。不得自动推断旧档已经领取过的金钱/物品。

`save_path` 默认保持旧玩家路径，仅供隔离QA重定向。

### B线针对旧档恢复的边界

- B的故事v1/v2备份回退使用 D 已提交的 `atomic_story_save.gd`。
- D的正式 V3 `first_act_state.gd` 以及 `world_state_sync.gd` 仍由D负责地图/章节/坐标恢复；本次没有偷偷改其恢复策略。
- 损坏主档和备档、保存目录不存在、奖励重放与回执失败是专项测试项；结果待运行。

## Batch 1：现有基础与未闭合接线

静态源已有 `world_npc_daily.gd` 的40人正典本地图作息、寻路、交谈停止/面对玩家，以及 `world_home_interactions.gd` 的12个独立室内、52个调查物及前后阶段记忆。B这两处成熟度是“数据/可调用逻辑存在”，不是“主游戏实际调用”。

D线应落实：
1. 正式场景每帧仅按该地图调用 `residents_for_map(map_id)` 与 `world_npc_daily.step(...)`，并更新真实可视节点位置、动态占用格、面向和可交互距离。交谈时 `begin_talk/end_talk`，卸载时 `reset_route`。
2. 通过 D 唯一场景路由处理NPC面向、透墙遮挡、门/室内、两向回程、战斗后的输入恢复。不允许同时调用旧 `world.interact()` 与新桥接器产生双重事件。
3. 家具由 `InteriorInteraction.inspect` 生成 `home_seen` 效果，由 `WorldInteractionExecutor.commit` 以V3单域保存。B的 `world_home_interactions.inspect` 会修改内存记录，不应在未接上失败回滚的共享输入层直接使用。家具本身没有经济奖励，不要让D重复发奖。
4. A/D联接 `reward_granted` 的 tagged payload。需与A的战斗收益 nonce 区分命名空间，并在一个权威存档内持久化“已消费event_id+实际奖励”，再回执B。

**前3章与40地图全量运行、72章连续通关、120任务全量实际接取与结算仍未通过验收，不能误写成已完成。**

## B线专项测试命令及通过门禁

```sh
python tools/validate_b_npc_home.py
python tools/validate_b_line_delivery.py
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/d_control/smoke_atomic_story_save.gd
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/smoke_b_story_transactions.gd
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/smoke_b_npc_home_v1.gd
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/d_control/smoke_world_interaction.gd
```

上面命令为**待执行**的单批验收集合。必须在最新合并SHA上获取真实编译、专项smoke和连续游玩证据。没有 Godot 可执行环境时不得伪造结果或改写矩阵为Godot通过。

## 未闭合风险

- `story_runtime.gd` 是独立故事入口；正式世界目前还没有证明接入此运行器。需要D检查 live 入口后再判定其 P0 是否已经覆盖所有玩家路径。
- A/D主游戏 `first_act` 的章节、Boss和V3奖励仍需按权威存档事务门禁单独修复；B这次只修复自己的故事域。
- 跨B故事存档与A/D金钱经验存档的断电窗口依赖“consumer event ledger + replay/ack”，未集成前保留 P0。
- 当前静态验证只能检测数据结构和部分地图可达性，不能代替人工逐地图、逐任务保存恢复、昼夜NPC与遮挡测试。
