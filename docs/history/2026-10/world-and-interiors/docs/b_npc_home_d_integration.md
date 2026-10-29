# B线 → D线下一步实际接入契约

**当前状态**：B线逻辑已经提交，但下列 D 线场景代码未修改，尚未运行 Godot 4.7.2。请勿将静态验收当成完成整合。

## 世界NPC：替换旧地区批量生成

D 控制器原来调用 `town_life.residents(region_id)`，可能使地图 `map_coast_02` 重复出现晨露村居民。改由已存在的 `town_life.residents_for_map(map_id)` 按NPC正典 `map_id` 获取，并保持 `citizen:npc_id` 节点ID不变。

预加载 `res://scripts/world_npc_daily.gd`，维护一个长期实例（不要每帧 `new()`）。
逐帧执行 `step(npc_id, map_id, clock_minutes, citizen.position, delta, blocked, Vector2i(WIDTH,HEIGHT))`。
返回字段：`position`、`moving`、`state`、`facing`、`goal`、`path_cached`。
D负责实际将 `position` 写到可视节点，同时维护交互范围所需的 `npc_positions`；路径缓存不能代替动态人物碰撞，必要时须追加占用格阻挡规则。

进入居民对话时调用 `begin_talk(npc_id, player_position)`，结束对话调用 `end_talk(npc_id)`；区域卸载时调用 `reset_route()`。
禁止在跨时段直接重写居民坐标，路由会沿当前坐标渐进变更目标。动作与视觉过渡仍由C/D线负责。

## 家具：加载现有独立室内

D从 `world_interior_v4.gd:load_level` 的 `investigations` 读取 `cell`（`Vector2i`），标注玩家可调查的对象。切勿以美术贴图碰撞点代替检查位置：已有52个B线专门选择的可达检查格。

B的 `res://scripts/world_home_interactions.gd` 提供：
- `objects(map_id, building_id)`：读取原始家具数据（不改变存档）
- `object_at(map_id, building_id, cell)`：根据格子取得家具ID
- `preview(map_id, building_id, object_id, state)`：预览阶段及是否已调查，不改状态
- `inspect_at(map_id, building_id, cell, state, owner_present)`：执行交互
- `inspect(map_id, building_id, object_id, state, owner_present)`：通过已有ID交互
- `snapshot(state, map_id, building_id, object_id)`：检查前后阶段的存档记录

仅当 `changed == true` 且 `requires_save == true` 时触发已有存档机制。B家具奖励始终为空，不允许D二次发放。保存桶 `rpg.home_investigations_v1`；不生成新的主线完成旗标。

传入 `owner_present=true` 必须来自**当前房间内有实际主人可见**，而不是仅凭人物职业推断；没有正式主人身份的房间暂按无人回应处理。

## 验收分层

静态数据（无Godot）：
```sh
python tools/validate_b_npc_home.py
```

B线运行时测试（需要Godot 4.7.2）：
```sh
godot --headless --path . --script res://tools/smoke_b_npc_home_v1.gd
```

统一整合还必须在游戏中检查晨露村白天→傍晚→夜晚移动、NPC碰撞、谈话面向、房屋进出、52个家具互动、重复保存/加载、章节变化和一次性奖励。本文件不是整合完成的证明。
