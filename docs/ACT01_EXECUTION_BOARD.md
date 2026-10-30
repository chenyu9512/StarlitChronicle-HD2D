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
