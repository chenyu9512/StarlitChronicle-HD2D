# 《星灯纪行》全局同步与架构对齐实况（2026-10-29）

> 唯一开发分支 `Main2美术优化版`；`main` 只读；Godot 4.7.2；正式载入以代码与具体SHA为准。所有结果区分 `SOURCE_VERIFIED`、`WIRED`、`GODOT_VERIFIED`、`PLAYER_ACCEPTED` 与 `RELEASE_ACCEPTED`。本文件不是商业级验收通过声明。

## 一、运行中的唯一权威链

```text
project.godot / scenes/first_act.tscn
    └─ scripts/first_act.gd                         【剧情/战斗/存档/互动唯一编排器】
         ├─ scripts/story_catalog.gd
         │    └─ scripts/systems/CampaignProductionIndex.gd
         │         ├─ story/campaign/act_01..12.json     【72章正典】
         │         ├─ story/data/{side_quests,companion_quests,regional_quests_v2}.json
         │         ├─ story/data/bosses.json            【66 Boss设计记录】
         │         ├─ story/runtime/chapter_play_patterns.json
         │         └─ story/runtime/mechanics_registry.json
         ├─ scripts/first_act_world.gd              【可玩地图与室内主场景】
         │    ├─ scripts/world_geography.gd
         │    ├─ data/levels/world_atlas_v2.json         【42节点，40正式可玩】
         │    ├─ data/levels/v3/map_*.json             【40正式地表】
         │    ├─ scripts/world_interior_v4.gd
         │    │    └─ data/levels/v4/interiors/*.json   【153室内，其中54地区房】
         │    └─ scripts/world_interior_art.gd         【A线主题/地区HD2D渲染】
         ├─ scripts/first_act_battle.gd / scripts/rpg_core.gd
         │    └─ scripts/d_world_interaction/battle_v3_settlement.gd
         ├─ scripts/world_home_interactions.gd
         ├─ scripts/save_slots.gd / scripts/first_act_state.gd
         └─ scripts/first_act_ui.gd / scripts/map_hud.gd
```

`project.godot` 的 `State` autoload 为兼容原型的 `scripts/game_state.gd`（V1），并不代表游戏正式剧情唯一存档是V1。正式剧情与道具、奖励结算继续通过既有V3状态/事务/存档接口，**不新增平行账本**。

## 二、截至本轮的全游戏结构事实

| 领域 | 已核对的事实 | 系统状态/不可替代的验收 |
|---|---|---|
| 剧情 | 12幕×6章=72章；四阶段及ID顺序正确 | `SOURCE_VERIFIED`；72章不等于全部逐章实机通过 |
| 支线 | 36生活/航页、48伙伴、36地区 = 120；没有重复ID或孤立章节 | `SOURCE_VERIFIED`；部分原文件仍是设计合同 |
| Boss | 66个唯一章节Boss设计关联 | `SOURCE_VERIFIED`；没有证据证明66战斗已实装或平衡 |
| 职业 | 20项，ID唯一 | **20/20都标注`design_ready_not_implemented`**；不能当作实际可选职业 |
| 世界 | 42地图节点、40正式可玩V3地表、8地区 | V3布局源完整；真实步行/像素画验收另计 |
| 建筑 | 68座外部建筑均对应V4室内 | 数据连接成立；门口碰撞/读档回程仍需实跑 |
| 室内 | 153个V4房间；54地区房均持有显式家具/灯光及实体柜台 | 静态物理连通性完成；真实Godot视觉与操作尚未全部验收 |
| 美术 | 角色、区域地表、室内通过共享主题/覆盖入口接入 | **美术专项CI出现资产缺失/角色贴图失败**；正式画面签收不可用旧报告替代 |
| 存档/任务奖励 | V3原有状态、结算回执、旧档兼容继续作为唯一写入路径 | 同SHA故障回滚、重奖、后期剧情还须回归 |
| Runtime | Main2统一测试门禁控制独立可玩快照发布 | GameCore No-Art镜像成功≠Runtime已发布，未验证不应强制同步 |

## 三、本次工程修复，改变的是正式生产入口

1. `scripts/systems/CampaignProductionIndex.gd`：章节不再只验72总数，现校验每幕六章的完整顺序、正式完成旗标、剧情场景唯一ID及阶段；任务校验归属章节、唯一阶段和完成旗标；Boss校验所属章节和独立身份；72个章节玩法合同、机关章节键必须属正典。任何严重错配阻止索引通过 `load_all()`。
2. `tools/validate_global_runtime_contract.py`：独立静态校验正典—职业外的120任务—Boss—世界图—68门—153间V4的一致性。仅静态读取，不推进剧情、发放奖励或更改状态。
3. `tools/d_control/run_main2_ci.py`：将上述全局校验并入**每次统一Main2 CI基础检查**，与原有世界/美术/系统选择性检查配合。
4. B线现有修复保留：54地区房真实家具脚点、服务与储物站位、静态四向连通、正式V4美术档位、室内灯光；旧数据回退不可当完成态。
5. 没有改动 `main`、没有绕过战斗/任务结算、没有为了绿灯删除断言、没有强行发布不合格Runtime。

## 四、当前P0/P1和跨线依赖（12方向合一）

| 优先级 | 方向 | 当前唯一下一步及完成判据 |
|---|---|---|
| P0 | 01/12 工程QA | 最新Main2 SHA的全局索引、Godot冷导入、全套关键smoke须有完整日志；取消或进行中的CI不算通过 |
| P0 | 07/08 美术与人物 | 主角原始贴图加载错误、部分上传包素材不可用、第一幕Boss阶段图像缺失；修真资源与身份映射，不以错误图片代替 |
| P0 | 02/03/10 世界与交互 | 晨露村、收容所、黑帆酒馆和地图出口，按玩家原路进出、交互、无遮挡、存档回程逐个验收 |
| P0 | 04/05/06 剧情战斗存档 | 前六章合法战斗和任务顺序、读档幂等、V3身份与时代锁；成功仅按实机记录 |
| P1 | 04/05/08 后续全篇 | 将全72章、66 Boss、20职业的设计合同逐章转换为玩家可主动操作的真正流程 |
| P1 | 07/09/11 画面/视听/发行 | 逐张高清2D画面、人物动作、性能、目标端运行与Runtime正式发布证据 |

### 已定位的美术CI失败（按原始日志，不推测已修复）

过往 `Main2 · Real Art Runtime Acceptance` 的 `import-and-world-art` 曾报告：主角现有图像加载失败、后上传包6个槽位仅3个可用、第二至第六章Boss阶段素材找不到、第一幕26幅预期截图因前序测试失败而未产生。其后仍有持续的并行美术提交；只看**具体最新SHA**的状态，不把历史失败当作已自动修复，也不把单独`Town Ground Rendering`成功扩写为整体美术通过。

## 五、状态判定

- **成功（源文件核查）**：72章 / 120任务 / 66 Boss数据关联；42/40图、68建筑/153室内数据对应；54地区房静态家具合同。
- **代码已修复，待同SHA验收**：全局加载器严格身份校验、新的全局静态审计及CI集成。
- **未测试 / 未通过商业验收**：最新Main2全量Godot通关证据、第一幕六章正常玩家通关、全部职业和Boss实装、高清2D最终画面、正式Runtime发行。

**下一次更新该文档时**：写入实际使用的Main2 SHA、具体Actions run链接、每项成功/失败和对应实机画面文件，禁止继承别的SHA的验收状态。
