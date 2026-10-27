# 《星灯纪行》C线 V10 · 晨露村灯火与安全布景

日期：2026-10-27。承接C V5-V9；main-only，不创建分支/PR，不触及A战斗/B任务/D交互和存档。

## 本批已落代码（实际画面模块）

- `scripts/c_live_coast_dressing.gd`：保留既有 **24** 处四张海岸地图布景及 **7** 张运行贴图来源，新增读取已有`light_pool.svg`的原生`PointLight2D`。仅`paper`纸灯、`lantern`石灯装饰产生灯光：晨露村1盏、白砂港2盏，其余地图0盏。图片本体仍由`CArtOverrides.texture`读取，兼容原图/用户单图/DLC。
- 依正式世界时间控制明暗：17:00逐渐亮起，19:00后为夜间亮度，5:30后逐渐熄灭，7:00完全关闭。`visual_quality=0`无额外灯，`1`每地图最多1盏，`2`最多3盏；禁用动态阴影以限制移动端GPU负担。
- `scripts/world_coastal_scene.gd`：正式`set_clock`与`set_visual_quality`现向这层布景转发，不需要改动D线或旧的夜景逻辑。
- `configure`支持对同一Node重复构建：先从树上移除并销毁旧布景与灯节点，再重建，不留下重复装饰。此操作不会删除任何资源文件。
- 布景从最终权威`layout`只读`features`与`gates`，前者留出四周1格视觉空白，后者留出2格；继续避开堵塞、水域、道路、出生点、建筑和门口。只移动装饰的`Sprite2D`坐标，**不修改**碰撞/寻路/任务/存档数据。
- `tools/smoke_c_coastal_lantern_v10.gd`：新增 Godot 专项回归入口，覆盖晨露村与白砂港灯数、昼夜、画质预算、剧情/出口标记避让、同Node重建清理与collision只读。

## 当前质量与资源台账

- 不新增PNG，不把未适配的1032条候选谎报为正式图片；正式库101条资源契约和V6的1888条分配记录保持原统计。
- 本轮提升的是既有场景中灯笼的可见照明行为、贴图替换兼容及场景稳定性；**非**B02角色动作重绘、室内全图定稿或40地图商业级视觉验收。
- `source_packs/.gdignore` 与 `candidates/.gdignore` 保留，未移动或删除任何原档、地图或剧情数据。

## 测试状态（仅成功/未测试）

| 检验 | 状态 |
|---|---|
| GitHub代码读取：两处运行脚本接线、灯光来源路径与V10专项测试文件 | 成功（静态） |
| 保持C7的24个放置点、7个不同贴图路径和既有地图条件 | 成功（源码及清单静态对照） |
| Godot 4.7.2解析及V10专项烟雾脚本执行 | 未测试 |
| 低配/中配/高配手机GPU灯光开销与夜晚画面截图 | 未测试 |
| 住宅进出、NPC对话、可达性、存档加载全链路 | 未测试 |

## 建议本机集中验收

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c_live_coast_dressing.gd
godot --headless --path . --script res://tools/smoke_c_coastal_lantern_v10.gd
godot --headless --path . --script res://tools/smoke_c_coastal_render.gd
godot --headless --path . --script res://tools/smoke_first_act.gd
```

玩家实景：晨露村晴昼与20:00灯笼、白砂港昼夜两盏灯、主角路过纸灯及建筑入口；必要时调整灯光颜色、强度和偏移。建议下一批推进NPC四方向真正帧动画与B02身份匹配；如果没有Godot画面证据，仍只能将其标作`未测试`。
