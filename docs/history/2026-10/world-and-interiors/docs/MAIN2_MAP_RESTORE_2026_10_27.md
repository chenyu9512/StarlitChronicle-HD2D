# 《星灯纪行》Main2 三级地图与第三方地形兼容修复

日期：2026-10-27。目标分支：Main2美术优化版。

## 修复原因

2026-10-26 的地图代码提交 de242d7b49cde4bd154d3bb82b0c1ddfb62c879b 和 52820506ae9ae55818c828c7dfd4d23967ffa9ac 移除了“地区分块”和“世界航路”模式。地图数据仍在，但正式UI只剩当前区域。

随后第三方独占美术迁移删除了 coast_ground.png、coast_water.png 和 world_navigation_v4.png 等旧图像，两个地形槽位都被重定向为第三方沙漠素材；原图片集排布无法直接满足 Godot 32px、8×8 地形约定。

## 已接线

- 地图弹窗恢复当前区域、地区分块、世界航路三个选项卡，无迷雾，保持最新本地图标和生态信息。
- 世界地图使用现有世界注册表/42节点坐标与区域关系绘制，不依赖已经退役的旧世界导航 PNG。
- 图上点选地名、显示可用路线、旅行按钮只走 shortest_route 计算的下一相邻可达站点；再经 can_travel 二次授权，不解锁地图或越过剧情。
- 世界路线、地区地图和当前场景图均不写入发现标记、地图迷雾或存档进度。
- 运行时为已迁移的 ground/water 第三方图片构造 256×256、8×8 的 32px TileSet 兼容入口，避免空白贴图或把沙漠原图直接作为海水。此适配保留格子ID和现有碰撞，但仅属于临时显示基础，尚待商业级各地貌图集修整。
- 更新 smoke_map_ui.gd 与 smoke_no_fog_local_map.gd，回归三级模式、不变更存档、无迷雾和地图弹窗。

## 目前验收边界

本次代码在 GitHub 已进行路径和调用静态检查，未在 Godot 4.7.2 环境中执行编译或视觉回归，不应标记为商业完工。

本地完整验证：

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_map_ui.gd
godot --headless --path . --script res://tools/smoke_no_fog_local_map.gd
godot --headless --path . --script res://tools/smoke_all_maps_minimap.gd
godot --headless --path . --script res://tools/smoke_c_shared_terrain_v8.gd
```

最终画面需独立审阅：八大地区颜色与地貌差异、海水河流、道路/悬崖/岸线图块、建筑碰撞、NPC位置、所有剧情目标和门口出入。
