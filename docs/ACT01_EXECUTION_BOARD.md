# 第一幕12方向执行台账｜Batch 01｜2026-10-28

> 真实执行目标是6章正常可玩；这份记录不代表全部12个方向已完成。只在`Main2美术优化版`开发，绝不修改`main`。

## 当前基线和已经提交的代码
- 记录整理归档：`d506d2f9074104654f5c1fa98e277f65c7f6133c`。
- 本次Batch 01修复提交：`b93250a40288545d2a24cdc21d0086da6ca4d62e`。
- 第5章真实海岸潮池`saltwind_shoal_tidal_step`已在`data/levels/v4/coastal_scenery.json`定义，修复`tools/capture_act01_visual_evidence.gd`使用不存在的旧ID问题；改为摄像机取景、不传送玩家。
- `tools/smoke_c_main2_art_runtime.gd`加入第5章真实地标存在、材质语义、可见性断言。
- `scripts/first_act_state.gd`对无穷/非数字的时间与道具、负角色HP等不可能存档状态拒绝加载；`tools/smoke_save_integrity.gd`覆盖故障注入。
- 工作流的真实结论以 Actions 对应的完整提交SHA为准，当前为**已提交代码，验收运行中／待核验**。

## 本轮启动的全量门禁
| 方向 | 工作流 | 主要验证 | 签收 |
|---|---|---|---|
| 01 工程 | godot-core-validation | 静态目录、Godot冷导入、主控与状态接线 | 待同SHA CI |
| 01 工程 / 12 验收 | godot-full-smoke-suite | 所有smoke分片，保留失败 | 待同SHA CI |
| 01/06 | batch0-seven-qa-gates | 构建/奖励/回滚/旧档/战斗/任务/资产 | 待同SHA CI |
| 02 地图 | main2-map-regression | 路线、路标、布局、实机画面 | 待同SHA CI |
| 02/03 世界与室内 | m01-world-geometry-qa | 40图、68门、路线与室内恢复 | 待同SHA CI |
| 06 存档 | m01-services-qa | 交易防重复、失败回滚、城镇服务 | 待同SHA CI |
| 07/12 美术截图 | c-main2-art-runtime-acceptance | 6章实机地标与3室内截图 | 待同SHA CI |
| 11 Runtime | main2-to-runtime | 精简运行快照、Godot加载与实际smoke | 待同SHA CI |

## 未达成的商业签收，不能因绿色工作流改为完成
- 第一幕六章正常新档连贯人工通关、Boss数值与难度体验。
- 每张地图由美术总监逐张人工签收，尤其黑帆酒馆、浅滩、村庄。
- Windows目标机型性能、输入手感、音效、资源授权和发行验收。

## 执行与更新规则
每条任务写编号、改动SHA、涉及文件、测试结果、玩家证据、剩余问题。只有运行完成且同SHA成功的门禁才能标记`GODOT_VERIFIED`；未完成时标记`HOLD`。

## 2026-10-28 第二次实际修复（跨方向02、06、08）
- 修复首轮同SHA测试的真实失败：`smoke_world_object_transactions`因晨露村/白砂港街区名错配被阻断，`smoke_b_npc_navigation_safety`因NPC日程无法解析真实目的地而失败。
- 修正`data/levels/v7/town_ecology.json`六条活动街区，`data/content/npcs.json`五名NPC共25个日程项。
- 仅迁移目标区划名称，不修改章节锁、时间、触发、奖励、人物ID或路径算法；新数据与`town_director_v4.json`真实区划逐项匹配。
- 老资产QA仍有历史资源路径缺失，**必须保持失败**，不能伪造图片或关闭断言。
- 本次修复后全套QA重新运行；不能复用`2874f1c5`上的部分成功作为最新HEAD验收。

## 2026-10-28 第三次实际修复：第三章潮阀实体位置
- 旧V7潮阀与最新V3洞窟地形不符：`b` [89,50]、`c` [69,51]、`seal` [65,49] 位于坍塌区或不可达处。
- 将它们放到已经设计的洞窟连通区域：`b` [50,16] 洞内第二阀室、`c` [54,34] 第三阀室、`seal` [29,37] 可选遗物洞室；保留`a`、`b→a→c`顺序和原奖励、剧情与存档ID。
- 在`tools/smoke_b_act01_physical_reachability.gd`加入四处实际世界物件的碰撞、步行连通和位置一致性门禁；不是模拟开启机关或取消墙体。
- 当前状态：**已提交修复、待同SHA Godot运行验收**。

## 2026-10-28 全量Godot冒烟修复验收｜136/136
- **Godot 4.7.2 full smoke SUCCESS** at code+QA trigger SHA `ea49e69f00d70750d2a6aa60d340a0842739d247`.
- [GitHub Actions run 40623444126](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40623444126): shard 0 **34/34**; shard 1 **34/34**; shard 2 **34/34**; shard 3 **34/34**; total **136/136**, 0 failing.
- Real game geometry fix: `scripts/world_geography.gd` connects canonical dungeon/discovery objects by visible navigable tiles after final authored collision, preserving IDs, order and rewards.
- Runtime cave art fix: `data/assets/c_shared_terrain_v8.json` selects the approved V14 coast-04 water asset; `scripts/c_coherent_terrain_materials.gd` and `scripts/world_tileset_pool.gd` compile it into a real 256px 8x8 tile atlas using V18 water materials instead of stretching the original standalone image.
- Four obsolete graphical acceptance contracts now check live V18 imported sprites, physically rendered/native fallback buildings, actual 12 V4 room stage layouts and genuinely loaded textures. Deleted original signature SVG files are **not** falsely claimed to have been restored.
- Full test success proves scripted acceptance at this SHA, **not** manual six-chapter art/UX signoff; legacy asset-catalog QA is a separate unresolved migration gate. Later game-code changes require a fresh SHA-aligned full run.

## 2026-10-30 Batch 01 / 工程可靠性与素材同步（实施中）

- 定位到独立 Runtime 构建器 `tools/build_runtime_snapshot.py` 的真实阻塞：在遍历补充图片 manifest 时将项目根目录 `source: Path` 覆盖为图片资源字符串，后续 `source / name` 抛出 TypeError。修复为独立的 `image_ref`，保留项目根路径。
- 修复 Runtime 打包筛选遗漏 `assets/fonts/` 的问题：随精简游戏包收集自定义中文字体资源，确保之前提交的 `assets/fonts/chinese_system_font.tres` 不会在打包时丢失。
- `tools/verify_runtime_snapshot.py` 将中文字体资源和 `font_setup.gd` 作为独立运行包必需件，缺失则阻断发布。
- 新增针对路径变量覆盖和字体资源选择的 Python 回归测试，并接入 `main2-to-runtime.yml` 的独立打包步骤之前。

### 同步素材交付约定（适用于此后每个批次）

1. **新增画面/素材同一批交付**：场景设计的实体角色、物件、建筑、地形或UI新增时，必须在同一批次生成/导入其合法授权资源，记录稳定素材ID、用途、来源、尺寸及哈希；候选资源不能冒充正式资源。
2. **同一提交完成分配与接线**：同时更新有效的 `data/assets/art_theme_v2.json`、`data/assets/c_art_runtime_registry_v1.json` 或对应章节/地图/室内的正式美术清单及真实场景引用。严禁只有 PNG、没有运行时入口的“伪接入”。使用现有V3生成器与V2美术审核/替换管线，不再创建平行图片账本。
3. **同步验证而非仅计数**：对新增资源执行身份与路径检查、尺寸/透明度和来源哈希、Godot资源导入、真实场景加载和截图；独立 Runtime 必须确实包含素材。遇到加载失败或错人物/错位置，保留红灯，不以其他图片假充。
4. **交付记录**：每批记录素材ID → 生成/导入路径 → 分配ID → 使用的游戏实体/场景 → Godot截图/QA运行链接 → 最终签收。未通过的素材标注 `candidate` / `blocked`。
5. **本批范围**：本次仅工程修复，**没有新增游戏画面或图片**；因此没有需新生成的角色/场景素材。后续六章场景扩充时，此条为强制验收门槛。

**证据边界**：2026-10-30 的 Runtime 旧失败记录为 [41007555189](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41007555189)。代码提交不等于独立 Runtime 发布通过；应对修复提交运行新测试后更新本条。

### 2026-10-30 Batch 01 / 第二次 Runtime 失败闭环（实施中）

- 本批上一提交 `5630676b5bcfaa62b3cbf4748272294c93aa4398` 的 [统一质量门禁](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41009991766) 显示：Godot选择性 QA 成功，运行包构建成功，但 Runtime headless 首次加载时报 `res://shaders/hd2d_three_realms.gdshader` 缺失，连锁导致 `first_act.gd` 无法加载，冒烟脚本超时。**上一提交不得标记 Runtime 成功。**
- 根因：正式 `scripts/systems/ThreeRealmsOptics.gd` 预载 `res://shaders/hd2d_three_realms.gdshader`，但 `is_game_file` 只收录 `assets/shaders/`，漏掉工程根的 `shaders/` 资源。
- 修复方式：保留 `ThreeRealmsOptics` 原设计、不删去屏幕特效；Runtime 扫描纳入根目录 `shaders/*.gdshader` 及 `*.gdshaderinc`；发布验证把现用 Shader 设为必需项，补同类静态回归测试。
- **素材生成/分配/接入**：本批修复的是已经存在、已由运行脚本引用的正式 Shader 资产，没有制作新图、没有替换身份映射。保证现有 Shader 与项目运行脚本作为同一资源图打包。后续新增美术继续遵循上节同步生产与接入门禁。
- 新提交需要等待自身 SHA 的 Runtime smoke、独立快照与其他测试通过后，才允许将此项状态从 `待验收` 改为 `通过`。

## 2026-10-30 Batch 02 / 剧情 Boss 正式结局与回执（第一项，待同 SHA QA）

- **目标**：把第5章「缚潮古兽」非致命救援和第6章「潮歌守门人」共同见证做成不可被其他调用方绕过的 V3 原子结算约束。主控制器此前已有战斗前置判定，本批补强底层 `BattleV3Settlement.settle_victory`。
- **修复**：这两场 Boss 的 `story_resolution` 必须分别严格等于 `nonlethal` 与 `testimony`，包括空字符串都拒绝。不会通过普通胜利补领金币、经验或切换剧情；战斗失败路径及第2–4章原行为不变。
- **回归**：扩展原 `smoke_act01_six_chapters_normal.gd`；对缺失/错误的剧情结局调用结算入口，断言交易失败且 V3 状态不变；真实六章普通角色/真实指令回归仍要求战胜五 Boss，并检查第5章 `ch005.beast_released`、第6章 `ch006.lighthouse_testimony`、双份奖励回执中的 `story_resolution` 和最终磁盘重载状态。
- **素材同步**：本项只变更现有剧情结算与测试，**没有新增或更改画面素材**，不需要生成新 PNG；既有第五章古兽和第六章守门人美术及运行资源保持原接线。以后新增特效/人物/场景继续执行“生成 → 分配 → 正式接入 → Godot 实画 → Runtime 包含”的强制门禁。
- **验收口径**：代码提交后，只有对应新 SHA 的统一 CI（含六章 normal smoke）成功、Runtime 需要时成功发布，才将本任务标为通过；这不是人工六章无传送通关和五 Boss 数值平衡的完成证明。

## 2026-10-30 Batch 02 / 战败回退与五场 Boss 重试（待同 SHA QA）

- 上一项第五/六章剧情结局补丁 `7d2d799ed06d16e323df05ff5df9f511d507991a` 的 [统一 CI 和独立 Runtime](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41012179363) 均已成功。剧情结果底层门禁通过自动化验收，人工真实游玩尚未验收。
- **战败数值修复**：仅扣除实际持有金币与 15G 的较小值（0—15G），并把准确 `lost_gold` 返回交易结果；战败提示显示真实损失而非笼统上限。
- **Boss 重试保护**：`settle_defeat` 拒绝使用稳定 `boss:` 胜利回执充当失败 ID，强制使用每次战斗新生成的 `random:` 回执，确保同一 Boss 的再次挑战允许独立、准确地结算战败，同时每次败北只扣一次。
- **回滚与回归**：扩展真实 Godot V3 故障注入脚本，覆盖 0/7/15/30G、重复提交、失败存档回滚、使用同一回执重试及同 Boss 下一次独立战败；将已有 `tools/d_control/smoke_live_battle_v3_transaction.gd` 明确纳入统一 CI 的 systems 分组，验证全局战斗交易而不仅是表面六章剧情。
- **画面素材**：本任务仅修改已有战斗结果文字及交易逻辑，不引入新的角色、场景、贴图或特效；现有 HUD 字体与战斗素材引用保持不变。以后新增战斗特效时仍需同步生成、登记、接入和截图验收。
- **质量边界**：提交后仅同 SHA Godot+Runtime CI 通过才可标记本任务成功；人工五场 Boss 手感和真实 iPhone 验收仍另行执行。

## 2026-10-30 Batch 02 / 第五、六章 Boss 目标提示与正式战斗 HUD（待同 SHA QA）

- **当前问题**：`boss.ch005` 与 `boss.ch006` 的资料仍用“破防后取胜 / 拆卸技能直接攻击”等旧提示，而实际战斗规则要求第5章朔弦先吹双哨，分三次解除星锁；第6章凭三枚灯芯碎片，接续四位不同归航者的见证。
- **数据**：更新 `data/gameplay/boss_mechanics.json` 内两位 Boss 的目标、开场提示、阶段描述和专属行动指导。不修改 `goal=legacy` 和 `settlement=legacy_story`：这是专属章节运行器所需的内部兼容标识，不能错误改为通用机制结算。
- **游戏内实际接入**：在正式 `scripts/first_act_battle.gd` 的开场文本和战斗 HUD 显示这两场专属 Boss 的已登记目标与行动提示；不激活通用 `BattleBossMechanics` 第二胜利途径。保留原双哨、星锁、灯芯、见证的真实动作及存档回执。
- **验证**：新增 `tools/smoke_act01_boss_objectives.gd`，使用真实 `EncounterRegistry`、`Battle`、`FirstActState` 和现有 HUD，检查第5/6章开场提示、实时 HUD 目标、专属行动按钮与星锁/共鸣进度，并断言通用胜利通路保持关闭。纳入统一 CI systems 分组。
- **美术**：本批新增的是游戏内文本说明，复用现有 HUD、中文字体、角色和 Boss 动画贴图；**没有新增图片或视觉实体**，不生成重复素材。任何后续新图仍必须在同提交完成生成、资产注册、场景接线与真实截图验收。
- **验收**：必须以本次新 SHA 的 Godot+Runtime CI 实际成功为准；人工五 Boss 战斗难度和 iPhone 实机画面仍需单独签收。

## 2026-10-30 Batch 02 / 五场 Boss 预告与防御反馈（待同 SHA QA）

- 上一项 `20b3168e4db1c6601fd65e55b1ad358a8c47fac9` 的 [统一 CI 和 Runtime 发布](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41015800446) 均通过，代表目标提示代码的自动化门禁合格，不代表真人难度签收。
- **可玩性问题**：此前 `_telegraph_next_boss_action` 将任何非“普通攻击”的标签（包括“观察”等常规动作）都当作充能重击播放红色警示，玩家难以判断什么时候应优先防御。此项使用同一回合已经冻结的 `round_boss_intent` 来区分危险强攻（倍率 >= 1.25）和普通动作；常规意图继续展示在敌人状态栏，但不触发警戒音效和红色蓄力图示。
- **战斗反馈**：强攻预告显示敌人的目标偏好（倾向当前较低 HP / 高 HP / 低 MP，或目标不固定）以及“防御可减伤”；明确“倾向”，不假定治疗后攻击目标不会变化。沿用原 `CombatRules` 伤害/防御计算，不改数值、奖励、剧情 Boss 的合法胜利条件。
- **测试**：新增 `tools/smoke_act01_boss_telegraph.gd`，在实际 `Battle` 和 `BattleHud` 上覆盖第2—6章的普通回合、强攻回合、一次性警告及防御减伤，同时检查第5—6章不会激活通用胜利途径；已挂到统一 CI 的 systems 冒烟列表。
- **素材**：只改变复用中的预告字样和警告触发，不新增角色、特效、画面贴图。原预告 VFX/SFX 和中文字体仍为已接入正式资源，无重复生成/登记必要。
- **证据边界**：此项提交之后仍要以新 SHA 的 Godot QA、Runtime 发布结果判定；五场真人正常等级战斗时间和 iPhone 真机体验尚需后续实测。

## 2026-10-30 Batch 02 / 五场 Boss 无作弊节奏基线与回合反馈（待本 SHA QA）

- 前一提交 `72d391fad9b358ee20c7cc41ae1faae913b49580` 的 [统一 Godot QA 与 Runtime 发布](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41016453733) 已成功；当前提交的测试需要重新独立通过。
- **玩家反馈**：在第一幕真实 Boss 战斗 HUD 持续显示当前回合数，即使多敌人单位在场也不丢失计数；不改回合顺序、攻击伤害、奖励和正式胜利机制。
- **无作弊节奏基线**：扩展已运行的 `tools/smoke_act01_six_chapters_normal.gd`；沿用真实剧情调查、正式 NPC/选项、第一幕五 Boss 的战斗指令、V3 存档回执及无作弊新游戏流程。每场记录开战队伍等级、实际回合、指令次数、防御/草药/专属行动数、战前/战后生命和草药存量；在 CI 日志输出 `ACT01_BOSS_PACING` JSON 行，便于后续用数据调难度。
- **软锁门槛**：五场 Boss 均须拥有实际专属行动并成功结算；每场不得超过 24 回合或 64 次玩家指令（超限则 CI 失败），防止把 100 次超时上限当作可接受游戏手感。继续保留无作弊、真实奖励回执与六章重载验收。
- **证据边界**：这是一个 Godot 中沿既定行动策略的单次标准剧情基线，部分镜头/步行环节仍使用标记定位，**不是**统计意义上的战败率、不同构筑胜率或真人完全步行的通关报告。不能据此擅自修改五 Boss 数值；后续应补不同装备与职业、攻防策略的实测分布，再做有依据的调整。
- **美术**：本项新增的是复用现有 Label 的回合计数和自动化指标，不增加新图片、动画、场景物件；正式中文字体、战斗 HUD 和五位 Boss 素材保持原接线。后续新增视觉实体时仍要同步生成、登记、接入并拍摄实机截图。

## 2026-10-30 Batch 02 / Boss 真实压力与防御效果量测（待本 SHA QA）

- 前一提交 `24517c878fceae9a2c4774c4ae2bb8484fb83c4e` 的 [统一 Godot QA 59/59 与 Runtime 发布](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41017579506) 均成功。读取其 Godot 实际六章 `ACT01_BOSS_PACING`：第2—6章分别为 `4/7`、`4/7`、`2/3`、`2/6`、`2/4`（回合/指令）；五场均为0次防御、0次药草，角色开战最高等级分别为4、8、12、15、18，而推荐等级是2、3、4、5、7。
- **风险判断**：流程可通，但推荐等级曲线与自动剧情实际升级速度明显不匹配，而且原测试策略不需要防御或治疗。暂不盲目削减 HP/经验，因为两章专属 Boss 不以伤害清空 HP 结算，且关卡 XP 同时影响后续存档。
- **实测补充**：在 `first_act_battle.gd` 新增只在战斗本地存在的出手数、实际 HP 伤害量、防御命中次数。数值来自真正执行的 `_enemy_strike`，不改变 V3、AI、伤害计算、奖励或故事胜利条件。六章无作弊流程每场输出这些字段、角色当前最高等级与配置推荐等级差。
- **真实防御验证**：新增 `tools/smoke_act01_boss_guard_pressure.gd`，使用真实 Godot `Battle`/状态/职业系统/五章 Boss 配置，对每场冻结相同强攻回合、同一随机种子，分别在无防御和全员防御下实际执行 Boss 出手；核对 HP 伤害减少、命中次数和战斗本地统计一致。纳入统一 CI systems 分组。
- **美术与素材**：本项是内部战斗压力指标和自动化验证，不添加任何贴图、音效或画面元素；现有 Boss 动作、HUD、特效及中文字体维持正式接线。如果未来采用新的阶段特效，将同批完成授权素材、资源ID、运行时引用和截图。
- **下一阶段决策**：取得本 SHA 的新六章 metrics 与五 Boss 真实防御结果之后，再决定是调整关卡经验成长、敌人动作节奏还是部分战斗机制；真人低配/低等级胜率另行验收。

## 2026-10-30 Batch 02 / 经验成长与奖励来源归一（本 SHA 待 CI）

- [上一提交统一 QA 60/60 与 Runtime 发布通过](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41020436902)。真实战斗日志第2—6章初始等级 4/8/12/15/18，推荐为 2/3/4/5/7；五场战斗实伤 16/3/1/11/1 且无需草药和防御，但五 Boss 真实伤害防御对照明确证明防御能有效减伤。
- 通过追踪真实 `QuestV3Settlement.settle_scene_effects` 和 `settle_local`，修正第一幕三条**真正发 XP** 的渠道，而不是只改游戏任务目录：`story/campaign/act_01.json` 六章结算 XP = 35/40/45/50/55/60；`data/first_act_side_quests.json` 六条本地支线 XP = 20/24/28/32/36/40；`data/gameplay/combat_progression.json` 第一幕 Boss XP = 45/55/70/85/100/115（第1章尚无剧情 Boss）。
- 对齐 `data/content/quests.json` 的前六章主线任务登记 XP 与剧情实际发奖数值；`EncounterRegistry.story_boss` 在前六章以已登记 `boss_xp` 为权威，修复旧默认 `150 + chapter * 65` 抬高实际经验的问题。第7—72章奖励算法不变。
- 保留金币、药草、职业经验、伤害、Boss 特殊胜利条件和 V3 原子回执不变。旧档已经取得的经验不会回溯扣除，旧档难度仍需人工验证；朔弦的预设入队等级目前仍为8，不在此次减少其已拥有的等级。
- 增加 `tools/validate_act01_xp_pacing.py` 静态验收实际奖励来源一致性，并在 `tools/smoke_act01_six_chapters_normal.gd` 的**真实六章通关**中检查初始双人角色的章节推荐等级差≤2，现有 Boss 实际伤害、回合数、战斗回执仍持续验收。
- **素材**：数值配置与 QA 脚本变更，不新建任何战斗画面、人物、建筑或动画，无需新 PNG；已接入字体/Boss素材/场景不变。后续新增素材依然要求同批生成、登记、接入与实景检查。

### 2026-10-30 Batch 02 / Godot 4.7 GDScript 解析兼容修复

- 经验归一首次提交 `d3b42bf46f7a5971b505c07f79e3a10dd5c08670` 的 [CI](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41022260519) 在静态奖励校验通过后被 Godot 导入解析拦截：`encounter_registry.gd:128` 调用了仅支持两个参数的 `maxi()`，原因是新增的第7章以后兼容分支使用了三个参数。
- 立即改成等价的嵌套 `maxi(maxi(a,b),c)`；不改变第一幕奖励数据和其他幕逻辑。严格要求重跑新的完整 SHA Godot QA 及 Runtime 发布门禁，之前失败提交不得标记完成。

## 2026-10-30 Batch 02 / 第四章朔弦动态入队平衡（本 SHA 待 CI 验收）

- 上一提交 `745725e89d555292b71e51e27d172fa09b133074` [统一 QA 61/61 和 Runtime](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41022389884) 已通过，正式六章实测开战主角等级依次为 Lv2、3、5、6、7；朔弦第五章 Lv8、第六章 Lv9（初始双人 Lv6、7），固定 Lv8 入队引起的等级优势未随经验曲线修复。
- **调整**：第四章首度招募 `char_seeker` 时按原两位主角等级的平均数取整，最高受 `level_cap` 限制。朔弦新入队 Lv5 时使用原角色的专属基础 HP136、MP35、攻30、防15、速16，每多/少1级按现有 `give_rewards` 的 15HP/6MP/4攻/2防同步缩放。
- **旧档安全**：已经在 `actors` 中的朔弦一律提前返回，不修改已拥有的等级、损伤、XP、职业、背包或 V3 记录；旧存档中原 Lv8 的朔弦仍保持 Lv8。没有使用开发者传送或伪造奖励。
- **实际验证**：新 `tools/smoke_act01_recruit_balance.gd` 在 Godot 内检查 Lv5/5、Lv5/7、Lv18/19、Lv1/1 队伍入队属性、重复入队、V3 快照兼容和已招募旧档；纳入 systems 质量门禁。原六章真实流程额外检查第五、六章第三人等级与双人主角差≤2。
- **画面与素材**：只有角色成长数值与测试发生变化，没有新增人物模型、贴图、场景或特效；朔弦继续复用正式注册的角色像素图和战斗动作素材，不生成重复资产。后续如新增入队演出则同一批次同步制作、分配ID、接入和截图验收。
- **质量边界**：本次代码提交不等于实际六章 Godot 测试成功，必须看到本 SHA 的 QA 和 Runtime 全绿才能标记完成；真人 iOS 试玩与不同存档兼容仍单独验收。

## 2026-10-30 Batch 02 / 第五六章专属Boss分回合推进（本 SHA 待 CI）

- 前一提交 `5873ea398963d0b5aed743918517e4a2293a7cc0` 的 [统一 Godot 62/62 与 Runtime](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41023587294) 均通过，真实队伍第五/六章已回到 6/6/6 与 7/7/7，但这两场仍只需2回合：三个星锁和四份见证能由多名队友在同回合连续推进，缺乏攻防选择。
- **机制**：第五章双哨/拆锁和第六章见证新增战斗局部 `story_progress_round`，一个真实回合最多推进一个剧情阶段；不会触碰 V3 存档、Boss 胜利 nonce、星锁和四位见证身份。第五章至少6回合、第六章至少4回合。紧接着的队友必须选防御/药草/攻击；专属按钮置灰并显示下一回合可继续，直呼 `_act("special")` 也拒绝同回合重复推进。
- **可玩性**：已有红旗过载复位、灯塔倒计时与敌方正常出手仍真实执行；不是简单提高 Boss HP。保留每场24回合/64指令的上限、真实失败重试/奖励事务和原 HD-2D 特效。
- **QA**：新增 `tools/smoke_act01_boss_phase_pacing.gd`，通过真实 Godot Battle 检查两场的回合锁、按钮置灰、敌方出手、最低阶段回合数、唯一剧情结局且没有通用击杀捷径；接入 systems CI。原 `smoke_act01_six_chapters_normal.gd` 改为在阶段锁定时实际防御，并要求每场至少2次敌方攻击/2次防御选择及第5/6章最短回合数；仍需验证无作弊、真实地图剧情、原子回执和存档重载。
- **素材/画面**：仅调整原战斗按钮文字与既有剧情机制资源引用；原 Boss/VFX/HUD/字体不变，没有新增图像或 UI 实体，不需要制作或再注册 PNG。后续新增任何视觉资源仍应同批生成、分配、接入与截图验收。
- **状态约束**：提交后必须由本 SHA Godot 质量门禁和 Runtime 实测通过，才能将本项标为完成，真人连续通关及 iPhone 真机另行验收。

## 2026-10-30 Batch 02 / Boss 分回合回归失败闭环（待新 SHA QA）

- 追加的 [统一 QA Run 41025217886](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41025217886) 在 Godot 导入成功后为 **61/63**，Runtime 发布被跳过（不是已成功）。失败详情已核实，不回退第5/6章分回合玩法。
- **真实机制已有证据**：Godot 新专项测试实际得到第5章 `7` 回合、`13` 次玩家行动、`6` 次敌方出手、`6` 次防御/间隔选择、结局 `nonlethal`；第6章 `4` 回合、`7` 次玩家行动、`3` 次敌方出手、`3` 次防御/间隔选择、结局 `testimony`。原完整六章无作弊测试也通过；不能把单项冒烟的 PASS 文本当整个进程验收成功。
- **失败1（旧 route-only smoke）**：`tools/smoke_first_act_flow.gd` 仍连续调用 `_act("special")` 100次，未处理新增回合门禁，导致第5章循环卡死并串联报剧情标记未完成。更新旧路线检查：关键阶段已完成的回合先正常 `guard` 并推进真实回合，不跳过三锁/四见证。
- **失败2（专项进程清理）**：`tools/smoke_act01_boss_phase_pacing.gd` 虽显示两场阶段/伤害的 PASS，结束时使用 `queue_free` 后立即 `quit` 导致 ObjectDB 资源仍在队列、实际脚本退出码为1。增加 `await process_frame`，先清空正式 Godot 战斗节点后再退出。
- **美术同步**：只修测试策略/节点清理，无新增图像、音效、场景实体；沿用先前登记并接入的战斗素材。需新 SHA 的 63/63 Godot QA、独立 Runtime 发布通过，才能宣称本批完成；iPhone 真机仍另行签收。

### 2026-10-30 Batch 02 / Boss 单项 Godot 资源释放二次修复

- 上一个测试修复提交 `a10f8fe627ca3c6a7bf7912a64fab11ae8a9a804` 的 [统一 CI](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41026058843) 已将六章旧流程冒烟从失败修复为 PASS，整体 **62/63**；新专项 `smoke_act01_boss_phase_pacing.gd` 的玩法断言也全部通过（仍 7/4 回合），但 `queue_free(); await process_frame` 只把退出时未销毁的 Node 从 12 减少至 6，进程仍返回1。
- 原因是独立 `SceneTree` 测试在结束帧仍有延迟删除的战斗子节点；正式运行的战斗回调不受影响。现将**仅测试脚本**中的 `battle.queue_free()` 改为 `battle.free()`，同步销毁本次专测创建的全量节点树，不需要异步帧冲洗。第5/6章玩法、动态奖励、字体和既有素材均不变。
- 下一次 CI 必须完整验证 63/63 和 Runtime 成功；不得用“测试脚本打印 PASS”替代 Godot 进程退出码。

### 2026-10-30 Batch 02 / 第一幕专项 QA 变更强制触发完整 CI

- 修复 `f72b4e5749804bbc286800c3d1f7a1dce990f6c1`（新阶段测试立即释放节点）后，发现统一 `.github/workflows/main2-ci.yml` 的 `push.paths` 只列出旧六章测试而未包含 `tools/smoke_act01_boss_phase_pacing.gd`，导致**仅修改该专项冒烟并不会触发新的质量门禁**。
- 本批将 `tools/smoke_act01_*.gd` 及 `tools/validate_act01_*.py` 加入触发路径。所有第一幕专项回归与经济静态校验修改都需要重新跑新的 Godot 测试，而非借用旧 SHA 的绿色结果。这次 workflow 自身变更也触发完整 CI。
- 本轮没有新增游戏画面或素材，原分回合 Boss 玩法与美术接线均保持不变。需在新 SHA 获得 Godot 63/63 与独立 Runtime 通过才可最终签收。

### 2026-10-30 Batch 02 / 分离 Boss 专项验收与 SceneTree 退出生命周期

- `59e1bdf2d4089e72eb104ebf5216109768970a31` [完整 CI 结果](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/41026813482)：导入、旧六章测试、无作弊完整六章均成功，只有 `smoke_act01_boss_phase_pacing.gd` 检查结果正常但退出仍有 11 ObjectDB 残留（**62/63**）。将 Battle 改为 `free()` 也未解决，表明不只是 Node 的延迟删除，还涉及脚本的 RefCounted 局部变量和终止时序。
- 本次测试把 `progress`、`core`、`battle` 清空后让 `_run` 返回，再用 `call_deferred("_finish_test")` 单独等待三个引擎帧，最后按完整运行结果退出；避免在仍持有战斗数据的脚本栈内调用 `quit()`。所有场景与 VFX 照常构造、攻击/防御照常执行；不得通过删掉胜利演出或降低断言来获得绿灯。
- 本次没有新增游戏画面/素材。必须待新 SHA 63/63、正式 Runtime 发布后标为通过。

### 2026-10-30 Batch 03 / 六章真实视觉取证字体可信度门禁（本 SHA 待视觉 CI）

- 前一阶段 `32d395b0f173b27faa9513de543427d552b55a2c` 统一 Godot QA 与 Runtime 均通过；第5章7回合、第6章4回合的实际专属战斗已完成自动化验收。
- 将 `capture_act01_visual_evidence.gd` 的系统字体覆盖移除，截图必须使用实际运行中的 `FontSetup.cjk_font` FontFile。验证真实字体 SHA256 与 `assets/fonts/NotoSansCJKsc-Regular.otf` 一致、19个中文/日文/英文基本字形存在、三个正式 UI 控件使用同一 FontFile。
- 真实画面仍为六章外景+旧屋/收容所/酒馆+重要地标26帧，截图目录增加 `cjk-font-evidence-v1.json`。校验器和负面用例拒绝系统字体假冒证据；GH Workflow 截图脚本变更自动触发并上传画面和报告。
- 不伪称 iPhone 已验收：Godot Linux 可见字体证明不等于 iOS PCK payload 或 Apple 真机最终光栅效果；`ios_ipa_payload_verified`、`ios_device_verified` 固定为 false；人工图片审稿仍需单独完成。
- 本项仅是来源取证/代码/测试工作，不添加新美术画面，因此无需注册新资产；后续需要新增视觉实体时严格执行生成 → 唯一ID → Manifest → 正式渲染引用 → Runtime 打包 → 实际截图。
