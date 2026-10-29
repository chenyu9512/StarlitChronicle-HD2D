# 《星灯纪行》HD-2D渲染与资源节省 · R1交付（2026-10-26）

## 范围与原则

起始主线SHA：`788b3f7ea287026bfbf79fa7b486b1d39f786ab6`  
本记录编写时最新主线SHA：`0ceb06bfce5a34bc3f40c31a7dbe60ef7b8bf447`（共享main有A/B/C/D并行提交，以复核当时main为准）。

本批已**实际改写主游戏代码**，不改变40张地图的图块坐标、门、碰撞、72章、战斗/任务、存档格式或正式玩家流程。继续执行上一轮产品决策：**不添加探索迷雾，不显示全局地图，只保留当前区域地图和小地图**。

## R1实际上线的改动

1. `scripts/world_tileset_pool.gd`：共用32px TileSet/TileSetAtlasSource构造，key包含美术贴图路径、图集维度、局部行范围及 `c_art_overrides.gd` 的修订号。LRU最多保留12份图集定义；被淘汰的资源仍由在用的TileMapLayer正常持有，新场景才重新请求。不将地图TileMapLayer的格子、碰撞或状态放进缓存。提供 `stats()` 供引擎统计命中数/构造数/淘汰数。
2. `scripts/first_act_world.gd`：地面/水面共享两源图集，原0=地表、1=水面与8×8坐标不变；地区美术失效时回退到内建地表与水面。加入 `set_visual_quality(0..2)`，新建地图、室内、海岸装饰时将画质下发。
3. `scripts/world_coastal_scene.gd`：海岸地表细节共享单图集；省电档禁用水面反射/浪花可见与持续动画，高档恢复；洞穴动态灯光在省电/标准/高清分别至多1/2/3盏，保留必要环境照明。
4. `scripts/c_coastal_painter.gd`：晨露村/港口原创彩绘地表图集及专用鹅卵石路面图集改走同一个缓存。
5. `scripts/world_interior_art.gd`：室内墙缘只复用TileSet图集第7行；光源上限省电1/标准2/高清4，实时阴影仅在高清启用且至多2处；火焰降低速度，省电档停止周期性光源呼吸刷新。
6. `scripts/world_ambience.gd`：天气状况不变，但每次绘制粒子数省电16/标准36/高清62；省电降低重绘频率，不对游戏天气/战斗/移动参数做任何改变。
7. `scripts/rpg_menu.gd` + `scripts/first_act.gd`：设置页可选「省电／标准／高清」，复用现有 `rpg.settings.visual_quality` 存储，保存失败回滚，读档恢复并即时影响运行场景。

## 资源收益与严格边界

- 减少反复进入地图和城镇/房屋时重复生成完整TileSet与AtlasSource的CPU开销，8地区同图集跨地图共享。
- 图集缓存最多12条，阻止全世界图集定义无限留在内存；但这是**缓存条目数量上限**，不是GPU显存MiB的精确硬限制。
- 不伪称已减小PNG文件体积：目前未重新打包实际美术图片、未批量压缩图片，也未制作40张最终手绘场景。
- Godot ResourceLoader本身会缓存相同资源路径的Texture2D。R1主要新增的是**TileSet资源对象**的复用，并提供避免连续GPU动画的三级预算；不可把它夸大为贴图像素显存必然下降百分之几十。
- 目前尚未实行离线布局预编译或真正的多地图Streaming；现有40份V3布局与97份V4室内继续为权威数据，以免重写B/D控制逻辑。
- 允许的用户私有美术替换仍由 `c_art_overrides.gd` 管理，修订号变化会使新请求不复用旧atlas资源。

## 可核对的测试入口

- `tools/validate_render_budget_wiring.py`：静态检查四个主画面源均从共享缓存装配，省电画质/正式入口已接线，迷雾/全局地图未恢复。
- `tools/smoke_world_tileset_pool.gd`：32px双图集、缓存命中、LRU达到上限时仍保留在用TileMapLayer、相同地图重进不改变图块或剧情。
- `tools/smoke_world_render_quality.gd`：实地图白天/室内往返、省电与高清的天气/反射/灯光预算、保持天气、金币、剧情旗标不变。
- 现有 `tools/smoke_c_coastal_render.gd`、`tools/smoke_world_production.gd`、`tools/smoke_all_maps_minimap.gd` 回归画面和真实布局。
- 手动CI：`.github/workflows/render-budget-validation.yml`，仅 workflow_dispatch，**不按每次main推送自动执行**。

### 实际测试状态

GitHub源文件与变更已读取核对。**本执行环境无Godot运行程序，也不能直接在用户Windows电脑进行实机FPS/显存采样，因此没有声称编译、Godot专项脚本、性能对照已通过。** GitHub Action也尚未触发，GitHub回执SHA不是测试通过证据。

## 下一批 R2 的具体优先级

1. 在Godot 4.7.2运行手动批量引擎测试，优先修真实parse/纹理导入与房屋往返回归错误。
2. 收集海岸村、港口、室内及其他地区在PC和目标移动设备的Draw Calls、内存、帧时间，量化从R1之前到R1之后的收益。
3. 研究V3布局离线编译和只读预设TileMapLayer资源的收益；如果运行时重新组合比加载预设开销显著，再分批部署，避免提前引入不必要的Streaming系统。
4. 做 C 线8地区共享手绘图集与版权可追溯资源包，减少重复绘制与无效导入，不误删Godot正常依赖的.import配置。
5. 维护A/B/C/D文件所有权与main-only协作，下一轮D线再决定是否全局推广统一画质到独立战斗演出、剧情特效。

