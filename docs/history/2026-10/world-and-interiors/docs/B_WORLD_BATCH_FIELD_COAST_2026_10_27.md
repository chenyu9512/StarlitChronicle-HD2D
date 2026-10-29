# 《星灯纪行》B线：野外交互、室内调查和前三章沿海路线（2026-10-27）

**起始main**：`b3adb973f5cabf668c3c2769384ed6601ac9b449`  
**本交付书生成时main**：`40d5300b8488c18696e6e42ce131853bca32391f`（A/C/D线并行提交可能继续推进）。  
**产品定位**：原创离线单人JRPG；40个正式地图、72章正典不更换ID；继续保留当前区域地图和小地图，**不恢复探索迷雾、不恢复全局地图**。main-only，无分支、无PR或强制推送。

## B线本轮实际代码变更

| 路径 | 落地功能 | 相关提交 |
| --- | --- | --- |
| `scripts/world_field_ecology.gd` | 新增 `preview_interact`，21个野外区域×4交互点=84项任务逻辑全部只读预览；既有 `interact` 复用同一合法性判断并维持原行为 | `5feb2bb95dc5a066b5613b2d3050ae9759d5161f` |
| `scripts/world_home_interactions.gd` | 根据正式V4室内加载器核对家具**ID和实际格子坐标**；错误场景与错误位置不提供调查入口 | `6bab394f804984052e05e3e435b530bc38bf5c38` |
| `scripts/world_registry.gd` | 修复动态字典键 `{initial:""}` 导致的路线计算错误；新实现用 `seen[initial]=""`，保留原章节、发现与相邻旅行规则 | `061fd31ca9cf5f027a04dd545f65dbd2b69e5507` |
| `tools/smoke_b_field_interaction_preview.gd` | 84项预览不变更V3，天气HP影响、每日采集、解锁捷径、一次性宝藏、旧快照恢复 | `17134853f757aa34236abb922b458b641c692236` |
| `tools/smoke_b_coast_three_chapter_routes.gd` | 第1–3章地图路线的解锁、邻接/不可快速越级传送、回程、只读引导、存档恢复 | `5a2aebb7f8ba52d4ffb4ac68055a6a46729855ff` |
| `.github/workflows/b-world-batch-validation.yml` | 手动Batch入口整合野外/沿海路线测试与原有B线室内、NPC、城镇、地图QA | `e6a2f28aac59a3ef554dd141e4dcd5a366804ee0` |

## 正典位置核查（真实GitHub数据）

- 第1章：`map_coast_01` 晨露村；第2章：`map_coast_02` 白砂港；第3章：`map_coast_03` 盐风古道。
- 三张图连通关系为 `map_coast_01 ↔ map_coast_02 ↔ map_coast_03`，章节解锁由正式 `WorldRegistry` 维护，不存在地图菜单直接跨图传送。
- 21个野外地图，84个独立交互点，336个现存野外装饰数据条目；所有交互点位于各自V3布局的合法边界内、无同图重复占格。
- 上述是**静态数据/接口核查**，不是宣称Godot已经真实完成84次交互或玩家实走前三章。

## B线对D线的严格接入合同（关键P0）

### P0-1：野外交互的V3奖励事务必须一次完成

正式 `first_act.gd::_interact("field:")` 仍先调用 `world.field_ecology.interact()` 改写HP、每日采集和隐藏秘藏状态，再加道具/金币、记录GameEvents，最后调用 `_save_progress()`。这不是原子提交；保存失败可能造成玩家HP/道具与进度不同步。

D应：

1. 通过游戏自身的有效玩家站位和相邻交互验证后调用 `preview_interact(map_id,action,progress,weather,minutes,day)`；拒绝未解锁、每日重复、未知点。
2. `preview` 包含 `event_id`（例如 `b.field.map_coast_03.gather.day.2`）、`requires_save`、`hazard`、`reward`、`teleport` 与自然文本。每日采集事件ID带游戏内 `day`，宝藏等永久性事件ID不带日期。
3. 在已有 `V3RewardLedger` 或同等级D原子事务内再次验证preview，执行原有 `interact` 逻辑并同步HP/奖励/物品/地图位置；用完整V3快照一次保存，失败恢复全部状态。
4. 只有事务成功后记录事件，更新HUD/小地图、触发传送或播放奖励提示；重入/重放同一receipt绝不能再次授予奖励。
5. 已打开秘密通道的重复通行 `allowed=true,changed=false,teleport=true,requires_save=false`；必须允许正常往返但不得再次记首次解锁事件。若通行改变玩家存档位置，由D根据世界位置事务保存。
6. 除原有效行为外，不增加MMORPG式每日排行榜、网络账号、服务器时间或无限刷取宝箱。

### P0-2：室内家具实景落点与保存回执

`world_home_interactions.dossier` 现在确保V4布局真实加载成功，调查物件的ID和格坐标与正式渲染一致。D必须只根据B侧批准的 `objects` / `object_at` 显示交互，使用已有 `d_world_interaction/interior_interaction.gd` 进行V3持久化，不能在先行 `inspect` 修改后再补存。C线更新室内碰撞后必须同步调查位置数据。

### P1：前三章线路验收

D应在Godot中从正式新游戏入口实走：晨露村→白砂港→盐风古道，并确认第一章不能跨越剧情门槛；真实道路与地图UI位置一致；出口、NPC、建筑、采集点、战斗、Boss、存档往返完整。B已经修复 `shortest_route` 的实际起点访问键，不允许地图引导直接更改 `visited/discovered` 或调用 `travel`。

## 测试与尚未完成部分

本轮已通过GitHub API再次读取并交叉验证以下源数据：21区域84交互/336装饰、前三章实际地图与邻接、脚本与手动CI配置。此工作环境没有Godot 4.7.2引擎，**所有新增Godot测试均尚未执行**。当下不宣称画面实测、性能数据、存档失败注入、84场玩家交互、前三章商业级验收已通过。

手动CI：`https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/workflows/b-world-batch-validation.yml`。

下一步是D线接入野外奖励事务与室内回执，然后实际运行测试，先验收晨露村至盐风古道黄金流程，其他地区以同样规则推广。
