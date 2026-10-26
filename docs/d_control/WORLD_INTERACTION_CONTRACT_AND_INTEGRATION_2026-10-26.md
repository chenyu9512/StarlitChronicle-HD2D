# D线统一世界交互接口契约与集成记录（2026-10-26）

源代码审计SHA：`acf4af71b4e680458aacc5cce7266fbd2b8653fd`（C线刚完成艺术管理器修复）。D线只向新增 `scripts/d_world_interaction/*`、`tools/d_control/*`、`docs/d_control/*` 写入。A/B/C 独占文件均未覆盖。

## 1. 现有系统与D线接口责任

| 提供方 | 现有能力（已查源文件） | D接口映射 | 集成状态 |
|---|---|---|---|
| 旧世界 | `first_act_world.gd::nodes / blocked / interact / enter_building / leave_building / spawn_from_exit` | `world_interaction_bridge.select/dispatch_legacy/restore_position` | D适配器已实现；**原游戏输入点未改** |
| 旧章节 | `first_act.gd::_interact/_capture_world_position/_restore_world_position` | `world_interaction_bridge`接管输入，旧`_interact`仍唯一执行故事动作 | 待三线冻结后接线 |
| 地图路由 | `world_registry.gd::can_travel / travel / neighbors` | `scene_transition.begin`之前验证合法邻接及解锁 | 静态契约完成；运行时待接 |
| 地图几何 | `world_geography.gd / world_level_v3.gd` | blocked网格、地块尺寸、通行范围 | 纯算法实现；逐图Godot未验 |
| 城镇 | `town_director.gd::resident_anchor` | 受保护门口和剧情格/占位表 | D行为控制器已实现；B现场调用未接 |
| B NPC | `world_npc_daily.gd::step / begin_talk / end_talk` | D NPCBehaviorController包裹NPC寻路结果与禁止占用 | 适配器已实现，静态接口核对 |
| B室内调查 | `world_home_interactions.gd::objects/snapshot` | D InteriorInteraction只预览，D Executor写同一V3存档 | 适配器已实现，主游戏接线待完成 |
| C人物 | `world_npc_visual.gd::set_motion/face_player/perform_life_action` | NPCBehaviorController, WorldPresentationAdapter | 适配器已实现，视觉实测待验 |
| C视听 | `c_interaction_fx.gd::trigger`、`c_town_soundscape.gd::configure` | D WorldPresentationAdapter；open映射door_open | 适配器已实现，场景实测待验 |
| A战斗返回 | `battle_world_handoff.gd::find_safe_position/restore` | D转场安全落点，不改变战斗奖励与胜负 | 接口对照完成；集成测试待验 |
| V3存档 | `first_act_state.gd::_pack/save/restore_snapshot` | D `WorldStateSync`及`WorldInteractionExecutor` | 新命名空间独立实现，旧档回归待验 |

## 2. 严格数据契约

`InteractionRouter.context(map_id,chapter,target_id,target_type,actor_id,minutes,flags,indoor_id)`：

- 必填：`map_id`非空、`target_id`稳定ID、`target_type`；`chapter`为0–72，`minutes`为0–1439，`story_flags`深拷贝，`indoor_id`为空表示室外。
- 已在项目使用的稳定命名：`building:<id>`、`questdoor:<id>`、`citizen:<id>`、`exit:<map_id>`、`story_stage_<index>`。D新增持久家具键 `<map_id>#<building_id>#<object_id>`。
- 结果字典统一携带 `handled`、`dialogue`、`message`、`effects`、`animation`、`transition`（无转场时为空字典）。
- `effects`限白名单：`home_seen`、`set_flag(world.d.*)`、`add_gold`、`add_item`。需`event_id`，一事件一次账务，`progress.save()`失败恢复原状态。其他奖励不得通过D层偷发。
- **范围边界：**本规则只保障全部效果与`consumed[event_id]`在**同一V3存档域**的原子化逻辑；A/B单独剧情存档和跨域事件的完整exactly-once仍属现有P0，不能错误关闭。

## 3. 交互裁决与防阻断规则

1. 先过滤非可见、禁用、超出独立`range`和网格遮挡的目标，再按main > story > quest > quest_door > interior_exit > door > npc > furniture > service > gate > ambient裁决；同权选最近，仍同距离按稳定ID排序。
2. 低优先级对象在玩家面朝相反方向时不得抢输入；当前主线目标不因转身而失效，但仍遵守范围和墙体遮挡。不能单凭main优先级在远处调用事件。
3. NPC走位复用B线`step`，D额外隔离玩家、队友、出口、剧情标记和已被其他NPC预留的格；不允许夜间变更瞬移到阻挡点。
4. 队友单步候选位置只在物理边界和占位检验通过时移动；现有三名跟随角色还需现场逐人接入。
5. 门/城镇/地下城转场先`begin`锁住输入，成功后`complete`、失败`abort`，350毫秒同入口冷却；进入/离开必须提供原门ID、室内ID、存档回程点、来源图和目标图。

## 4. 全局静态覆盖与真正的验收边界

快照中：40活跃地图；11个聚落；66个普通登记建筑门口（每聚落inn/shop/guild/smith/house/shrine各一个）；40名NPC来自8个地区、共200段日常作息，全天覆盖无时间空档或重叠；78条有向相邻连接全部互为反向。

- 已核实：`world_geography.layout`对每个登记建筑生成`features.building`和`door`，`first_act_world._build_sites`把它们注册成`building:<id>`，`enter_building`按ID查找布局。`first_act_world.leave_building`保存外部位置后重建地图并恢复；**现有逻辑缺乏统一出口重生碰撞保护**。
- 97份`data/levels/v4/interiors`JSON中，普通建筑专用美术/布局文件仅12份，对剩余普通建筑使用procedural fallback的数量与实际画面效果必须在Godot逐个验收。
- 普通邻接图有**两个分量**：35张大地图、5张城市地图。仅证明每条邻接边双向，不证明玩家从第一个分量可自然走入第二个；剧情/城镇脚本的跨分量转移需B线证明。
- 静态数据完整 ≠ 房屋66/66已在引擎进出成功、NPC40/40可对话、日夜无穿模、存档72章通过。结果见 `world_interaction_coverage_2026-10-26.json` 中每个实体的`NOT_GODOT_TESTED`。

## 5. 集成计划/状态（不改现有A/B/C独占文件）

- A线：战斗接续安全落点接口已静态核对；正式Boss结束归还角色控制与转场互斥回归 **待统一验收**。
- B线：40 NPC日程、40 NPC对话与11聚落屋内调查接口已静态核对；需交付门禁/时间锁/家居私人物件规则及正式停写声明；主游戏接线 **待统一验收**。
- C线：NPC动画、开门/调查特效、场景音频方法已核对；主游戏回调和淡入淡出视觉及音轨 **待统一验收**。
- D线：7个独立模块＋1个组合桥接＋Godot专项脚本＋Python世界覆盖审计工具；实现全部提交至main，不改共享脚本。原`world.interact()`调用仍有效，新D`dispatch_legacy()`**尚未替换**；不可宣称已经应用到用户可玩的画面。

## 6. 执行测试命令与发布限制

- `python tools/d_control/audit_world_interactions.py --root . --strict --output /tmp/starlit-world-interactions.json`。
- `python tools/d_control/verify_crosslinks.py --root . --json`。
- `Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/d_control/smoke_world_interaction.gd`。
- `Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/smoke_b_npc_home_v1.gd`。
- `Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/smoke_c_town_presentation.gd`。
- `Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tools/smoke_a_line_world_handoff.gd`。

上述Godot命令**本轮未执行**；当前环境无Godot 4.7.2、无法联网下载。严格遵守旧决议：三线冻结、B/C确认独占文件交付后，D协调一次正式Godot完整批次QA，保留最新SHA与逐步日志，不改 `docs/qa-batch-trigger.json`，不创建分支/PR/强推，不绕过实际战斗、剧情或断言。

**商业级验收：未通过；需要正式运行确认。**
