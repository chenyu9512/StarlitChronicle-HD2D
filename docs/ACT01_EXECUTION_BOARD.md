# 第一幕12方向执行台账｜Batch 01｜2026-10-28

> 真实执行目标是6章正常可玩；这份记录不代表全部12个方向已完成。只在`Main2美术优化版`开发，绝不修改`main`。

## 当前基线和已经提交的代码
- 记录整理归档：`d506d2f9074104654f5c1fa98e277f65c7f6133c`。
- 本次Batch 01修复提交：`b93250a40288545d2a24cdc21d0086da6ca4d62e`。
- 第5章真实海岸潮池`saltwind_shoal_tidal_step`已在`data/levels/v4/coastal_scenery.json`定义，修复`tools/capture_act01_visual_evidence.gd`使用不存在的旧ID问题；改为摄像机取景、不传送玩家。
- `tools/smoke_c_main2_art_runtime.gd`加入第5章真实地标存在、材质语义、可见性断言。
- `scripts/first_act_state.gd`对无穷/非数字的时间与道具、负角色HP等不可能存档状态拒绝加载；`tools/smoke_save_integrity.gd`覆盖故障注入。
- 工作流的真实结论以 Actions 对应的完整提交SHA为准，当前为**已提交代码，验收运行中／待核验**。

## 本轮启动的全量门禁
| 方向 | 工作流 | 主要验证 | 签收 |
|---|---|---|---|
| 01 工程 | godot-core-validation | 静态目录、Godot冷导入、主控与状态接线 | 待同SHA CI |
| 01 工程 / 12 验收 | godot-full-smoke-suite | 所有smoke分片，保留失败 | 待同SHA CI |
| 01/06 | batch0-seven-qa-gates | 构建/奖励/回滚/旧档/战斗/任务/资产 | 待同SHA CI |
| 02 地图 | main2-map-regression | 路线、路标、布局、实机画面 | 待同SHA CI |
| 02/03 世界与室内 | m01-world-geometry-qa | 40图、68门、路线与室内恢复 | 待同SHA CI |
| 06 存档 | m01-services-qa | 交易防重复、失败回滚、城镇服务 | 待同SHA CI |
| 07/12 美术截图 | c-main2-art-runtime-acceptance | 6章实机地标与3室内截图 | 待同SHA CI |
| 11 Runtime | main2-to-runtime | 精简运行快照、Godot加载与实际smoke | 待同SHA CI |

## 未达成的商业签收，不能因绿色工作流改为完成
- 第一幕六章正常新档连贯人工通关、Boss数值与难度体验。
- 每张地图由美术总监逐张人工签收，尤其黑帆酒馆、浅滩、村庄。
- Windows目标机型性能、输入手感、音效、资源授权和发行验收。

## 执行与更新规则
每条任务写编号、改动SHA、涉及文件、测试结果、玩家证据、剩余问题。只有运行完成且同SHA成功的门禁才能标记`GODOT_VERIFIED`；未完成时标记`HOLD`。

## 2026-10-28 第二次实际修复（跨方向02、06、08）
- 修复首轮同SHA测试的真实失败：`smoke_world_object_transactions`因晨露村/白砂港街区名错配被阻断，`smoke_b_npc_navigation_safety`因NPC日程无法解析真实目的地而失败。
- 修正`data/levels/v7/town_ecology.json`六条活动街区，`data/content/npcs.json`五名NPC共25个日程项。
- 仅迁移目标区划名称，不修改章节锁、时间、触发、奖励、人物ID或路径算法；新数据与`town_director_v4.json`真实区划逐项匹配。
- 老资产QA仍有历史资源路径缺失，**必须保持失败**，不能伪造图片或关闭断言。
- 本次修复后全套QA重新运行；不能复用`2874f1c5`上的部分成功作为最新HEAD验收。

## 2026-10-28 第三次实际修复：第三章潮阀实体位置
- 旧V7潮阀与最新V3洞窟地形不符：`b` [89,50]、`c` [69,51]、`seal` [65,49] 位于坍塌区或不可达处。
- 将它们放到已经设计的洞窟连通区域：`b` [50,16] 洞内第二阀室、`c` [54,34] 第三阀室、`seal` [29,37] 可选遗物洞室；保留`a`、`b→a→c`顺序和原奖励、剧情与存档ID。
- 在`tools/smoke_b_act01_physical_reachability.gd`加入四处实际世界物件的碰撞、步行连通和位置一致性门禁；不是模拟开启机关或取消墙体。
- 当前状态：**已提交修复、待同SHA Godot运行验收**。

## 2026-10-28 全量Godot冒烟修复验收｜136/136
- **Godot 4.7.2 full smoke SUCCESS** at code+QA trigger SHA `ea49e69f00d70750d2a6aa60d340a0842739d247`.
- [GitHub Actions run 40623444126](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40623444126): shard 0 **34/34**; shard 1 **34/34**; shard 2 **34/34**; shard 3 **34/34**; total **136/136**, 0 failing.
- Real game geometry fix: `scripts/world_geography.gd` connects canonical dungeon/discovery objects by visible navigable tiles after final authored collision, preserving IDs, order and rewards.
- Runtime cave art fix: `data/assets/c_shared_terrain_v8.json` selects the approved V14 coast-04 water asset; `scripts/c_coherent_terrain_materials.gd` and `scripts/world_tileset_pool.gd` compile it into a real 256px 8x8 tile atlas using V18 water materials instead of stretching the original standalone image.
- Four obsolete graphical acceptance contracts now check live V18 imported sprites, physically rendered/native fallback buildings, actual 12 V4 room stage layouts and genuinely loaded textures. Deleted original signature SVG files are **not** falsely claimed to have been restored.
- Full test success proves scripted acceptance at this SHA, **not** manual six-chapter art/UX signoff; legacy asset-catalog QA is a separate unresolved migration gate. Later game-code changes require a fresh SHA-aligned full run.
