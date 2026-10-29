# 《星灯纪行》第19-8批｜85处剧情内景静态验收、NPC状态与CI异常调查

日期：2026-10-25；所有变更增量进入 `main`，保留原120任务正典、分支选择及V3存档。

## 已实际核查与修复

- 核对 `Phase 19 World Story Acceptance`、`Godot Core Validation`、`Map UI` 等多条工作流：这些运行在几秒内失败，`jobs[].steps=null`，没有导入或执行Godot的日志。**这不能证明游戏代码已通过，也不能据此定位游戏逻辑错误。** 仓库Actions可用性、账户计费/配额和工作流权限须由有权限者在GitHub界面核查。
- 使用连接的GitHub文件接口逐一读取新增的54张伙伴/地区V4关卡，分别对0–17、18–35、36–53三个分组执行独立BFS通行检查。**54/54成功读取，54/54关卡的出生点、出口、11种剧情及证物标记均可连通；新54张未发现互动格冲突，全部三个批次的几何形状各不重复。** 这是资料级校验，不是Godot运行成功的证据。
- `scripts/first_act_world.gd`：有多个专属建筑入口时，使用最近门距离优先规则，避免先加入列表的远门截断玩家操作。
- `scripts/world_npc_visual.gd`：基于原剧情推进阶段（初遇、调查、社区、回访、结算）、存档中的A/B路线和实际昼夜为NPC设置表情、披肩色和光色；没有凭空补选A/B，也没有重绘角色身份。
- `scripts/first_act_world.gd` 与 `scripts/first_act.gd`：在加载存档及刷新支线后使NPC颜色/微表情同步变更。现有85张独立室内原任务的首谈、结算和回访标记复用NPCVisual，原任务ID与四/五阶段结算均不变。
- `tools/smoke_phase19_companion_regional_rooms.gd`：为54个新场景增加A/B外观变化、不默认分支及昼夜外观状态断言。由于Actions作业尚无法正常开始，**这批新增Godot测试尚未在引擎内完成验证**。

## 可执行本地验收替代入口

`tools/run_phase19_acceptance.py` 收录原任务、A/B剧情、120地点、12航页独立房间、12推理、19生活场景、54伙伴/地区场景和72章回归。Windows PowerShell可执行：

```powershell
py -3 tools/run_phase19_acceptance.py --godot "C:\\path\\to\\Godot_v4.7.2-stable_win64_console.exe"
```

也可用 `--skip-godot` 仅执行静态核验，但该模式会明确标记 `static_only_engine_unverified`，不能冒充游戏可运行。日志位于已被 `.gitignore` 忽略的 `logs/phase19_acceptance/summary.json`，每一项均有独立日志和退出码。

## 遗留问题与边界

1. GitHub Actions工作流无法正常启动步骤的异常仍未解决；需要从仓库/账户层面排查，不能通过改动游戏数据假装修复。
2. 54个新伙伴/地区内景已通过独立的GitHub数据读取+BFS，但完整85房间的Godot自动执行、实际UI、资源加载和旧档互操作仍须在引擎中复测。
3. 本批NPC表情、配色和阶段服装标记属于程序化演出；最终商业级表情立绘、动作分镜、全语音和角色专项换装尚待原画与动画制作。
4. 保留35处正典户外现场及全部章节、任务和奖励规则。不宣称本阶段已完成120条全流程人工通关。
