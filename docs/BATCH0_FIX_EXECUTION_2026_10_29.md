# 《星灯纪行》Batch 0 逐项修复执行台账（2026-10-29）

> GitHub在线Main2实际修复。保留main，不新建分支、不提交PR、不强推。状态只能区分**代码已提交、同SHA CI成功、失败、未测试**，旧提交验证不能覆盖最新HEAD。

## 本轮实际完成的源码修复

| 序号 | 对象 | 修改内容 | 提交 | 证据与状态 |
|---|---|---|---|---|
| 01 | `scripts/rpg_core.gd` | 队伍切换返回文案由ASCII句号修正为完整中文句号，与既有成功契约一致；不松动人物时间线门禁 | `6de9be79383a` | 代码已提交；最新同SHA RPG测试未核实 |
| 02 | `tools/d_control/smoke_ch021_direction_gate.gd` | 第15章现为 active 合法试炼，拒绝使用过期“必须pending”断言；同时验证ch014无登记时不能生成控制器 | `ae72701a960a` | [隔离版章节门禁CI成功](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40881108050)，只证明该次提交 |
| 03 | `tools/audit_art_pipeline_v3.py` | 第三方素材删除后，允许两份已退役的历史来源统计清单缺席并标记警告；继续强制核查109正式语义槽、黑帆酒馆、V18、源文件是否存在 | `b77d0c983326` | 后续[Art CI日志](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40881589245)证明109/109运行源可见；仍查出地板路径真实错误 |
| 04 | `scripts/c_art_overrides.gd` | 旧素材清理后，动态从当前`active.json`把生成的真实图像注册到美术UI/DLC槽位；不把候选标注为视觉签收 | `4aa0cc4c64c0` | 代码已提交；后续主题兼容专项确认生成素材注册有效 |
| 05 | `tools/smoke_c_art_packs.gd` | 主题切换测试改为检查现行生成器、禁用旧包、可安装/启用/卸载用户DLC、界面有实际素材 | `9b5904e19601` | 后续[美术主题兼容CI成功](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40881589228) |
| 06 | `tools/smoke_c_uploaded_later_pack.gd` | 不再强制恢复已清理的6组第三方素材；改为校验旧包拒绝启用、正式生成素材可加载且可见 | `76a2899849ee` | 与上一项同SHA美术主题兼容CI成功 |
| 07 | `data/levels/v4/interiors/map_coast_02__tavern.json` | 正式黑帆酒馆地板源从已删的旧SVG改为V10 256×256生成图集，和唯一V2语义槽一致 | `e2a471d874cc` | 当前HEAD静态读取确认V4/V2/生成清单路径完全相同，图集尺寸256×256；同SHA Godot/人工画面未完成 |

## 当前证据边界

- 验证成功（仅对应明确的Actions）：第21章隔离门禁；最新修复后的美术主题包专项。
- 通过静态核对：黑帆酒馆正式V4图集与主题索引及生成资源清单路径完全一致，且生成清单尺寸256×256。
- **仍未通过全游戏发行验收**：最新HEAD统一Main2 Godot全量门禁、第一幕完整六章玩家通关、40地图通行/画面、153室内、66Boss、120任务、20职业以及Runtime正式发布均须另行验收。
- 最近历史失败仍包含实际海岸场景的旧纹理依赖、Boss/主角身份图片、部分回归测试和图片人工审美缺口；不能仅把旧测试替换成空测试。今后以**失败日志→生产代码→指定SHA CI→玩家画面**顺序修。

## 下一批 P0 处理顺序

1. 拿到`e2a471d8`后的完整统一Main2 CI日志，按真正失败用例逐个修复（当前可能处于排队/执行，不继承更早的绿色报告）。
2. 核对第一幕主角/Boss以及五地图可见渲染节点与生成资源索引，用正式身份美术补齐实际缺图，不重建旧第三方目录。
3. 真实修复黑帆酒馆完整空间布局、家具尺寸与进退、收容所、浅滩、灯塔碰撞和截图。
4. 验证新旧档与战斗结算，优先保护任务时间锁、重复奖励及人物代际权限。
5. 复验后才允许Runtime发布；任何只读无素材GameCore镜像成功不等于游戏发行成功。

执行规则：修改文件前读最新blob SHA，同文件串行写，不造伪截图、不绕过游戏正常流程。


## Batch 0 连续修复批次｜2026-10-29｜第二轮

### 故障证据

- Main2统一门禁 [run 40881785276](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40881785276) 在`e2a471d8`提交仅 **39/55**；Godot 4.7.2冷导入本身成功，16项静态/冒烟失败不能视为商业合格。
- 具体阻塞：40个V3地图尺寸审计误比对不存在的atlas字段、`art_source_contract`已删除、发行包作弊入口缺少editor门禁、旧源blob审核与已删除的图片/第三方迁移JSON冲突、第一幕1/3章证据热点被旧冒烟脚本跳过、V18场景脚本仍指向删掉的旧素材、V14场景加载器拒绝生成器新路径、NPC尝试解析已移除的V12清单、旧船只仍引用已删资源。

### 本轮线上源码实改（全部在Main2，仅指代码提交成功）

| 目标 | 文件 / SHA摘要 | 说明与验收边界 |
|---|---|---|
| 40地图审核 | `validate_global_runtime_contract.py` / `97ec34ce` | 校验实际V3尺寸且只有atlas显式给出grid_size才做跨表比对，不篡改地图数据 |
| 发行包作弊拦截 | `cheat_panel.gd` / `53f274ce`，`first_act.gd` / `2611a339` | 发行版本禁用调试菜单/命令；禁用已保存的无敌、无遇敌、5倍经验及速度作弊 |
| 第一幕正式资源静态检查 | `validate_first_act.py` / `3787623c` | 从旧第三方图片导入检查改为真实V9 `active.json` 中451图和401张法线的SHA256、路径、剧情、Boss身份校验；实际画面仍未签收 |
| NPC缺失旧资源清单 | `c_art_regional_npc.gd` / `29bd8804` | 文件不存在时不再触发JSON解析错误，直接回退NPC具名生成4方向精灵 |
| 玩家证据调查回归 | `smoke_first_act_flow.gd` / `7f66a3ca`，`smoke_act01_six_chapters_normal.gd` / `36df4244` | 通过真实证据热点UI按钮完成第一、三章调查，不直接写完成旗标/假胜利 |
| V18海岸正式布景 | `c_act01_hd2d_dressing.gd` / `b2c1e724` | 从manifest匹配真正的V10 `prop__hd2d__*`纹理ID，不再因旧路径限制整张地图遗漏布景 |
| V18资源完整性 | `validate_c_act01_hd2d_v18.py` / `8c5ce080` | 17个实际场景布置位、14种精确道具身份、11张256px材质，均验证原生V10 SHA256；审美依旧未测试 |
| 旧第三方审核更新 | `audit_act01_third_party_art.py` / `e25be5cd` | 只审计仍在使用的109语义槽、原图不存在、现行生成图片与6章/2关键室内；商业视觉验收参数仍不能假通过 |
| 港口船只实际纹理 | `c_act01_matched_props_v16.gd` / `81a46e6e`，`validate_c_act01_matched_props_v16.py` / `f5b3f48a` | 正式入口使用唯一`prop.harbor.dock_boat`身份、图像源/尺寸/哈希验证，不再要求已删原船/错误木桥 |
| 第一幕海岸语义纹理 | `c_act01_semantic_art_v17.gd` / `a5c98e51`，`validate_c_act01_semantic_v17.py` / `71c2d682` | 旧palm_tree正确映射真实V10红树林语义槽；洞窟水晶与海岸水晶共用同一个具名素材 |
| V14场景真实资源入口 | `c_act01_global_art_v14.gd` / `e80d03c8`，`validate_c_act01_global_art_v14.py` / `c83487e4`+`f63b5b0f`+`70162831` | 允许V14原有场景ID使用生成器V10资源；验证45图（10道具/6场景/9怪/5Boss候选/10地形/2背景/3UI）及SHA，明确区别章节Boss ID与生成图像ID。 |

### 已确认与未确认

- 已确认历史提交的 **Godot冷导入成功**、`smoke_save_integrity.gd`成功、`smoke_rpg_core.gd`成功、地图迷雾/小地图/可达性门禁成功；这些均为原`e2a471d8`SHA的结果，不能自动转移到最新SHA。
- [Main2 美术专项](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40885262725) 在旧`f63b5b0f`源验证到V14生成背景命名转换错误；已在`70162831`改正，**该修复需要同SHA复验**。
- **未测试/未通过**：最新统一门禁全部55项、真实玩家第一幕六章无作弊通关、全部美术实际截图的身份/美观人工签收、Boss数值及Runtime发布。任何单次成功的GameCore无美术镜像≠完整游戏成功。
- 现存场景对已删旧资源的引用必须继续逐项修复；不可以删断言、标记通过或者临时制造假图片掩盖美术缺口。


## Batch 0 续修：实机美术回归与正式图集清理（2026-10-29）

本轮真正修复的运行链与同SHA证据：

| 修复对象 | Main2修复提交 | 实际改变 | 截止目前的验收 |
|---|---|---|---|
| V18 Godot 运行图集合同 | `1eda5f42`、`e9a377b3` | 测试正式V10 11类材质256px纹理和晨露村实际大橡树ID，保留地物可达与碰撞断言 | **成功**：`e9a377b3`美术专项，V18 smoke返回0 |
| 第2章收容所专用地砖 | `90feb747` | 正式V4室内从错误的老酒馆SVG切换至自身`map_coast_02__shelter.png`生成图集 | **成功**：`e9a377b3`实机港口室内smoke返回0 |
| 收容所/黑帆酒馆家具身份 | `428d8665`、`3f2cda35`、`a6cb8cdf` | 游戏真实室内脚本只使用V10语义家具源和已有用户整包主题，不再引用已删的`act01_tavern_v2`/`act01_shelter_v3` SVG；测试核对20件酒馆/11件收容所实景装饰及交互 | **成功**：`e9a377b3`美术专项，`smoke_main2_act01_harbor_rooms_visual`返回0 |
| 真实场景灯塔视觉 | `cc683366`、`ebdea364` | 96×128生成灯塔图显示为故事地标的大画面尺度，不动真实出生格与碰撞；专项检查真实渲染宽高 | **成功**：同专项`smoke_c_act01_art_production_v10`返回0；人工美术品质未签收 |
| V17海岸角色与场景图 | `986f3b59` | 从删除的V17图像路径切换至当前语义V10源，同时检验实体Sprite2D | **成功**：同专项`smoke_c_act01_semantic_v17`返回0 |
| 五张海岸地图独立地表 | `fcf765e7`、`148dcd22`、`540f1abc` | 保留玩家整包主题优先级；在未选择DLC时优先读取V14正式登记、V10生成的每地图256px地表/水面，而不将同一地区图集涂满全部地图，重点恢复洞窟独立水面 | **代码已提交，Godot回归未确认**；`148dcd22`对应主题兼容CI和Pixel Fantasy主题CI成功 |
| 缺失旧地砖的真实回退 | `7967df2b` | `WorldTilesetPool._verified_material_for`从已删V18材质目录迁移至当前V10源，保留构建可见opaque 8×8逻辑及碰撞不变 | **代码已提交，最新镇地面CI尚待确认** |
| 五Boss六状态动画回归 | `c3643f08` | 旧smoke错误要求Boss肖像Texture对象不变；现在动画图集由真实512×768 AtlasTexture接管，测试检查5个独立Boss源、原肖像安全保存、六状态序列和战斗shader | **代码已提交，最新Godot测试尚待确认** |

### 实际可复核美术运行证据

[Main2 Real Art Runtime Acceptance · run 40886321749](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40886321749) 在`e9a377b39b02c26e6ed8ca1889017424e3d0ded8`提交整体 **SUCCESS**，16个Godot真实资源/角色/场景冒烟均返回0，包括酒馆和收容所、晨露村大橡树、V18五地图与所有Boss动作源。该提交可能有非致命资源退出日志；“工作流成功”不等于商业视觉人工审美验收。

**注意后续跨线程修改**：同分支还有自动生成器并行改动。更后提交`7147b2d1`的同类美术CI失败，真实阻塞为Boss引入六状态动画后旧smoke仍要求静态纹理不变，已经在`c3643f08`修复测试；镇地面CI还因旧图集恢复仍引用已删除目录而失败，已在`7967df2b`修复运行源。后续各项必须以对应最新SHA重新判定，不能拿`e9a377b3`的成功代表最新全部通过。

### 仍未达成的硬门槛

1. 最新HEAD全套统一Main2 CI必须完整运行成功，不得只看被取消的旧运行。
2. 第一幕六章须经不作弊的实际玩家动作、村镇进出、收容所两项实地病例检查、第四章酒馆证据、第三章机关、第五章救援红旗/星锁、第六章灯塔灯芯、五Boss真实指令与V3回执逐项通过。
3. 全40地图/153室内必须有正常实际进退/布局/场景截图，不用静态地图展示替代。
4. 20职业、66Boss、120任务和72章逐项独立签收，最终人工美术/发行/平台真机回归尚未完成。


## Batch 0 续修：真实地面与第一幕推进（2026-10-29，本轮新增）

| 问题 | 直接修复 | 同SHA证据 |
|---|---|---|
| 已删除旧地砖导致部分城镇地面无可绘制回退 | `WorldTilesetPool`改为从V10材料构建32px×8×8地面/水面，保持真实TileMap与碰撞 | [run 40887466269](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40887466269)，`7967df2b` **SUCCESS** |
| Boss生成器升级后，旧美术测试误将真正六状态动画图集切换当成“身份图被替换” | `tools/smoke_main2_act01_live_boss_motion.gd`支持`generated_six_state_atlas`，强制检查五个真实512×768动画源、原始肖像安全保留、可切换攻击/受击/阶段/失败动画和shader反馈；无跳过Boss战斗 | `c3643f08` 已提交；**最新同SHA CI未确认** |
| 五张海岸地图原来都被通用地区地面图集覆盖，场景缺少真实区域差异 | `WorldTerrainAtlasRegistry`以V14已登记的每图V10地表与水面优先，Pixel Fantasy玩家整包主题仍优先，其他地区和缺失来源仍安全回退 | `fcf765e7`、`148dcd22`、`540f1abc` 已提交；主题兼容与Pixel Fantasy专项在`148dcd22`成功 |
| 每图V10地表缺少“沙地/可走道路/悬崖”语义区分 | `CCoherentTerrainMaterials.assemble`读取V10具名地形素材及材质源，按正式地形行重构8×8图集；四张地图进一步调整道路、沙地、峭壁明度，保留第3章洞窟的独立雕刻道路配色 | `1d53dd47`、`e98b5c21`、`4b7a76ba`；**最新美术CI待复核** |
| 第一幕正常通关两套检查在第2章卡住：真人必须进入收容所并检查病历，不可在街道直接触发Boss | `smoke_first_act_flow.gd`、`smoke_act01_six_chapters_normal.gd`在第2章使用真正`building:shelter`实体入口和`homeinspect:`互动，确认2份V3病例调查收据；第4章亦实际进入黑帆酒馆和核查两项真实证据，不伪造剧情/战斗胜利旗标 | `0cac996f`、`e3d06275` 已提交；**最新完整六章CI待复核** |

### 修复前的对照事实

- [旧统一Main2执行run 40887466268](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40887466268)：历史执行日志达到`54/56`，剩余`smoke_first_act_flow`和`smoke_act01_six_chapters_normal`，都在第二章收容所调查卡住；该流程最终因后续HEAD被取消，**不能当成最新HEAD全通过**。
- [原美术失败run 40887906421](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40887906421)：新地形V10图集里沙地/道路/悬崖仍没有明显区别，已做`4b7a76ba`进一步色彩角色修复，等待新SHA实跑。
- [原美术成功run 40886321749](https://github.com/chenyu9512/StarlitChronicle-HD2D/actions/runs/40886321749)：16项Godot美术专项通过仅对`e9a377b3`有效，不能将成功挪用到随后的Boss动画或地图改造提交。

未签收：第一幕真实无作弊六章全通、全部Boss战斗和奖励账本、玩家逐地图/室内人工验收、发行包在目标机实际操作与全游戏商业美术质量。下一批持续按**最新同SHA失败日志 → 正式运行代码 → 同SHA Godot验证 → 玩家画面**修复。
