# C线 C0/C1/C2 实际交付 — 2026-10-26

## 修改范围
仅 main，未创建分支/PR，未强推。正式入口 `scenes/first_act.tscn` → `scripts/first_act.gd` → `scripts/first_act_world.gd` → `scripts/world_coastal_scene.gd`。沿用既有 `TileMapLayer`、`Sprite2D`、`CanvasItem` 灯光，保留 V3 地图/角色/建筑/剧情等ID。

## 本次真实接入内容
- 两张原创 SVG 8×8 手绘线稿装饰图集：`dew_ground_glaze.svg`、`harbor_ground_glaze.svg`，`c_coastal_painter.gd` 将它们逐格绘制到正式游戏地图的 `OriginalCoastalInk` TileMapLayer，保留32px网格。它们是现有地表上叠加的稀疏笔触，不是假冒整张高清手绘地表替换。
- 三类独立原创2D装饰：`dew_street_lantern.svg`、`dew_saltcloth_rack.svg`、`harbor_mooring_post.svg`；晨露村和白砂港实景用 `Sprite2D` Y-sort 加载。安放前检查建筑范围、道路、水域、门前台阶和出生区域。它们当前是非碰撞布景，不能被误认为真实有交互的房屋或有碰撞家具。
- 原创 `coastal_reflection.gdshader` 作用于已有受32个上限约束的水面反光Sprite；不修改水体/桥梁碰撞，不替换地图导航。
- 街灯 `PointLight2D` 在游戏世界时钟夜间启动、白天归零。C模块提供 `set_visual_quality(0..2)` 降级接口，0停用局部光和水纹，1减少波动，2恢复精细动态。默认场景路径未私自改动用户画质设置。
- 改动 `world_coastal_scene.gd` 挂载新C渲染节点，修改 `first_act_world.gd` 两处将正式时钟传给C层；不触碰战斗、任务、奖励、地图路径、存档结构。
- 在 `data/assets/c_coastal_original_registry.json` 登记素材源、状态及实际消费者。原创源文件保留，可复编辑；不是第三方CC0批量替换。
- 专项测试 `tools/smoke_c_coastal_render.gd` 验证海岸两图实际TileMap层、原创物件、灯光夜昼、Shader与碰撞数据不变，**测试已提交但本轮未运行**。

## C0静态清单
- `docs/art_audit/c0_scene_runtime_matrix_20261026.json` 收录40份V3正式地图和97个V4室内文件的路径级矩阵。40张正式地图均有地区地表和水面图集；独立手绘地表叠层当前只接入晨露村和白砂港。
- 97份室内JSON文件存在并可从当前V4入口按ID解析，但本轮连接器批量读取触发单次调用限制；矩阵中室内 art_profile 均标记 `NOT_INSPECTED`，不能声称97个室内完成视觉确认。
- 现有晨露村客栈、住宅的 `art_profile` 已在单独源文件抽检：`coast_inn_v1`、`coast_district_house_v1` 对应正式 `world_interior_art.gd`，家具及光源列表已存在，但未做运行截图/碰撞验收。
- `map_coast_03` 和 `map_coast_04` 已使用现有SVG独立区域TileSet、海岸布景等；其他地区还需逐图画风设计，而不仅是颜色主题。

## C → D 接口
- `WorldCoastalScene.configure(map_id,layout,scenery)` 不改签名，仅在 `map_coast_01/02` 挂 `OriginalCoastalDressing`。
- `WorldCoastalScene.set_clock(minutes)` 已由 `first_act_world.gd` 的建图与 `sync_world_clock` 调用。
- `WorldCoastalScene.set_visual_quality(level)` 可供 D 线将来连接全局图像设置，不会改变存档或地图状态。
- `C_COAST` 不写 `layout.blocked`、`layout.water_mask`、地图解锁、交互目标、剧情ID、战斗数值。
- 正式建筑碰撞和门口站位仍由 B/D 的 `world_geography.gd`、`first_act_world.gd` 负责。视觉工作不能私自改动碰撞来适应画面。

## 质量门禁与尚未完成
- **ASSET_READY:** 五个原创SVG和一份Shader的资源文件已提交。
- **RUNTIME_CONNECTED:** 两地图的渲染代码已挂在真实游戏入口链路（静态代码证据）。
- **GODOT_TESTED:** 否；当前工作环境没有Godot引擎。新C专项脚本尚未执行。
- **VISUAL_REVIEWED:** 否；未取得真实Godot像素截图，不能用概念图替代。
- **COMMERCIAL_ACCEPTED:** 否；首批2D笔触与小场景布景远未覆盖商业级高清手绘场景，未做设备/交互质量验收。
- 旧主分支的全量QA运行 [40322238747](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40322238747) 在本轮C提交之前失败，日志包含“Town doorway was blocked”、“Town building is inaccessible”；由于城镇封房门规则与旧测试门口假设可能不同，需由D线统一对齐建筑内实心门格与门前一格交互契约。不能把旧运行当成C新提交的失败/通过证明。

### 需要执行的集中测试
```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_c_coastal_render.gd
godot --headless --path . --script res://tools/smoke_town_entrances.gd
godot --headless --path . --script res://tools/smoke_c_town_presentation.gd
godot --headless --path . --script res://tools/smoke_first_act.gd
```
需要真实运行画面：晨露村昼夜、白砂港、盐风古道、海蚀洞、客栈、住宅，户外建筑门前与室内返回。接下来应在C2补绘更完整的城镇外墙、屋顶/地表原创高清美术和住宅布景；C3/C4的其他地图/室内不得因本次复用渲染架构宣称完成。
