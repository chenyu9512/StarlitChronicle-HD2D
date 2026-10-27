# 《星灯纪行》40张剧情地图 · 游戏可用地表细节 V1

- 数据：`data/levels/story_map_blueprints_v1.json`，40张、独立主路/探索支路/3个叙事地标，从当前V3地形和正式区域表读取。
- 真实Godot运行接线：`first_act_world._make_tiles` → `world_story_dressing.configure` → `TileMapLayer` (z=-4) → 8个256×256透明SVG，32px 8×8 tile atlas。不是一张铺满全图的插画，更不是网页地图示意图。
- 编辑原则：保留原有区域地表/水域图集、实体建筑与屋门；新增地表微植被、石屑、路面旧痕、风痕、金色星灯微光。通过`TilePool.shared`和原有DLC`CArtOverrides.texture`进入纹理系统，支持跨地图缓存。
- 安全：只渲染，跳过水域、碰撞、道路、出生点、建筑/任务图钉、旧剧情交互锚点；不产生战利品、触发事件、修改存档、Quest ID或碰撞。
- 第一幕源数据冲突：主线3章旧任务写`map_coast_03`（实际上是`map_coast_04`洞窟），4章旧任务写`map_coast_04`（实际上是`map_coast_02`酒馆），5章旧任务写`map_coast_05`（实际上是`map_coast_03`鲸骨浅滩），6章旧任务写`map_coast_01`（实际上是`map_coast_05`灯塔）。只登记不直接迁移旧档；D/B必须单独审批并加实机回归。
- 地图美术成熟度：**可以作为正式场景的原生绘制层加载**，但不是商业级手绘世界地图的最终验收。现有住宅/地图渲染质量、每个地区的专属大型资产、实际剧情机关点按、长期帧率和玩家完成路线仍需逐图制作及引擎/人工测试。
- 测试：`tools/smoke_story_map_dressing.gd` 验证40张、图集导入、不同主路/分支、绘制层非空和无碰撞修改。未经真实 CI 执行不得标记成功。
