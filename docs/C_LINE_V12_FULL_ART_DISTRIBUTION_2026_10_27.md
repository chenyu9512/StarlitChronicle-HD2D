# 《星灯纪行》美术素材组全量分配 V12（2026-10-27）

分支：`Main2美术优化版`；`main` 保留、不合并。**本批交付为全量制作分配和可浏览审计，并非全图实机适配完毕。**

## 1. 全量范围与成果

- 已追踪图片：`assets/art/source_packs/` **746** PNG（制作原档、被 `.gdignore` 排除运行导入），`assets/art/external/cc0_named_v1/` **667** PNG（具备作为运行贴图的路径基础）。总计 **1,413 张**。
- 原档和其他内容：**85** 个 ZIP 压缩包以及 **19** 个其它工程/元数据文件（Spine、TMX、TSX、JSON、TXT、HTML）。这些压缩包内的单项内容**尚未解压展开统计**，不能把包内图片说成逐帧审核完成。
- 上述资源划入 **27 个**有技术导入/剧情/场景用途标签的组；总共 **1,517 个独立受控文件**，并以真实文件 SHA、文件大小和源路径登记。
- 文件树与三份分配明细交叉核对：没有未列入的在库文件、没有重复记录、没有失效路径或Git SHA不一致。**这一结论仅是静态登记核对。**

## 2. 分配是否等于游戏已使用？

| 后期命名PNG状态 | 不重复图数 | 实际含义 |
|---|---:|---|
| 已被物品/技能目录显式引用 | 28 | 288条ID共用28张图，Godot效果未验收 |
| 已被海岸装饰配置显式引用 | 7 | 24个装饰摆放记录共用7张图，Godot效果未验收 |
| 仅旧图路径重定向关联 | 50 | 可作为候选路径，但存在语义和动作/图集错配，不代表最终场景使用正确 |
| 已分配新组及预期用途，尚未接入 | 582 | 有场景/区域/界面归属，但无确认有效的运行入口 |
| **合计** | **667** | 正式运行与候选阶段严格分离 |

> 不应把50项旧路径重定向视为商业级通过；另有部分已显式引用图片同时也被旧重定向关联。上表按优先级互斥归类，避免重复计算。

## 3. 27个素材组的数量与具体任务

| 素材组 | PNG | ZIP | 其他 | 用途方向/技术验收条件 |
|---|---:|---:|---:|---|
| `external/bosses/foozle_goblin_beast` | 36 | 0 | 0 | Encounter boss archetype later region, not named act I fog boss. |
| `external/bosses/foozle_skeleton_ancient` | 36 | 0 | 0 | Distinct late ancient-boss animation set, not copied across 66 bosses. |
| `external/bosses/foozle_skeleton_king` | 36 | 0 | 0 | Distinct late skeleton-king boss set, not generic boss stand-in. |
| `external/characters/foozle_necromancer` | 41 | 0 | 0 | Directional necromancer later region archetype, not protagonist Chengzhou. |
| `external/characters/foozle_sorceress` | 40 | 0 | 0 | Directional sorceress later region archetype, not unique NPC identities. |
| `external/characters/foozle_warrior` | 40 | 0 | 0 | Directional warrior guards, do not use as four different protagonists. |
| `external/effects/foozle_effects` | 19 | 0 | 0 | Pickup/rarity/wave vfx sequences, infer animation sequence frame count from actual dimensions. |
| `external/icons/owlish_icons` | 108 | 0 | 0 | Inventory icons: 28 wired; remaining 80 are targeted to status effects, controls, quest/map and service surfaces. |
| `external/monsters/foozle_cultist` | 28 | 0 | 0 | Four-facing cultist elite for oldland/secret areas; validate hit and direction frames. |
| `external/props/pixelkensei_nature` | 10 | 0 | 0 | Nature and shore dressing, only true-size collision-safe cells; avoid cherry tree as coastal pine. |
| `external/props/pixelkensei_props` | 10 | 0 | 0 | Sake barrel/lantern candidates for village/tavern, Japanese themed prop roles reserved to oath region. |
| `external/props/pixelkensei_structures` | 10 | 0 | 0 | Well, bridge, shrine wall segments; never a full home/tower facade. |
| `external/tilesets/foozle_desert` | 6 | 0 | 0 | Dune/shore candidates only after tile semantic and water separation validation. |
| `external/tilesets/foozle_dungeon` | 1 | 0 | 0 | Cave interior candidate, not outdoor water. |
| `external/tilesets/foozle_exterior` | 1 | 0 | 0 | Top-down town exterior baseline after atlas mapping. |
| `external/tilesets/foozle_lava` | 15 | 0 | 0 | Forge/volcanic maps only, not first-act coast. |
| `external/tilesets/kenney_roguelike` | 2 | 0 | 0 | Assess tile dimensions and visual style; separate optional oldland dungeon atlas. |
| `external/ui/kenney_fantasy_ui` | 140 | 0 | 0 | NinePatchRect panels and button focus/disabled states; theme variant pool for title/dialogue/menu. |
| `external/ui/kenney_rpg_ui` | 88 | 0 | 0 | Alternate complete RPG UI skin; avoid mixing two themes in same screen without style review. |
| `source/2D Characters - Cute Adventurers_4_3` | 383 | 0 | 3 | AnimatedSprite2D sprite frames for ambient wildlife and non-canonical NPCs; never replace four protagonists by occupation. |
| `source/2D Isometric Village Asset Pack` | 4 | 0 | 0 | Perspective/color/layout study; no direct 2D orthogonal map binding. |
| `source/Aekashics Librarium - 3 Frame Frontview $Big_Monster Sprites` | 42 | 0 | 0 | 3-frame enemy atlases with correct content identity and battle-scale conversion. |
| `source/Aekashics Librarium - Dragonbones Animated Battlers` | 0 | 72 | 1 | Extract and catalog source archives; convert skeleton/DragonBones with verified exporter, first before runtime. |
| `source/Aekashics Librarium MV Format Animated Battlers` | 47 | 13 | 1 | MV side-view animation sheet slicing; confirm layout and boss phase identity. |
| `source/Chibi-Ragnarok-Inspired_FREE_Pack` | 35 | 0 | 1 | Outfit reference and proportions; canonical characters require separate signed-off identity. |
| `source/import_metadata` | 0 | 0 | 10 | Preserve acquisition and source license notes, never included as gameplay resource. |
| `source/kenney_sketch-town-expansion` | 235 | 0 | 3 | Group directional roof/ground/walls and doors; export validated top-down atlas with collision masks. |

## 4. 第一幕六章用法与缺口

| 章 | 地图 / 地点 | 可以优先适配的库存素材类别 | 无法靠简单分配完成的阻塞 |
|---|---|---|---|
| 1 | 晨露村/旧屋 | 村庄外景、石头/井/木桶/灯具、屋顶/草地原始图块 | 主角真实四方向行走及住宅完整立面、房屋出口和遮挡 |
| 2 | 白砂港收容所 | 码头铺地、桥、水井/货架、UI和物品图标 | 独立收容所内景/家具、门口出入与任务锚点 |
| 3 | 断桅海蚀洞 | 地下城图集、洞穴/水面候选、怪物动作组 | 地形Atlas UV、潮汐怪物与剧情Boss身份、洞内前景 |
| 4 | 黑帆酒馆 | 木桶、灯笼、服务UI、村镇屋顶/家具候选 | 独立酒馆室内和酒保/剧情动作，美术风格统一 |
| 5 | 鲸骨浅滩 | 潮池/沙地/岩石候选、波浪VFX、滨海生物 | 独立浅滩地图与剧情巨影Boss形象 |
| 6 | 潮歌灯塔 | 照明效果、港口外景、灯火小道具 | 高辨识度灯塔主体、塔内分层场景，**不能以纸灯笼代替** |

## 5. 可复用制作规则

1. **原档**：保留原始 ZIP、Spine、TMX/TSX、逐帧序列和授权说明。真正运行图从已验证导出生成，禁止将 `.gdignore` 下的原始文件当作可自动加载的正式游戏资源。
2. **候选**：每个PNG指定角色动作组、地形/建筑图块族、Boss族、道具类或UI表面；与六章不匹配的素材转入其他地区、图鉴备用或参考，并保留原始身份。
3. **运行**：只有完成真实像素尺寸、图集帧序、角色身份、场景入口出口及实机截图验收的资源，才能从候选升至正式运行。多个地区共享同一图集时，仍必须保证地图语义、图块UV及碰撞一致。
4. **复用**：同一场景用统一风格族及正常缩放；Boss原型分配和正式剧情Boss身份必须一一对应；禁止通过单张32px道具冒充房屋、码头吊车、灯塔或四方向人物图集。
5. **清理**：不对源ZIP或仍需导出的图集做删除；已记录的35个显式绑定与616条旧槽映射保留可追溯性，错误旧映射按独立审核换图，而非一键强行替换。

## 6. 文件与实机核查入口

- `data/assets/c_art_usage_source_v12.json`：746份图片原档，含动画剪辑/地区/待适配工序。
- `data/assets/c_art_usage_external_v12.json`：667份后期命名图，含UI/角色/怪物/Boss/环境的具体用途及真实连接状态。
- `data/assets/c_art_nonimage_groups_v12.json`：85份ZIP与19份非图片工程/授权/配置文件。
- `data/assets/c_art_group_contracts_v12.json`：27组统一约束、后续技术交付和六章缺口。
- `assets/art/candidates/manifest.json`、`data/assets/c_art_selection.json`、`data/assets/external_cc0_named_index.json`：已增加V12索引入口，旧V6信息保留用于历史对照。
- `scenes/c_art_distribution_gallery.tscn`：只读开发图库，按组分页预览后期命名PNG并显示分配状态；因Godot未运行，其画面仍待验证。
- `tools/audit_art_usage_v12.py`：对全部1,517个资产进行路径、分组、Git SHA、明确UI/装饰绑定与首幕阶段审计。
- `.github/workflows/c-art-distribution-v12.yml`：对Main2源素材、清单及工具变化进行自动静态核验；需要在GitHub Actions执行记录中确认实际结果。

在完整仓库的Python环境执行：

```bash
python tools/audit_art_usage_v12.py --verify-git-blobs
python tools/audit_art_usage_v12.py --require-commercial
godot --headless --path . --editor --quit
```

第二条在未完成商业视觉签核前**预计失败**，是明确阻止误报的放行门槛；第三条需要本地Godot 4.7.2和实际画面审阅。

## 7. 验收状态

| 环节 | 状态 |
|---|---|
| GitHub真实文件树/路径/SHA/组契约静态交叉核对 | 成功 |
| 3份V12资源清单与V12组契约提交 | 成功 |
| V12历史候选/选型/外部索引接线 | 成功 |
| V12只读分页图库源码/场景提交 | 成功（尚未在Godot执行） |
| Python脚本在本地完整仓库运行 | 未测试 |
| GitHub Actions CI运行结果 | 待核实 |
| PNG视觉质量、Atlas图块/碰撞、UI九宫格、NPC/Boss动作 | 未测试 |
| 六章主线成品与商业画面验收 | 未完成 |

**结论：1413张现存图片及104份源工程/压缩文件全部获得明确库内分配，不再是无归属文件；仍需逐组加工、核对并适量接入场景，才是商业级成品。**
