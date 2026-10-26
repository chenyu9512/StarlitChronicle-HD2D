# 《星灯纪行》B线 Batch B0–B3 代码交付与 D/C/A 接线（2026-10-26）

**起始线上 main SHA**：`4feafb76d77388970659df16af54229736d7cdb0`  
**完成源矩阵提交**：`61d3e7a6cf48144f3b79247c8ed8466448030555`（之后并行提交可能继续推进 main）  
**开发策略**：main-only、独立文件CAS写入；无新分支、无PR、无强推。仅记录本批已证实的事实，不把代码存在当作正式引擎验收。

## 1. 本批实际修改代码

| 文件 | 可直接核对的更改 | 本批SHA |
| --- | --- | --- |
| `scripts/world_geography.gd` | 修复房屋避让0-1 BFS：以 `Vector2i` **动态键**初始化 `distances[start]`、`parents[start]`，避免把start当作字面字符串键 | `ff07cd0907d73546f57ab81234fd7e92303359d2` |
| `scripts/world_town_life.gd` | 新增只读 `preview_talk`（40 NPC对话、首见稳定事件ID）与旧`talk`兼容；公会状态查询不再修改存档、拒绝无效地区 | `016a7cd9...` / `522206df...` |
| `scripts/world_home_interactions.gd` | `objects()` 调查清单只暴露正式V4室内加载器认可、实际没被房间碰撞剔除的调查点，避免美术修改留下“幽灵家具”互动入口 | `00ec16d704645bfa81b2197a2d8bdd28baadde2c` |

**边界**：未修改 D 拥有的 `scripts/first_act.gd`、`scripts/first_act_world.gd` 和 `scripts/d_world_interaction/`，不改 A 战斗代码/C贴图。现有正式玩家流程仍由D线控制，需要D整合下面的 P0 才能宣称B2/B3正式上线。

## 2. 精确覆盖源矩阵

文件：`docs/b_world_source_coverage_2026_10_26.json`（40张地图逐图含正典ID/名称、地形尺寸、66建筑的真实门格、NPC IDs、72章节分布、120支线锚点、剧情Boss设计引用、每图室内JSON数量和各验收状态）。

GitHub实际读取、交叉核对：

- 40张正式地图；另2个非正式原型节点；8个地区。
- 11个有建筑街区的居民区，66个房屋入口定义。
- 97份V4室内文件；目前12间普通室内有52个B线专门配置的调查物件。
- 正典NPC 40个，八区各5个。NPC固定在所属 `map_id`；不能因为同一区域就错置在另一城镇。
- 72章正典主线；120条独立扩展支线存在于 `side_quests.json` 36、`regional_quests_v2.json` 36、`companion_quests.json` 48，而非只读取 `data/content/quests.json` 的12条旧支线。
- 66份剧情Boss**设计记录**，不能与游戏A线正式战斗、胜利回执的实际接入画等号。

此矩阵是 `SOURCE_REFERENCE_ONLY`，全部 `live_player_path_tested`、`save_restore_tested`、`final_art_accepted` 均明确为false。独立静态检查脚本 `tools/audit_b_world_source_matrix.py` 可复查并将输出写入临时路径。

## 3. 新增真实 Godot 验收脚本（未运行）

- `tools/smoke_b_roof_pathfinding.gd`：合成隔墙路线与11城镇66门口，检查不穿屋顶、四邻接路径和门前可达性。
- `tools/smoke_b_npc_dialogue_preview.gd`：40 NPC 首次对话预览不改 V3、稳定事件ID、重复/错区域不会误领首见回执。
- `tools/smoke_b_town_guild_readonly.gd`：八区公会读接口无副作用、任务领取/成功/重复领取本地状态规则。
- `tools/smoke_b_home_runtime_geometry.gd`：全97份V4室内与实际可见调查点核对；12普通房间52家具。
- `.github/workflows/b-world-batch-validation.yml`：**手动触发**一次批次，导入Godot 4.7.2，连带现有 `smoke_town_entrances`、`smoke_b_npc_home_v1`、`smoke_world_production` 统一验证。不会按每个main提交自动运行。

本工作环境没有 Godot 4.7.2 二进制程序、也没有可写可运行的仓库工作副本。仅实际完成GitHub数据交叉核对、代码提交及远端读回，无引擎运行日志；不要写“已通过Godot测试”或“40图全验收”。

## 4. D线必须处理的 P0 / P1

### P0 · 当前正式游戏仍有的接线风险

1. **NPC出生地点错误**：`first_act_world.gd::_spawn_residents` 当前用 `town_life.residents(region_id)`；在白砂港 `map_coast_02` 等同区聚落，可能重复生成本该固定在 `map_coast_01` 的居民。改为 `residents_for_map(world.map_profile.id)`，维护 `citizen:npc_id`，接 `world_npc_daily.step`，换时段沿导航走，不穿模。
2. **家具在正式玩家入口未完整接通**：D线需在 `first_act.gd::_interact` 和 `first_act_world.gd` 使用已确认的V4 `investigations` 可达位置，分配唯一交互节点ID；通过 `d_world_interaction/interior_interaction.gd` + `world_interaction_executor.gd` 在V3快照内确认 `home_seen`。B的 `Home.inspect` 会修改状态，**不能**直接调用后在D保存，避免保存失败造成假完成。
3. **首见NPC事务**：正式 `first_act.gd` 旧路径仍先 `town_life.talk` 写 `talked_to` 再保存。D应改为先 `preview_talk` 取得 `b.npc.first.<id>`，将首次见面记录与V3保存组成单个事务，成功后展现对话、失败返回提示并保留首次交互资格；不重复记录 `resident_met`。
4. **公会与其他生活奖励事务**：`first_act.gd::_service_action` 现调用 `guild_action` 修改金币后才 `_save_progress`，失败可能丢失/重复收益。将其和野外营地、社区任务等接入统一D事务回滚/幂等回执。B已保证公会UI查询只读，但这**不等于**奖励结算完成。
5. **屋内门口存档往返**：确保玩家站位、`indoor_building`、`outdoor_return`、`fog_key` 与数据、碰撞一致；保存失败恢复原角色位置和屋内外状态。

### P1 · 体验/美术协调

- C线使用各地图正典屋体矩形、门格与可达门前格来摆树冠、立面和道具，避免把门口遮住。
- 120支线/66剧情Boss设计只算源完整；必须由D证明玩家真实触发、A线战斗胜利回执和存档恢复，逐项标记证据等级。
- 40图的主路径、NPC/任务点和实际HUD地图的相同坐标，逐图执行玩家可达与碰撞回归，不能单靠JSON图标通过。

## 5. 本批建议执行命令

```sh
python3 tools/audit_b_world_source_matrix.py --output /tmp/b-world-source.json
python3 tools/validate_b_npc_home.py
python3 tools/validate_b_line_delivery.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/smoke_b_roof_pathfinding.gd
godot --headless --path . --script res://tools/smoke_b_npc_dialogue_preview.gd
godot --headless --path . --script res://tools/smoke_b_town_guild_readonly.gd
godot --headless --path . --script res://tools/smoke_b_home_runtime_geometry.gd
godot --headless --path . --script res://tools/smoke_town_entrances.gd
godot --headless --path . --script res://tools/smoke_world_production.gd
```

或在GitHub Actions手动触发 `b-world-batch-validation.yml`，运行后根据真实错误继续修复；不要将未执行的测试写成通过。完成D线接线后应在正式游戏亲自从序章到前三章实走包括对话、室内、战斗、任务、存读档的完整链条。
