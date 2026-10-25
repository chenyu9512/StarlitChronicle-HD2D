# 星灯纪行｜叙事内容包（正典基线 V2.1）

> **当前正典（V2.1）**：[正式中文剧本索引](SCREENPLAY_CURRENT_INDEX.md) · [结局与场景条件](NARRATIVE_DESIGN.md) · [人物时间线](CAST_BIBLE.md)。此前V1阶段统计为历史快照；请以当前JSON及V2.1验收报告为准。

> 正式企划：洛维恩世界 / 十二幕七十二章 / 七座母灯 / 现世、映世、岁影回廊。作者原创，吸收经典JRPG的通用设计思想，不复制现成作品专有剧情、咒文、敌人、角色或音乐。

## 最新推进（2026-10-25）

第9阶段已经在 `main` 完成第7–12章120句正文扩写，并新增12场生活／调查文本候选和12组选项回应；第1–12章共24场可选事件与24种选择反应已有制作行为表。主线现为2,797句，已进行同级文本深化的章节为30/72。当前阶段详情参见 [第9阶段交付报告](PHASE_09_OPENING_01_12_DELIVERY.md)，当前阅读入口请以 [V2.1剧本索引](SCREENPLAY_CURRENT_INDEX.md) 为准。新增可选事件尚未注册地图与运行器；脚本和Godot运行需要CI及正式回放确认。

## 第10阶段更新（2026-10-25）

已在 `main` 扩写第13–18章《赤炉联邦》主线120句，另新增12场独立工业/生活调查场景72句、12组选项即时回应36句，并写入8类基础职业试炼和四组主炉阀门制作规格。当前72章主线为2,917句、36章经过第8–10阶段同级深化；可选事件和机关均为文本制作方案，未注册至运行器。正式稿参见 [第三幕完整阅读稿](screenplay/act_03_phase10_full.md)，详情见 [第10阶段交付报告](PHASE_10_RED_FURNACE_DELIVERY.md)。

## 第11阶段更新（2026-10-25）

已在 `main` 深化第19–24章《失落回忆与白夜祭》主线120句，补充12场独立生活／档案证物戏72句、12组选项回应36句，明确第19章十年前雷索、第20章七年前朔弦与第21章少年岚音的历史可操作视角，并修正第21章选择前必须回到现世的演出过渡。全72章现有3,037句主线、42章已进行同级文字深化。详情见 [第11阶段交付报告](PHASE_11_MEMORIES_DELIVERY.md) 与 [第四幕310句全量阅读稿](screenplay/act_04_phase11_full.md)。可选场景仍未进入Godot地图事件，CI实际运行及游戏回放仍需验证。

## 仓库中的实际状态
- `story/campaign/act_01.json` 至 `act_12.json`：72章、每章四个基本场景（开场/调查/冲突/收束），最终章额外结局节点，共289个场景。每一章都有对白ID、NPC发言人、任务目标、条件、完成标志、奖励；Boss章节含战斗触发元数据。
- `story/campaign/prologue.json`：童年星灯祭九场可编排事件，建立澄舟失踪及主角未被记录的秘密。
- `story/data/`：角色、地理、支线、系统UI、职业、怪物等叙事关联素材，供后续地图、事件、战斗系统引用。
- `scripts/story_catalog.gd`：Godot独立读取、检索与条件检查接口，不依赖任何在线服务。
- `scenes/story_preview.tscn`：剧情数据预览场景，供编剧与开发者逐句查阅，不替换当前主游戏。
- `tools/validate_story.py`：从仓库根目录运行数据检查。

## 严格说明
此内容包是**覆盖完整剧情架构的生产级第一轮叙事蓝图与可消费的文本数据**，并非90-120小时终版全部配音稿；章节剧情已按可实施事件拆解，但演出资产、对应新地图、事件坐标、Boss AI、时长/难度调校、成百条支线的逐句终稿仍需要继续深化。带有 `production_status: scripted_blocking_v1` 的章节即表示“已有可用文本与分场，但未达到文本锁定”。

## 与当前 v0.1.1 原型的关系
原型：晨露村、星落遗迹、黎昂/澪、守灯人找星核；新正典：玩家主角（可自定义名）、岚音、养父澄舟、星灯祭与七灯冒险。
为确保旧存档可读，本次**不修改** `scripts/game.gd` / `scripts/game_state.gd` / `data/village.json`。把原版“黎昂”解释为默认主角名候选，把“澪”设为可重命名的原型同伴占位，正式上线统一更换为岚音；“星落遗迹”保留为第一幕地下遗迹之一，“守灯人带回星核”改写为年轻时的预兆任务。详见 `story/CANON_MIGRATION.md`。

## 数据约定
- 章节：`id=ch001..ch072`、`act`、`required_flags`、`scenes[]`
- 场景：`trigger`, `dialogue[{id,speaker,text}]`, `objectives[]`, `effects[]`
- 条件：`story.ch001.done` / `world.*` / `party.*` 为稳定key
- 战斗：`encounter.enemy_id` 不直接表示敌人已实现，获胜须写入 `win_flag`
- 决策：`choice.options[].sets` 为决策状态变化；封闭场景须由游戏控制器检查必需标志
- 变量：角色称呼在文本里使用“主角”，正式对话器可替换为自定义名称

## 运行与校验
1. Windows在仓库根目录运行 `python tools/validate_story.py`。
2. Godot导入本仓库，点击“场景 > 打开”选择 `scenes/story_preview.tscn` 并运行当前场景（F6）。
3. 预览器按“上一章 / 下一章 / 下一句”浏览剧情；读取的是游戏工程内实际JSON。
4. `StoryCatalog`可用`load_all()`, `get_chapter(id)`, `get_scene(chapter_id,scene_id)`, `requirements_met(data,flags)`。
5. 正式地图触发器仍需在游戏事件系统中注册场景target与地图坐标，这一步不由JSON自动完成。

## 内容制作用途
文档针对开发者：`WORLD_BIBLE.md`、`CAST_BIBLE.md`、`NARRATIVE_DESIGN.md`、`CANON_MIGRATION.md`。
文本针对引擎：`campaign/*.json`、`data/*.json`。
避免直接将这份草稿当作终版配音送审，最终本地化/过场/配音需要单独锁版。

## 2026-10-24｜第三阶段：纯剧情与文本精修

本次**不修改Godot运行代码或存档协议**。第二幕（第7–12章）186条、第三幕（第13–18章）197条、第四幕（第19–24章）190条独立对白已按各章人物矛盾重写；第一幕保留178条精修对白。以上四幕的Markdown阅读版已与剧情JSON重新同步。

新增 `story/data/ambient_dialogues.json`（36段选项后续反应、23场营地对白）、`story/data/lore_texts.json`（27份世界阅读物），并把 `story/data/npc_barks.json` 扩为69句。第7–24章任务日志与16个Boss剧情模板也已对应更新。

**注意**：新扩展的ambient/lore文本仍是文本资源，不意味着已接入场景；第五至十二幕仍处于首轮草稿状态。完整统计、人物登场时间线和待办请看 `story/PHASE_03_TEXT_AUDIT.md`。
