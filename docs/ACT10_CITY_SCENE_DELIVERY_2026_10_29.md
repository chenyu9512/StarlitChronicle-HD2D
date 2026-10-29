# 第10幕「群灯之城」正式场景开发批次（2026-10-29）

> 分支：`Main2美术优化版`。本批按用户指令**暂不测试**。状态：源文件已提交 / 正式入口已接线 / Godot、人工画面、正常玩家路径一律**未测试**。

## 1. 不再扩架构：在原有42图世界里制作实物

本批继承已存在的 `WorldRegistry`、`WorldGeography`、`WorldStructure`、`TownDirector` 与 `first_act_world`，不修改总地图数量、42图旅行邻接、40正式世界地图计划、66 Boss、120任务、V3保存及现有屋门碰撞。所有门口、建筑位置取 `data/levels/world_atlas_v2.json` 实际建筑节点。

### 1.1 六份原画SVG立面（256×192）

| 世界地图 | 正式现有建筑ID | 资源路径（位于`assets/art/exteriors/coast_final_pass/`下） |
| --- | --- | --- |
| `map_city_01` 群灯旧会馆 | `guild` | `map_city_01_guild.svg` |
| `map_city_01` 群灯旧会馆 | `shop` | `map_city_01_shop.svg` |
| `map_city_02` 自由议事厅 | `guild` | `map_city_02_guild.svg` |
| `map_city_02` 自由议事厅 | `shrine` | `map_city_02_shrine.svg` |
| `map_city_03` 群灯居民街 | `house` | `map_city_03_house.svg` |
| `map_city_03` 群灯居民街 | `inn` | `map_city_03_inn.svg` |

`WorldStructure.setup()` 既有的 `map_id + building_id` 命名路径会自动解析上述立面。SVG为新绘制的原始高清2D矢量资产，不是把小型道具强行放大成房屋；若载入失败会保留原来可绘制的建筑回退，防止从地图删除入口。第10幕矢量建筑使用线性过滤，而其他旧图的像素过滤不变。

**边界**：不是为所有30栋城镇建筑都完成美术；以上六份是第一批具备确切真实入口的地标立面。也未验证SVG在目标Godot版本中的导入表现。

### 1.2 第4–5张城市地图的地面识别

- `assets/art/world/city_districts/lantern_grid_inlay.svg` — `map_city_04` 星灯中枢，七灯连接的嵌地回路；只在已提交 `world.distributed_network` 后变亮。
- `assets/art/world/city_districts/west_rebuild_plan_inlay.svg` — `map_city_05` 西区工地，地面房屋规划/共同修缮图；只在已提交 `story.ch055.done` 后提高亮度。
- `scripts/world_city_floor_identity.gd` 在原 `PlayableGround` 上的无碰撞层寻找与出生点连通、包含5×3完整安全地格的落点。排除全部现存场景特征、出入口、主线标记、出生点和水/障碍地格。无合格地格则**不生成纹样**，绝不偷偷清理障碍、修改道路或创造虚假可达节点。
- `scripts/first_act_world.gd` 在正式地图构建和 `refresh_world_legacy` 中安装、恢复上述地表状态；室内不显示。

### 1.3 第55–60章的30个真实场景节点

- `data/levels/act10_city_stations_v1.json`：每章五个有名字的节点，按 `key_npc`、`clue`、`witness`、`crisis`、`resolve` 分配真实地区坐标。
- `scripts/world_act10_city_stations.gd`：只迁移**已有交互节点**，在最终建筑和市民位置生成后选择出生点可达且不与NPC/门槛重合的地格。找不到合适位置就保留原节点并发出警告，不传送角色，也不造虚假NPC。
- `scripts/first_act.gd`：第55–60章的原正式主线入口只允许从当前对应的 `WorldRegistry.chapter_map` 执行，避免玩家在无关区域推进剧情。
- `data/levels/story_map_blueprints_v1.json`：纠正五个城市场景原有的复制/跨章节景点说明，仅调整语义和艺术指令；不碰 `main_route`、`optional_route`、NPC、碰撞、自动旅行和存档。

### 1.4 正典地图对应关系及仍存在的制作差距

| 章节 | 当前**运行时**地图（保持原`quests.json`） | 本章真正剧情地点 | 仍需下一批补齐 |
| --- | --- | --- | --- |
| 55 | `map_city_01` 旧会馆 | 西区第一间修缮屋 | 西区施工区具体建筑/室内 |
| 56 | `map_city_02` 议事厅 | 旧会馆新公会 | 公会公开登记的专属场景 |
| 57 | `map_city_03` 居民街 | 居民街群灯节 | 活动人流、节庆可互动舞台 |
| 58 | `map_city_04` 中枢 | 城郊封存档案车 | 真实车辆、护送路线及追兵 |
| 59 | `map_city_05` 西区工地 | 自由议事厅 | 可抵达的正式议事分区 |
| 60 | `map_city_01` 旧会馆 | 星灯中枢 | 分布式线路真实节点与守卫攻防 |

**重要**：此次为现有运行世界改善城市美术与实地操作入口，未擅自重排跨图旅行。第55/56/58/59/60章当前运行地图与文学正典的独立场景仍有差距，绝不能把地图标记移动、地表装饰或建筑立面宣称为那些独立场景已制作完毕。下一阶段必须在正式地形设计中解决章地图对应关系，并按玩家实际道路行进验收，而非用章切换自动传送掩盖不匹配。

## 2. 质量门禁与停点判断

- **已完成**：本批六份美术源、两份城市地面主题、五图差异化场景语义、六章30个正式交互位置绑定逻辑与原始世界接线。
- **未测试**：资源导入、GDScript语法、地格实际落点、场景截图、真实NPC路径、各建筑进退、剧情节点切换、存档/读档与碰撞。
- **未完成**：所有42图正式画面、55–60章真正地点的地理一致性、城市动态演出和可进入新场景，以及完整发行验收。
- **合适的本批停点**：现有城市视觉和交互配置已经构成一组边界清楚的提交，可以**停止继续堆放临时装饰**；下一批应解决章地图映射、真实实体空间与素材替换，或在获准后先进行同SHA Godot导入/实际玩家路径验证。此停点不是商业级全游戏完成。

一切状态按 `DESIGN → WIRED → GODOT_VERIFIED → PLAYER_ACCEPTED → RELEASE_ACCEPTED` 分层；本批最高为 **WIRED（未引擎验证）**。
