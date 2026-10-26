# 《星灯纪行》C线 / 首页美术替换管理器

Date: 2026-10-26
Branch: `main` only. Change scope: resource catalog, loader adapters, home UI, static validation and Godot QA script.

## 功能
- 首页新增“▣ 美术资源管理 / 图片替换”。显示 **548** 条可识别美术记录，分成 **20** 类。按名称、路径、原始 ID 和自定义备注搜索；每页 18 张缩略图。
- 左侧列出资源缩略图，右侧预览**游戏原图**与**当前生效图**，可保存私人备注、从本机选 PNG/JPEG/WebP、恢复单张原图。
- 素材来源与状态明确显示；旧版素材与外部导入素材不标记为商业验收完成。中文名称保留 B02/B03 角色名称；遗留资源以词典/文件名命名，可在首页补充备注。
- 原始 `res://` 资源**只读**，自定义图片保存到 `user://c_art_replacements/`，映射写入 `user://c_art_overrides.cfg`，与游戏存档完全分离。恢复单张资源不修改任何剧情旗标、角色数值、NPC 数据。
- 导入限制：仅图片格式；24 MB；像素上限 8192×8192 且不大于 32 MP；动态图集要求像素完全相同；非图集长宽比差异不大于 12%，按原贴图分辨率缩放，确保 TileSet/Sprite2D 容器尺寸不会被意外更改。
- 场景需重新创建或重新进入后，已接入的纹理才会应用；首页背景更换立即刷新。

## 接入范围
- `first_act_ui.gd`: 首页灯塔、对话立绘。
- `first_act_actor.gd`, `world_npc_visual.gd`: 角色行走图集和 B02 NPC 全身图。
- `world_structure.gd`, `world_interior_art.gd`, `world_coastal_scene.gd`: 建筑外观、家具、室内图块、室外装饰与水面贴图。
- `first_act_world.gd`: **仅**土地/海水 TileSet 纹理与场景道具纹理来源；未更改地理布局、碰撞、输入、事件。
- `first_act_battle.gd`, `battle_actors.gd`: **仅** Boss/怪物/角色战斗立绘、背景和战斗视觉图块，不改攻击/技能/数值。
- `map_view.gd`: 世界地图纹理。
- Legacy `actor.gd`, `world.gd`, `battle.gd`: 旧版角色、地图、敌人、道具素材适配。
- 尚未全面覆盖每一个程序绘制 CanvasItem、直接缓存资源的其他 UI、编辑器工具及游戏外的图片资源。它们可显示在目录，但不能因为目录收录就声称所有运行位置已经换图。D线需继续用 `CArtOverrides.texture(path)` 接入未来新增绘制点。

## 设计约束与验收
- **无关数据保留：** 剧情和数值逻辑、存档格式、`project.godot`、QA workflow 都没有改动；资源类型、错误图像、坏文件都回退原图。
- 所有 548 条记录能在 GitHub 静态树中匹配。没有把外部素材或 B02 静态原画误标为完整动作。
- `python tools/validate_c_art_catalog.py`
- `godot --headless --path . --script res://tools/smoke_c_art_overrides.gd`
- `godot --headless --path . --script res://tools/smoke_first_act.gd`
- `godot --headless --path . --script res://tools/smoke_battle_actors.gd`
- `godot --headless --path . --script res://tools/smoke_coastal_interiors.gd`

**验收尚未完成**：当前执行环境没有 Godot 可执行文件，未能实际运行解析/导入/音画/移动端回归。静态 JSON/源文件存在性检查不等于引擎运行通过，不能保证“没有任何一点问题”。

## 已知限制
- Godot 文件选择器在某些 iOS 沙盒环境权限有限；桌面版文件选择与运行时 `user://` 持久化应在目标系统进一步实测。
- 当前版本是**玩家端本机替换**。若希望将自己替换的图提交为所有玩家通用正式美术，还需要独立的开发/审核/发行流程（不可直接覆盖发行包）。
- 用户自定义图仍需自行确保拥有相应使用权限；本机加载不等同于公开再发布。
- 大尺寸图会占用内存；缩略图18张/页，限制一次显示数量，但不代表已完成所有机型帧率验收。
