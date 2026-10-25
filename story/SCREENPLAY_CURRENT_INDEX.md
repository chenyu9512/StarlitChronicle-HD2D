# 《星灯纪行》正式中文剧本阅读入口｜V2.1

> 本页是唯一推荐的**当前阅读稿索引**。所有可运行剧情事实、stable ID、触发、奖励与条件，仍以 `story/campaign/*.json` 为最终准据；旧版Markdown仅作历史审校记录。

## 当前各幕首选文稿

| 幕 | 章节 | 当前批准阅读稿 | 基准内容 |
|---|---|---|---|
| 1 | 1–6 | [act_01_phase08_full.md](screenplay/act_01_phase08_full.md) | [act_01.json](campaign/act_01.json) |
| 2 | 7–12 | [act_02_phase09_full.md](screenplay/act_02_phase09_full.md) | [act_02.json](campaign/act_02.json) |
| 3 | 13–18 | [act_03_phase10_full.md](screenplay/act_03_phase10_full.md) | [act_03.json](campaign/act_03.json) |
| 4 | 19–24 | [act_04_phase11_full.md](screenplay/act_04_phase11_full.md) | [act_04.json](campaign/act_04.json) |
| 5 | 25–30 | [act_05_phase12_full.md](screenplay/act_05_phase12_full.md) | [act_05.json](campaign/act_05.json) |
| 6 | 31–36 | [act_06_phase13_full.md](screenplay/act_06_phase13_full.md) | [act_06.json](campaign/act_06.json) |
| 7 | 37–42 | [act_07_phase14_full.md](screenplay/act_07_phase14_full.md) | [act_07.json](campaign/act_07.json) |
| 8 | 43–48 | [act_08_phase08_full.md](screenplay/act_08_phase08_full.md) | [act_08.json](campaign/act_08.json) |
| 9 | 49–54 | [act_09_phase08_full.md](screenplay/act_09_phase08_full.md) | [act_09.json](campaign/act_09.json) |
| 10 | 55–60 | [act_10_phase15_full.md](screenplay/act_10_phase15_full.md) | [act_10.json](campaign/act_10.json) |
| 11 | 61–66 | [act_11_phase16_full.md](screenplay/act_11_phase16_full.md) | [act_11.json](campaign/act_11.json) |
| 12 | 67–72 | [act_12_phase08_full.md](screenplay/act_12_phase08_full.md) | [act_12.json](campaign/act_12.json) |

## 编剧阅读规则

1. 第1、8、9、12幕采用第8阶段全量稿；第2幕采用第9阶段306句全量稿；第3幕采用第10阶段317句全量稿；第4幕采用第11阶段310句全量稿；第5幕采用第12阶段288句全量稿；第6幕采用第13阶段296句全量稿；第7幕采用第14阶段全量稿；第10幕采用第15阶段全量稿；第11幕采用第16阶段全量稿；72章至此均经历第8–16阶段同级主线对白深化。
2. 第22章匿名宫廷乐师不是伊泽；第26章取得的是航路证据，不能计作无条件获得`world.page_01`。
3. 第72章`resolve`是选择前的共同交接，`ending`才是A/B/C最终选择；选项写入后必须播放对应`data/endings.json`的四场，之后再宣布正篇完结。
4. A/B/C的条件以`data/endings.json`为准，C必备的地区协作由12航页见证与第60章分散灯网建设代表，暂不添加隐藏第四条件。
5. `story/data/stage07_*.json`、`story/data/phase08_*.json`、`v21_ch026_page_reactions.json`是独立文本候选，尚未绑定原有主线运行器。不得按已经可操作的地图事件、可播互动或全量A/B路线验收。
6. 历史文稿`screenplay/act_01.md`、`act_08.md`、`act_09.md`、`act_12.md`保留为旧版；第1幕`act_01_phase08_expansion.md`是差异附录，**不是**全文阅读稿。
7. 第9阶段第1–12章的玩家可操作事件设计见 `data/phase09_opening_event_plan.json`；它是制作方案而非地图/运行器实装。第2幕旧 `screenplay/act_02.md` 成为历史稿。
8. 第10阶段第13–18章的八基础职业试炼、四阀门及12场独立事件设计见 `data/phase10_act03_production_plan.json`；这是制作候选，不能当作运行器已实装。
9. 第11阶段第19–24章的三个回忆可操作年代、现世选择前转换、白夜祭潜入和档案机关设计见 `data/phase11_act04_production_plan.json`；并非运行器已实装。
10. 第12阶段第25–30章的船籍、潜水钟、三段残谱和六座航标设计见 `data/phase12_act05_production_plan.json`；不是已实装关卡，且第26章航路证据不代表取得支线航页。
11. 第13阶段第31–36章的重复日期调查、镜面退出机关、七重梦庭、玄璃自主身份与疗养院分批醒转设计见 `data/phase13_act06_production_plan.json`；内容仍未接入地图与运行器。
12. 第14阶段第37–42章的返乡、诺依救援、历史双证词、根系空门和根忆灯见证规范见 `data/phase14_act07_production_plan.json`；尚未注册地图事件。
13. 第15阶段第55–60章城镇重建、公会委托、维莎听证、志愿防卫和12社区灯网节点制作规格参见 `data/phase15_act10_production_plan.json`；只有 `ch060.resolve` 正式设置 `world.distributed_network`，不得据此自动解锁结局C。
14. 第16阶段第61–66章星帆往返、七份实验报告、澄舟影像与空白未来、天衡退出协议、七守门者与终末天桥制作规格参见 `data/phase16_act11_production_plan.json`；仅第66章resolve设置七灯总旗标，最终A/B/C仍于第72章选择。
15. 归档交付每批必须同时更新JSON、正式阅读稿、此索引与静态测试；禁止在版本号不明时只引用旧Markdown内容。

## 支线当前阅读稿｜第17阶段长期A/B

- **12张失落航页**：24条A/B路线、72场候选、216句新增对白。以 [航页阶段与分支清单](data/phase17_lost_pages_manifest.json) 和 `data/phase17_lost_pages_*.json` 为准，原支线阅读稿在 `screenplay/sidequests/lost_pages_01_12.md`。
- **24条生活支线**：[完整A/B阅读稿](screenplay/phase17_life_all_branches.md)，48条路线、144场候选、432句新对白；[制作表](data/phase17_life_manifest.json)。
- **36条地区支线**：[完整A/B阅读稿](screenplay/phase17_regional_all_branches.md)，72条路线、216场候选、648句新对白；[地区制作表](data/phase17_regional_manifest.json)。

## 伙伴剧情｜第18阶段

- [48条伙伴任务A/B完整稿](screenplay/phase18_companion_all_branches.md)：8名伙伴、96条独立路线、288场、864句新增中文对白。
- [伙伴结局尾声](screenplay/phase18_companion_endings.md)：8人 × 3种结局 × 最终个人选择2路线，共48场、144句新增对白；不能在结局原场景之前播出。
- [伙伴触发/存档契约](data/phase18_companion_manifest.json) 保持原任务奖励与结局条件不变。

## 剧情实装｜第19阶段

- `scripts/story_branch_runtime.gd`：将第17–18阶段的分支候选纳入任务后续播放、顺序、已阅状态与存档管理。
- [第19-2A～F批地图交互交付](data/phase19_quest_world_anchors.json)：120条任务落在已解锁的30个正式分块及真实建筑入口/区域节点，三段独立实地互动、NPC/物件状态、小地图与回访导航已经运行时接入；复合地名尚需独立子地图美术。
- `story/data/phase19_quest_world_anchors.json`：120任务与正式地图一一关联，检查器 `tools/validate_phase19_world_anchors.py`、真实Godot场景测试 `tools/smoke_story_world_phase19_2.gd`。
- `tools/smoke_branch_story_phase19.gd`：运行时回归入口。**事件数据存在 ≠ 已经完成全部场景角色动作、地图细节与真机回归。**

## 校验入口

- `python tools/validate_story.py`：主线结构及数据格式。
- `python tools/validate_story_progression.py`：离线剧情、失落航页与三结局的静态条件。
- `python tools/validate_narrative_v21.py`：对白ID、正典P0守卫、120条支线及插入锚点。
- Godot测试还需检查实际分支播放、旧档加载、地图交互、结局选择及尾声，不得以静态通过替代。
