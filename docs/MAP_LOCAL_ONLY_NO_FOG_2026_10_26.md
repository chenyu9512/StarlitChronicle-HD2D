# 地图功能调整：取消探索迷雾与全局地图（2026-10-26）

## 用户要求与范围
正式游戏**不再使用探索迷雾**，区域地图和右上角小地图直接显示当前可玩场景的完整地形；**取消全局世界航路图和地区总览切换**。保留玩家可走区域的真实TileMap数据、当前位置、任务交互标记、当前地图缩放/拖动。世界之间原有出口、邻接关系、故事解锁仍由WorldRegistry与实体地图入口维护，不能因为删除地图UI而开放非法传送。

## 已改动
- `scripts/map_view.gd`：只渲染本地地形，去除每格已揭示检测、全局atlas纹理、地区绘制和世界pins。
- `scripts/map_hud.gd`：去除世界/地区模式、路线图上的旅行按钮、已揭示百分比，保留小地图与当前区域放大视图。
- `scripts/rpg_menu.gd`：删除「世界地图」菜单分页；「地区探索」中的地图按钮改为进入**当前区域地图**。
- `scripts/first_act.gd`：不再创建、绑定或保存新的迷雾；旧世界地图入口改为本地地图入口；普通出口旅行不变。
- `scripts/first_act_world.gd`：删除雾图写入、每步揭图、迷雾配置和迷雾状态字段。
- 删除 `scripts/world_fog_v3.gd` 及 `tools/smoke_world_fog_v3.gd`。

### 旧档
旧V3存档中若有 `rpg.world.fog` 数据，保持原样，不做危险的迁移/清洗。新的正式游戏不再读写它，地图视图也不再根据它隐藏地形。**天气薄雾/气象表现不是探索迷雾，不受本修改影响。**

## 测试更新
- `tools/smoke_map_ui.gd`：原全球pin模式测试改为本地map与zoom。
- `tools/smoke_all_maps_minimap.gd`：40张地图和室内地形仍需完整加载、户内外正确切换，没有新增雾保存。
- `tools/smoke_world_production.gd`：世界绘制验证改为本地地形尺寸一致。
- 新建 `tools/smoke_no_fog_local_map.gd`：无雾状态、菜单视图不泄漏全局地图、无雾保存还原。
- 新建 `tools/validate_no_fog_local_map.py`：静态防回归门禁。
- 更新 `.github/workflows/map-ui-validation.yml` 和 `.github/workflows/godot-core-validation.yml`。

## 测试事实
当前环境没有Godot 4.7.2程序，不宣称游戏已编译通过，也不宣称界面截图实测完成。GitHub远程源内容、功能入口和静态政策条件已核对。需要手动触发 `Map UI Gameplay Validation`，然后真实游戏中从新建游戏、旧档读档、野外、村镇、迷宫和室内分别打开地图，确认没有地图遮罩、世界图页面和意外的传送权限变化。

当前工作结果基于提交后最新 `main`，本记录写入前快照 SHA：`15fb550f5f2ab4cee9b95fd6747976e55444e9de`。并行的A/C/D线可能继续推进main；以后审计以重新读取的main为准。
