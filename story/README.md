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

## 项目校验

- 静态主线与文本校验：`python tools/validate_story.py`、`python tools/validate_story_progression.py`、`python tools/validate_narrative_v21.py`
- 地区与伙伴任务：`tools/validate_phase17_*.py`、`tools/validate_phase18_companions.py`、`tools/validate_phase19_world_anchors.py`
- Godot 环节：`tools/smoke_branch_story_phase19.gd` 以及核心游戏/世界/存档回归测试；以实际 GitHub Actions 结果为准。

## 文档维护纪律

- 新剧情改动优先修改**运行 JSON、正式阅读稿及其索引**；不要再为每一次小阶段创建一个仅重复进度的 `PHASE_XX_DELIVERY.md`。
- 工程问题写到 `docs/RELEASE_STATUS_2026_10_25.md` 或对应制作规范；版本影响写到根目录 `CHANGELOG.md`。
- 历史阶段报告已通过 Git 历史保留，如需追溯可查看旧提交；不要把旧阶段快照当作当前可玩进度。
