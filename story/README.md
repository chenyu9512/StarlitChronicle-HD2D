# 星灯纪行｜剧情正典与开发入口

> 本页保留**目前有效的目录和制作约束**，不再堆积每批交付流水账。过往阶段文档已归入 Git 提交历史。统计仅表示内容记录与工程接入范围，不等于全篇实机商业级验收。

## 权威资料与阅读顺序

| 用途 | 文件 | 说明 |
|---|---|---|
| 运行时主线 | [campaign/](campaign/) | 序章 + 12幕72章；章节ID、选择、奖励及剧情旗标的最终依据 |
| 当前完整中文阅读稿 | [SCREENPLAY_CURRENT_INDEX.md](SCREENPLAY_CURRENT_INDEX.md) | 每幕唯一推荐正式阅读版本 |
| 世界设定 | [WORLD_BIBLE.md](WORLD_BIBLE.md) | 七灯、映世、岁影回廊、地区与时代 |
| 核心人物与时间线 | [CAST_BIBLE.md](CAST_BIBLE.md) | 角色关系、初见与入队时点 |
| 正典选择与结局 | [NARRATIVE_DESIGN.md](NARRATIVE_DESIGN.md) | A/B/C结局与关键条件 |
| V2.1正式基线 | [NARRATIVE_BASELINE_V21.md](NARRATIVE_BASELINE_V21.md) | P0/P1纠错及准入检查 |
| 运行时与事件契约 | [NARRATIVE_V21_INTEGRATION_CONTRACT.md](NARRATIVE_V21_INTEGRATION_CONTRACT.md) | 稳定ID、可选戏、状态与旧档约束 |
| 全支线总索引 | [QUEST_EXPANSION_INDEX.md](QUEST_EXPANSION_INDEX.md) | 各类委托的导航 |
| 剧情质量差距 | [COMMERCIAL_NARRATIVE_AUDIT_2026-10-25.md](COMMERCIAL_NARRATIVE_AUDIT_2026-10-25.md) | 历史基线审计，数值与当前正文不应混用 |

**注意**：阅读稿是供编剧和制作审稿使用的 Markdown；游戏运行的剧情条件、文本和事件仍以对应 JSON 与 GDScript 的实际代码为准。旧版 `screenplay/act_XX.md` 是历史稿，正式推荐版本由阅读索引逐幕指定，不能因为名称较短而覆盖新版。

## 主线与支线现存内容

- **主线**：9场序章、12幕72章；主线文字与可选事件经过第8–16阶段扩写，当前以 `story/campaign/` 和正式阅读稿逐章核对。
- **任务**：原有36条（失落航页12、生活24）+ 地区任务36 + 伙伴任务48，合计120条独立支线任务。
- **第17阶段**：失落航页24条A/B后续路线、生活任务48条路线、地区任务72条路线，正文、阶段触发与条件保存在 `story/data/phase17_*.json` 及对应 `screenplay/` 阅读稿。
- **第18阶段**：8名伙伴共48条任务，96条A/B后续路线，包含288场候选互动、48场结局条件化尾声，详见 `story/data/phase18_*.json` 与伙伴专属阅读稿。
- **第19阶段**：第19-1批将720场A/B任务后续和48场条件化尾声接入可存档的事件状态机；第19-2批把120条任务映射到30个已有正式地图分块，接入NPC→证物→告示板的3步实地交互、小地图与世界地图路线导航。**正式子地图、NPC终版素材、独立调查谜题仍未全面完成**。详见[第19-2批地图事件交付](data/phase19_quest_world_anchors.json)与独立[阶段19实机验收](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/workflows/phase19-world-validation.yml)。

## 不得破坏的关键正典

1. 第22章不能让伊泽提前以正式身份登场；第27章初见，第28章正式入队。
2. 第26章航路证据不能无条件替代第一张失落航页。
3. 分散灯网在第60章建立，七灯旗标在第66章结算；第72章才做最终A/B/C抉择。
4. 结局C不添加未经数据迁移和策划确认的隐藏第四条件；旧存档与稳定事件ID必须保持兼容。
5. `text_only_not_runtime_bound` 是实际制作边界；有文本不意味着可直接在地图互动、播放动画或触发完整任务。
6. 分支剧情需核实：完成原任务、原A/B选项、章节解锁、后续回访顺序、一次性奖励、存档恢复和不重复触发。

## 第19阶段第三批｜现场调查与证据记录（2026-10-25）

120条原任务拥有以正典调查对白为依据的独立证物/记录档案；第19-2地图节点已经升级为NPC交谈、证物核对、后续公告三个现场步骤，后两步须玩家确认，暂缓不会消耗事件。三条记录按原对白ID保存在`rpg.branch_story.field_log`，可在功能手册中查阅。地图子区域、全角色换装与复杂解谜仍需继续制作。详情：[第19-3批交付报告](PHASE_19_BATCH03_SCENE_DELIVERY.md)。

## 第19阶段第四批｜失落航页12独立室内关卡（2026-10-25）

12条失落航页已经各自拥有真实的V4室内碰撞布局与步行通路。玩家从对应世界分区的独立入口进入，在专属室内完成原五阶段任务与符合A/B条件的后续调查，查看三处线索陈列；进出、查看证物和中途读档沿用既有存档机制。已通过Godot专项12场景实地验收。当前使用原有环境美术，不等于12张全新精绘美术。详见 [第19-4批交付报告](PHASE_19_BATCH04_LOST_PAGE_INTERIORS_DELIVERY.md) 和 [12间场景索引](data/phase19_lost_page_submaps.json)。

## 第19阶段第五批｜12个可玩证据推理与室内美术深化

12个航页场景已增加基于正典证据的三处调查与不同结论选择（错误可重试，正确记录V3档案）；12间独立室内各自设置日夜光色、已有SVG家具与碰撞，其他108条支线的现场证据标记加入任务专属名称和物件类型。仍缺全新精绘美术与108条完整独立建筑场景。详见[第19-5批交付报告](PHASE_19_BATCH05_ART_AND_PUZZLES.md)和[12个机关数据](data/phase19_lost_page_puzzles.json)。

## 第19阶段第六批｜24条生活支线的真实场景（2026-10-25）

已按正典地域将24条生活支线分为19处可进入室内与5处真实户外调查地点。19间独立V4关卡具备不同地形、家具、碰撞、昼夜灯光、三处调查点及原V3存档回访；12张航页独立关卡完整保留。48伙伴与36地区任务仍需继续场景制作。详见[第19-6批交付报告](PHASE_19_BATCH06_LIFE_SCENES_DELIVERY.md)、[24条生活支线地图合同](data/phase19_life_submaps.json)。

## 项目校验

- 静态主线与文本校验：`python tools/validate_story.py`、`python tools/validate_story_progression.py`、`python tools/validate_narrative_v21.py`
- 地区与伙伴任务：`tools/validate_phase17_*.py`、`tools/validate_phase18_companions.py`、`tools/validate_phase19_world_anchors.py`
- Godot 环节：`tools/smoke_branch_story_phase19.gd` 以及核心游戏/世界/存档回归测试；以实际 GitHub Actions 结果为准。

## 文档维护纪律

- 新剧情改动优先修改**运行 JSON、正式阅读稿及其索引**；不要再为每一次小阶段创建一个仅重复进度的 `PHASE_XX_DELIVERY.md`。
- 工程问题写到 `docs/RELEASE_STATUS_2026_10_25.md` 或对应制作规范；版本影响写到根目录 `CHANGELOG.md`。
- 历史阶段报告已通过 Git 历史保留，如需追溯可查看旧提交；不要把旧阶段快照当作当前可玩进度。
