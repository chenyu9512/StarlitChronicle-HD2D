# 《星灯纪行》B线：离线JRPG城镇活动与NPC路径升级 · Batch B2（2026-10-27）

**本批读取的main起点**：`babae4417066a2cdea25936662de2c3b48627ceb`  
**生成本记录时的main快照**：`d5c7b6bad3dae469b744d71399a609b4d31541ba`

产品方向：保留单人离线JRPG、四人指令战斗、原创72章；40图不加探索迷雾、不恢复全局地图UI。B线负责内容与行为，D线拥有主控制器、经济奖励事务和NPC实体生命周期。本批遵守main-only，不创建分支/PR、不强推。

## 已完成的真实代码

### B2.1 街区活动——先预览，后安全事务

修改 `scripts/world_town_ecology.gd`：

- `preview_interact(map_id,event_id,state,hour)` 是**严格只读**的内容服务。对已完成、未到开放时间、前置条件不足和无效地点返回 `allowed=false`；不会发奖、不会设置进度、不会更新金币与道具。
- 合法活动返回：`allowed=true`、`event_id="b.town.<map_id>.<event_id>"`、`requires_save=true`、具体叙事、奖励意图、前置活动ID及实际地图ID。
- 既有 `interact()` 保留向后兼容，改为先复用同一预览规则，再在B域内更新任务状态；旧调用者仍可运行。但**旧调用者的操作并不等于自动完成持久化**，D必须用下方一次性V3事务消费。
- 数量与ID不变：11个村镇/城市，33个固定社区阶段，完成奖励仍仅在各地区原定的handoff阶段。没有MMO日常刷新、账号联网或多人任务。

### B2.2 NPC日程寻路——不穿建筑，不永久卡住

修改 `scripts/world_npc_daily.gd`：

- 大地图路径BFS上限从4096放宽为8192，同时受真实地图内格子数量限制，避免104×72等长距离城镇路径被过早截断。
- `safe_destination` 对被实体家具、建筑立面或临时居民占用的日程目标，寻找半径4格内的合法站位；只改变导航目标，不篡改设计图地形和剧情触发位置。
- 非法/实体封堵的目标直接由路径规划拒绝，不让NPC穿过墙。
- 被动态住民临时包围而缓存为只有起点的死路后，每约1.25秒限频重试，防止永久不动与每帧BFS双重问题。
- 路径仍严格四邻接连续、每次移动受现有速度上限约束、不远距传送；保留D控制器的位移应用、碰撞裁决和Y-sort表现职责。

## 实际交付测试（尚未通过Godot执行）

- `tools/smoke_b_town_activity_preview.gd`：11城镇33阶段，逐一验证预览完全不改state、前置/时间窗口、稳定事件ID、与原正常交互奖励一致、重复不可领取、V3快照恢复。
- `tools/smoke_b_npc_navigation_safety.gd`：104×72地图跨越4096格搜索边界、四邻接无瞬移、被占日程点替代站位、暂时堵塞后限频重试及地图ID隔离。
- `.github/workflows/b-world-batch-validation.yml`：追加上述两个Godot测试，保留手动 `workflow_dispatch`，不每次提交就耗费Actions分钟。

通过GitHub读取正式JSON后完成的**数据交叉核对**：40个独立NPC的24小时日程各时间段均只有一条对应安排；11城镇33活动的前置顺序与居民活动地区合法；正式地图共40张。以上是数据/源码核查，**没有冒充引擎运行或玩家真实实测**。

## D线紧急接线事项（B无权覆盖主控制器）

### P0: 城镇社区活动的金币/物品事务

`scripts/first_act.gd::_interact("townlife:")` 目前仍直接调用 `world.town_ecology.interact()`，提前修改 `rpg.town_ecology_v7`，之后再发道具和执行 `_save_progress()`。保存失败可能导致当前游戏内标记已完成、奖励不一致。

D应将正式入口改为：

1. 调用B的 `preview_interact(map_id,event_id,progress,hour)` 校验真实玩家交互阶段和时间。
2. 对合法事件，使用 `V3RewardLedger.settle`（或已有统一V3事务组件）基于 `preview.event_id` 作为稳定receipt；intent包含实际map_id/event_id/奖励内容，执行时再次检查允许条件。
3. 在同一次snapshot mutation中写入 `rpg.town_ecology_v7[map_id][event_id]`、更新金币/物品；保存失败则一次回滚所有状态和道具。
4. 仅保存成功后记录 `town_ecology_activity` / `town_ecology_completed` 事件，展示预览文案；重放receipt不可二次派奖。
5. 在无效入口、尚未开放和已有receipt时返回明确无收益的提示，保证旧V3存档继续可读。

### P1: 玩家可见NPC日程禁止瞬移

`scripts/first_act_world.gd::sync_world_clock` 目前会在跨昼夜分界时立刻重设 `citizen:` 实体的 `position`，因此NPC在屏幕中可能瞬间传送。D需集成已存在的 `d_world_interaction/npc_behavior_controller.gd` 和B的 `WorldNPCDaily.step`：

- 加载当前地图先取稳定NPC id + 设计出生位置；D保留占格、门口/出口/剧情点保护。
- 当玩家在场景内观察NPC时，时间变动只更新其目标；用bounded path step与C的NPC运动表现走向新地点。
- 对已离开屏幕且不可见的NPC可以应用离线日程同步；必须先验证落点安全，不能把NPC放到建筑/任务触发格内。
- 一进入对话就 `begin_talk` 暂停，结束 `end_talk`；不要以瞬移替代走路。
- 不增加网络模拟、MMO服务器、PvP或强制联网机制。

### 原有P0未解决

`first_act.gd` 的 `field:` 野外采集、`wild_camp`、`_service_action()` 等部分经济流程仍采用**先内存变更、后保存**。这不是本批所修改内容，但D需要继续用统一V3事务与失败回滚修复。

## 实际状态

- 代码提交至远程main；D/C/A的独占文件未修改。
- 此执行环境无Godot 4.7.2可执行程序，因此本批所有新增引擎脚本标记 **未运行 / 未获得Godot验收**。
- 不宣称完成40张地图的商业级玩家体验或所有NPC可见行动；本批完成的是B线逻辑以及D线可消费的接线契约。
- 下一阶段仍应集中实现晨露村→白砂港前三章的真实单机玩家流程，D完成上述事务与自然NPC运动后再进入跨图黄金样板验收。
