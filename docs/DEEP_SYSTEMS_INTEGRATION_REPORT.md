# 《星灯纪行》深度工程模块匹配接入记录（Main2）

本记录基于用户提供的 `gemini-code-1793253032321.sh`，仅进行源码比对与正式接线，**未运行 Godot 编译、实机测试或人工验收**。不修改 `main`。

## 1. 已匹配和接入

| 上传代码 | Main2 采用路径 | 正式入口 | 取舍 |
|---|---|---|---|
| `TacticalCombatEngine.gd` | `scripts/combat/TacticalCombatEngine.gd` | `scripts/first_act_battle.gd` | 保留 HP、Unrest、star_locks、安全绳/分诊/双哨/泄压等操作，接入真实回合；旧战斗时间轴、剧情Boss机制和V3结算不被替换 |
| `DeductiveReasoningGraph.gd` | `scripts/systems/DeductiveReasoningGraph.gd` | `scripts/rpg_menu.gd`、`scripts/first_act.gd` | 证据分级：HARDWARE_LOG/PHYSICAL_TRACE/SUBJECT_TESTIMONY/PENDING_HYPOTHESIS；结论必须有真正V3调查来源 |
| `hd2d_three_realms.gdshader` | `shaders/hd2d_three_realms.gdshader` | `scripts/systems/ThreeRealmsOptics.gd` 和 `scripts/first_act.gd` | 修正ColorRect误采自身纹理，改采真实screen_texture；按正典世界epoch切换现世/映世/岁影回廊 |
| `SaveLoadManager.gd` | `scripts/core/SaveLoadManager.gd` | 手动槽位 `_save_slot/_load_slot` | 只委托现有V3槽位/备份、结构完整性与原回滚；**完全移除上传版本的SHA-256签名、硬编码盐和强制V2.1状态覆盖** |

## 2. 未直接纳入的第5个文件

上传脚本还包含 `scripts/ui/MainGameUI.gd`。这是展示用独立工作台，有“上一章/下一章”“构造包含诺依和维莎的演示战斗”“直接生成推理证据”等按钮。**不将其作为72章正式主入口**，因为它能绕开真正的章节、人物时间线和证据来源。相关可玩交互已改接至现有游戏战斗界面、冒险手册和世界交互点。

## 3. 源码问题及修订

- 上传文件的 `enumTriagePriority` 缺少 `enum ` 关键字，原稿不可直接按GDScript解析；新版用有效枚举声明。
- 上传战术引擎声明共鸣消耗但未执行扣费、职业权限，且可以在早期演示中操控未入队诺依/维莎；新版在真实战斗职业名单、剧情时间线和共鸣余额上逐项检查。
- CTB展示沿用正式 `CombatRules` / `BattleTimeline` 的行动序列，不生成第二套可绕过敌方回合的假时间轴。第3、5、6章特殊Boss按旧非暴力正典机制结算；通用技能不能自行标记主线Boss胜利。
- 第8章调拨账册需到世界可达点调查并作出合理批号交叉核对，真实证据才进入V3。第40章必须有两份独立章节机制见证回执，不能从菜单自动生出。
- 原Shader在普通ColorRect上读取 `TEXTURE`，无法表现整场景；正式着色使用 `hint_screen_texture`，仅限视觉效果，不修改地图或战斗判定。三角影为2D光学近似，而非真正物理光追。
- 原 `SaveLoadManager.gd` 引入独立V2.1存档、SHA签名拦截、自动修改角色状态，和已有V3档不兼容；全部不采用。

## 4. 金手指兼容

`scripts/cheat_panel.gd` 的星标五连点和已有口令流程继续保留，也不再因不是编辑器构建而自动隐藏。原恢复、金币、药草、等级、属性、无敌、禁遇敌、五倍经验、移速与调试指令仍走 `scripts/first_act.gd` 的旧回调。无敌、禁遇敌、五倍经验和移速开关额外记录于V3 `rpg.cheat_settings_v1` 并在读档后恢复。新增SaveLoadManager既不检测金手指也不对存档施加SHA签名；**保留基础文件结构校验与失败回滚仅用于防止损坏文件造成崩溃或数据丢失**。

## 5. 验收状态与后续

**代码接线：已提交。Godot编译：未测试。游戏手柄/触控与UI布局：未测试。玩家路线与Boss胜利条件：未测试。三界shader视觉：未测试。存档兼容及金手指实机：未测试。**

需后续验证战术动作真正消耗行动回合、不同职业许可、三界全屏Canvas层顺序、第8章实物调查及第40章两份证词存档，以及V3自动/手动槽位和编辑器/发行版本金手指一致性。未经此验收不可标记商业级完成。
