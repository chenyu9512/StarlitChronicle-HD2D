# 《星灯纪行》v0.5 — 全篇游戏架构与接口契约

**分支：`main` · Godot 4.7.2 · GDScript · 横屏 iPhone 优先**

## 一、架构目标及验收口径

以 **12幕、72章、三结局** 的原创长篇剧本为唯一叙事源，形成地图—探索—事件—战斗—养成—任务—存档一体化的可扩展单机JRPG工程。**架构接通 ≠ 每张地图、美术、怪物动作、配乐都已经生产完成。**

本版本的所有正式程序直接放在 `main`；未创建新长期开发分支。

## 二、运行依赖与模块

```text
project.godot
  └── scenes/first_act.tscn
      └── scripts/first_act.gd                 [唯一主协调器]
          ├── scripts/story_catalog.gd         [12幕72章、序章、对白]
          ├── scripts/chapter_ambient.gd       [每章2处调查、NPC状态、中段见证]
          ├── scripts/ending_director.gd       [A/B/C三结局与后日谈]
          ├── scripts/world_registry.gd        [42地图ID、8地区、72章主线地图锚点]
          ├── scripts/first_act_world.gd       [TileMapLayer、碰撞、人物与任务实体]
          ├── scripts/encounter_registry.gd    [63普通怪、66剧情Boss、12幕Boss]
          ├── scripts/first_act_battle.gd      [回合制战斗、手选技能、特殊胜利]
          ├── scripts/rpg_core.gd              [20职业、装备、背包、队伍与120支线]
          ├── scripts/game_events.gd           [事件账本、成就、游戏时间]
          ├── scripts/first_act_state.gd       [唯一权威状态/自动存档V3]
          ├── scripts/save_slots.gd            [3手动槽位、备份/读回]
          ├── scripts/first_act_ui.gd          [地图HUD、对白、触屏、主菜单]
          ├── scripts/rpg_menu.gd              [冒险手册16栏目]
          └── scripts/cheat_panel.gd           [隐藏密码9169，仅开发辅助]
```

旧版 `scenes/main.tscn` 及 `scripts/game.gd` 仍在仓库中，保留用于回归对照，**不是正式主入口**。

## 三、数据层与稳定ID

| 数据域 | 真正的源文件 | 使用规则 |
| --- | --- | --- |
| 主线 | `story/campaign/act_01.json` ~ `act_12.json` | `ch001` ~ `ch072` 是唯一章节ID；不可随意改名 |
| 章节任务/地图锚点 | `data/content/quests.json` | `quest_main_XXX.chapter` → `map_id` → `region_id` |
| 世界地图 | `data/content/maps.json`、`regions.json` | 42条地图定义、8地区；双向邻接检查与章节门槛 |
| 章节调查 | `story/data/stage07_*.json` | 每章2处命名线索、居民状态、可选中段见证 |
| 普通怪/Boss | `data/content/monsters.json`、`story/data/bosses.json`、`data/content/bosses.json` | 63地区怪、66故事Boss与12幕数值蓝图，杜绝Boss ID凭空映射 |
| 角色成长 | `data/content/weapons.json`、`armor.json`、`skills.json`、`story/data/jobs.json` | 81武器、54防具、63技能、20职业，程序不再将列表硬编码到UI |
| 委托 | `story/data/side_quests.json`、`companion_quests.json`、`regional_quests_v2.json` | 36+48+36=120条任务；追踪状态和选项写入存档 |
| 结局 | `story/data/endings.json` | 三结局的必要条件与每结局四场后日谈，不复制到UI |
| 美术 | `assets/art/`、`assets/art/art_manifest.json` | ID/路径固定；导入前检查尺寸、透明度、对齐和命名 |

**严禁把“JSON资源条目数”当作“正式场景/正式角色美术成品数”。** 例如42张地图中大量 `scene_path=null`，当前引擎会使用地图ID产生地区配色/布局变化，但它仍属于替代场景。

## 四、跨系统事务和游戏状态

### 地图生命周期

1. `WorldRegistry.bind(progress)` 从存档载入 `rpg.world`。
2. `sync_chapter(chapter)` 从正式主线任务表找地图，不猜章节地区；记录发现及到访。
3. `profile()` 返回地图ID/名称/地区/类型/主题/美术是否已实装。
4. `FirstActWorld.build()` 绘制区域、角色、碰撞、交互与任务标记。
5. 玩家在“世界地图”选择相邻地点，`can_travel()` 必须验证 **邻接关系 + 剧情章节解锁**。
6. `travel()` 写入当前地图、旅行次数，并由协调器写入存档；主线换章时回到对应锚点。

**地图解锁不会自动解锁主线旗标。** 未达到前置章节的邻区显示锁定而不准瞬移。

### 剧情和委托

`ChapterAmbient` 解析章节物件、NPC及中段证言；`RPGCore` 持有主线和支线任务进度；`GameEvents` 只记录真正触发的调查、战斗胜利、章节结算、旅行、委托完成。不能通过打开图鉴直接领取任务奖励。

### 战斗

`EncounterRegistry` 依据主线任务 `region_id` 在对应地区63怪物数据中抽取怪物；剧情Boss由稳定 `boss.chXXX` 回查正典Boss列表，配合12幕蓝图提供可运行的基础数值。前6章已制作的特殊胜利条件保留。战斗中“技能”必须由玩家从已解锁且MP足够的技能中选择，不再自动挑最后一个。

**Boss数值仍是通用可运行曲线**，并未逐场完成正式战斗策划、美术与平衡，绝不能标记为已通过游戏性验收。

### 存档

- 自动存档：`user://first_act_v3.json`、`user://first_act_v3.backup.json`，保持旧存档格式兼容。
- 手动存档：`user://slots/slot_01.json` 至 `slot_03.json`；逐槽位有 `.bak`，写入临时文件并校验后替换。
- 新增状态在 `progress.rpg` 内：`world`、`history`、`event_counters`、`achievements`、`game_clock`、`equipment`、`jobs`、`narrative_side`。
- 读档由 `restore_snapshot()` 验证数据，再 `bind()` 各服务；不能直接改写旧版独立V1原型档。
- 目前是本机离线存档；**云端同步和多设备合并未开发**。

### UI

冒险手册目前16栏目：队伍、背包、武器、防具、技能、职业、任务、世界地图、地区探索、图鉴、商店、锻造、结局档案、冒险履历、存档管理、设置。

## 五、游戏架构与商业美术分离的工程纪律

- `scripts/first_act.gd` 协调流程，禁止承载新武器表或怪物表。
- `scripts/world_registry.gd` 只管理地图目录、故事门槛与旅行；不复制剧情对白。
- `scripts/encounter_registry.gd` 只负责编排敌人初始数据；战斗UI不再内置地区怪物清单的权威数值。
- `scripts/rpg_core.gd` 处理装备/职业/背包与任务奖励，数据ID由原目录提供。
- `scripts/game_events.gd` 是事件日志和成就的唯一账本，不替代 `State` 进行存档写入。
- 长期只维护主程序 `main`、剧情分支、美术数据分支这3条。
- 每次编剧升级制作状态，校验使用版本格式及内容一致性，不能仅靠旧标签拒绝新版剧本。

## 六、自动验收、未交付范围

| 自动验收 | 目的 |
| --- | --- |
| `tools/validate_story.py` | 12幕72章、对白ID、情节条件和剧本格式 |
| `tools/validate_content.py` | 资源表完整性、ID关联 |
| `tools/smoke_campaign_72.gd` | 72章流程完整性（使用模拟Boss胜利，不是人工通关） |
| `tools/smoke_endings.gd` | A/B/C条件、后日谈、存档、回放 |
| `tools/smoke_rpg_core.gd` | 武器、防具、职业、商店、背包、菜单 |
| `tools/smoke_architecture.gd` | 42地图、8地区、章节地图路由、事件、3手动存档槽 |
| `tools/smoke_encounter_architecture.gd` | 63地区怪、66故事Boss、技能主动选择、战斗ID |
| `tools/smoke_chapter_ambient.gd` | 72章调查、居民和证言 |
| `tools/smoke_legacy_ending.gd` | 旧通关存档迁移 |

**未交付、仍必须制作：** 42张地图中的正式手工场景、地区过场动画、Boss专属动作与复杂AI、职业战斗数值平衡、完整音乐音效、HD-2D多层灯光表现、iPhone真实帧率/耗电/触控质量测试、App Store正式签名和商店提交。上述内容没有因为架构完成而自动完成。
