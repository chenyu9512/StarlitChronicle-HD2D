# Main2 第一幕1–4项修复交付及真实验收状态（2026-10-27）

目标分支：Main2美术优化版；保留main。完成的是下面具体工程修复，不是完整商业级六章成品。

## 源码已提交
- scripts/first_act_world.gd：误映射成荷叶的路牌采用含义正确的可读取临时纹理；室内调查按作者配置使用不同家具图标；室外返回点阻挡时选择实际连通铺地。
- scripts/world_geography.gd：同侧多个地图出口错位/重叠时去重并逐项接通道路。
- scripts/first_act_battle.gd：第五章解除星锁，第六章四次共鸣见证后才允许战斗完成；不能以普通攻击跳过正典机制。
- scripts/d_world_interaction/battle_v3_settlement.gd + scripts/first_act.gd：救援和见证的结果、奖品、Boss完成和进度写入同一笔V3事务，重复回调和失败保存不会提前结算。
- scripts/art_assets.gd + scripts/av_asset_registry.gd：过期B03头像路径使用Main2五张独立、实际导入的首幕候选Boss图，恢复战斗与音画运行时可见性，但**候选图不是商业视觉成品**。
- tools/d_control/smoke_main2_act01_route_and_room_transactions.gd + tools/d_control/smoke_live_battle_v3_transaction.gd：新增地图、返回、调查点、V3救援/见证防重与写盘回滚断言。
- tools/smoke_campaign_72.gd：旧测试直接调用 _finish(true) 伪造Boss胜利，现改为实际执行 Special 指令；与正常玩家数值平衡仍是不同证据等级。
- tools/smoke_main2_act01_boss_portrait_recovery.gd：五场首幕Boss战斗/AV同源与独立图片的Godot实测入口。

## 首轮同 SHA b5308b1ff3f8566e501125a9b196be26f897034e 已取得的结果
- 地图回归成功：https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40468787948
- 世界几何M0.1成功：https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40468787949
- 七门禁6/7：assets门禁失败（旧源图与B02/B03路径已删除、动画图集缺失、素材总表过期、源包含macOS元数据）：https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40468787952
- 全库Godot冒烟108/120成功；12项失败中11项为旧B03/原海岸资源、音画与专属室内素材缺口，1项为旧72章脚本使用假胜利，被现在的剧情保护正确拦截。https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40468787963
- Core失败在 tools/smoke_campaign_72.gd 的旧Boss假胜利；现已更新脚本，需要新SHA复测：https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40468787947

## 仍然开放的商业级验收
1. 商业级正式室内（收容所、黑帆酒馆）、鲸骨浅滩独立场景、大型灯塔美术与光束；全六章正式配音、音效与角色身份统一。
2. 原B03多状态Boss、海岸9怪物完整动作图集；新五Boss图仍为候选静态图，没有证明身份或逐帧商业品质。
3. 美术源包增量分配、macOS非运行元数据清理、Windows检出/完整导出及旧路径引用消除。
4. 第1–6章无需开发者开无敌/瞬移、完整连续人工实玩、音画/帧率、旧档中断与发行授权验收。任何旧CI绿色不代表本轮新SHA全部完成。

**本文件是实际源码与测试回执交接记录；未完成部分不得标记商业通过。**

## 增量：港口室内实际接入及 Runtime 完整性

- 第二章收容所及第四章酒馆从 V4 空美术配置升级：每间11个实际加载的V14 PNG家具、4处医药/名册/账簿图标、3组室内灯光和6段独立实体隔断。
- 保留8条真实可交互调查线索、已有门口、NPC服务、出口与存档ID；相应72×48网格连通性均通过静态检查。
- 完整运行时的脚本为 scripts/world_interior_art.gd 与 scripts/first_act_world.gd；旧图标节点仍能交互但不会压在新家具画面上。
- 清除20个Finder/WebDAV压缩包元数据文件，没有删除任何原始图片。新验证器仅豁免历史归档中的这些垃圾项，所有真正的源图和运行图仍需存在并核对 SHA。
- Godot通过：Main2 Art Runtime https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40474503772
- Runtime精简构建通过：https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40474533911
- 之后又将这两间室内和灯塔状态测试加入Runtime发布前流程，具体新批次需以该SHA的Actions为准。
- 尚未商业验收：B03多帧Boss动作、9怪物完整动作、区域专属家具美术/水面氛围、旧静态归档源索引3127处未分配候选问题、六章正常难度完整人工实玩。

## 增量：九种海岸怪物语义与五场Boss运行状态

- 改正 `scripts/encounter_registry.gd` 的 mon_coast_03/05/06/07 正典名称与旧战斗别名错位：砂灯蜥、白礁鸟、空贝寄居、盐纹狼重新绑定各自的正式美术ID。其余5种保持正确。
- `scripts/c_b03_fog_tide_body_motion.gd` 增加真实Boss肖像Shader后备：第2–6章五个不同真实纹理都能蓄力、攻击、受击、进入二阶段和退场；保留低动态效果及身份原图。不虚构已删除的B03逐帧图集。
- `scripts/battle_enemies.gd` 增加9种海岸怪物各自的实际图片轻量动态效果，并处理战斗中切换低动态选项后残留的旋转/位移。这些是Shader/Transform表现，不视为正式多帧动作。
- 真实 Godot 验证：https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40483467445 SUCCESS；五Boss动作测试和九怪物身份/攻击/受击/死亡/无动态回归均通过。
- 精简 Runtime 构建已新增 `smoke_main2_act01_live_boss_motion.gd` 与 `smoke_main2_act01_coast_monster_identity.gd`，正式发布必须在不复制原始素材包的快照中再次确认。
- **尚未达商业级：** 源作者绘制的5场Boss和9种海岸怪物多状态帧动画、分镜与粒子表现仍缺。旧 `.svg` 动作图集不可当作已接入。正常难度玩家完整通关及发行级整体视觉尚无签收。

## 增量：第3–6章主线目的地与必经道路修复

- data/content/quests.json 第3/4/5/6章真实主线地图由旧值更正为：map_coast_04（洞窟）、map_coast_02（酒馆）、map_coast_03（浅滩）、map_coast_05（灯塔）。第1章与第2章保持原地图。
- scripts/world_registry.gd 从已审定 data/levels/act01_scene_locations_v1.json 的 route_map_ids 设定非传送的最低道路解锁章数；第3章必须由白砂港经盐风古道进入海蚀洞，不能凭故事地图目标直接跨区域传送。
- 新增 tools/smoke_main2_act01_canonical_chapter_routes.gd：实际 Godot 检查6张主线地图目标、五段沿路的相邻旅行、解锁前隔离、章节变化保留位置。
- 新增 tools/validate_act01_canonical_routes.py：CI 前置静态闸，任务/地点/相邻出口有偏差就拒绝精简 Runtime 发布；没有删除或改写旧存档。
- 真实 Godot/精简 Runtime 回归已通过：https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40484843220 ，日志包含六章全剧情、五Boss、主线路由测试 PASS 与新运行快照提交。
- 新静态验证器的后续批次以对应SHA的 Runtime Job 为准；不能把提交标记等同于 Godot 结果。

### Phase19 支线门禁同步修复

- 旧 `tools/validate_phase19_world_anchors.py` 仅根据主线最终目的地确定区域首次开放时间，错误阻止第3章盐风古道的 `rq_002` 任务。
- 修复后以 `act01_scene_locations_v1.json` 中原有真实相邻路线的最低章数审查120条支线任务。所有地图与建筑入口约束、任务章节的验证仍然有效。
- 失败证据：https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40484869949
- 修复后前置 Core 的“Validate maps, story and item catalog”步骤已显示 SUCCESS：https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40485744535
- 独立精简 Runtime 静态路线校验与 Godot 六章烟测均通过：https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40485315404 。
- 完整 Core 中的后续大量场景回归需以对应 Actions 完结结论为准；此处不声明尚在进行的全量运行通过。
