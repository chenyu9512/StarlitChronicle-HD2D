# 《星灯纪行》全库商业成熟度审计及下一阶段路线（2026-10-26）

**定位**：以《勇者斗恶龙 X》的操作反馈、世界生活、职业战斗、任务引导及品质验收为成熟度参照，制作原创、离线、单机JRPG；不以MMO多人服务规模为本轮交付目标，也不得复制原作设定、地图、人物、音乐和剧情。

## 0. 审计基础与证据等级

- 源码快照：GitHub main 的 e85d57f1000e066ed36c7bc40410ae9eab774643。后续并行提交可能改变主线；D线冻结时须重新核对。
- GitHub完整递归文件树，未截断：2,030个文件、161个GDScript、305个JSON、1,181个PNG、175个SVG；主脚本目录94项。仓库公开，查询时只有main分支。
- 核对对象：主场景入口、系统脚本、正典数据与交付矩阵、静态地图邻接图、素材分类、官方DQX玩法介绍及GitHub Actions历史。
- 局限：不是对2,030个文件逐个完成实际Godot运行；没有当前提交的完整Godot 4.7.2结果、人工连续通关、性能基准、iPhone实测或商业资产签收。
- 证据分级：DESIGN=数据存在；WIRED=真实主游戏入口调用；GODOT_VERIFIED=同一SHA对应真实引擎成功日志；RELEASE_ACCEPTED=完整实玩、性能、存档、版权及发行门禁验收。
- 历史Godot成功参考：Actions run 40274482154 对应 6c32e274182aeb6460af913742be48d8626da1bb，不代表本次SHA已通过。https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40274482154

## 1. 完成度和真实边界

| 内容 | 静态确认 | 未解决的玩家体验验收 |
| --- | --- | --- |
| 主线 | 序章、12幕72章正典数据 | 全篇连续实玩、三结局、剧情回放、旗标与旧档一致性 |
| 地图 | 40活跃独立地图、2原型；40活跃地图美术均标not_final_painted | 每张正式地貌、碰撞、入口、返程、独特场景音画 |
| 相邻区域 | 40图静态邻接分两组：35张和5张城市图 | 剧情/城镇系统是否实际实现两个分量之间可逆转场 |
| NPC | 40居民、8地区、日程与对白数据 | 40名NPC真实走位/交谈、朝向、回访变化、日夜阻挡 |
| 建筑/家具 | 66建筑门口；97份V4室内JSON仅12份普通建筑专用配置；B线52处室内调查 | 当前输入链实际接入、重复调查、任务旗标、回门位置、安全恢复 |
| Boss | 66正典Boss、66份机制配置；64配置待Godot、2旧实现待替换 | 逐场正常规则战斗、非致命结局、奖励幂等与失败恢复 |
| 职业 | 20职业目录与20数值profile；目录状态仍design_ready_not_implemented | 20职业切换、技能和装备限制、三难度平衡 |
| 任务 | 36普通+36地区+48伙伴=120基础任务；84地区/伙伴文本仍标未绑定 | 逐条可接、可玩、可结算、可重载；不能把候选文本当新增任务 |
| 普通怪与装备 | 63怪、81武器、54护甲、63技能有目录 | 普通怪美术占位，装备/技能美术未制标记仍大量存在 |
| C线资源 | 外部CC0候选图807份、已有资源替换器和程序化音频 | 正式采用表、许可证、动作帧、BGM/SFX、美术一致性 |
| D线共享 | 新增交互裁决、NPC控制器、场景转场、状态同步及工具 | 当前 first_act.gd / first_act_world.gd 仍未引用新D命名空间主入口 |
| QA/平台 | 工作流和专项脚本众多；历史成功 | 当前SHA最终Godot与设备验收、发布签名与玩家测试 |

**商业成熟度工作估计：约25–35/100。** 这是以“玩家能得到成熟商业作品的连续体验”为终点的**专家判断区间**，不是代码行覆盖率、开发工时百分比、融资估值或严谨测量值。内容/系统原型准备程度显著高于最终可售完成度。

## 2. 风险清单

| 风险 | 优先级 | 可见证据 | 修复责任 |
| --- | --- | --- | --- |
| 最新Godot导入仍未统一验收，近期用户报告真实脚本解析错误 | P0 | first_act_battle.gd等修复已写入，但最新SHA无完整测试 | D+A |
| 独立剧情存档直接写正式文件，保存失败仍可能发送奖励事件 | P0（若此运行器可由正式路径调用） | story_runtime.gd 的 save_story 与 _finish_scene / complete_side_quest | B+D |
| 正式控制器章节推进/部分奖励没有把保存成功作为事务门禁 | P0 | first_act.gd 的 _advance_scene / _complete_chapter / _battle_finished | D+A+B |
| 新D交互适配器与现有旧世界输入控制未统一 | P0 | first_act.gd / first_act_world.gd 无D桥类引用 | D |
| 原世界交互半径优先，缺统一视线/面向/遮挡，住宅反馈不够丰富 | P1 | first_act_world.gd::interact 与 D独立路由 | D+B |
| 建筑出入口、战败安全点及遭遇冷却存在两套逻辑 | P1 | first_act.gd::_battle_finished 与 battle_world_handoff.gd | D+A |
| 35图/5城市图的跨分量旅行连接未证明 | P1 | data/content/maps.json 的40图邻接图 | B+D |
| 40 NPC动态、12家专用室内与52调查尚未完全D接入 | P1 | b_npc_home_delivery_matrix_v1.json | B+C+D |
| 66Boss、20职业、120任务均缺全量真实运行验收 | P1 | 各正典目录和D/B交付矩阵 | A+B+D |
| 地区美术/音轨、外部资源许可、设备峰值缺终稿及证据 | P1 | 各资产数据及C交付文件 | C+D |
| 两大世界主脚本超过1000行，跨系统耦合较高 | P2 | first_act.gd约1768行、first_act_world.gd约1285行 | D |

注意：story_runtime.gd是独立剧情运行器，其是否由正式主场景使用需要进一步确认；不能因它存在便断言所有正式存档必然损坏。可达路径若存在须按P0处理；不可达时必须隔离入口并继续保留故障测试。

## 3. 《勇者斗恶龙 X》对标的正确尺度

其官网介绍涵盖：场景中可见的野怪与接触开战、职业转职和装备差异、居民/设施/委托、住房、工匠与丰富的休闲行为。来源：
- https://web.dqx.jp/online/playguide/battle/
- https://www.dqx.jp/online/playguide/other/
- https://secure.dqx.jp/sc/public/playguide/guide01/

本作应追求：清晰交互优先级、连贯移动与转场、居民有日常记忆、Boss指令战术可读、职业差异真实、地图引导流畅、资源美术统一、战斗结果与故事奖励持久且可靠。**不要求**本批开发在线公会、多人市场、PvP、赌场或服务器运营。保留本作原创剧情、敌人、职业名称和像素风格。

## 4. 下一阶段生产与门禁（按依赖关系执行）

### Batch 0：安全编译/存档阻断关闭（P0）
- A/B/C停止修改共享核心后，D读取最新main形成冻结SHA，安排一次干净Godot导入和精简主入口加载检查。
- 解决报错、重复变量、错误预载，修正故事存档直写、跨域奖励nonce、章节推进失败回滚、旧档保护。
- 故障注入：空间不足、写盘失败、坏主档与备档、重复回调、战斗失败后重试、读档重复奖励。
- 门禁：编译错误0、P0错误0、关键进度不丢、关键奖励不重发，保存失败要可恢复且明确提示。

### Batch 1：D唯一世界交互状态机接线
- D只在协调后修改 first_act.gd、first_act_world.gd 等共享文件；接入 InteractionRouter、WorldInteractionBridge、NPCBehaviorController、InteriorInteraction、SceneTransition、WorldStateSync。
- 将A BattleWorldHandoff的进出战斗与安全恢复，B移动NPC/房屋调查，C角色朝向/门/屋内音景统一绑定到主入口。
- 门禁：无隔墙对话、无错误抢焦点、无双击进门、返回位置可走、普通住宅不遇敌、Boss胜败后输入恢复正确；旧档保持兼容。

### Batch 2：晨露村 + 前三章商业可玩切片
- 可玩路径：新游戏→序章→晨露村居民/6功能建筑→调查→外出→普通遭遇→第2/3章Boss→补给→返回→存档→退出→读档继续。
- B：至少3–5名样板NPC实现独立对白、走位、昼夜、回访；物件调查有状态与反应。
- C：一套真正可复用的角色动画/对话方向/室内外音景/开门音效/光照与规范UI，禁止占位素材标成终稿。
- A：两场有区分度的剧情Boss，含非致命条件、多职业和战败恢复；记录真实战术动作，不能用跳过胜利。
- D：通过新档与旧档连续实玩，进出屋、对话、Boss、奖励与场景恢复不出软锁。
- 门禁：内部测试者普通设置从头连续完成前3章，录制操作过程并附目标SHA；0 P0/P1阻断。

### Batch 3：规模复制到全游戏
- 地区生产：40地图逐张正式审查入口、机关、视觉、NPC、音轨、返程与安全落点；解决35+5分组连接。
- 战斗生产：66 Boss逐场机制和奖励矩阵，20职业流派、63怪与成长掉落及三难度平衡。
- 叙事生产：72章、120任务每条具备运行链，能够正常完成、重载、回访和三结局关联。
- 资产生产：正式地貌、立绘、动作图集、UI、BGM/SFX，附授权台账与反向资源引用表。
- 门禁：所有正典ID均有来源、玩家触发入口、持久化结算与真实回归证据；每张图至少1份可视人工验收记录。

### Batch 4：商业内容润色
- 地区差异化生活、美术风格统一、UI节奏、战斗镜头、打击反馈、场景光效、音乐混音。
- 用户体验：任务方向、地图缩放、对话快进与重看、键鼠/手柄、音量与减少动态效果等辅助设置。
- 经济：成长速度、装备购买与制作、掉落/稀缺度、所有难度长线调优。
- 门禁：通过美术/玩法/叙事/音效/性能/授权六类审查，停止以资源和JSON数量作为进度依据。

### Batch 5：发行候选验收
- Windows/Linux玩家回归、安装/更新/卸载/签名/崩溃记录；性能在指定目标硬件测试。
- iPhone若作为发行目标，则需iOS签名、触控、安全区、热性能、内存、功耗和权限的真机测试。
- 建议目标：支持的桌面配置持续60FPS；明确选择的手机配置持续30FPS。用P50/P95/P99帧耗、峰值纹理内存与场景切换时延报告证据，而不是凭单个平均FPS。
- 门禁：P0/P1已清零、完整玩家连续通关与存档恢复、第三方许可合格、目标设备验收通过，才允许RELEASE_ACCEPTED。

## 5. A/B/C/D下一批接口责任

| 线 | 工作重点 | 必须交付的证据 |
| --- | --- | --- |
| A | Boss与世界恢复冲突、前3章两场Boss策略、20职业基本可用性 | Boss命令日志、恢复测试、结果nonce/奖励无重复 |
| B | 晨露村居民和房屋体验、地图双向转换、任务完成旗标 | 稳定NPC/家具/门ID、地图位置信息、旧存档和实测路径 |
| C | 城镇动作、光效、室内外声景、正式资产及原图替换管理 | 资源运行引用表、授权来源、动画/音频演示和占位清单 |
| D | 本SHA编译、唯一世界交互/保存事务、全线集成与统一QA | 本次SHA对应日志、逐条P0/P1关闭证据、40地图/120任务矩阵 |

全程遵循 docs/DEVELOPMENT_BATCH_POLICY.md：仅main、不新建分支/PR、不强推；小批量提交并在一整批完成后做完整引擎验收，避免对每次提交重复触发Actions。历史绿色日志不能替代本次SHA验收。

## 6. 审计索引

- 主工程和流程：project.godot、scripts/first_act.gd、scripts/first_act_world.gd、scripts/first_act_battle.gd
- 安全存档和剧情：scripts/first_act_state.gd、scripts/story_runtime.gd、scripts/story_catalog.gd
- 战斗与交接：scripts/battle_boss_mechanics.gd、scripts/battle_world_handoff.gd、tools/A_LINE_WORLD_HANDOFF_DELIVERY.md
- D线独立架构：scripts/d_world_interaction/、docs/d_control/WORLD_INTERACTION_CONTRACT_AND_INTEGRATION_2026-10-26.md
- B线内容：scripts/world_npc_daily.gd、scripts/world_home_interactions.gd、story/data/b_npc_home_delivery_matrix_v1.json
- 正典审计：docs/d_control/matrix_chapters.json、matrix_bosses.json、matrix_jobs.json、matrix_maps.json、matrix_side_quests.json
- C线美术：docs/C_LINE_MORNING_DEW_AV_2026_10_26.md、docs/C_ART_SWAP_MANAGER_2026_10_26.md
- 统一批次：.github/workflows/godot-core-validation.yml、docs/d_control/CONTRACT_AND_RELEASE_GATE.md

**最终建议：停止堆叠内容规模，先闭合稳定引擎入口→唯一世界交互→晨露村前三章黄金切片，再复制到全部地图、Boss和剧情。**
