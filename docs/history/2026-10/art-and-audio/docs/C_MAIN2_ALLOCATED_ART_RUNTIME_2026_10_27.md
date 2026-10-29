# 《星灯纪行》Main2 美术实际运行接入 · 2026-10-27

**工作分支：** `Main2美术优化版`。本批不修改 `main`、不改剧情/碰撞/战斗数值/存档，不将错误语义图集强行贴到游戏中。

## 真实游戏接入（不是仅登记）

- `scripts/first_act_actor.gd` + `scripts/c_third_party_walk.gd`：现有四名探索队员的历史 `walk_4dir_3frames.png` 槽经迁移解析到第三方人物族，再读取 **4个方向的真实48px连续走/跑帧** 与待机帧。不会把 `attack_01.png` 当成行走动画，也不会把384×48帧条错误地拆成3×4。角色身份仍有复用问题，尚未确认原创角色最终形象。
- `scripts/prologue_actor_blocking.gd`：序章附属演员通过同一美术替换器读取真实后期上传素材；不再把已删除的历史路径当成文件丢失。
- `scripts/battle_actors.gd`：战斗中队友对话/身体图按 `CArtOverrides` 实际映射读取，避免 `ResourceLoader.exists(legacy_path)` 因旧图被删除导致透明/空白角色。
- `scripts/first_act_world.gd` + `scripts/c_allocated_decor_runtime.gd`：每次在正式世界地图生成时新增无碰撞的指定美术装饰层，从 `data/assets/c_art_allocated_decor_runtime_v1.json` 实际创建Sprite2D。当前经过文件形态/用途筛选的8项正式接线：`map_oaths_01` 6项，`map_city_01` 1项，`map_sanctum_01` 1项。实际位置由可行走地表、安全距离和门口避让决定，不改动入口、存档或事件。
- 第一幕 **125个不同运行槽位** 通过 `CArtOverrides.texture` 可取得 `Texture2D`；**六章地图**由实际 `FirstActWorld.build` 构造。注意这仅证明物理加载，不证明125项都是画面语义正确的独立正式美术。
- 既有游戏中的 **288个道具/武器/防具/技能内容ID图标** 由 `CArtItemIcons` 注册；**6项后期上传的道具/DLC换图**继续可解析，保留用户本地替换优先级。

## Godot 4.7.2 真实验收证据

GitHub Actions: https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40461090758

在 **Main2** 干净检出上，官方 Godot 4.7.2 headless editor 导入与 GDScript 解析成功；Python静态迁移审计成功；以下场景/脚本实际加载运行且全部退出码为0：

1. `smoke_c_character_motion.gd` — 四方向、连续动画、NPC表情/行为基线
2. `smoke_battle_actors.gd` — 战斗队友肖像真实加载、战斗/技能动作与游戏战斗实例
3. `smoke_c_uploaded_later_pack.gd` — 已有6项换图真正加载
4. `smoke_c_act01_art_production_v10.gd` — 第一幕地图/灯塔节点和Boss视觉槽位按迁移解析
5. `smoke_world_tileset_pool.gd` — 图集32px、缓存和实际地图重建
6. `smoke_c_main2_art_runtime.gd` — 125种第一幕槽位、六章真实地图、真实人物四方向贴图、8个指定环境道具

这证明**本批接线通过Godot自动运行验收**，不代表已经逐帧截图、人工语义审美验收，也不代表全部游戏美术商业签收。

## 尚未真实接入，必须保留缺口

`data/assets/c_art_allocation_v6.json` 1888条分配记录的原始状态（此文件为工作台账，本批不把未适配候选擅自改名为完成）：

| 原始分类 | 条数 | 本批处理原则 |
|---|---:|---|
| 制作原档/后期新增图 `adaptation_needed` | 705 | 很多原档处于 `.gdignore`，必须切图/转换、重定身份和导出后才能用于发布 |
| 新增图 `reference_only` | 41 | 仅参考，禁止作为运行成品 |
| 第三方 `adaptation_needed` | 324 | 需要角色、Boss、地形等真实状态机/图集适配 |
| 第三方 `layout_check_needed` | 228 | 多为UI候选，需具体界面元素/九宫格、尺寸和视觉核对 |
| 第三方 `runtime_menu_icon` | 28 | 图标库复用到既有288个内容ID，不意味着288个独立PNG |
| 第三方 `icon_library_spare` | 80 | 图标备用，未在玩家路径上使用 |
| 第三方 `runtime_bound_pending_visual_qa` | 7 | 海岸装饰已有运行代码，未逐图视觉签收 |
| `core_reserve` `runtime_path_usage_unverified` | 472 | 需区别动态使用和冗余引用，不能删除 |
| **合计** | **1888** | `allocated` 只是记录分配用途，不等于 `visible` |

另外，主线第2章收容所、第4章酒馆、第5章浅滩仍需要独立美术场景；第6章灯塔的大型地标不能用32px纸灯笼代替。旧图在第三方迁移里指向角色/道具/地形语义错误的情况仍需整理。**不能将第一幕六章称作商业级完成。**

## 持续准入规则

- 新资源必须证实实际PNG帧/图集几何以及`CArtOverrides`可加载，再绑定到真实World/Battle/UI入口，且能在对应地图/状态实际创建节点。
- 通过引擎自动化后，进一步取得画面截图检查语义、清晰度、遮挡、地图入口和动画；没看到的图片不标记成成品。
- 已分配但不能直接用的，继续保留`adaptation_needed`和缺口。禁止把所有1,888条分配一键转为`runtime`，更不能为此删除仍有合法引用的原档。
