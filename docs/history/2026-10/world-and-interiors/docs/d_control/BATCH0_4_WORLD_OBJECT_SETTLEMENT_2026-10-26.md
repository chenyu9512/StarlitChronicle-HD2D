# D线 Batch 0.4 — JRPG世界对象统一结算（参考DQIX模块化设计）

## 范围

本批依据DQIX公开反编译项目中可见的 `World/LootableContainer.cpp`、`Resource/Script.cpp` 等模块职责分离思想，原创实现 Godot V3 世界对象事务。**不复制原作函数、公式、地图、数据与商业资源**，也不声称这些是 Square Enix 的内部工程图。

主游戏正式入口 `scripts/first_act.gd::_interact` 的五组对象：
- 地区发现（`discovery:`）
- V7地下城实体机关（`puzzle:`）
- 传统符文开关（`dungeon_switch_`）
- 传统地下城宝箱（`dungeon_chest`）
- 野外补给箱（`wild_cache`）

统一调用 `scripts/d_world_interaction/world_object_settlement.gd`。
一次V3保存同时包含机关/探索完成状态、金币、道具、历史存档快照。失败恢复 `_pack()`，失败不展示成功奖励；重复调查依据原有稳定flag、V7 claimed保持防重复。**不新增V3字段、不开新存档域**；旧档flags以及V7谜题进度继续兼容。

## 关键边界

- 只处理已确认可交互对象，不代替地图的真实距离、路径、碰撞及前置条件验证。
- `RPGCore.add_item` 负责道具注册和药草衍生数量，未知物品、负金币、非法数量拒绝结算。
- 原本V7机关运行器继续负责顺序、通路和解锁条件；事务层仅保证机关进度与领奖同次保存。
- `game_events.record` 在保存成功后由主游戏发出，避免失败后显示已获得成就；但这些事件历史可能直到下一次保存才持久化（P1后续审计）。
- 地形生态、城镇生活、营地、客栈、商店等非本次对象仍存在独立改造项，不宣称全部世界经济事务化。
- `_capture_world_position()` 发生于事务前，可保留合法站位；不会修改原V3结构。

## 新增专项测试（待执行，非PASS）

`tools/d_control/smoke_world_object_transactions.gd` 使用隔离user://：旧式旗标重复领取、真实RPGCore物品、写盘故障回滚、保存重启、V7机关中途失败与奖励结算失败、重复开封，不使用玩家正式存档。

下一次完整单批Godot 4.7.2验收：
```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/d_control/smoke_world_object_transactions.gd
godot --headless --path . --script res://tools/smoke_world_discoveries.gd
godot --headless --path . --script res://tools/smoke_world_v3.gd
godot --headless --path . --script res://tools/smoke_first_three_playable.gd
```

未实际运行Godot，不得称为引擎验收通过。Batch 0 与公开P0 issues仍按D线总控标准管理。
