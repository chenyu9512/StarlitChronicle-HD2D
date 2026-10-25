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
| 0 全工程基线 | `story/campaign/act_*.json`、`story/SCREENPLAY_CURRENT_INDEX.md`、`data/content/manifest.json`、`.github/workflows/godot-core-validation.yml` | **未通过**：静态多数校验可过，近期运行回归曾持续失败 | 恢复每项 CI 绿色；统一历史文档的现行/过期标记，建立资源ID跨系统检查 |
| 1 战斗成品化 | `scripts/first_act_battle.gd`、`battle_formation.gd`、`combat_rules.gd`、`encounter_registry.gd` | **部分实现**：多敌人、敌方目标、护盾/强化、Boss阶段和失败回营有代码 | 完整异常状态（中毒/睡眠/麻痹等）、按速度行动序列、敌方AI与状态免疫、目标非法时可恢复、战斗交互与数值回归 |
| 2 第一幕地图 | `data/levels/act01_layouts.json` 的第1—6章配置、`scripts/first_act_world.gd` 的44×28图块地图 | **部分实现**：六套章节布局数据，可移动和触发交互，但复用图块及统一生成世界 | 逐章独立场景/地牢内部、路线阻断与捷径、机关、场景转场、地图制作验收 |
| 3 武器职业经济 | `story/data/jobs.json`、`data/content/weapons.json`、`armor.json`、`skills.json`、`scripts/rpg_core.gd` | **部分实现**：职业/装备/技能目录，商店锻造与武器特性代码 | 20职业实战成长与每种武器/防具特性有效性测试、价格掉率/锻造配方平衡 |
| 4 任务事件 | `story/data/side_quests.json`、`regional_quests_v2.json`、`scripts/optional_director.gd` | **部分实现**：120条支线文本及部分可选事件有运行入口 | 第1—18章每项可选事件的触发/存档/重放测试；120条支线统一事件规范；stage07调查及地区变化接入 |
| 5 家屋生活 | `scripts/housing_service.gd`、`housing_room.gd`、`data/content/housing*.json` | **部分实现**：格子房间可行走、家具/仓库/休息等操作 | 从UI网格场景进入真正室内世界场景；碰撞、家具交互、NPC造访、烹饪/升级/存档复原 |
| 6 第一幕产品验收 | `tools/smoke_first_act.gd`、`smoke_first_act_flow.gd` 和 Actions | **未通过**：自动化不能代替真机六章通关 | 六章完整新档实玩、所有Boss胜负、音效/美术/触摸与存档压力测试 |
| 7 第7—48章 | `story/campaign/act_02.json` 至 `act_08.json`，多批可选文字与规划 | **文本底稿充足，玩法未完成** | 按每章正式地图、事件、NPC、Boss、过场与回归逐批实装 |
| 8 第49—72章 | `story/campaign/act_09.json` 至 `act_12.json`，`story/data/endings.json`，`scripts/ending_director.gd` | **结局条件与部分运行逻辑存在，产品未验收** | 三结局动画、奖励、后日谈、回看、旧档迁移和章节49—72场景 |
| 9 美术声音UI | `assets/art` 与 B01、旧HD-2D批次；`tools/qa_hd2d_refinement.py` | **未通过**：程序生成资源不能当商业定稿；曾有平涂资源检查失败 | 资产规范/实际成品复核，场景角色怪物动效、SFX/BGM/语音、统一UI和性能 |
| 10 iPhone QA发布 | `codemagic.yaml`、`export_presets.cfg` | **未通过**：配置存在不能证明已签名/真机通过 | 合法签名和导出、iPhone操控/性能、反复读档、全程测试、崩溃恢复 |

## 当前已核实的阻塞问题

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
