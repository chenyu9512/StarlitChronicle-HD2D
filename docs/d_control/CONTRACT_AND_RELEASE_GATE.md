# 《星灯纪行》D线：架构契约、风险和最终验收门禁（2026-10-26）

## 权限与边界

所有 D 线工具只放在 tools/d_control/，矩阵快照及报告放 docs/d_control/。只操作 main，不开分支、不建 PR、不强推，不触碰 A 战斗数值、B 地图剧情、C 美术音频及共享核心脚本，不修改 docs/qa-batch-trigger.json。每次提交读取最新 main SHA 并采取非强制、预期 SHA 相同才允许提交的方式。A/B/C 三线全部明确停止写入之后，D 才能修改共享文件并进行**一次**完整 Godot 4.7.2 集成测试。

## 可核验完成度：永不混淆策划与运行

静态快照源 SHA：8398587547f0b2fee3d1339d56ddf3cc8284405d。快照不是最新最终状态，后续三线继续写入时须重扫。详细逐ID证据见同目录五个JSON。

| 对象 | 数量 | 来源与工程边界 | 目前结论 |
|---|---:|---|---|
| 章节 | 72 | story/campaign/act_01..12.json | 有编排数据；入口/结算/存档重进缺最终Godot证据 |
| Boss | 66 | story/data/bosses.json 与 data/gameplay/boss_mechanics.json | 66 ID 对齐；64条机制状态 a_line_runtime_pending_godot，2条 legacy_runtime_not_replaced |
| 活跃地图 | 40 | data/levels/world_levels_v3.json | 40条正式美术均 not_final_painted；基础目录42条包括两个 prototype |
| 职业 | 20 | story/data/jobs.json 与 data/gameplay/vocation_profiles.json | 20条目录状态 design_ready_not_implemented，20个数值profile已在数据层存在 |
| 支线 | 120 | 原 side_quests 36，regional_quests_v2 36，companion_quests 48 | 36条主支线有五阶段文本；36地区+48同伴标明 text_only_not_runtime_bound 或 text_only_not_bound |

以上仅代表数据存在状态，**没有任何一项因此被判为商业级完成**。phase17/18支线可选后续扩展不重复增加正典任务数量。

### 证据等级

- DESIGN：ID、文字、数值、位置存在。
- WIRED：可追踪入口、实际游戏状态变更和相关触发器；必须附文件和代码路径。
- GODOT_VERIFIED：本次提交 SHA 的真实 Godot headless 端到端成功记录，区分正常、失败与恢复。
- MOBILE_VERIFIED：特定设备与构建版本的资源/内存/帧耗证据。
- RELEASE_ACCEPTED：三线冻结、P0/P1闭环、最终一批完整Godot验收通过、证据封存。

工具不以DESIGN或静态校验合格冒充GODOT_VERIFIED。

## 公共接口契约 v1（提案；不代表共享代码已有全部相同函数名）

| 事件 | 生产→消费 | 约束 |
|---|---|---|
| story.chapter.enter(chNNN) | B→A/C | 验证required_flags，不能因读档重入重复领取奖励 |
| battle.request(boss_id, chapter_id, context) | B→A | 必须在66个正典Boss表和机制表中匹配同ID，禁止通过剧情虚构战斗胜利 |
| battle.result(encounter_id, outcome, reward_nonce) | A→B | win/loss/escape三种结果；只有真实胜利可给对应flag，reward_nonce保证幂等 |
| world.enter(map_id, entry_point) | B→C | map_id必须在40个活跃区域；入口非法时退回安全坐标；不得静默传送已锁定地图 |
| audio.cue(cue_id, scene_id, priority) | A/B→C | 缺资源要报告并安全静音；不能阻塞战斗、任务或存档 |
| quest.complete(quest_id, flags, reward_nonce) | B→A | 120个正典ID；先满足前置、选择分支后再结算；重复回调不能重复发奖 |
| save.snapshot(schema, payload, checksum) | A/B→D验收 | 有版本、完整校验、写入临时文件、flush、备份与恢复；原子替换失败需可恢复上次完整快照 |

数据字典必须由各线提交：正典ID、输入字段类型、完成/取消事件、版本号、脚本入口、奖励nonce生成与旧档迁移。跨线变更先报D线冲突清单；不能多线同时改一个共享函数。

## 源代码确定性风险清单（不是设备上已复现的崩溃）

| 等级 | 代码证据 | 必须完成 |
|---|---|---|
| P0 | scripts/story_runtime.gd::save_story 直接 FileAccess.open(STORY_SAVE_PATH, WRITE)；没有V3式临时/校验/备份提交链 | B提供安全写盘补丁，D测中断写入、损坏恢复、无重发奖 |
| P1 | scripts/story_runtime.gd::load_story 支持v1/v2，但v1恢复调用_open_scene，存在重新进入场景的副作用路径 | 保存黄金v1样本，不应重置原分支或重放奖励 |
| P1 | scripts/game_state.gd (v1), scripts/first_act_state.gd (v3), scripts/story_runtime.gd (v2) 是不同保存域 | 分域管理和兼容回归，禁止隐式互相覆盖 |
| P1 | 66 Boss 两个正典表与 data/content/bosses.json 的12条基础目录是不同口径 | A提供逐场真实绑定、旧档ID兼容、失败/胜利结算证据 |
| P1 | 84条地区/同伴支线在数据头部明确 text_only；40地图全为正式美术待替换 | B给运行时注册与持久化证据，C给正式资产和授权台账 |
| P2 | scripts/content_db.gd::load_entries 每次调用读盘与JSON解析，内容/美术多版本同时存在 | 对热点加缓存策略但不得由D抢改，C测内存峰值/节点/渲染批次 |

### 存档兼容报告（静态审计）

V3：scripts/first_act_state.gd 使用.tmp写入、校验、有效旧档备份及失败回退；tools/smoke_save_integrity.gd 已存在测试案例，但**未针对本次D基线执行**。原型v1：scripts/game_state.gd 独立JSON保存，格式 version=1，需黄金旧档读写证据。剧情v2：scripts/story_runtime.gd 允许version=1/2，缺临时替换与备份。三种存档混用时未形成一个统一原子事务；D不能宣称跨文件断电安全已通过。旧版缺少分支决策信息不得自动替玩家选A/B或重新结算任务。

### 性能与发行风险

- 移动端发布必须检查：场景加载峰值、纹理内存、渲染层叠/draw call、音源并发、节点数量、P50/P95/P99帧耗、冷启动时间、地图切换及二次进入后的资源释放。
- 大资源扫描仅给出字节数和引用关系，不能用磁盘大小预测GPU内存或实机帧率。
- iPhone真机安全区、发热、电池、崩溃率、导出签名、授权素材和App Store相关合规无充分证据时不得标记为发布通过。

## 自动化测试矩阵与执行顺序

1. D线隔离单测：python -m unittest discover -s tools/d_control -p 'test_*.py' -v。用独立临时目录构造72章/66Boss/40地图/20职业/120支线的数据样本，故意制造重复ID、缺机制、损坏JSON、错误前置、缺预载、直接写正式存档；断言检查器真正报错，不更改玩家或测试主线状态。
2. 仓库静态审计：python tools/d_control/audit.py --root . --output /tmp/starlit-d-matrix.json --strict。输出318条逐ID状态矩阵及P0保存风险、资源字面引用。报告中含not verified，不意味着运行成功。应记录执行时main SHA。
3. A线专项证据：66Boss的真实击杀、失败、撤退、阶段、奖励nonce防刷及20职业状态与经济模拟。
4. B线专项证据：72章真实flag解锁、80+支线运行时注册、120任务每条持久化/分支/结算、40地图路径双向进入/读档恢复。
5. C线专项证据：正式素材资源链接、逐场动画音效、移动端峰值、素材授权和许可证明。
6. 三线全员明确停止写入且D取得冻结 SHA 后：核对跨线文件diff，解决冲突，才由D统一集成公共脚本，并用一个明确批次执行完整Godot 4.7.2测试。不得跳关、锁血、设无敌、预置胜利flag、模拟奖励成功。
7. 测试成功后再判是否具备商业级工程验收。未成功或P0/P1仍在即FAIL，不可用旧Actions绿色结果替代。

**本次D线测试状态**：本地验证器夹具样本有测试记录；仓库整套静态审计=NOT_RUN；完整Godot验收=NOT_RUN；iPhone实机=NOT_RUN；最终商业级统一验收=NOT_PASSED。所有状态是按对应执行范围分别声明。
