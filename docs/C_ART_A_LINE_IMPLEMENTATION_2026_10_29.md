# A线｜Main2 美术资源接入实际交付（2026-10-29）

## 验收边界

基于 `Main2美术优化版` 的 Git 树，原始核查确认 **788** 张图像文件（runtime 109、external 667、其他12），包括 PNG 与 SVG。注册表已记录每张图的 Git blob SHA、物理存在状态、已知注册入口、场景绘制证据和视觉验收状态。它不将“登记”混同“已绘制”，也不将资源已存在混同身份正确。

**状态：** 注册表与运行接口代码已提交＝**成功**；Godot 4.7.2 编译、地图实际显示、Boss身份、跨场景层级遮挡、逐帧动作和视觉审美验收＝**未测试**。必须从游戏实机场景复核。

## 本次代码实际生效点

- `data/assets/c_art_runtime_registry_v1.json` 为**统一正式索引**：资源状态、109个主题槽位、八地区、288项内容图标、7个地区怪物ID、UI样式和严格允许的4个旧资源重定向。
- `scripts/c_art_runtime.gd` 为 B/D 线唯一建议调用入口； `texture_path(path)`、`texture_slot(slot)`、`region_profile(region)`、`texture_region(region, category, id)`、`atlas_paths(region, map, authored, outdoors)`、`ui_texture(icon)`、`content_icon_texture(content_id)`、`monster_source(monster_id)`、`audit_source(path)`。
- `scripts/c_art_overrides.gd` 禁止直接采纳历史616条无语义证明的跨物体迁移；只有4条同物体类型的白名单可作为缺失原路径重定向。用户选择的正式换肤功能仍保留，但旧有不合格整包处于隔离状态。
- `scripts/c_art_theme_v2.gd` 原始主题也能解析语义槽；官方主题的资源路径由统一索引注入。未批准的第一幕Boss候选图默认不伪装为正式Boss身份。
- `scripts/world_terrain_atlas_registry.gd` 仍沿用V8地图兼容及自定义外观主题，但**八地区地形源路径**以正式索引为准。`scripts/world_tileset_pool.gd` 和 `scripts/c_coherent_terrain_materials.gd` 使用语义材质重组 32px×8×8 图集，避免错误沙漠源简单充当海水。
- 地图、建筑、室内、NPC、角色、界面图标、战斗特定怪物等已有调用点改走 `CArtRuntime`。未审核的其他直接路径不能自动宣称消除。

## 八地区现有覆盖（仅列已有真实源）

| 地区 | 地形逻辑映射 | 原生场景/道具 | 具名地区怪物 PNG | 角色/NPC/Boss身份 |
|---|---|---|---|---|
| 海岸 region_coast | 成功（代码映射） | 6个语义源 | 0 | 未测试 |
| 三誓 region_oaths | 成功（代码映射） | 暂无核准地区独立表 | 2 | 未测试 |
| 熔炉 region_forge | 成功（代码映射） | 暂无核准地区独立表 | 2 | 未测试 |
| 群岛 region_isles | 成功（代码映射） | 暂无核准地区独立表 | 1 | 未测试 |
| 镜境 region_mirror | 成功（代码映射） | 暂无核准地区独立表 | 1 | 未测试 |
| 旧土 region_oldland | 成功（代码映射） | 暂无核准地区独立表 | 1 | 未测试 |
| 圣域 region_sanctum | 成功（代码映射） | 暂无核准地区独立表 | 0 | 未测试 |
| 王都 region_city | 成功（代码映射） | 暂无核准地区独立表 | 0 | 未测试 |

此表的地形“成功”只指有效的运行资源选择与程序生成逻辑，**不指现场地图/碰撞/美术观感通过**。怪物图片存在并注册不代表动态战斗动作完成。完整角色与66 Boss身份、美术规模统一仍未完成，不能用职业模板代替角色身份证明。

## B线统一调用

```gdscript
const RuntimeArt = preload("res://scripts/c_art_runtime.gd")

var terrain_paths: Array[String] = RuntimeArt.atlas_paths(region_id, map_id)
var crane: Texture2D = RuntimeArt.texture_region("region_coast", "scene_props", "crane")
var hero_art: Texture2D = RuntimeArt.texture_slot("scene.coast.harbor_crane")
var herbal_icon: Texture2D = RuntimeArt.content_icon_texture("item_herb_01")
var regional_monster: String = RuntimeArt.monster_source("mon_oaths_01")
```

`texture_region` 返回 null 时，应将该对象标为美术缺口；**不要任意借用其他地区或其他角色的贴图**。留空身份候选与界面降级样式不构成已完成美术。

## 可重复核对

```powershell
python tools/check_c_art_runtime_registry.py
```

脚本对照 Git 已跟踪文件核查每个源路径、Git blob SHA、109个主题槽、8地区、288个 UI 内容 ID、怪物资源和重定向；并输出重复内容数量而**不删除**。这个检查只是静态数据完整性，不是 Godot 运行/场景绘制/视觉验收。重复资源仍可能是 DLC 或场景显式引用，未经确认不清理。

## 本线尚未完成的实际内容

- 636个来源仍缺显式注册使用证据（已登记152个；此为最后一次在线快照，实时数量需以脚本为准）。
- 八地区建筑/NPC/Boss未形成逐物体身份确认的完整运行映射。
- 大型装饰的真实占地缩放、全地图Y-sort/遮挡、室内家具、贴图边缘、帧动作与全部40地图的现场图像未完成实机验收。
- 独立新原创正式美术资产并未在本批引入；不合格老映射已隔离，但**不是**已完成替换全部美术。
- 当前不删除疑似重复的21组相同 Git blob，避免错删正式换肤、场景或历史引用。

**结论：统一入口及严谨状态清单已入库（成功）；全游戏美术最终商业级验收尚未达到（未测试/未完成）。**
