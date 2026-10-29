# 《星灯纪行》全游戏架构总契约｜2026-10-29

> 工作分支：`Main2美术优化版`；`main` 不修改。本次为**继续开发、暂不测试**批次，全部改动均记为“代码已写入 / 未进行 Godot 实机验收”。保留原有12方向总控及既有V3存档。

## 1. 唯一权威源与依赖方向

```text
story/campaign/act_01.json..act_12.json (72章主线)
story/data/{side_quests,companion_quests,regional_quests_v2,bosses}.json (120任务、66Boss)
story/runtime/chapter_play_patterns.json (差异化玩法设计合同，26重点章节)
story/runtime/mechanics_registry.json (正式可加载机关模块与pending标记)
        ↓ 只读生产索引
scripts/systems/CampaignProductionIndex.gd
        ↓
scripts/story_catalog.gd (production_contract / production_quest / production_summary)
        ↓
scripts/first_act.gd (现有正式全72章入口)
        ├─ StoryBranchRuntime / OptionalDirector / StarlightJournal
        ├─ MechanicsRegistry / EndgameExpansionBridge / BattleV3Settlement
        ├─ RPGCore / PartyCanonGuard
        └─ first_act_world / world_ambience (HD-2D时代层)
        ↓
first_act_v3.json (唯一权威存档；不能新增平行奖励账本)
```

生产索引只产生可查询的合同，不伪造完成度，不代替真实游戏状态，不对V3存档写入任何奖励。主线四阶段仍以原JSON为准，第72章保留独立 `ch072.ending`。

## 2. 72章差异化玩法量产规则

- 尚未分配独立玩法的章节：`play_pattern.status = design_only`，必须保留“待制作”标签。
- 已有机制注册表 `active`：仅代表控制器路径在工程层面可被加载，不代表画面、节奏、战斗和商业验收通过。
- 最低可玩合同：玩家可亲自触发/观察线索 → 控制机关或救援 → 正典选择 → 完成非伪造战斗/非暴力目标 → 保存世界后果。
- 独立章节制作原则：首先复用输入、存档、奖励和镜头系统；每章可替换**玩家决策负担**、**调查工具**、**战斗行为目标**，不得只替换台词和背景。
- 设计重点：3、5、6、7、15、17、19–23、27、29、35、36、40、44、46、47、49、54、58、60、66、71、72章。所有合同在 `chapter_play_patterns.json` 可查询，其他章节仍需逐章评审。
- 第一幕黄金样板优先级继续高于全72章同时铺地图；不以“存在72章JSON”冒充玩家通过。

## 3. 三界、灾变、十二年后可切换2D视觉层

`CampaignProductionIndex.epoch_for()` 从章节和既有 `ch021.campfire_returned` 标志导出视觉时代：

| 范围 | Epoch | 视觉用途 |
|---|---|---|
| 1–18, 22–30 | present | 现世，常规昼夜/暖色区域光 |
| 19–21回忆中 | historical | 低饱和回忆；21章回营火后恢复present |
| 31–36 | mirror | 映世永恒午后，柔和高曝光 |
| 37–42 | chronicle_corridor | 岁影回廊银灰影调 |
| 43–48 | black_star | 黑星灾变压暗环境 |
| 49–72 | twelve_years_later | 战后时代色彩偏移、等待重建资产 |
 
已通过 `StoryCatalog → first_act → first_act_world → world_ambience` 将当前epoch交给地图的实时2D环境叠色，**暂不修改角色碰撞或路线数据**。这只是基础视觉层；原有时代专属建筑、美术图层、灾后地表和动态投影仍需美术接入，不能把叠色当成完整HD-2D美术验收。

## 4. 120任务 + 27文献 + 768后续事件

- 120独立任务以唯一ID去重：24生活委托、48伙伴任务、36地区支线、12航页收集。跨时代回访是阶段事件，不另计任务。
- `SideQuestsAndLoreLoader` 继续为27份文献及四阶羁绊提供数据接口；`StoryBranchRuntime` 保持768条后续/后日谈事件及V3中`branch_story`存档。
- `StoryBranchRuntime` 的八伙伴在场权限使用 `PartyCanonGuard` 正典状态；儿童诺依、匿名乐师、尚未入队的维莎不会因旧存档在场标记被视作正式参战成员。
- 任务完成奖励和航页结算仍只能经原`RPGCore`、任务结算事务和回执执行；扩展事件永远不追加同一任务的经验/金币。

## 5. 不可破坏的跨时空与终局合同

- 第19–21章历史控制权限独立于现世编队，`ch021.crisis` 必须先回现世营火、后显示成人选择。
- 第39章旧车票以 `ch039.noe_mothers_ticket` 及`canonical_item_provenance_v1` 保留唯一来源；54章纪念册仅读取同一对象，不允许根据剧情已完成旗标合成新物品。
- 第49–51章成年诺依视角优先，52–54章逐步协作与交接。
- 结局C仍严格执行 `endings.json` 中的原始旗标与12航页收集条件；非恋爱路线不得被限制。
- 第46–47章三城门撤离由玩家操作和真实战斗回执推动，不允许通过设定进度百分比直达胜利。

## 6. 本轮状态与下一批接入次序

**本轮只进行编写、主入口接线和仓库提交，不触发测试工作流，也不声称同SHA引擎通过。**

后续开发顺序：

1. 原有三界地图的时代差异：把现有视觉epoch对接场景、NPC、建筑和光照资产层；不能新增无出口的假地图。
2. 从26个重点章节生产合同，逐步为其余46章定义非同质化玩家动作；优先第8–12幕。
3. 针对年代表现扩展持续世界变化：亮灯、窗口、路标、重建建筑均须读取存档旗标且可回访。
4. 待用户恢复测试指令后，先进行最新同SHA Godot静态/实机/玩家路径验证，失败分项修复，之后才提高阶段状态。

## 2026-10-29 下一开发批次：72章操作合同与世界后果投影（未测试）

- `story/runtime/chapter_play_patterns.json` 已扩展为72章独立的操作合同：每章3项，共216条生产级玩家操作需求。它们仍标记 `design_only`，并非216个已实装的玩法动作。
- `story/runtime/world_legacy_projection.json` 定义22种长期世界变化，关联19张已有正式地图规划与原始V3正典旗标。
- `scripts/systems/WorldLegacyProjection.gd` 为无碰撞2D层，严格依附地图上**已存在的交互节点坐标**绘制点灯、修复、史料、救援、公共公约等微型视觉回声；缺少锚点时不捏造地点或修改地图通行。
- `scripts/first_act_world.gd` 在地图构建时挂载投影；因室内切换、回到户外而重建时由旗标快照恢复；室内投影自动隐藏。
- `scripts/first_act.gd` 在读档、切图以及剧情事务真正保存成功后刷新投影；存档失败时不显示未经保存的世界后果。
- 仍未完成的部分：世界事件的专属手绘2D瓦片和建筑换装、动态NPC路线、城市重建碰撞及所有章节的玩家实际动作脚本。本批不是美术验收，也不能据此认定全72章可玩。
- **用户约束：暂不测试**。本批未运行Godot、未触发或查询验收工作流，不标记任何同SHA测试通过。

## 本轮正式开发：可恢复的社区变化与第10–12幕玩家操作（未测试）

本批不重新定义世界旗标，不向V3存档追加专用世界后果副本，按实际主线保存状态反映地图变化。

### 1. 世界后果的实体布景和居民行为

- `story/runtime/world_legacy_projection.json` 将22项原有长期变化扩展为具备 `world_prop`、`npc_response`、`npc_activity` 的单一规则源，避免视觉与对白各写一套不一致的旗标。
- `scripts/systems/WorldLegacyProjection.gd` 不再只有悬浮图标；在现有节点周围绘制风格化的灯柱、告示板、修缮屋、工作台、纪念碑和旗帜。所有物件均为**非碰撞、无新增交互的过渡性2D实物布景**，不冒充正式手绘建筑、道路或可进住宅。
- `scripts/world_town_life.gd` 根据当前地图与已提交的主线旗标，向实际居民对白提供所在地后续近况；不改变接触回执、金钱或区域开放条件。
- `scripts/world_npc_visual.gd` 通过 `set_world_legacy_activity` 支持维修、挥手、整理物资、扫除、观察等视觉动作，并保留既有市民身份与真实寻路位置。
- `scripts/first_act_world.gd` 在 `refresh_world_legacy` 中同步NPC活动。恢复存档、地图重建、回到室外、场景效果持久化后会重新计算，不把旧活动状态硬写入存档。

### 2. 第10–12幕后期生活与制度机制

- `story/runtime/chapter_mechanics_steps.json` 新增八章共39项结构化玩家安全决策，分别覆盖第55、56、57、60、61、62、65、70章。每项有正典操作、错误选项和顺序状态。
- `scripts/mechanics/Act10To12CivicMechanics.gd` 复用通用的 `ChapterMechanicsSequence`，拒绝不在支持列表中的章节以及缺失正确选项的操作配置。
- `story/runtime/mechanics_registry.json` 和正式主控只将 **55、56、57、61、62、65、70章，共七章34项操作** 纳入危机选择前的V3保存交互；不直接完成章节、不授予Boss战绩、不绕过玩家结局选择。
- 第60章已有并行建立的 `Act10To12EndgameMechanics.gd` 专属机制，注册表仍为 `pending`；本批只写入五条群灯网安全操作资料，不覆盖其现有状态，也不声称已接入正式流程。
- 第58、59、64、66、71、72章的既有待接入专属控制器同样保留，不得通过新通用面板伪装已实现。

### 3. 技术边界与剩余问题

- **已提交代码 ≠ 编译通过 ≠ 实机可玩**。按用户指令，本轮没有Godot运行、CI执行、画面截图或玩家路径验收。
- 实体布景仍需正式HD-2D绘制，NPC活动目前只是原有NPC上的状态化演出，不含新路径规划；真实撤离与终局章节继续由原各自控制器负责。
- 下阶段应按第10–12幕地区逐项完成可达实体节点、NPC日程、世界重建资产与对应专属机制的原位接线。

## 架构冻结候选：第58–72章正典终局接线（未运行测试）

本章记录**本轮后生效的最新状态**，覆盖上文较早批次中“ch060仍 pending”的历史描述。没有删除旧批次日志，便于追溯。

### 当前工程完成的结构

- `story/runtime/chapter_mechanics_steps.json`：20个重点章节共80项顺序式玩家安全交互，其中本轮增补第58、59、64、66、71、72章17项，第60章沿用此前5项。
- `scripts/mechanics/Act10To12CanonActionAdapter.gd`：第58、59、60、64、66、71、72章正式危机选择之前的交互适配器，校验正选项、顺序和重复选项；不负责发金币、Boss胜利或结局通关。
- `scripts/first_act.gd`：为上述七章加上与第15、17、23、27、29、36、40及第55–70章部分章节相同的V3保存门禁；原剧情、真实战斗和结局仍走现有权威接口。
- `story/runtime/mechanics_registry.json`：24条已登记的重点机制当前均为 `active`、无 `pending`；**仅说明各登记入口已配置，不代表引擎编译通过，更不代表其余48章全部具有专属实装机关。**
- `scripts/mechanics/Act10To12EndgameMechanics.gd`：保留原专属状态模型，不替换为通用选择面板。新增切换存档前的清空接口。
- `scripts/systems/EndgameExpansionBridge.gd`：原 `rpg.endgame_expansion` V3扩展中增加 `finale` 子项，加载时校验、重置、恢复；章节效果写盘后依据已存V3玩家操作和正式正典回执更新后续状态。
- `story/runtime/endgame_expansion_registry.json`：正式登记终局专属后处理模块。

### 不可绕过的完成边界

1. 第58章人工接管：必须有 **三项完整、顺序正确的V3操作回执 + `story.ch058.done`**；不会提前让维莎入队。
2. 第59章轮值守灯章程：必须有三项操作回执、`story.ch059.done`、第58章合法接管记录。
3. 第60章群灯网：必须由玩家完成五项操作，然后仍须走正式第60章 `resolve`，原剧情才会持久化 `world.distributed_network`；交互模块本身不能写入该旗标。
4. 第64章三重时间锁环：必须有三项真实操作回执和 `story.ch064.done`，再逐枚登记锁环；不直接点亮七灯。
5. 第66章七灯：必须经历原正典第66章完成结算，原剧情写入 `world.seven_lanterns`。
6. 第71章赫西安：三个后处理阶段分别依赖 `ch071.started`、`ch071.decision_made`、**`ch071.battle_won` 真实战斗回执**；绝不拿选择记录代替Boss胜利。
7. 第72章结局：正式 `EndingDirector` 读取 `story/data/endings.json` 决定A/B/C实际可用性。结局C同时要求12张航页、分散式灯网、七灯与第71章真实决战，不由扩展状态模型自行授权。

### 现阶段建议的工程停点

在用户明确**暂不测试**的条件下，已经具备一个相对合适的**架构冻结候选**：72章数据管线、120任务目录、时代与世界变化、已登记重点章节控制器及终局后处理桥接均有明确代码入口。继续无止境地新增通用系统，会增加未经Godot验证的集成风险；更合适的下一阶段是**最新同SHA导入、编译、存读档和真实玩家路径验收，然后针对证据修复**。此处的“合适”是指**停止继续扩架构**，不是“全游戏商业级完成”。未测试的所有状态一律保留 `WIRED / UNVERIFIED`。

保留第一幕第1–6章完整玩家路径、美术正式资产、全地图可达性、所有Boss与支线、旧档恢复、三结局等尚待验收项目；不得将“注册表无pending”解释为发行准备完成。
