# 星灯纪行｜40 地图独立探索内容 V6

## 范围与结果

2026-10-25，在 `main` 既有 V5 独立地形和 72 章/120 条支线基础上新增 **40张地图 × 3处 = 120处地图专属探索事件**。

本次没有移动主线、房屋、剧情证物、任务入口，也没有改变世界地图解锁或任务ID。探索事件属于**独立可选世界内容**，不取代或重复计数原有120条支线。

| 地图类型 | 已接入内容 |
|---|---|
| 11个聚落 | 地区传闻、历史道路线索、遗留补给 |
| 8座地下城 | 铭文调查、辅助机关、独立秘藏 |
| 21处原野/道路/地标 | 地形痕迹、旧路调查、旅人补给 |

每张地图的三条正文均独立编写，以潮痕、巡逻箭刻、锻造风道、珊瑚潮色、镜像反射、旧洲遗迹、星序与城市修复等不同细节区分地貌和剧情语感。按地图扩展节点绘制实际交互 Sprite2D，非只有说明表。

## 运行链

`data/levels/v5/world_discoveries.json` (40张地图，每图三事件) → `scripts/world_discoveries.gd` (数据、坐标和先后关系验证) → `scripts/first_act_world.gd` (场景交互点及小地图实体) → `scripts/first_act.gd` (调查、依赖判定、物品金币、事件账本、存档) → `scripts/map_view.gd`、`scripts/map_hud.gd`、`scripts/rpg_menu.gd` (定位和进度回显)。

- 每张地图按 **trace → mechanism → cache** 顺序调查；线索与后续事件各有自己的地理位置和文本。
- 先尝试领取未开启的秘藏只会得到提示，不会发奖励。
- `progress.flags[`discover.<map_id>.<event_id>`]` 保存永久完成状态；重复交互不发第二次金币或道具。
- 奖励在已有的 `rpg_core.add_item()` 和 `progress.gold` 中结算；实际数据 `data/content/items.json` 已有对应道具。
- 原存档 `first_act_v3.json` 无需改版：新旗标是可选增量，旧存档缺少它们时视为未调查。
- 互动点采用独立世界坐标，40区原有尺寸、道路和门口不重新生成。

## 自动化验收

`tools/smoke_world_discoveries.gd` 验证：

1. 40个地图记录与40张实际地图范围匹配，120处事件文案不重复；
2. 每处探索节点均处于可行走地形、可从该地图出生点抵达；
3. 地图中真的有交互实体；
4. 阶段未解锁不能越过线索直接拿奖励；
5. 物品/金币仅领取一次，重复调查不刷奖励；
6. 事件已保存后可从现有 `State.restore_snapshot()` 恢复。

已纳入 `.github/workflows/unique-map-layout-validation.yml`：覆盖数据→Godot实际地图→交互/奖励→存档回归，新增内容能和上一批40地图尺寸测试一起检查。

- [首次完整通过：Unique 40-Map Layout Acceptance #40188036159](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40188036159)
- [更新后再次通过：Unique 40-Map Layout Acceptance #40188101298](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40188101298)

## 仍待完成

这是**可玩的逐图探索内容 V6**，尚不是40张独立商业级场景的终点。当前三阶段探索使用共通交互顺序；下批应该制作至少8座地下城的不同机关规则、11座聚落的日夜生活与独特商业区、21处野外的支路谜题，并补真实专属建筑、环境音、过场动作和地区宝箱打开美术。不能把三条调查文本误写成完整手工关卡或专属Boss演出已完成。
