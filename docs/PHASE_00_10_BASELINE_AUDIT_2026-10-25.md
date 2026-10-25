# 星灯纪行｜第0—10阶段工程基线审计（2026-10-25）

> 结论按已在 main 上存在的真实路径、Godot 4.7.2 Actions 运行结果和源码能力判定。**文件存在 ≠ 已接入运行时；静态 PASS ≠ 新档可玩、商业美术或真机验收。**

## 基线与并行工作约束

- 主要开发分支：`main`，无需建立新分支；现有 `content/full-story-v1` 和 `feature/content-foundation-v0-2` 仅作为历史差分来源。
- 唯一正典章节源：`story/campaign/prologue.json`、`story/campaign/act_01.json` 至 `act_12.json`。
- 中文正式阅读稿由 `story/SCREENPLAY_CURRENT_INDEX.md` 选择；候选剧情文件的 `text_only_not_runtime_bound` 标记必须保留。
- 内容总目录：`data/content/manifest.json`。72章剧情已经在 `main`；以前写为“必须先合并独立剧情分支”的目录说明已修正。
- 每次提交以最新 main 为父提交，避免因并行写入覆盖新内容，不使用强推。

## 逐阶段核对

| 阶段 | 仓库已存在的证据 | 验收判定 | 尚需完成的直接动作 |
| --- | --- | --- | --- |
| 0 全工程基线 | `story/campaign/act_*.json`、`story/SCREENPLAY_CURRENT_INDEX.md`、`data/content/manifest.json`、`.github/workflows/godot-core-validation.yml` | **自动化基线已通过**：Actions 40166855994、40166970363 均为 Success | 保留跨系统ID检查，继续真机与手动验收；不得将 CI 绿灯解读为产品成品 |
| 1 战斗成品化 | `scripts/first_act_battle.gd`、`battle_formation.gd`、`combat_rules.gd`、`encounter_registry.gd` | **首批运行时已实现并通过**：7种限时异常状态、按速度排列队员行动、目标选择修复、独立回归；旧Boss机制保留 | 继续实现敌我混合速度序列、敌人异常状态和免疫、AI策略、职业技能与大量战斗平衡 |
| 2 第一幕地图 | `data/levels/act01_layouts.json` 的第1—6章配置、`scripts/first_act_world.gd` 的44×28图块地图 | **部分实现**：六套章节布局数据，可移动和触发交互，但复用图块及统一生成世界 | 逐章独立场景/地牢内部、路线阻断与捷径、机关、场景转场、地图制作验收 |
| 3 武器职业经济 | `story/data/jobs.json`、`data/content/weapons.json`、`armor.json`、`skills.json`、`scripts/rpg_core.gd` | **部分实现**：职业/装备/技能目录，商店锻造与武器特性代码 | 20职业实战成长与每种武器/防具特性有效性测试、价格掉率/锻造配方平衡 |
| 4 任务事件 | `story/data/side_quests.json`、`regional_quests_v2.json`、`scripts/optional_director.gd` | **部分实现**：120条支线文本及部分可选事件有运行入口 | 第1—18章每项可选事件的触发/存档/重放测试；120条支线统一事件规范；stage07调查及地区变化接入 |
| 5 家屋生活 | `scripts/housing_service.gd`、`housing_room.gd`、`data/content/housing*.json` | **部分实现**：格子房间可行走、家具/仓库/休息等操作 | 从UI网格场景进入真正室内世界场景；碰撞、家具交互、NPC造访、烹饪/升级/存档复原 |
| 6 第一幕产品验收 | `tools/smoke_first_act.gd`、`smoke_first_act_flow.gd` 和 Actions | **自动化通过，产品未验收**：六章流程及72章控制器测试全绿 | 六章完整新档实玩、所有Boss胜负、音效/美术/触摸与存档压力测试 |
| 7 第7—48章 | `story/campaign/act_02.json` 至 `act_08.json`，多批可选文字与规划 | **文本底稿充足，玩法未完成** | 按每章正式地图、事件、NPC、Boss、过场与回归逐批实装 |
| 8 第49—72章 | `story/campaign/act_09.json` 至 `act_12.json`，`story/data/endings.json`，`scripts/ending_director.gd` | **结局条件与部分运行逻辑存在，产品未验收** | 三结局动画、奖励、后日谈、回看、旧档迁移和章节49—72场景 |
| 9 美术声音UI | `assets/art` 与 B01、旧HD-2D批次；`tools/qa_hd2d_refinement.py` | **资源自动化检查已通过，商业审美未验收**：海岸地面瓦片及9种怪物待机四帧更新 | 资产规范/实际成品复核，场景角色怪物动效、SFX/BGM/语音、统一UI和性能 |
| 10 iPhone QA发布 | `codemagic.yaml`、`export_presets.cfg` | **未通过**：配置存在不能证明已签名/真机通过 | 合法签名和导出、iPhone操控/性能、反复读档、全程测试、崩溃恢复 |

## 历史阻塞与尚存风险（以末尾更新为准）

1. 早期成功的 Godot Core Validation 之后，新增可选事件曾使第一幕新档流程在第1章停住；必须继续看 `smoke_first_act_flow.gd` 的阶段级结果。
2. 随后的 `main` 上曾出现 `Could not preload resource script res://scripts/first_act_battle.gd`，使第一幕运行验收和后续测试被跳过。已对新增武器特性局部变量作兼容性修订（提交 `e0930a91`）；**必须以最新 Actions 结果再判定是否修好，不提前写通过**。
3. 在较早的完整 Actions 运行中，`qa_hd2d_refinement.py` 因 `assets/art/tilesets/coast_ground.png` 颜色层次过少而失败；不能通过降低视觉验收门槛假装资源达到商业品质。
4. `story/data/stage07_*.json` 和第8—13批的大量可选文本多为未绑定场景候选；不能将其计入实际地图支线完成量。
5. `scripts/first_act_world.gd` 仍以单一世界脚本和图块集合生成地区，第1—6章虽有独立布局数据，但不能当成逐章精制地牢。
6. `scripts/housing_room.gd` 使用 UI `GridContainer` 进行房屋操作；“自由行走”只是格子内位置交互，不等于独立室内探索场景。
7. `scripts/combat_rules.gd` 已支持护盾、攻击强化、蓄力与元素乘数，但完整负面异常状态和按速度混合敌我行动序列未见闭环。

## 建议的交付顺序

- **P0-A** 完整恢复 Godot Core Validation（第一幕语法/流程、72章控制器、房屋与战斗、最终资产审查），保留失败日志。
- **P0-B** 清理正典/数据入口过时描述，统一资源ID、唯一剧情版本、存档迁移、脚本事件责任。
- **P1-C** 完善多敌人战斗、目标选定、状态效果、速度顺序、失败恢复并加独立回归。
- **P1-D** 第一幕六章正式地图与地牢独立场景，连接剧情、任务和Boss。
- **P1-E** 20职业/81武器/54防具实战平衡与玩家可操作经济循环。
- **P1-F** 可选事件、120支线与非阻塞任务引擎的状态/存档测试。
- **P1-G** 家屋真实室内场景、家具/仓库/烹饪/NPC互动。
- **GATE-6** 第一幕产品级新档通关且 iPhone 设备接受后，再批量制作后续章节及音频美术。

不得以“设计表条数”“自动生成图片数量”“单脚本冒烟测试通过”替代最终交付判定。

## 2026-10-25 追记｜P0 基线修复与 P1 第一批开发

- **当前验证事实：** [Actions 40166855994](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40166855994) 与 [Actions 40166970363](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40166970363) 都为 **Success**。前者确认 P0 现有测试全部通过；后者额外覆盖 P1 七类异常状态、队员速度行动顺序及手动施法目标选择。
- **已修复的实际 P0 根因：** `combat_rules.gd` 中武器特性规则的参数命名导致预加载解析失败，曾使 Godot 脚本实例化失败并让测试长期卡在 `.new()`。已改名，并加入 `tools/check_combat_load.gd` 主动阻断无法实例化的脚本，CI 单项测试有超时保护。
- **P0 美术检查已过：** `assets/art/tilesets/coast_ground.png` 更新为 256×256 像素、8×8 32px 地块的新明暗图集，同步其 SVG 母稿；海岸9种怪物的 4 帧待机图不再静态重复，保留首帧和透明背景。静态美术验收通过不代表终稿美术已制作完成。
- **P1 已实际接入：** `scripts/combat_rules.gd` 实现中毒、灼烧、眩晕、睡眠、冻结、沉默、迟缓的时间、治疗与 DOT；`scripts/first_act_battle.gd` 在真实回合生效、队友按速度行动、限制沉默技能、显示异常提示，修复多敌人技能选目标反复弹窗。`tools/smoke_combat_turns.gd` 有单独回归。
- **仍缺 P1 成品验收：** 目前是队友速度排序＋敌人回合，尚不是敌我混合速度队列；敌方主动施加更多异常的平衡、异常免疫、复活与职业联动、Boss策略和战斗操作审美仍待建设。P1 不能整体标为已完成。
- **下一交付入口：** P1 补齐敌我行动顺序/免疫/状态应用/战斗平衡后，执行第2阶段六章独立地形与地下城；每张地图以玩家与全部任务标记的可达性和真机性能验收，不因 `act01_layouts.json` 已有6条配置就计为6张已完成地图。

## 2026-10-25 追记｜P1 第二批：敌我混合速度队列

- **最新实际结果：** [Godot 4.7.2 完整 Core Validation #40167796235](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40167796235) 为 **Success**（27个工作流步骤成功），包括新加的 P1 测试、六章通关回归、72章控制器、地图/UI、住房、存档和美术QA。
- **已运行代码：** `scripts/combat_rules.gd` 新增 `turn_timeline`，按队友和怪物共同速度形成稳定单队列；支持敌方异常状态、DOT、Boss控制免疫及抗性；`scripts/encounter_registry.gd` 绑定怪物原目录的速度、AI类型和Boss抗性；`scripts/first_act_battle.gd` 的 `_start_actor` 处理敌我穿插行动、跳过击败目标并遵守每回合一次行动，沿用第5章解锁而非击杀的剧情胜利机制。
- **新增真实回归：** `tools/smoke_combat_turns.gd` 覆盖高速敌人先手、同速队友优先、队友下一行动、Boss免疫、毒伤回合、冻结失去行动和指定敌方目标的技能释放。
- **仍不属于商业战斗最终验收：** 敌方AI现为规则型策略，不是每个Boss单独制作的数十回合技能脚本；更多职业异常/复活技能、职业与装备抗性百分比、战斗演出、长线掉率和全难度数据平衡仍待深化。
- **顺序上的下一交付项：** 第2阶段把首幕第1—6章地形从共享程序模板升级为互不重复的可玩拓扑、章节专属地图数据和真正的地下城路障/解谜；保留小地图、大地图和原章节全部实体目标，新增可达性/唯一性回归，不能以6个配置JSON等同6个完整商业地图。
