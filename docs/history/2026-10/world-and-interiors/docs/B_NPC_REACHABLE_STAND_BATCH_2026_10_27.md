# 《星灯纪行》B线 · NPC可达站位寻路修复（2026-10-27）

## 范围与所有权

本批仅修改B线 `scripts/world_npc_daily.gd` 与 `tools/smoke_b_npc_navigation_safety.gd`，保留Godot 4.7.2、32px逻辑网格、离线单人JRPG定位。没有新增世界地图、探索迷雾、网络功能，也没有修改D线控制器/存档事务、A线战斗或C线美术资产。

## 缺陷与解决

旧实现用 `safe_destination(goal,walls,extent)` 选第一个没有障碍的近邻格，再用BFS从居民当前位置向它寻路。如果某格虽然空闲，却处于围墙另一侧，NPC会持续向其靠近，但永远无法抵达日程目的地。静态家具或后续美术改动容易触发该问题。

现在BFS寻路新增可选 `stand_radius`，在**起点实际可达**的网格中评选距日程中心曼哈顿距离不超过4格的站位；优先选与中心最接近的可达格，同距离沿BFS优先短步行路线。该选择不需要额外执行一次BFS；仍保留8192格搜索上限、连续四向格移动和不可达时的限频重试。直接调用四参数 `_route` 的旧测试行为保持不变（目标本身被墙占据返回空路径）。

`step()` 保留原日程中心作为首选目标，对越界配置保留原有最近可用格回退；从实际缓存路径尾部返回 `navigation_goal`，避免报告一个NPC无法到达的空格。所有NPC稳定ID、对白、奖励、物品、剧情事件和旧存档数据保持不变。

## 新增测试

原有 `smoke_b_npc_navigation_safety.gd` 增加隔墙工况：目标(16,12)被挡，x=14有完整分隔墙，起点(8,12)；原最近空格候选落在墙另一侧，新BFS应缓存并抵达墙这一侧的(13,12)。同时检查整条路线每步4邻接、不穿越封闭格。原有8192上限大地图、部分路径限频及临时障碍打开的回归仍保留。

手动B线GitHub Actions工作流 `.github/workflows/b-world-batch-validation.yml` **已经引用该同一Godot测试**，本批无需重复新增入口。

## 本批事实状态

- GitHub main直接提交与源文件再读取：**成功**。
- 根据相同障碍坐标做的独立Python BFS小型逻辑算例：**成功**（得到(13,12)）；此结果不等同于Godot执行。
- Godot 4.7.2脚本编译、手动B线CI、游戏实机NPC可见移动和性能压测：**未测试**。本执行容器未找到Godot可执行文件，GitHub Actions未在本批触发。
- 第一幕商业可玩验收：**未测试**；不能据此宣布通过。

复核命令：

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_b_npc_navigation_safety.gd
godot --headless --path . --script res://tools/smoke_b_npc_home_v1.gd
godot --headless --path . --script res://tools/smoke_b_act01_physical_reachability.gd
```

## 仍然未解决的跨线P0

1. D线完成第3章洞窟开放与第4–6章实际正典入场、旧V3存档安全迁移；B只提供章节路线和可行走关卡数据。
2. D线将第2/4章室内调查转为真实玩家输入、验证面向和距离并纳入统一存档回滚。
3. C线继续正式海岸场景、NPC动作和室内美术；在视觉调整后重新验收NPC动态遮挡和可达性。
4. Godot批次及不作弊的第一幕六章连续玩家流程必须实跑，不以已有测试脚本数量代替结果。
